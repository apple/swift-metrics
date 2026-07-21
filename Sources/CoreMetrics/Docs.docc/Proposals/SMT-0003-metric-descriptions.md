# SMT-0003: portable metric descriptions

Carry a human-readable metric description from Swift Metrics to backends that support
descriptions, including Prometheus and OpenTelemetry.

## Overview

- Proposal: SMT-0003
- Author(s): [Anuj Raja](https://github.com/anujraja)
- Status: **Awaiting Review**
- Issue: [apple/swift-metrics#236](https://github.com/apple/swift-metrics/issues/236)
- Implementation: _To be added after this proposal is ready for implementation._
- Feature flag: _None._
- Related links:
  - [Lightweight proposals process description](https://github.com/apple/swift-metrics/blob/main/Sources/CoreMetrics/Docs.docc/Proposals/Proposals.md)
  - [Prometheus `HELP` metadata](https://prometheus.io/docs/specs/om/open_metrics_spec_2_0/#help)
  - [OpenTelemetry metric descriptions](https://opentelemetry.io/docs/concepts/signals/metrics/#metric-instruments)

### Introduction

Add a `MetricDescriptor` value that describes a metric's identity and optional
human-readable description. Add descriptor-based metric construction and factory
methods so a backend can export the description without a backend-specific API.

### Motivation

Swift Metrics lets libraries define portable labels and dimensions, but it does not
let them provide the explanatory text that observability backends display next to a
metric. That forces backend-specific workarounds:

- `swift-prometheus` exposes separate registry APIs to register Prometheus `HELP`
  text.
- `swift-otel` stores description-like data in dimensions because its Swift Metrics
  factory receives only a label and dimensions.

Both approaches make a library choose a backend or duplicate its metric definition.
They also make a metric's name and its explanation easier to change independently.
The description belongs with the metric identity at creation time and should travel
through the same factory boundary as the label and dimensions.

### Proposed solution

Introduce an additive `MetricDescriptor` type:

```swift
public struct MetricDescriptor: Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    public let description: String?

    public init(
        label: String,
        dimensions: [(String, String)] = [],
        description: String? = nil
    )
}
```

The `description` is optional because existing metrics do not always have useful
human-readable metadata. It is metric metadata, never a dimension: it must not
increase metric cardinality and must not be emitted as an attribute or label.

Add descriptor-based initializers to the public metric types. The spelling keeps a
descriptor visually distinct from the existing label-only API:

```swift
let requests = Counter(
    descriptor: .init(
        label: "http_requests_total",
        dimensions: [("service", "checkout")],
        description: "Number of HTTP requests handled by the checkout service."
    )
)

let latency = Timer(
    descriptor: .init(
        label: "http_request_duration",
        description: "End-to-end duration of handled HTTP requests."
    )
)
```

The same `descriptor:` initializer is available for `Counter`,
`FloatingPointCounter`, `Meter`, `Recorder`, `Gauge`, and `Timer`, with the existing
type-specific arguments retained where applicable (for example, `aggregate` for a
`Recorder` and `preferredDisplayUnit` for a `Timer`). Each initializer also has the
existing optional `factory:` overload.

Add matching `MetricsFactory` requirements:

```swift
func makeCounter(descriptor: MetricDescriptor) -> CounterHandler
func makeFloatingPointCounter(descriptor: MetricDescriptor) -> FloatingPointCounterHandler
func makeMeter(descriptor: MetricDescriptor) -> MeterHandler
func makeRecorder(descriptor: MetricDescriptor, aggregate: Bool) -> RecorderHandler
func makeTimer(descriptor: MetricDescriptor) -> TimerHandler
```

Every new requirement receives a default implementation that forwards the label and
dimensions to today's corresponding factory method. Therefore a backend that has not
yet adopted descriptor support continues to receive and report metrics exactly as it
does today. A backend that does adopt it overrides the descriptor method and maps
`descriptor.description` to its native metadata:

- Prometheus uses the value as the metric's `HELP` text.
- OpenTelemetry uses the value as the instrument description.

Backends must treat `nil` as “no description supplied”; they must not synthesize an
empty `HELP` line or empty OpenTelemetry description. If a backend rejects, normalizes,
or deduplicates descriptions, it must apply its native backend rules consistently and
document them in that backend package.

### Detailed design

`MetricDescriptor` lives in `CoreMetrics` alongside `MetricsFactory`. Its stored
properties are immutable, and it conforms to `Sendable`. The initial release does not
make it `Hashable`: an ordered array of dimensions cannot safely use dictionary-style
equality without first defining duplicate-key semantics. That decision is deliberately
left out of this proposal.

The existing `label:dimensions:` factory methods and public metric initializers remain
unchanged. Descriptor-based overloads call descriptor-based factory methods. The
default factory methods bridge to the existing methods, preserving the behavior of
every current `MetricsFactory` implementation. The existing default implementations
for floating-point counters and meters also bridge using the descriptor's label and
dimensions, so their wrapper handlers retain the new metadata at creation time when an
upstream factory supports it.

`MetricDescriptor` does not include a metric kind, aggregation mode, unit, histogram
boundaries, or backend resource attributes. Those concepts either already belong to a
specific metric type or require separate cross-backend semantics. The descriptor is a
small extensible identity container: future fields can be proposed without expanding
every factory method again.

### API stability

This is a semver-minor, additive API change.

**Existing Metrics users.** Existing source continues to compile and existing metric
creation continues to take the same code paths. Libraries can adopt descriptions one
metric at a time and need not add descriptions merely to update Swift Metrics.

**Existing `MetricsFactory` implementations.** The descriptor methods have default
implementations, so an existing backend does not need source changes to conform.
It will receive the same label and dimensions and will ignore the optional description
until it deliberately implements the new overloads. Before release, maintainers should
also confirm the binary-compatibility policy for adding defaulted protocol requirements
to the supported Swift toolchains.

**Metric definition consistency.** Backends may register a metric identity once. Two
descriptors with the same label and dimensions but different non-`nil` descriptions
are a backend configuration conflict, not two distinct metrics. This proposal does not
prescribe one error policy because factory methods cannot throw; individual backend
packages should document their deterministic policy (for example, retain the first
registered description and log a diagnostic).

### Implementation and test plan

Once this proposal is ready for implementation, the implementation PR will:

1. Add `MetricDescriptor`, descriptor initializers, descriptor factory requirements,
   and their compatibility defaults in `CoreMetrics`.
2. Update `NoOpMetricsFactory`, `MultiplexMetricsHandler`, and the built-in
   floating-point-counter and meter fallback paths to preserve descriptor dispatch.
3. Extend `MetricsTestKit` so tests can inspect the descriptor received by a test
   backend without treating the description as a dimension.
4. Add regression coverage for every metric type, explicit and global factories,
   default forwarding to a legacy factory, multiplex forwarding, and `nil` versus
   non-`nil` descriptions.
5. Add API documentation with Prometheus and OpenTelemetry examples, then run the
   package test suite and the repository formatting and DocC checks.

Follow-up PRs in `swift-prometheus` and `swift-otel` can then implement their native
mapping and add integration coverage. Keeping those changes out of this repository
makes this proposal reviewable without coupling its release to either backend.

### Future directions

- Add a portable unit field after aligning its semantics with OpenTelemetry units and
  Prometheus naming conventions.
- Add typed metric kinds or instrument metadata if a future backend capability needs
  them.
- Provide a test helper that asserts descriptions from a backend-neutral descriptor.

### Alternatives considered

**Add `description:` to every existing initializer and factory method.** This creates
many overloads and requires another round of API expansion for future metadata. A
descriptor keeps identity metadata together and gives the API room to evolve.

**Use a `MetricDescription` type.** That name can read as the text itself rather than
the complete metric identity. `MetricDescriptor` makes the distinction clear while
retaining a `description` field for the human-readable text.

**Put the description in dimensions.** Dimensions identify time-series values and
affect cardinality; descriptions are static metadata. Mixing them would produce
incorrect backend output and potentially costly duplicate series.

**Keep separate `help:` APIs in each backend.** Backend-specific APIs cannot be used
by portable libraries and retain the current duplication problem.
