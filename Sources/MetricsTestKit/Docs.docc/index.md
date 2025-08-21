# ``MetricsTestKit``

A set of tools for testing Metrics emitting libraries.

## Overview

This module offers a ``TestMetrics`` type which you use to bootstrap the metrics system and assert metric values on it.

## Example

```swift
import XCTest
import Metrics
import MetricsTestKit

final class ExampleTests: XCTestCase {
    var metrics: TestMetrics! = TestMetrics()

    override func setUp() {
        MetricsSystem.bootstrapInternal(self.metrics)
    }

    override func tearDown() async throws {
        self.metrics = nil
        MetricsSystem.bootstrapInternal(NOOPMetricsHandler.instance)
    }

    func test_example() async throws {
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
