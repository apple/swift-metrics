# ``MetricsTestKit``

A set of tools for testing Metrics emitting libraries.

## Overview

This module offers a ``TestMetrics`` type which you use to bootstrap the metrics system and assert metric values on it.

### Example

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

## Topics

### Test metrics

- ``TestCounter``
- ``TestMeter``
- ``TestRecorder``
- ``TestTimer``
