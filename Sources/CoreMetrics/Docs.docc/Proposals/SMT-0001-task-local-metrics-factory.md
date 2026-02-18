# SMT-0001: Task-local metrics factory

Enable task-local factory overrides for testing metrics creation in complex code and dependencies.

## Overview

- Proposal: SMT-0001
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: [apple/swift-metrics#165](https://github.com/apple/swift-metrics/issues/165)
- Implementation:
  - [apple/swift-metrics#196](https://github.com/apple/swift-metrics/pull/196)
- Related links:
  - [Lightweight proposals process description](https://github.com/apple/swift-metrics/blob/main/Sources/CoreMetrics/Docs.docc/Proposals/Proposals.md)

### Introduction

Add task-local factory override for metrics to enable testing code that creates and emits metrics without global state
pollution. The factory is captured at metric creation time and used for the metric's entire lifetime.

### Motivation

Testing code that creates and emits metrics currently requires either:

- Bootstrapping a test factory globally, which prevents parallel test execution and pollutes test state across tests.
- Passing factory explicitly through the API boundaries, which pollutes API of internal methods and libraries.

#### Testing complex code with metrics

Applications have complex business logic spread across multiple layers (handlers, services, repositories). Testing
this code requires verifying that it creates and reports metrics correctly.

```swift
struct UserService {
    let repository: UserRepository

    func createUser(name: String) async throws -> User {
        let counter = Counter(label: "users.created")
        let timer = Timer(label: "users.create.duration")

        let user = try await timer.measure {
            try await repository.create(name: name)
        }

        counter.increment()
        return user
    }
}

@Test
func testUserCreation() async throws {
    let testMetrics = TestMetrics()
    MetricsSystem.bootstrap(testMetrics)  // ❌ Affects global state

    let service = UserService(repository: InMemoryRepository())
    _ = try await service.createUser(name: "Alice")

    let counter = try testMetrics.expectCounter("users.created")
    #expect(counter.values == [1])
}
```

The global bootstrap approach has critical problems:

1. **No parallel test execution**: Tests must run serially to avoid factory conflicts.
2. **State pollution**: One test's metrics leak into another test's factory.
3. **Test isolation**: Cannot test multiple components with different metric backends simultaneously.

#### API pollution with explicit factory parameters

To enable testing without global state, you might add explicit factory parameters to all APIs. This pollutes every
method signature with testing infrastructure.

```swift
struct UserRepository {
    func create(name: String, factory: MetricsFactory) async throws -> User {
        let timer = Timer(label: "db.query.duration", factory: factory)
        return try await timer.measure {
            // Database operation
        }
    }

    func find(id: UUID, factory: MetricsFactory) async throws -> User? {
        let counter = Counter(label: "db.queries", factory: factory)
        defer { counter.increment() }
        // Database operation
    }
}

struct UserService {
    let repository: UserRepository
    let factory: MetricsFactory  // ❌ Required for dependency injection

    func createUser(name: String) async throws -> User {
        let counter = Counter(label: "users.created", factory: factory)
        let user = try await repository.create(name: name, factory: factory)  // ❌ Must pass factory
        counter.increment()
        return user
    }

    func getUser(id: UUID) async throws -> User? {
        try await repository.find(id: id, factory: factory)  // ❌ Must pass factory
    }
}

struct UserHandler {
    let service: UserService

    func handleRequest() async throws {
        let user = try await service.createUser(name: "Alice")
        // ...
    }
}

// Now testing requires factory threading through every layer
@Test
func testUserHandler() async throws {
    let testMetrics = TestMetrics()
    let repository = UserRepository()
    let service = UserService(repository: repository, factory: testMetrics)  // ❌ Constructor pollution
    let handler = UserHandler(service: service)

    try await handler.handleRequest()

    let counter = try testMetrics.expectCounter("users.created")
    #expect(counter.values == [1])
}
```

Problems with this approach:

1. **API pollution**: Every method that creates metrics needs a factory parameter.
2. **Constructor pollution**: Every type that creates metrics needs factory stored as property.
3. **Threading through layers**: Factory must be passed through entire call stack.
4. **Breaking change**: Adding metrics to existing code requires changing all method signatures.

### Proposed solution

Add `MetricsSystem.with(factory:)` method that binds a factory to task-local context. Metrics created within this
context use the task-local factory instead of the global factory.

#### Usage pattern: factory override for testing

```swift
@Test
func testUserCreation() async throws {
    let testMetrics = TestMetrics()

    // Factory bound to task-local context - no global state
    let service = await Metrics.with(factory: testMetrics) {
        UserService(repository: InMemoryRepository())
    }

    _ = try await service.createUser(name: "Alice")

    let counter = try testMetrics.expectCounter("users.created")
    #expect(counter.values == [1])
}

@Test
func testConcurrentUserCreation() async throws {
    let testMetrics1 = TestMetrics()
    let testMetrics2 = TestMetrics()

    // Two tests run in parallel with isolated factories
    async let user1 = Metrics.with(factory: testMetrics1) {
        let service = UserService(repository: InMemoryRepository())
        return try await service.createUser(name: "Alice")
    }

    async let user2 = Metrics.with(factory: testMetrics2) {
        let service = UserService(repository: InMemoryRepository())
        return try await service.createUser(name: "Bob")
    }

    _ = try await (user1, user2)

    // Each factory has isolated metrics
    #expect(try testMetrics1.expectCounter("users.created").values == [1])
    #expect(try testMetrics2.expectCounter("users.created").values == [1])
}
```

#### Factory selection priority

When creating a metric, the factory is chosen in this order:

1. **Explicit `factory` parameter** (if provided) - highest priority.
2. **Task-local factory** via `with(factory:)` (if present).
3. **Global factory** via `MetricsSystem.bootstrap()` - fallback.

The factory is captured at creation time and stored in the metric for its entire lifetime.

#### Factory behavior: creation time only

```swift
let testFactory = TestMetrics()
let productionFactory = ProductionMetrics()

// Factory captured at creation
let counter = Metrics.with(factory: testFactory) {
    Counter(label: "requests")  // Uses testFactory
}

// Task-local factory at operation time is ignored
Metrics.with(factory: productionFactory) {
    counter.increment()  // Still uses testFactory (captured at creation)
}
```

This semantic ensures metrics have a stable factory reference for their lifetime, avoiding confusion about which
backend receives metric updates.

## Detailed design

### Public API additions

This proposal adds task-local factory support through `MetricsSystem.with(factory:)` methods and a convenience
typealias.

#### Core methods

```swift
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension MetricsSystem {
    /// Runs the given closure with a factory bound to the task-local context.
    ///
    /// Metrics created within the closure will use the specified factory instead of the global factory. The factory
    /// is captured at metric creation time and used for the metric's entire lifetime.
    ///
    /// ## Example: Testing with isolated factory
    ///
    /// ```swift
    /// @Test
    /// func testRequestHandling() async {
    ///     let testFactory = TestMetrics()
    ///     let service = await Metrics.with(factory: testFactory) {
    ///         RequestService()  // Creates metrics using testFactory
    ///     }
    ///
    ///     service.handleRequest()
    ///
    ///     let counter = try testFactory.expectCounter("requests")
    ///     #expect(counter.values == [1])
    /// }
    /// ```
    ///
    /// ## Example: Parallel tests with isolated factories
    ///
    /// ```swift
    /// @Test
    /// func testParallelRequests() async {
    ///     let factory1 = TestMetrics()
    ///     let factory2 = TestMetrics()
    ///
    ///     async let result1 = Metrics.with(factory: factory1) {
    ///         let service = RequestService()
    ///         return service.handleRequest()
    ///     }
    ///
    ///     async let result2 = Metrics.with(factory: factory2) {
    ///         let service = RequestService()
    ///         return service.handleRequest()
    ///     }
    ///
    ///     _ = try await (result1, result2)
    ///
    ///     // Each factory has isolated metrics
    ///     #expect(try factory1.expectCounter("requests").values == [1])
    ///     #expect(try factory2.expectCounter("requests").values == [1])
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - factory: The metrics factory to use for metric creation within the closure.
    ///   - operation: The closure to execute with the factory bound.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func with<Result, Failure: Error>(
        factory: MetricsFactory,
        _ operation: () throws(Failure) -> Result
    ) rethrows -> Result

    /// Runs the given async closure with a factory bound to the task-local context.
    ///
    /// Async variant of `with(factory:_:)`. See that method for detailed documentation.
    ///
    /// - Parameters:
    ///   - factory: The metrics factory to use for metric creation within the closure.
    ///   - operation: The async closure to execute with the factory bound.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func with<Result, Failure: Error>(
        factory: MetricsFactory,
        _ operation: () async throws(Failure) -> Result
    ) async rethrows -> Result

    /// Accesses the current factory for the task-local context.
    ///
    /// Returns the task-local factory if one is bound via `with(factory:)`, otherwise returns the global factory.
    /// This is useful for passing the current factory to APIs that expect an explicit factory parameter.
    ///
    /// ## Example: Passing current factory to explicit API
    ///
    /// ```swift
    /// // Library API that requires explicit factory
    /// func createMetricWithExplicitFactory(label: String, factory: MetricsFactory) -> Counter {
    ///     Counter(label: label, factory: factory)
    /// }
    ///
    /// // Usage with task-local factory
    /// Metrics.with(factory: testFactory) {
    ///     // Pass current factory to API expecting explicit parameter
    ///     let counter = createMetricWithExplicitFactory(
    ///         label: "requests",
    ///         factory: MetricsSystem.currentFactory
    ///     )
    /// }
    /// ```
    ///
    /// - Returns: The task-local factory if bound, otherwise the global factory.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public static var currentFactory: MetricsFactory { get }
}
```

#### Convenience typealias

```swift
/// A shorter alias for `MetricsSystem` for more ergonomic API usage.
///
/// This typealias allows using `Metrics.with(...)` instead of `MetricsSystem.with(...)`:
///
/// ```swift
/// Metrics.with(factory: testFactory) {
///     Counter(label: "requests")
/// }
/// ```
public typealias Metrics = MetricsSystem
```

### Metric initialization changes

All metric types (`Counter`, `Timer`, `Gauge`, `Meter`, `Recorder`, `FloatingPointCounter`) check for task-local
factory at initialization:

```swift
public convenience init(label: String, dimensions: [(String, String)] = []) {
    let factory: MetricsFactory
    if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
        factory = MetricsSystem._taskLocalFactory ?? MetricsSystem.factory
    } else {
        factory = MetricsSystem.factory
    }
    self.init(label: label, dimensions: dimensions, factory: factory)
}
```

### API stability

This is a purely additive change with no breaking impact.

**Platform requirements**: Task-local functionality requires macOS 10.15+, iOS 13.0+, watchOS 6.0+, tvOS 13.0+ due to
the use of `@TaskLocal` property wrappers.

**Existing metrics backend implementations**: backends continue to work unchanged. No changes required to existing
`MetricsFactory` implementations.

**Existing users of Metrics**: all existing `Counter`, `Timer`, `Gauge`, `Meter`, and `Recorder` APIs remain
unchanged. Code that creates and uses metrics without task-local context continues to work with zero impact.

Libraries can adopt task-local factory gradually:

```swift
// Old style - still works
MetricsSystem.bootstrap(myFactory)
let counter = Counter(label: "requests")

// New style for testing - opt-in
@Test
func test() async {
    let testFactory = TestMetrics()
    let counter = await Metrics.with(factory: testFactory) {
        Counter(label: "requests")
    }
}
```

### Future directions

A future proposal will add structured task-local dimensions propagation.

### Alternatives considered

#### Alternative 1: global factory stack

Add push/pop methods to maintain a stack of factories:

```swift
MetricsSystem.pushFactory(testFactory)
defer { MetricsSystem.popFactory() }
```

**Advantages**:

- Works with older Swift versions without task-local support.
- Explicit push/pop makes factory lifecycle clear.

**Disadvantages**:

- **Not thread-safe**: Requires manual synchronization for concurrent tests.
- **Error-prone**: Forgetting `defer` leaves factory stack corrupted.
- **No structured concurrency**: Does not compose with async/await patterns.
- **Global state**: Still pollutes global state, just with a stack instead of a single value.

**Decision**: rejected because it does not solve the core problem of global state and parallel test execution.

#### Alternative 2: dependency injection pattern

Require explicit factory injection:

```swift
struct UserService {
    let factory: MetricsFactory

    func createUser(name: String) async throws -> User {
        let counter = Counter(label: "users.created", factory: factory)
        // ...
    }
}
```

**Advantages**:

- Explicit dependencies.
- No task-local state.
- Works with older Swift versions.

**Disadvantages**:

- **Breaking change**: requires modifying all types that create metrics.
- **Verbose**: every type must store and pass factory.
- **Poor composability**: deep call stacks require factory threading through many layers.
- **Does not help with dependencies**: Cannot control factory used by third-party libraries.

**Decision**: rejected because this is a breaking change for all existing code and does not solve the dependency
testing problem.
