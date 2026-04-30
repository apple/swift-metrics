# ``MetricsTestKit``

A set of tools for inspecting metrics emitted by `swift-metrics` instrumented code.

## Overview

This module provides two `MetricsFactory` implementations, each focused on a different workflow:

- ``TestMetrics`` — an in-memory factory that records every reported value so you can assert on it
  in tests.
- ``LoggingMetricsFactory`` — a stateless factory that emits one `swift-log` `.debug` message per
  metric mutation, so you can observe metric activity as it happens without standing up a real
  backend.

The two compose — combine them via `MultiplexMetricsHandler` to layer debug logging on top of any
real backend.

### Asserting metrics in tests

Use the various `expect*` helpers on ``TestMetrics`` to retrieve a typed handler and inspect its
recorded values.

```swift
import Metrics
import MetricsTestKit
import Testing

struct ExampleTests {
    @Test func recorderWithCustomMetrics() async throws {
        // Create a local metrics object
        let metrics: TestMetrics = TestMetrics()

        // Explicitly use metrics object to create a recorder,
        // this allows you to avoid relying on the global system
        Recorder(label: "example", factory: metrics).record(300)

        // Extract the `TestRecorder` from the test metrics system
        let localRecorder = try metrics.expectRecorder("example")
        #expect(localRecorder.lastValue! == 300)
    }
}
```

### Logging every metric mutation as it happens

Use ``LoggingMetricsFactory`` when you want a running trace of metric activity emitted through a
`swift-log` `Logger`. Each mutation produces one structured `.debug` log line carrying the metric
name, dimensions, and the recorded delta or value.

```swift
import Logging
import Metrics
import MetricsTestKit

var logger = Logger(label: "metrics")
logger.logLevel = .debug
MetricsSystem.bootstrap(LoggingMetricsFactory(logger: logger))

Counter(label: "requests", dimensions: [("method", "GET")]).increment(by: 5)
// debug: increment counter [metric.amount=5, metric.dimensions=[[method, GET]], metric.name=requests]
```

The factory is stateless and faithfully logs every recorded value, including values a real
backend would silently drop (for example, `meter.increment(by: .nan)`). Purely configurational
calls such as `Timer.preferDisplayUnit(_:)` are hints rather than recorded values and are not
logged. The intent is to make instrumentation bugs visible rather than to hide them.

> Warning: One log line is emitted per metric mutation. On a hot request path that fires many
> metrics per request, the cost can become significant once the configured `level` is enabled
> on the supplied logger. This factory is intended for examples, demos, and local debugging,
> not for always-on production tracing.

## Topics

### Factories

- ``TestMetrics``
- ``LoggingMetricsFactory``

### Articles

- <doc:UsingMultipleBackends>

### TestMetrics handlers

- ``TestCounter``
- ``TestMeter``
- ``TestRecorder``
- ``TestTimer``
