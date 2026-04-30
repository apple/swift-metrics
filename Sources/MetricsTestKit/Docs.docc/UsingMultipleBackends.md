# Using multiple backends with debug logging

Compose ``LoggingMetricsFactory`` with a real backend via `MultiplexMetricsHandler` to layer a
running trace on top of production reporting without tearing the wiring apart.

## Overview

Use `MultiplexMetricsHandler` (from `CoreMetrics`) to fan every metric mutation out to multiple
factories at once. A common pattern is to wrap a remote backend together with a
``LoggingMetricsFactory``, gated on a runtime flag so the extra logging only happens when
explicitly enabled.

```swift
import CoreMetrics
import Foundation
import Logging
import Metrics
import MetricsTestKit

let remoteFactory: MetricsFactory = MyMetricsFactory()  // Prometheus, StatsD, etc.

// In a real app you would source this flag from a proper configuration system such as
// swift-configuration; reading an environment variable directly is shown here only because
// it keeps the example self-contained.
let enableMetricsLogging = ProcessInfo.processInfo.environment["METRICS_DEBUG_LOG"] != nil

let factory: MetricsFactory
if enableMetricsLogging {
    var logger = Logger(label: "metrics")
    logger.logLevel = .debug
    factory = MultiplexMetricsHandler(factories: [
        remoteFactory,
        LoggingMetricsFactory(logger: logger),
    ])
} else {
    factory = remoteFactory
}

MetricsSystem.bootstrap(factory)
```

When the `METRICS_DEBUG_LOG` flag is set, every mutation is reported to the remote backend AND
streamed to the logger via ``LoggingMetricsFactory``. Otherwise only the remote backend is
wired up.
