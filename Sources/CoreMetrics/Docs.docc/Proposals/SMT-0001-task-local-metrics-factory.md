# SMT-0001: Task-local metrics factory

Enable task-local factory overrides for constructing metrics with different factories in different contexts.

## Overview

- Proposal: SMT-0001
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Ready for Implementation**
- Issue: [apple/swift-metrics#165](https://github.com/apple/swift-metrics/issues/165)
- Implementation:
  - [apple/swift-metrics#196](https://github.com/apple/swift-metrics/pull/196)
- Related links:
  - [Lightweight proposals process description](https://github.com/apple/swift-metrics/blob/main/Sources/CoreMetrics/Docs.docc/Proposals/Proposals.md)

### Introduction

Add task-local factory override for metrics to enable constructing metrics with different factories in different
contexts. The factory is captured at metric creation time and used for the metric's entire lifetime.

### Motivation

Applications often need to construct metrics with different factories in different contexts. While the global factory
via `MetricsSystem.bootstrap()` works for setting up one global factory per process, there are scenarios where context-specific
factory selection is required without polluting API boundaries with explicit factory parameters.

Testing is a particularly important use case of context-specific factory selection. Applications have complex business
logic spread across multiple layers. Testing this code requires verifying that it creates and reports metrics
correctly, but testing code that creates and emits metrics currently requires adopting one of the sub-optimal approaches.

1. Bootstrapping a test factory globally, which does not allow using different factories in different components of the system and prevents parallel test execution:

```swift
struct UserService {
    let counter = Counter(label: "users.created")  // ❌ Relies on the global state

    func createUser(name: String) async throws -> User {
        let user = User()
        counter.increment()
        return user
    }
}

@Test
func testUserCreation() async throws {
    let testMetrics = TestMetrics()
    MetricsSystem.bootstrap(testMetrics)  // ❌ Changes the global state

    let service = UserService()
    _ = try await service.createUser(name: "Alice")

    let counter = try testMetrics.expectCounter("users.created")
    #expect(counter.values == [1])
}
```

2. Passing factory explicitly through the API boundaries, which pollutes the API:

```swift
struct UserService {
    let counter: Counter

    init(metricsFactory: MetricsFactory) {  // ❌ Required for dependency injection
        self.counter = Counter(label: "users.created", factory: metricsFactory)
    }

    func createUser(name: String) async throws -> User {
        let user = User()
        counter.increment()
        return user
    }
}

@Test
func testUserCreation() async throws {
    let testMetrics = TestMetrics()

    let service = UserService(metricsFactory: testMetrics)  // ❌ Required for dependency injection
    _ = try await service.createUser(name: "Alice")

    let counter = try testMetrics.expectCounter("users.created")
    #expect(counter.values == [1])
}
```

### Proposed solution

Add `withMetricsFactory(_:)` free function that binds a factory to task-local context. Metrics created
within this context use the task-local factory instead of the global factory. This enables context-specific factory
selection without global state or API pollution.

#### Usage pattern: testing with isolated factories

```swift
struct UserService {
    let counter = Counter(label: "users.created")  // ✅ Gets factory from the task-local storage

    func createUser(name: String) async throws -> User {
        let user = User()
        counter.increment()
        return user
    }
}

@Test
func testUserCreation() async throws {
    let testMetrics1 = TestMetrics()
    let testMetrics2 = TestMetrics()

    async let user1 = withMetricsFactory(testMetrics1) {
        let service = UserService()
        return try await service.createUser(name: "Alice")
    }

    async let user2 = withMetricsFactory(testMetrics2) {
        let service = UserService()
        return try await service.createUser(name: "Bob")
    }

    _ = try await (user1, user2)

    #expect(try testMetrics1.expectCounter("users.created").values == [1])
    #expect(try testMetrics2.expectCounter("users.created").values == [1])
}
```

#### Correct metrics usage pattern

This proposal does not change the correct pattern for creating and using metrics.

Metrics objects should be created **once**, with pre-defined labels and dimensions known at initialization time, and
reused for the lifetime of the component. Creating new metric objects on every request or operation is an antipattern:

- It can lead to **unbounded memory allocation** if the labels or dimensions are unbounded (e.g. per-request IDs),
  causing unbounded cardinality in the metrics backend.
- It is **slow** and can become a bottleneck for fast parallel execution, since metric creation typically involves
  factory synchronization and backend registration.

```swift
// ❌ Creating metrics on demand — unbounded allocation and unbounded cardinality when dimensions vary per-request
func handleRequest(requestID: String) {
    let counter = Counter(label: "requests", dimensions: [("request_id", requestID)])
    counter.increment()
}

// ✅ Create metrics once during setup with fixed dimensions and reuse them
struct RequestHandler {
    let requestCounter = Counter(label: "requests")

    func handleRequest(requestID: String) {
        requestCounter.increment()
    }
}
```

Task-local factory is scoped to the initialization block: the factory override is only active for the duration of
the `withMetricsFactory(_:)` closure, without touching the global state. Any metrics created outside that scope will
not see the task-local factory and will fall back to the global one. If the application has not bootstrapped a global
factory, such metrics will fail to initialize, providing a safeguard against accidentally creating metrics outside of
the designated setup scope.

```swift
struct UserService {
    let counter: Counter

    init() {
        // ✅ Created during init — picks up the task-local factory
        self.counter = Counter(label: "users.created")
    }

    func createUser(name: String) async throws -> User {
        // ❌ Created on demand — task-local factory is no longer in scope,
        //    falls back to global; fails if global is not bootstrapped
        let onDemandCounter = Counter(label: "users.created.on_demand")
        let user = User()
        self.counter.increment()
        return user
    }
}

@Test
func testUserCreation() async throws {
    let testMetrics = TestMetrics()

    // The task-local factory is only active inside this block
    let service = withMetricsFactory(testMetrics) {
        UserService()  // counter is created here — uses testMetrics
    }

    // service.createUser() runs outside the withMetricsFactory scope,
    // so onDemandCounter inside it will NOT use testMetrics
    _ = try await service.createUser(name: "Alice")

    #expect(try testMetrics.expectCounter("users.created").values == [1])
}
```

#### Factory selection priority

When creating a metric, the factory is chosen in this order:

1. **Explicit `factory` parameter** (if provided) - highest priority.
2. **Task-local factory** via `withMetricsFactory(_:)` (if present).
3. **Global factory** via `MetricsSystem.bootstrap()` - fallback.

The factory is captured at creation time and stored in the metric for its entire lifetime. This semantic ensures
metrics have a stable factory reference for their lifetime, avoiding confusion about which backend receives metric updates.

## Detailed design

### Public API additions

This proposal adds task-local factory support through `withMetricsFactory(_:)` free functions.

#### Core functions

```swift
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
///     let service = await withMetricsFactory(testFactory) {
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
///     async let result1 = withMetricsFactory(factory1) {
///         let service = RequestService()
///         return service.handleRequest()
///     }
///
///     async let result2 = withMetricsFactory(factory2) {
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
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
@inlinable
public func withMetricsFactory<Result, Failure: Error>(
    _ factory: MetricsFactory,
    _ operation: () throws(Failure) -> Result
) throws(Failure) -> Result

/// Runs the given async closure with a factory bound to the task-local context.
///
/// Async variant of `withMetricsFactory(_:_:)`. See that function for detailed documentation.
///
/// - Parameters:
///   - factory: The metrics factory to use for metric creation within the closure.
///   - operation: The async closure to execute with the factory bound.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
@inlinable
nonisolated(nonsending)
public func withMetricsFactory<Result, Failure: Error>(
    _ factory: MetricsFactory,
    _ operation: nonisolated(nonsending) () async throws(Failure) -> Result
) async throws(Failure) -> Result
```

#### currentFactory property

`MetricsSystem.currentFactory` exposes the active factory for the current task, allowing callers to pass it
explicitly to APIs that require a factory parameter:

```swift
extension MetricsSystem {
    /// Accesses the current factory for the task-local context.
    ///
    /// Returns the task-local factory if one is bound via `withMetricsFactory(_:)`, otherwise returns
    /// the global factory. This is useful for passing the current factory to APIs that expect an explicit factory
    /// parameter.
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
    /// withMetricsFactory(testFactory) {
    ///     // Pass current factory to API expecting explicit parameter
    ///     let counter = createMetricWithExplicitFactory(
    ///         label: "requests",
    ///         factory: MetricsSystem.currentFactory
    ///     )
    /// }
    /// ```
    ///
    /// - Returns: The task-local factory if bound, otherwise the global factory.
    @inlinable
    public static var currentFactory: MetricsFactory { get }
}
```

### Metric initialization changes

All metric types (`Counter`, `Timer`, `Gauge`, `Meter`, `Recorder`, `FloatingPointCounter`) delegate to
`MetricsSystem.currentFactory` at initialization, which returns the task-local factory when one is bound:

```swift
public convenience init(label: String, dimensions: [(String, String)] = []) {
    self.init(label: label, dimensions: dimensions, factory: MetricsSystem.currentFactory)
}
```

### API stability

This is a purely additive change with no breaking impact.

**Platform requirements**: Task-local functionality requires macOS 10.15+, iOS 13.0+, watchOS 6.0+, tvOS 13.0+ due to
the use of `@TaskLocal` property wrappers.

**Existing metrics backend implementations**: backends continue to work unchanged. No changes required to existing
`MetricsFactory` implementations.

**Existing users of Metrics**: all existing `Counter`, `Timer`, `Gauge`, `Meter`, and `Recorder` APIs remain
unchanged. Code that creates and uses metrics without task-local context continues to work with minimal impact.

Libraries can adopt task-local factory gradually:

```swift
// Old style - still works
MetricsSystem.bootstrap(myFactory)
let counter = Counter(label: "requests")

// New style for testing - opt-in
@Test
func test() async {
    let testFactory = TestMetrics()
    let counter = await withMetricsFactory(testFactory) {
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

#### Alternative 3: put withMetricsFactory into MetricsSystem

Expose `withMetricsFactory(_:_:)` as static methods on `MetricsSystem` rather than free functions:

```swift
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension MetricsSystem {
    public static func withMetricsFactory<Result, Failure: Error>(
        _ factory: MetricsFactory,
        _ operation: () throws(Failure) -> Result
    ) throws(Failure) -> Result

    public static func withMetricsFactory<Result, Failure: Error>(
        _ factory: MetricsFactory,
        _ operation: () async throws(Failure) -> Result
    ) async throws(Failure) -> Result
}
```

Usage would look like:

```swift
MetricsSystem.withMetricsFactory(testFactory) {
    Counter(label: "requests")
}
```

**Advantages**:

- Consistent with other `MetricsSystem` configuration API (`bootstrap`, `factory`).
- No additional symbols in the module's top-level namespace.

**Disadvantages**:

- **Requires knowledge of MetricsSystem**: `MetricsSystem` is an application-author API for bootstrapping the metrics
  backend. Metrics users — library authors and application code that creates counters, timers, and gauges — typically
  do not interact with `MetricsSystem` directly. Requiring them to know about it to write tests is an unnecessary
  coupling.
- **Inconsistent with distributed-tracing**: `swift-distributed-tracing` exposes context-scoping functions such as
  `withSpan(...)` as top-level free functions, not as methods on `InstrumentationSystem`. Following the same
  convention makes the two packages easier to use together and lowers the learning curve.

**Decision**: rejected in favor of free functions following the `swift-distributed-tracing` precedent and keeping
`MetricsSystem` as an application-author concern.
