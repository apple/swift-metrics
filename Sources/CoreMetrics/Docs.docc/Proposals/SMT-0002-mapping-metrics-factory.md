# SMT-0002: mapping metrics factory

A `MetricsFactory` wrapper that transforms labels and dimensions before forwarding to an upstream factory.

## Overview

- Proposal: SMT-0002
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Implementation:
  - [apple/swift-metrics#194](https://github.com/apple/swift-metrics/pull/194)
- Related links:
  - [Lightweight proposals process description](https://github.com/apple/swift-metrics/blob/main/Sources/CoreMetrics/Docs.docc/Proposals/Proposals.md)

### Introduction

Add `MappingMetricsFactory`, a wrapper that applies a user-supplied transformation to the label and dimensions of
every metric before forwarding creation to an upstream `MetricsFactory`.

### Motivation

Libraries that emit metrics today have no built-in way to let the application customize metric labels or dimensions at
the factory level. This forces several common patterns into ad-hoc, error-prone workarounds:

**Adding common dimensions across all metrics.**
In multi-service or multi-region deployments, every metric should carry dimensions such as `service`, `env`, or
`region`. Without a factory-level transform, each call site must remember to include them:

```swift
// Every call site must repeat the same dimensions — easy to forget one.
let counter = Counter(
    label: "http_requests_total",
    dimensions: [("method", "GET"), ("service", "checkout"), ("env", "production")]
)
let timer = Timer(
    label: "http_request_duration",
    dimensions: [("method", "GET"), ("service", "checkout"), ("env", "production")]
)
```

**Namespacing third-party library metrics.**
When integrating a library that defines its own metric labels (for example, `db.query.duration`), the application may
want to prefix them (`myapp.db.query.duration`) to avoid collisions or improve discoverability. Today, this requires
either
patching the library or writing a custom `MetricsFactory` implementation that only adds a prefix.

**Adapting shared library metrics to different backend naming conventions.**
Libraries like [swift-system-metrics](https://github.com/apple/swift-system-metrics) emit a fixed set of metric labels
(for example, `process_cpu_usage`, `process_memory_virtual`). Different backends expect different naming conventions:
Prometheus uses underscores, while others may use dots or other separators. Without a
generic transform, each library would need to implement its own renaming support, duplicating the same logic across the
ecosystem. A factory-level transform keeps renaming generic and reusable by any library.

A core role of swift-metrics is to make it easy to connect libraries with metrics backends. Providing a standard
mapping factory in the library ensures that every library and backend in the ecosystem shares a single, well-tested
implementation instead of each project rolling its own wrapper with subtly different semantics.

### Proposed solution

Introduce a new public type `MappingMetricsFactory` and a convenience method on `MetricsFactory`:

```swift
let factory = metricsBackend.withLabelAndDimensionsMapping { label, dimensions in
    ("myapp.\(label)", dimensions + [("env", "production")])
}

// All metrics created through this factory get the prefix and dimension automatically.
let counter = Counter(label: "http_requests", dimensions: [("method", "GET")], factory: factory)
// The upstream backend receives label "myapp.http_requests"
// with dimensions [("method", "GET"), ("env", "production")].
```

### Detailed design

**New type: `MappingMetricsFactory`.**

```swift
/// A metrics factory that transforms labels and dimensions before forwarding to an upstream factory.
///
/// `MappingMetricsFactory` wraps an existing ``MetricsFactory`` and applies a transformation to the label
/// and dimensions of every metric before creating it in the upstream factory. This is useful for adding
/// common dimensions (for example, service name, environment), renaming labels, or filtering dimensions
/// across all metrics created through this factory.
///
/// The transformation is applied once at metric creation time (inside each `make*` call), not on every
/// `increment`, `record`, or other recording operation. This keeps the hot path free of user-supplied
/// code.
///
/// ### Label divergence
///
/// The transformation only affects what the upstream factory receives. The metric object itself (for
/// example, `Counter.label`, `Counter.dimensions`) retains the original values passed at creation time.
/// This means the label you see on the metric handle may differ from the label stored in the backend:
///
/// ```swift
/// let factory = upstream.withLabelAndDimensionsMapping { label, dimensions in
///     ("myapp.\(label)", dimensions)
/// }
/// let counter = Counter(label: "requests", factory: factory)
/// // counter.label == "requests"                  — original value on the handle
/// // backend received label == "myapp.requests"   — transformed value in the backend
/// ```
///
/// Keeping the original label on the metric object helps when debugging local code. This discrepancy
/// only requires attention when correlating local metric handles with data in a remote backend.
public struct MappingMetricsFactory<Upstream: MetricsFactory>: Sendable {
    /// Create a new `MappingMetricsFactory`.
    ///
    /// - parameters:
    ///   - upstream: The upstream ``MetricsFactory`` to forward metric creation to after transformation.
    ///   - transform: A closure that maps the label and dimensions to new values before forwarding
    ///     to the upstream factory.
    public init(
        upstream: Upstream,
        transform: @escaping @Sendable (String, [(String, String)]) -> (String, [(String, String)])
    )
}

extension MappingMetricsFactory: MetricsFactory {
    /// Create a backing counter handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `CounterHandler`.
    ///   - dimensions: The dimensions for the `CounterHandler`.
    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler

    /// Create a backing floating-point counter handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `FloatingPointCounterHandler`.
    ///   - dimensions: The dimensions for the `FloatingPointCounterHandler`.
    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler

    /// Create a backing meter handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `MeterHandler`.
    ///   - dimensions: The dimensions for the `MeterHandler`.
    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler

    /// Create a backing recorder handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `RecorderHandler`.
    ///   - dimensions: The dimensions for the `RecorderHandler`.
    ///   - aggregate: A Boolean value that indicates whether to aggregate values.
    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler

    /// Create a backing timer handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `TimerHandler`.
    ///   - dimensions: The dimensions for the `TimerHandler`.
    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler

    /// Invoked when the corresponding counter's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyCounter(_ handler: CounterHandler)

    /// Invoked when the corresponding floating-point counter's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler)

    /// Invoked when the corresponding meter's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyMeter(_ handler: MeterHandler)

    /// Invoked when the corresponding recorder's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyRecorder(_ handler: RecorderHandler)

    /// Invoked when the corresponding timer's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyTimer(_ handler: TimerHandler)
}
```

**New extension method on `MetricsFactory`.**

```swift
extension MetricsFactory {
    /// Create a new ``MappingMetricsFactory`` that applies the given transformation to all metrics
    /// created through it.
    ///
    /// - parameters:
    ///   - transform: A closure that maps the label and dimensions to new values.
    /// - returns: A ``MappingMetricsFactory`` wrapping this factory with the given transformation.
    public func withLabelAndDimensionsMapping(
        _ transform: @escaping @Sendable (String, [(String, String)]) -> (String, [(String, String)])
    ) -> MappingMetricsFactory<Self>
}
```

### API stability

**Existing `MetricsFactory` implementations** are not affected. `MappingMetricsFactory` is a new type that wraps
existing factories; it does not change the `MetricsFactory` protocol.

**Existing users of Metrics** might be affected. The new extension method on `MetricsFactory` is additive. However,
there is a risk users might already have a `withLabelAndDimensionsMapping` method in a custom extension.

### Future directions

**Exposing the post-transform identity from a metric handle.**
Today, `Counter.label` and `Counter.dimensions` return the original (pre-transform) values. While it makes sense as
metric objects carry exactly the label given when constructing them, a future API could let
callers retrieve the transformed identity that the backend actually received, improving debuggability and mapping
metric objects to the remote reporting.

### Alternatives considered

**Separate methods for label-only and dimension-only transforms.**
Two methods like `mappingLabel(_:)` and `mappingDimensions(_:)` would be more targeted but less flexible — some
transforms might need to modify both the label and dimensions together (for example, extracting part of the label
into a dimension). A single transform that receives both avoids the need for two factory wrappers.
