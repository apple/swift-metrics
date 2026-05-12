# Using multiple backends with debug output

Compose ``StreamMetricsFactory`` with a real backend via `MultiplexMetricsHandler` to layer a
running trace on top of production reporting without tearing the wiring apart.

## Overview

Use `MultiplexMetricsHandler` (from `CoreMetrics`) to fan every metric mutation out to multiple
factories at once. A common pattern is to wrap a remote backend together with a
``StreamMetricsFactory``, gated on a runtime flag so the extra output only happens when
explicitly enabled.

```swift
import CoreMetrics
import Foundation
import Metrics
import MetricsTestKit

let remoteFactory: MetricsFactory = MyMetricsFactory()  // Prometheus, StatsD, etc.

// In a real app you would source this flag from a proper configuration system such as
// swift-configuration; reading an environment variable directly is shown here only because
// it keeps the example self-contained.
let enableMetricsDebugOutput = ProcessInfo.processInfo.environment["METRICS_DEBUG"] != nil

let factory: MetricsFactory
if enableMetricsDebugOutput {
    factory = MultiplexMetricsHandler(factories: [
        remoteFactory,
        StreamMetricsFactory.standardOutput(),
    ])
} else {
    factory = remoteFactory
}

MetricsSystem.bootstrap(factory)
```

When the `METRICS_DEBUG` flag is set, every mutation is reported to the remote backend AND
streamed to standard output via ``StreamMetricsFactory``. Otherwise only the remote backend is
wired up.
