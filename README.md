# SSWG Metrics api

* Proposal: SSWG-xxxx
* Authors: [Tomer Doron](https://github.com/tomerd)
* Status: **Implemented**
* Pitch: [Server: Pitches/Metrics](https://forums.swift.org/t/metrics)

## Introduction

Almost all production server software needs to emit metrics information for observability. The SSWG aims to provide a number of packages that can be shared across the whole Swift on Server ecosystem so we need some amount of standardisation. Because it's unlikely that all parties can agree on one full metrics implementation, this proposal is attempting to establish a metrics API that can be implemented by various metrics backends which then post the metrics data to backends like prometheus, graphite, publish over statsd, write to disk, etc.

## Motivation

As outlined above we should standardise on an API that if well adopted would allow application owners to mix and match libraries from different vendors with a consistent metrics solution.

## Proposed solution

The proposed solution is to introduce the following types that encapsulate metrics data:

`Counter`: A counter is a cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero on restart. For example, you can use a counter to represent the number of requests served, tasks completed, or errors.

```swift
counter.increment(100)
```

`Recorder`: A recorder collects observations within a time window (usually things like response sizes) and *can* provide aggregated information about the data sample, for example count, sum, min, max and various quantiles.

```swift
recorder.record(100)
```

`Gauges`: A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down. Gauges are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads. Gauges are modeled as `Recorder` with a sample size of 1 and that does not perform any aggregation.

```swift
gauge.record(100)
```

`Timer`: A timer collects observations within a time window (usually things like request durations) and provides aggregated information about the data sample, for example min, max and various quantiles. It is similar to a `Recorder` but specialized for values that represent durations.

```swift
timer.recordMilliseconds(100)
```

How would you use  `counter`, `recorder`, `gauge` and `timer` in you application or library? Here is a contrived example for request processing code that emits metrics for: total request count per url, request size and duration and response size:

```swift
    func processRequest(request: Request) -> Response {
      let requestCounter = Metrics.makeCounter("request.count", ["url": request.url])
      let requestTimer = Metrics.makeTimer("request.duration", ["url": request.url])
      let requestSizeRecorder = Metrics.makeRecorder("request.size", ["url": request.url])
      let responseSizeRecorder = Metrics.makeRecorder("response.size", ["url": request.url])

      requestCounter.increment()
      requestSizeRecorder.record(request.size)

      let start = Date()
      let response = ...
      requestTimer.record(Date().timeIntervalSince(start))
      responseSizeRecorder.record(response.size)
    }
```

To ensure performance, `Metrics.makeXxx` can return a cached copy of the metric object so can be called on the hot path.

## Detailed design

### Implementing a metrics backend (eg prometheus client library)

As seen above, the general function `Metrics.makeXxx` provides a metric object. This raises the question of what metrics backend I will actually get when calling `Metrics.makeXxx`? The answer is that it's configurable _per application_. The application sets up the metrics backend it wishes the whole application to use. Libraries should never change the metrics implementation as that is something owned by the application. Configuring the metrics backend is straightforward:

```swift
    Metrics.bootstrap(MyFavouriteMetricsImplementation.init)
```

This instructs the `Metrics` system to install `MyFavouriteMetricsImplementation` as the metrics backend (`MetricsHandler`) to use. This should only be done once at the beginning of the program.  

Given the above, an implementation of a metric backend needs to conform to `protocol MetricsHandler`:

```swift
public protocol MetricsHandler {
    func makeCounter(label: String, dimensions: [(String, String)]) -> Counter
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder
    func makeTimer(label: String, dimensions: [(String, String)]) -> Timer
}
```

Here is an example in-memory implementation:

```swift
class SimpleMetricsLibrary: MetricsHandler {
    init() {}

    func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return ExampleCounter(label, dimensions)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        let maker:(String,  [(String, String)]) -> Recorder = aggregate ? ExampleRecorder.init : ExampleGauge.init
        return maker(label, dimensions)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return ExampleTimer(label, dimensions)
    }

    private class ExampleCounter: Counter {
        init(_: String, _: [(String, String)]) {}

        let lock = NSLock()
        var value: Int64 = 0
        func increment<DataType: BinaryInteger>(_ value: DataType) {
            self.lock.withLock {
                self.value += Int64(value)
            }
        }
    }

    private class ExampleRecorder: Recorder {
        init(_: String, _: [(String, String)]) {}

        private let lock = NSLock()
        var values = [(Int64, Double)]()
        func record<DataType: BinaryInteger>(_ value: DataType) {
            self.record(Double(value))
        }

        func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
            // this may loose precision, but good enough as an example
            let v = Double(value)
            // TODO: sliding window
            lock.withLock {
                values.append((Date().nanoSince1970, v))
                self._count += 1
                self._sum += v
                if 0 == self._min || v < self._min { self._min = v }
                if 0 == self._max || v > self._max { self._max = v }
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

    private class ExampleGauge: Recorder {
        init(_: String, _: [(String, String)]) {}

        let lock = NSLock()
        var _value: Double = 0
        func record<DataType: BinaryInteger>(_ value: DataType) {
            self.record(Double(value))
        }

        func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
            // this may loose precision but good enough as an example
            self.lock.withLock { _value = Double(value) }
        }
    }

    private class ExampleTimer: ExampleRecorder, Timer {
        func recordNanoseconds(_ duration: Int64) {
            super.record(duration)
        }
    }
}
```

which is installed using

```swift
    Metrics.bootstrap(SimpleMetricsLibrary.init)
```


## State

This is an early proposal so there are still plenty of things to decide and tweak and I'd invite everybody to participate.

### Feedback Wishes

Feedback that would really be great is:

- if anything, what does this proposal *not cover* that you will definitely need
- if anything, what could we remove from this and still be happy?
- API-wise: what do you like, what don't you like?

Feel free to post this as message on the SSWG forum and/or github issues in this repo.

### Open Questions
