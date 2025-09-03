# SwiftMetrics

A Metrics API package for Swift.

Almost all production server software needs to emit metrics information for observability. Because it's unlikely that all parties can agree on one specific metrics backend implementation, this API is designed to establish a standard that can be implemented by various metrics libraries which then post the metrics data to backends like [Prometheus](https://prometheus.io/), [Graphite](https://graphiteapp.org), publish over [statsd](https://github.com/statsd/statsd), write to disk, etc.

This is the beginning of a community-driven open-source project actively seeking contributions, be it code, documentation, or ideas. Apart from contributing to SwiftMetrics itself, we need metrics compatible libraries which send the metrics over to backend such as the ones mentioned above. What SwiftMetrics provides today is covered in the [API docs](https://apple.github.io/swift-metrics/), but it will continue to evolve with community input.

## Getting started

If you have a server-side Swift application, or maybe a cross-platform (e.g. Linux, macOS) application or library, and you would like to emit metrics, targeting this metrics API package is a great idea. Below you'll find all you need to know to get started.

### Adding the dependency

To add a dependency on the metrics API package, you need to declare it in your `Package.swift`:

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

###  Emitting metrics information

```swift
// 1) let's import the metrics API package
import Metrics

// 2) we need to create a concrete metric object, the label works similarly to a `DispatchQueue` label
let counter = Counter(label: "com.example.BestExampleApp.numberOfRequests")

// 3) we're now ready to use it
counter.increment()
```

### Selecting a metrics backend implementation (applications only)

Note: If you are building a library, you don't need to concern yourself with this section. It is the end users of your library (the applications) who will decide which metrics backend to use. Libraries should never change the metrics implementation as that is something owned by the application.

SwiftMetrics only provides the metrics system API. As an application owner, you need to select a metrics backend (such as the ones mentioned above) to make the metrics information useful.

Selecting a backend is done by adding a dependency on the desired backend client implementation and invoking the `MetricsSystem.bootstrap` function at the beginning of the program:

```swift
MetricsSystem.bootstrap(SelectedMetricsImplementation())
```

This instructs the `MetricsSystem` to install `SelectedMetricsImplementation` (actual name will differ) as the metrics backend to use.

As the API has just launched, not many implementations exist yet. If you are interested in implementing one see the "Implementing a metrics backend" section below explaining how to do so. List of existing SwiftMetrics API compatible libraries:

- [SwiftPrometheus](https://github.com/MrLotU/SwiftPrometheus), support for [Prometheus](https://prometheus.io)
- [StatsD Client](https://github.com/apple/swift-statsd-client), support for StatsD
- [OpenTelemetry Swift](https://github.com/open-telemetry/opentelemetry-swift), support for [OpenTelemetry](https://opentelemetry.io/) which also implements other metrics and tracing backends 
- Your library? [Get in touch!](https://forums.swift.org/c/server)

### Swift Metrics Extras

You may also be interested in some "extra" modules which are collected in the [Swift Metrics Extras](https://github.com/apple/swift-metrics-extras) repository.

## Detailed design

### Architecture

We believe that for the Swift on Server ecosystem, it's crucial to have a metrics API that can be adopted by anybody so a multitude of libraries from different parties can all provide metrics information. More concretely this means that we believe all the metrics events from all libraries should end up in the same place, be one of the backends mentioned above or wherever else the application owner may choose.

In the real world, there are so many opinions over how exactly a metrics system should behave, how metrics should be aggregated and calculated, and where/how to persist them. We think it's not feasible to wait for one metrics package to support everything that a specific deployment needs while still being simple enough to use and remain performant. That's why we decided to split the problem into two:

1. a metrics API
2. a metrics backend implementation

This package only provides the metrics API itself, and therefore, SwiftMetrics is a "metrics API package." SwiftMetrics can be configured (using `MetricsSystem.bootstrap`) to choose any compatible metrics backend implementation. This way, packages can adopt the API, and the application can choose any compatible metrics backend implementation without requiring any changes from any of the libraries.

This API was designed with the contributors to the Swift on Server community and approved by the SSWG (Swift Server Work Group) to the "sandbox level" of the SSWG's incubation process.

[pitch](https://forums.swift.org/t/metrics/19353) |
[discussion](https://forums.swift.org/t/discussion-server-metrics-api/) |
[feedback](https://forums.swift.org/t/feedback-server-metrics-api/)

### Metric types

The API supports six metric types:

`Counter`: A counter is a cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero on restart. For example, you can use a counter to represent the number of requests served, tasks completed, or errors.

```swift
counter.increment(by: 100)
```

- `FloatingPointCounter`: A variation of a `Counter` that records a floating point value, instead of an integer.

```swift
floatingPointCounter.increment(by: 10.5)
```

 `Gauge`: A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down. Gauges are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads. Gauges are modeled as a `Recorder` with a sample size of 1 that does not perform any aggregation.

```swift
gauge.record(100)
```

`Meter`: A Meter is similar to `Gauge` - a metric that represents a single numerical value that can arbitrarily go up and down. Meters are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads. Unlike `Gauge`, `Meter` also supports atomic increments and decrements.

```swift
meter.record(100)
```

`Recorder`: A recorder collects observations within a time window (usually things like response sizes) and *can* provide aggregated information about the data sample, for example count, sum, min, max and various quantiles.

```swift
recorder.record(100)
```

`Timer`: A timer collects observations within a time window (usually things like request duration) and provides aggregated information about the data sample, for example min, max and various quantiles. It is similar to a `Recorder` but specialized for values that represent durations.

```swift
timer.recordMilliseconds(100)
```

### Implementing a metrics backend (e.g. Prometheus client library)

Note: Unless you need to implement a custom metrics backend, everything in this section is likely not relevant, so please feel free to skip.

As seen above, each constructor for `Counter`, `Gauge`, `Meter`, `Recorder` and `Timer` provides a metric object. This uncertainty obscures the selected metrics backend calling these constructors by design. _Each application_ can select and configure its desired backend. The application sets up the metrics backend it wishes to use. Configuring the metrics backend is straightforward:

```swift
let metricsImplementation = MyFavoriteMetricsImplementation()
MetricsSystem.bootstrap(metricsImplementation)
```

This instructs the `MetricsSystem` to install `MyFavoriteMetricsImplementation` as the metrics backend (`MetricsFactory`) to use. This should only be done once at the beginning of the program.

Given the above, an implementation of a metric backend needs to conform to `protocol MetricsFactory`:

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

The `MetricsFactory` is responsible for instantiating the concrete metrics classes that capture the metrics and perform aggregation and calculation of various quantiles as needed.

**Counter**

```swift
public protocol CounterHandler: AnyObject {
    func increment(by: Int64)
    func reset()
}
```

**Meter**

```swift
public protocol MeterHandler: AnyObject {
    func set(_ value: Int64)
    func set(_ value: Double)
    func increment(by: Double)
    func decrement(by: Double)
}
```

**Recorder**

```swift
public protocol RecorderHandler: AnyObject {
    func record(_ value: Int64)
    func record(_ value: Double)
}
```

**Timer**

```swift
public protocol TimerHandler: AnyObject {
    func recordNanoseconds(_ duration: Int64)
}
```

#### Dealing with Overflows

Implementation of metric objects that deal with integers, like `Counter` and `Timer` should be careful with overflow. The expected behavior is to cap at `.max`, and never crash the program due to overflow . For example:

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

## Security

Please see [SECURITY.md](SECURITY.md) for details on the security process.

## Getting involved

Do not hesitate to get in touch as well, over on https://forums.swift.org/c/server
