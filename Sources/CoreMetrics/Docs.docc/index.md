# ``CoreMetrics``

A Metrics API package for Swift.

## Overview

Almost all production server software needs to emit metrics information for observability. Because it's unlikely that all parties can agree on one specific metrics backend implementation, this API is designed to establish a standard that can be implemented by various metrics libraries which then post the metrics data to backends like [Prometheus](https://prometheus.io/), [Graphite](https://graphiteapp.org), publish over [statsd](https://github.com/statsd/statsd), write to disk, and so on.

This is a community-driven open-source project that actively seeks contributions, be it code, documentation, or ideas.
Apart from contributing to SwiftMetrics itself, the project needs metrics-compatible libraries which send the metrics over to backend systems such as the ones mentioned above.
What SwiftMetrics provides today is covered in the [API docs](https://apple.github.io/swift-metrics/), and evolves with community input.

### Getting started

If you have a server-side Swift application, or maybe a cross-platform (for example, Linux and macOS) application or library, and you would like to emit metrics, targeting this metrics API package is a great idea.
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

### Selecting a metrics backend implementation (applications only)

Note: If you are building a library, you don't need to concern yourself with this section. It is the end users of your library (the applications) who decide which metrics backend to use. Libraries should never change the metrics implementation, as that choice is owned by the application.

SwiftMetrics only provides the metrics system API. As an application owner, you choose a metrics backend (such as the ones mentioned above) to make the metrics information useful.

Selecting a backend is done by adding a dependency on the desired backend client implementation and invoking the `MetricsSystem.bootstrap` function at the beginning of the program:

```swift
MetricsSystem.bootstrap(SelectedMetricsImplementation())
```

This instructs the `MetricsSystem` to install `SelectedMetricsImplementation` (the actual name will differ) as the metrics backend to use.

> Tip: Refer to the project's [README](https://github.com/apple/swift-metrics) for an up-to-date list of backend implementations.

### Swift Metrics Extras

You may also be interested in some "extra" modules which are collected in the [Swift Metrics Extras](https://github.com/apple/swift-metrics-extras) repository.
It provides additional helpers for recording, aggregating, and exporting metrics, including gathering common system metrics.

### API Architecture

For the Swift on Server ecosystem, it's crucial to have a metrics API that can be adopted by anybody so a multitude of libraries from different parties can provide metrics information. More concretely, all the metrics events from all libraries should end up in the same place: one of the backends mentioned above or wherever the application owner chooses.

There are so many opinions over how exactly a metrics system should behave, how metrics should be aggregated and calculated, and where/how to persist them that it's not feasible to wait for one metrics package to support everything while still being simple enough to use and remain performant. For this reason, the problem is split into two parts:

1. a metrics API
2. a metrics backend implementation

This package only provides the metrics API, and therefore, SwiftMetrics is a "metrics API package." 
SwiftMetrics can be configured (using `MetricsSystem.bootstrap`) to use any compatible metrics backend implementation. 
This mechanism allows libraries to adopt the API and support the application choosing a compatible backend implementation without requiring any changes to the libraries.

This API was designed with the contributors to the Swift on Server community and approved by the SSWG (Swift Server Work Group) to the "sandbox level" of the SSWG's incubation process.

[pitch](https://forums.swift.org/t/metrics/19353) |
[discussion](https://forums.swift.org/t/discussion-server-metrics-api/) |
[feedback](https://forums.swift.org/t/feedback-server-metrics-api/)

## Topics

### Metric types

- ``Counter``
- ``CounterHandler``
- ``FloatingPointCounter``
- ``FloatingPointCounterHandler``
- ``Meter``
- ``MeterHandler``
- ``Gauge``
- ``Recorder``
- ``RecorderHandler``
- ``Timer``
- ``TimerHandler``

### Metrics Handlers

- ``MultiplexMetricsHandler``
- ``NOOPMetricsHandler``

### Bootstraping

- ``MetricsFactory``
- ``MetricsSystem``

### Supporting Types

- ``TimeUnit``
