# swift-metrics

A Metrics API package for Swift.

Almost all production server software needs to emit metrics information for observability. Because it's unlikely that all parties can agree on one specific metrics backend implementation, this API is designed to establish a standard that can be implemented by various metrics libraries which then post the metrics data to backends like [Prometheus](http://prometheus.io/), [Grafana](http://grafana.com/), publish over [statsd](https://github.com/statsd/statsd), write to disk, etc.

This is the beginning of a community-driven open-source project actively seeking contributions, be it code, documentation, or ideas. Apart from contributing to swift-metrics itself, we need metrics compatible libraries which send the metrics over to backend such as the ones mentioned above.

What swift-metrics provides today is covered in the [API docs](https://apple.github.io/swift-metrics/). At this moment, we have not tagged a version for swift-metrics, but we will do so soon.

## Getting started

If you have a server-side Swift application, or maybe a cross-platform (e.g. Linux, macOS) application or library, and you would like to emit metrics, targeting this metrics API package is a great idea. Below you'll find all you need to know to get started.

### Adding the dependency

To add a dependency on the metrics API package, you need to declare it in your `Package.swift`:

```swift
// it's early days here so we haven't tagged a version yet, but will soon
.package(url: "https://github.com/apple/swift-metrics.git", .branch("master")),
```

and to your application/library target, add "Metrics" to your dependencies:

```swift
.target(name: "BestExampleApp", dependencies: ["Metrics"]),
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

swift-metrics only provides the metrics system API. As an application owner, you need to select a metrics backend (such as the ones mentioned above) to make the metrics information useful.

Selecting a backend is done by adding a dependency on the desired backend client implementation and invoking `MetricsSystem.bootstrap(SelectedMetricsImplementation.init)` at the beginning of the program. This instructs the `MetricsSystem` to install `SelectedMetricsImplementation` (actual name will differ) as the metrics backend to use.

As the API has just launched, not many implementations exist yet. If you are interested in implementing one see the "Implementing a metrics backend" section below explaining how to do so. List of existing swift-metrics API compatible libraries:

- Your library? [Get in touch!](https://forums.swift.org/c/server)

## Detailed design

### Architecture

We believe that for the Swift on Server ecosystem, it's crucial to have a metrics API that can be adopted by anybody so a multitude of libraries from different parties can all provide metrics information. More concretely this means that we believe all the metrics events from all libraries should end up in the same place, be one of the backend mentioned above or wherever else the application owner may choose.

In the real-world there are so many opinions over how exactly a metrics system should behave, how metrics should be aggregated and calculated, and where/how they should be persisted. We think it's not feasible to wait for one metrics package to support everything that a specific deployment needs whilst still being easy enough to use and remain performant. That's why we decided to split the problem into two:

1. a metrics API
2. a metrics backend implementation

This package only provides the metrics API itself and therefore swift-metrics is a "metrics API package". swift-metrics (using `MetricsSystem.bootstrap`) can be configured to choose any compatible metrics backend implementation. This way packages can adopt the API and the application can choose any compatible metrics backend implementation without requiring any changes from any of the libraries.

This API was designed with the contributors to the Swift on Server community and approved by the SSWG (Swift Server Work Group) to the "sandbox level" of the SSWG's incubation process.

[pitch](https://forums.swift.org/t/metrics/19353) |
[discussion](https://forums.swift.org/t/discussion-server-metrics-api/) |
[feedback](https://forums.swift.org/t/feedback-server-metrics-api/)

### Metric types

The API supports four metric types:

`Counter`: A counter is a cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero on restart. For example, you can use a counter to represent the number of requests served, tasks completed, or errors.

```swift
counter.increment(100)
```

`Recorder`: A recorder collects observations within a time window (usually things like response sizes) and *can* provide aggregated information about the data sample, for example count, sum, min, max and various quantiles.

```swift
recorder.record(100)
```

`Gauge`: A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down. Gauges are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads. Gauges are modeled as `Recorder` with a sample size of 1 and that does not perform any aggregation.

```swift
gauge.record(100)
```

`Timer`: A timer collects observations within a time window (usually things like request durations) and provides aggregated information about the data sample, for example min, max and various quantiles. It is similar to a `Recorder` but specialized for values that represent durations.

```swift
timer.recordMilliseconds(100)
```

### Implementing a metrics backend (e.g. Prometheus client library)

Note: Unless you need to implement a custom metrics backend, everything in this section is likely not relevant, so please feel free to skip.

As seen above, each of `Counter`, `Timer`, `Recorder` and `Gauge` constructors provides a metric object. This raises the question of which metrics backend is actually be used when calling these constructors? The answer is that it's configurable _per application_. The application sets up the metrics backend it wishes to use. Configuring the metrics backend is straightforward:

```swift
MetricsSystem.bootstrap(MyFavoriteMetricsImplementation.init)
```

This instructs the `MetricsSystem` to install `MyFavoriteMetricsImplementation` as the metrics backend (`MetricsFactory`) to use. This should only be done once at the beginning of the program.  

Given the above, an implementation of a metric backend needs to conform to `protocol MetricsFactory`:

```swift
public protocol MetricsFactory {
    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler
    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler
}
```

The `MetricsFactory` is responsible for instantiating the concrete metrics classes that capture the metrics and perform aggregation and calculation of various quantiles as needed.

**Counter**

```swift
public protocol CounterHandler: AnyObject {
    func increment<DataType: BinaryInteger>(_ value: DataType)
}
```

**Timer**

```swift
public protocol TimerHandler: AnyObject {
    func recordNanoseconds(_ duration: Int64)
}
```

**Recorder**

```swift
public protocol RecorderHandler: AnyObject {
    func record(_ value: Int64)
    func record(_ value: Double)
}
```

Here is a full example of an in-memory implementation:

```swift
class SimpleMetricsLibrary: MetricsFactory {
    init() {}

    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return ExampleCounter(label, dimensions)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        let maker: (String, [(String, String)]) -> RecorderHandler = aggregate ? ExampleRecorder.init : ExampleGauge.init
        return maker(label, dimensions)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return ExampleTimer(label, dimensions)
    }

    private class ExampleCounter: CounterHandler {
        init(_: String, _: [(String, String)]) {}

        let lock = NSLock()
        var value: Int64 = 0
        func increment(_ value: Int64) {
            self.lock.withLock {
                self.value += value
            }
        }

        func reset() {
            self.lock.withLock {
                self.value = 0
            }
        }
    }

    private class ExampleRecorder: RecorderHandler {
        init(_: String, _: [(String, String)]) {}

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

    private class ExampleGauge: RecorderHandler {
        init(_: String, _: [(String, String)]) {}

        let lock = NSLock()
        var _value: Double = 0
        func record(_ value: Int64) {
            self.record(Double(value))
        }

        func record(_ value: Double) {
            self.lock.withLock { _value = value }
        }
    }

    private class ExampleTimer: ExampleRecorder, TimerHandler {
        func recordNanoseconds(_ duration: Int64) {
            super.record(duration)
        }
    }
}
```

Do not hesitate to get in touch as well, over on https://forums.swift.org/c/server
