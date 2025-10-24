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
    let metrics: TestMetrics = TestMetrics()

    init() async throws {
        MetricsSystem.bootstrap(self.metrics)
    }

    @Test func example() async throws {
        // Create a metric using the bootstrapped test metrics backend:
        Recorder(label: "example").record(42)

        // Extract the `TestRecorder` from the test metrics system
        let recorder = try self.metrics.expectRecorder("example")
        #expect(recorder.lastValue! == 42)
    }
}
```

## Topics

### Test metrics

- ``TestCounter``
- ``TestMeter``
- ``TestRecorder``
- ``TestTimer``
