# ``MetricsTestKit``

A set of tools for testing Metrics emitting libraries.

## Overview

This module offers a ``TestMetrics`` type which can be used to bootstrap the metrics system and then assert metric values on it.

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
        Gauge(label: "example").record(100)
        
        // extract the `TestGauge` out of the 
        let gauge = try self.metrics.expectGauge("example")
        gauge.lastValue?.shouldEqual(6)
    }
}
```

## Topics

### Test metrics

- ``TestRecorder``
- ``TestCounter``
- ``TestTimer``