# ``MetricsTestKit``

A set of tools for inspecting metrics emitted by `swift-metrics` instrumented code.

## Overview

This module provides two `MetricsFactory` implementations, each focused on a different workflow:

- ``TestMetrics`` — an in-memory factory that records every reported value so you can assert on it
  in tests.
- ``StreamMetricsFactory`` — a stateless factory that writes one line per metric mutation to a
  `TextOutputStream`, so you can observe metric activity as it happens without standing up a real
  backend.

The two compose — combine them via `MultiplexMetricsHandler` to layer debug output on top of any
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

### Writing every metric mutation as it happens

Use ``StreamMetricsFactory`` when you want a running trace of metric activity written to a
`TextOutputStream`. Each mutation produces one line carrying the metric name, dimensions, and the
recorded delta or value.

```swift
import Metrics
import MetricsTestKit

MetricsSystem.bootstrap(StreamMetricsFactory.standardOutput())

Counter(label: "requests", dimensions: [("method", "GET")]).increment(by: 5)
// increment counter metric.name=requests metric.dimensions=[method=GET] metric.amount=5
```

The factory is stateless and faithfully writes every recorded value, including values a real
backend would silently drop (for example, `meter.increment(by: .nan)`). Purely configurational
calls such as `Timer.preferDisplayUnit(_:)` are hints rather than recorded values and are not
written. The intent is to make instrumentation bugs visible rather than to hide them.

> Warning: One line is written per metric mutation. On a hot request path that fires many metrics
> per request the cost of writing and flushing can become significant. This factory is intended
> for examples, demos, and local debugging, not for always-on production tracing.

## Topics

### Factories

- ``TestMetrics``
- ``StreamMetricsFactory``

### Articles

- <doc:UsingMultipleBackends>

### TestMetrics handlers

- ``TestCounter``
- ``TestMeter``
- ``TestRecorder``
- ``TestTimer``
