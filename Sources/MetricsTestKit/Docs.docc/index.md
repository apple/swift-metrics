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
    var metrics: TestMetrics! = TestMetrics()

    init() async throws {
        MetricsSystem.bootstrapInternal(self.metrics)
    }

    deinit() {
        self.metrics = nil
        MetricsSystem.bootstrapInternal(NOOPMetricsHandler.instance)
    }

    @Test func example() async throws {
        // Create a metric using the bootstrapped test metrics backend:
        Recorder(label: "example").record(100)
        
        // Extract the `TestRecorder` from the test metrics system 
        let recorder = try self.metrics.expectRecorder("example")
        recorder.lastValue?.shouldEqual(6)
    }
}
```

## Topics

### Test metrics

- ``TestCounter``
- ``TestMeter``
- ``TestRecorder``
- ``TestTimer``
