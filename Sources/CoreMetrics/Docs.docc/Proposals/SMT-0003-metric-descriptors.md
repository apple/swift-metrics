# SMT-0003: Portable metric descriptions via `MetricDescriptor`

* Proposal: SMT-0003
* Author(s): Manjunath Anawal ([@ManjunathAnawal](https://github.com/ManjunathAnawal))
* Status: **Draft** (pre-review)
* Implementation: [apple/swift-metrics#239](https://github.com/apple/swift-metrics/pull/239) (proof of concept, draft PR)
* Related: #236. Succeeds #237, which proposed the same `SMT-0003` slot and was closed without merging; this proposal reuses the number with maintainer agreement.

## Summary

Add a `MetricDescriptor` type and descriptor-based factory methods to `CoreMetrics`,
so libraries can attach a human-readable description to a metric without turning it
into a dimension. Existing backends keep working unchanged; descriptor-aware backends
can opt in to receive the description.

## Motivation

Swift Metrics currently passes only a `label` and `dimensions` to backends. There is
no portable way to express:

- a Prometheus / OpenMetrics `HELP` line, or
- an OpenTelemetry instrument `description`.

Today this is worked around per-backend: `swift-prometheus` exposes a separate
registry API that takes `help:`, and `swift-otel` packs the description into a
dimension. Neither approach is portable, and packing it into a dimension risks
increasing cardinality unnecessarily.

## Proposed solution

Introduce a small, `Sendable` and `Equatable` `MetricDescriptor` struct that carries
`label`, `dimensions`, and an optional `metricDescription`, with a memberwise
initializer left open to evolve (for example, to add a `unit` field later without
breaking existing call sites). The field is named `metricDescription` rather than
`description`, so `MetricDescriptor` remains free to conform to
`CustomStringConvertible` in the future without a naming clash.

`MetricsFactory` gains descriptor-based factory requirements alongside the existing
`label:dimensions:` ones. Each new requirement provides a default implementation
that simply forwards `label` and `dimensions` to the existing method, so every
backend that implements `MetricsFactory` today keeps compiling and behaving exactly
as before. A backend only needs to override the descriptor-based method if it wants
to read the `metricDescription`.

Convenience initializers on `Counter`, `FloatingPointCounter`, `Meter`, `Gauge`,
`Recorder`, and `Timer` let call sites construct a metric from a descriptor directly.
No existing initializer signature changes.

### Example

```swift
// Before: no way to attach a description
let requests = Counter(label: "http_requests_total", dimensions: [("route", "/users")])

// After: attach a description via MetricDescriptor
let descriptor = MetricDescriptor(
    label: "http_requests_total",
    dimensions: [("route", "/users")],
    metricDescription: "Total number of HTTP requests received"
)
let requests = Counter(descriptor: descriptor)

// A descriptor-aware backend (e.g. swift-prometheus) can read metricDescription
// to emit a Prometheus HELP line; a backend that doesn't override the
// descriptor-based factory method simply falls back to label + dimensions,
// exactly as it does today.
```

## Detailed design

Full API diff, with doc comments, as implemented in the linked PoC (#239):

```swift
/// A portable description of a metric, carrying everything a backend needs to
/// register it, including an optional human-readable description.
public struct MetricDescriptor: Sendable, Equatable {
    /// The label identifying this metric.
    public let label: String

    /// The dimensions (key-value pairs) attached to this metric.
    public let dimensions: [(String, String)]

    /// An optional human-readable description of what this metric measures,
    /// e.g. surfaced as a Prometheus `HELP` line or an OpenTelemetry
    /// instrument description.
    public let metricDescription: String?

    public init(
        label: String,
        dimensions: [(String, String)] = [],
        metricDescription: String? = nil
    ) {
        self.label = label
        self.dimensions = dimensions
        self.metricDescription = metricDescription
    }
}

extension MetricsFactory {
    /// Default implementation forwards to `makeCounter(label:dimensions:)`,
    /// dropping `metricDescription`. Override to read it.
    public func makeCounter(descriptor: MetricDescriptor) -> CounterHandler {
        makeCounter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    public func makeFloatingPointCounter(descriptor: MetricDescriptor) -> FloatingPointCounterHandler {
        makeFloatingPointCounter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    public func makeMeter(descriptor: MetricDescriptor) -> MeterHandler {
        makeMeter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    public func makeRecorder(descriptor: MetricDescriptor, aggregate: Bool) -> RecorderHandler {
        makeRecorder(label: descriptor.label, dimensions: descriptor.dimensions, aggregate: aggregate)
    }

    public func makeTimer(descriptor: MetricDescriptor) -> TimerHandler {
        makeTimer(label: descriptor.label, dimensions: descriptor.dimensions)
    }
}

extension Counter {
    public convenience init(descriptor: MetricDescriptor) { ... }
}
extension FloatingPointCounter {
    public convenience init(descriptor: MetricDescriptor) { ... }
}
extension Meter {
    public convenience init(descriptor: MetricDescriptor) { ... }
}
extension Gauge {
    public convenience init(descriptor: MetricDescriptor) { ... }
}
extension Recorder {
    public convenience init(descriptor: MetricDescriptor, aggregate: Bool = false) { ... }
}
extension Timer {
    public convenience init(descriptor: MetricDescriptor) { ... }
    public convenience init(descriptor: MetricDescriptor, preferredDisplayUnit: TimeUnit) { ... }
}
```

`MultiplexMetricsHandler` forwards the descriptor to every underlying factory.
`MappingMetricsFactory` transforms `label`/`dimensions` while preserving
`metricDescription`. `TestMetrics` stores the full descriptor, with
`label`/`dimensions` exposed as computed properties so existing test code that
reads them keeps working, and new tests can assert on `metricDescription`.

*(See #239 for the complete, up-to-date diff — the block above mirrors it but may
drift if the PoC changes; keep this section in sync when it does.)*

## Compatibility

- No existing public API is changed or removed.
- Every existing `MetricsFactory` conformance compiles unchanged, because the new
  requirements have default implementations.
- `swift package diagnose-api-breaking-changes` reports no breaking changes in
  `CoreMetrics`, `Metrics`, or `MetricsTestKit` for the PoC in #239.

## Alternatives considered

- **Put the description in `dimensions`.** Rejected — this is what backends already
  do as a workaround, and it risks increasing cardinality since dimensions are
  commonly used for grouping/filtering.
- **`description` as the field name**, instead of `metricDescription`. Rejected —
  it would collide with `CustomStringConvertible.description` and block
  `MetricDescriptor` from conforming to that protocol in the future.
- **`MetricDescription` as the type name**, instead of `MetricDescriptor`. Rejected
  in favor of `MetricDescriptor`, to match the naming of the property it now holds
  (`metricDescription`) and keep `description` free for `CustomStringConvertible`.
- **Silent vs. surfaced fallback.** When a backend does not override the
  descriptor-based factory method, `metricDescription` is dropped silently. Decided
  to keep this silent for now, consistent with how unused `dimensions` are already
  handled by backends that ignore them; can be revisited if backend authors want a
  more visible signal.
- **Moving `aggregate` inside `MetricDescriptor` for `Recorder`.** Rejected —
  `aggregate` only applies to `Recorder`, not to any other metric kind, so folding
  it into the shared `MetricDescriptor` struct would mean either a `Recorder`-only
  descriptor type or an unused field on every other metric's descriptor. Kept as a
  separate parameter on `makeRecorder(descriptor:aggregate:)` instead.

## Implementation

See the PR header above for the linked proof-of-concept implementation.
