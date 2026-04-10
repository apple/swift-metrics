# ``CoreMetrics``

A Metrics API package for Swift.

## Overview

Almost all production server software needs to emit metrics information for observability. Because it's unlikely that
all parties can agree on one specific metrics backend implementation, this API is designed to establish a standard that
can be implemented by various metrics libraries which then post the metrics data to backends like
[Prometheus](https://prometheus.io/), [Graphite](https://graphiteapp.org), publish over
[statsd](https://github.com/statsd/statsd), write to disk, and so on.

This is a community-driven open-source project that actively seeks contributions, be it code, documentation, or ideas.
Apart from contributing to SwiftMetrics itself, the project needs metrics-compatible libraries which send the metrics
over to backend systems such as the ones mentioned above.
What SwiftMetrics provides today is covered in the [API docs](https://apple.github.io/swift-metrics/), and evolves with
community input.

### Getting started

If you have a server-side Swift application, or maybe a cross-platform (for example, Linux and macOS) application or
library, and you would like to emit metrics, targeting this metrics API package is a great idea.
Below you'll find all you need to know to get started.

### Adding the dependency

To add a dependency on the metrics API package, declare it in your `Package.swift`:

```swift
// swift-metrics 1.x and 2.x are almost API compatible, so most clients should use
.package(url: "https://github.com/apple/swift-metrics.git", "1.0.0" ..< "3.0.0"),
```

and to your application/library target, add "Metrics" to your dependencies:

```swift
.target(
    name: "BestExampleApp",
    dependencies: [
        // ...
        .product(name: "Metrics", package: "swift-metrics"),
    ]
),
```

### Emitting metrics information

```swift
// 1) Import the metrics API package.
import Metrics

// 2) Create a concrete metric object, the label works similarly to a `DispatchQueue` label.
let counter = Counter(label: "com.example.BestExampleApp.numberOfRequests")

// 3) Use the metric.
counter.increment()
```

### Correct metrics usage

Create metric objects **once** with pre-defined labels and dimensions known at initialization time, and reuse them for
the lifetime of the component. Creating new metric objects on every request or operation is an antipattern:

- It can lead to **unbounded memory allocation** if the labels or dimensions are unbounded (for example, per-request
  IDs), causing unbounded cardinality in the metrics backend.
- It is **slow** and can become a bottleneck for fast parallel execution, since metric creation typically involves
  factory synchronization and backend registration.

```swift
// ❌ Creating metrics on demand — unbounded cardinality when dimensions vary per-request
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

When you use a scoped factory override — such as `withMetricsFactory(_:)` for testing — the factory is only active for
the duration of the closure. Any metrics created outside that scope do not see the overridden factory and fall back to
the global one. If no global factory has been bootstrapped, such metrics fail to initialize, providing a safeguard
against creating metrics outside of the designated setup scope.

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

### Selecting a metrics backend implementation (applications only)

> Note: If you are building a library, you don't need to concern yourself with this section. It is the end users of your
> library (the applications) who decide which metrics backend to use. Libraries should never change the metrics
> implementation, as that choice is owned by the application.

SwiftMetrics only provides the metrics system API. As an application owner, you choose a metrics backend (such as the
ones mentioned above) to make the metrics information useful.

Select a backend by adding a dependency on the desired backend client implementation and invoking the
`MetricsSystem.bootstrap` function at the beginning of your program:

```swift
MetricsSystem.bootstrap(SelectedMetricsImplementation())
```

This instructs the `MetricsSystem` to install `SelectedMetricsImplementation` (the actual name will differ) as the
metrics backend to use.

> Tip: Refer to the project's [README](https://github.com/apple/swift-metrics) for an up-to-date list of backend
> implementations.

### API architecture

For the Swift on Server ecosystem, it's crucial to have a metrics API that can be adopted by anybody so a multitude of
libraries from different parties can provide metrics information. More concretely, all the metrics events from all
libraries should end up in the same place: one of the backends mentioned above or wherever the application owner chooses.

There are so many opinions over how exactly a metrics system should behave, how metrics should be aggregated and
calculated, and where/how to persist them that it's not feasible to wait for one metrics package to support everything
while still being simple enough to use and remain performant. For this reason, the problem is split into two parts:

1. a metrics API
2. a metrics backend implementation

This package only provides the metrics API, and therefore, SwiftMetrics is a "metrics API package."
SwiftMetrics can be configured (using `MetricsSystem.bootstrap`) to use any compatible metrics backend implementation.
This mechanism allows libraries to adopt the API and support the application choosing a compatible backend implementation
without requiring any changes to the libraries.

This API was designed with the contributors to the Swift on Server community and approved by the SSWG (Swift Server Work
Group) to the "sandbox level" of the SSWG's incubation process.

[pitch](https://forums.swift.org/t/metrics/19353) |
[discussion](https://forums.swift.org/t/discussion-server-metrics-api/) |
[feedback](https://forums.swift.org/t/feedback-server-metrics-api/)

### Implementing a metrics backend

> Note: Unless you need to implement a custom metrics backend, everything in this section is likely not relevant, so feel
> free to skip it.

Each constructor for ``Counter``, ``Gauge``, ``Meter``, ``Recorder``, and ``Timer`` provides a metric object. This
uncertainty obscures the selected metrics backend calling these constructors by design. _Each application_ selects and
configures its desired backend. Configure the metrics backend like this:

```swift
let metricsImplementation = MyFavoriteMetricsImplementation()
MetricsSystem.bootstrap(metricsImplementation)
```

This instructs the ``MetricsSystem`` to install `MyFavoriteMetricsImplementation` as the ``MetricsFactory`` to use. Do
this only once at the beginning of your program.

An implementation of a metric backend needs to conform to ``MetricsFactory``:

```swift
public protocol MetricsFactory {
    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler
    func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler
    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler

    func destroyCounter(_ handler: CounterHandler)
    func destroyMeter(_ handler: MeterHandler)
    func destroyRecorder(_ handler: RecorderHandler)
    func destroyTimer(_ handler: TimerHandler)
}
```

The ``MetricsFactory`` is responsible for instantiating the concrete metrics classes that capture the metrics and perform
aggregation and calculation of various quantiles as needed.

**CounterHandler**

```swift
public protocol CounterHandler: AnyObject {
    func increment(by: Int64)
    func reset()
}
```

**MeterHandler**

```swift
public protocol MeterHandler: AnyObject {
    func set(_ value: Int64)
    func set(_ value: Double)
    func increment(by: Double)
    func decrement(by: Double)
}
```

**RecorderHandler**

```swift
public protocol RecorderHandler: AnyObject {
    func record(_ value: Int64)
    func record(_ value: Double)
}
```

**TimerHandler**

```swift
public protocol TimerHandler: AnyObject {
    func recordNanoseconds(_ duration: Int64)
}
```

#### Dealing with overflows

Implementations of metric objects that deal with integers, like ``Counter`` and ``Timer``, should be careful with
overflow. The expected behavior is to cap at `.max`, and never crash the program due to overflow. For example:

```swift
class ExampleCounter: CounterHandler {
    var value: Int64 = 0
    func increment(by amount: Int64) {
        let result = self.value.addingReportingOverflow(amount)
        if result.overflow {
            self.value = Int64.max
        } else {
            self.value = result.partialValue
        }
    }
}
```

#### Full example

Here is a full, but contrived, example of an in-memory implementation:

```swift
class SimpleMetricsLibrary: MetricsFactory {
    init() {}

    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return ExampleCounter(label, dimensions)
    }

    func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        return ExampleMeter(label, dimensions)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        return ExampleRecorder(label, dimensions, aggregate)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return ExampleTimer(label, dimensions)
    }

    // implementation is stateless, so nothing to do on destroy calls
    func destroyCounter(_ handler: CounterHandler) {}
    func destroyMeter(_ handler: TimerHandler) {}
    func destroyRecorder(_ handler: RecorderHandler) {}
    func destroyTimer(_ handler: TimerHandler) {}

    private class ExampleCounter: CounterHandler {
        init(_: String, _: [(String, String)]) {}

        let lock = NSLock()
        var value: Int64 = 0
        func increment(by amount: Int64) {
            self.lock.withLock {
                self.value += amount
            }
        }

        func reset() {
            self.lock.withLock {
                self.value = 0
            }
        }
    }

    private class ExampleMeter: MeterHandler {
        init(_: String, _: [(String, String)]) {}

        let lock = NSLock()
        var _value: Double = 0

        func set(_ value: Int64) {
            self.set(Double(value))
        }

        func set(_ value: Double) {
            self.lock.withLock { _value = value }
        }

        func increment(by value: Double) {
            self.lock.withLock { self._value += value }
        }

        func decrement(by value: Double) {
            self.lock.withLock { self._value -= value }
        }
    }

    private class ExampleRecorder: RecorderHandler {
        init(_: String, _: [(String, String)], _: Bool) {}

        private let lock = NSLock()
        var values = [(Int64, Double)]()
        func record(_ value: Int64) {
            self.record(Double(value))
        }

        func record(_ value: Double) {
            // TODO: sliding window
            lock.withLock {
                values.append((Date().nanoSince1970, value))
                self._count += 1
                self._sum += value
                self._min = Swift.min(self._min, value)
                self._max = Swift.max(self._max, value)
            }
        }

        var _sum: Double = 0
        var sum: Double {
            return self.lock.withLock { _sum }
        }

        private var _count: Int = 0
        var count: Int {
            return self.lock.withLock { _count }
        }

        private var _min: Double = 0
        var min: Double {
            return self.lock.withLock { _min }
        }

        private var _max: Double = 0
        var max: Double {
            return self.lock.withLock { _max }
        }
    }

    private class ExampleTimer: TimerHandler {
        init(_: String, _: [(String, String)]) {}

        let lock = NSLock()
        var _value: Int64 = 0

        func recordNanoseconds(_ duration: Int64) {
            self.lock.withLock { _value = duration }
        }
    }
}
```

### Related libraries

[swift-system-metrics](https://github.com/apple/swift-system-metrics) uses the Metrics API to emit system resource
metrics such as CPU, memory, and file descriptors, providing insight into your application's resource consumption.

## Topics

### Metric types

``Counter`` is a cumulative metric that represents a single monotonically increasing counter whose value can only
increase or be reset to zero on restart. Use a counter to represent the number of requests served, tasks completed, or
errors.

```swift
counter.increment(by: 100)
```

``FloatingPointCounter`` is a variation of a ``Counter`` that records a floating point value instead of an integer.

```swift
floatingPointCounter.increment(by: 10.5)
```

``Gauge`` is a metric that represents a single numerical value that can arbitrarily go up and down. Gauges are typically
used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the
number of active threads. Gauges are modeled as a ``Recorder`` with a sample size of 1 that does not perform any
aggregation.

```swift
gauge.record(100)
```

``Meter`` is similar to ``Gauge`` — a metric that represents a single numerical value that can arbitrarily go up and
down. Meters are typically used for measured values like temperatures or current memory usage, but also "counts" that can
go up and down, like the number of active threads. Unlike ``Gauge``, ``Meter`` also supports atomic increments and
decrements.

```swift
meter.record(100)
```

``Recorder`` collects observations within a time window (usually things like response sizes) and *can* provide
aggregated information about the data sample, for example count, sum, min, max and various quantiles.

```swift
recorder.record(100)
```

``Timer`` collects observations within a time window (usually things like request duration) and provides aggregated
information about the data sample, for example min, max and various quantiles. It is similar to a ``Recorder`` but
specialized for values that represent durations.

```swift
timer.recordMilliseconds(100)
```

- ``Counter``
- ``FloatingPointCounter``
- ``Meter``
- ``Gauge``
- ``Recorder``
- ``Timer``

### Metrics Handlers

- ``CounterHandler``
- ``FloatingPointCounterHandler``
- ``MeterHandler``
- ``RecorderHandler``
- ``TimerHandler``
- ``MultiplexMetricsHandler``
- ``NOOPMetricsHandler``

### Bootstrapping

- ``MetricsFactory``
- ``MetricsSystem``

### Supporting Types

- ``TimeUnit``

### Contribute to the project

- <doc:Proposals>
