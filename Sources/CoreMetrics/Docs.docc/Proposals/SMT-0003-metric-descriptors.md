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
registry API that takes `help:`, and `swift-otel` stuffs the description into a
dimension. Neither approach is portable, and stuffing it into a dimension risks
increasing cardinality unnecessarily.

## Proposed solution

Introduce a small, `Sendable` and `Equatable` `MetricDescriptor` struct that carries
`label`, `dimensions`, and an optional `description`, with a memberwise initializer
left open to evolve (for example, to add a `unit` field later without breaking
existing call sites).

`MetricsFactory` gains descriptor-based factory requirements alongside the existing
`label:dimensions:` ones. Each new requirement ships a default implementation that
simply forwards `label` and `dimensions` to the existing method, so every backend
that implements `MetricsFactory` today keeps compiling and behaving exactly as
before. A backend only needs to override the descriptor-based method if it wants to
read the `description`.

Convenience initializers on `Counter`, `FloatingPointCounter`, `Meter`, `Gauge`,
`Recorder`, and `Timer` let call sites construct a metric from a descriptor directly.
No existing initializer signature changes.

## Detailed design

- **`MetricDescriptor`** (in `CoreMetrics`): `Sendable`, `Equatable`, holds `label`,
  `dimensions`, and an optional `description`.
- **Five new `MetricsFactory` requirements**, each with a default implementation that
  forwards to the existing `makeXXX(label:dimensions:)` method:
  - `makeCounter(descriptor:)`
  - `makeFloatingPointCounter(descriptor:)`
  - `makeMeter(descriptor:)`
  - `makeRecorder(descriptor:aggregate:)`
  - `makeTimer(descriptor:)`
- **Descriptor-based convenience initializers** on `Counter`, `FloatingPointCounter`,
  `Meter`, `Gauge`, `Recorder`, and `Timer` (including the `preferredDisplayUnit`
  variant).
- **`MultiplexMetricsHandler`** forwards the descriptor to every sub-factory.
- **`MappingMetricsFactory`** transforms `label`/`dimensions` while preserving
  `description`.
- **`TestMetrics`** stores the full descriptor, with `label`/`dimensions` exposed as
  computed properties so existing test code that reads them keeps working, and new
  tests can assert on `description`.

Full code is intentionally not inlined here — see the linked implementation PR for
the diff.

## Compatibility

- No existing public API is changed or removed.
- Every existing `MetricsFactory` conformance compiles unchanged, because the new
  requirements have default implementations.
- `swift package diagnose-api-breaking-changes` reports no breaking changes in
  `CoreMetrics`, `Metrics`, or `MetricsTestKit` for the PoC in #239.

## Alternatives considered

- **Put `description` in `dimensions`.** Rejected — this is what backends already do
  as a workaround, and it risks increasing cardinality since dimensions are commonly
  used for grouping/filtering.
- **`MetricDescription` as the type name**, instead of `MetricDescriptor`. Open for
  discussion; naming bikeshed, no functional difference.
- **Silent vs. surfaced fallback.** When a backend does not override the
  descriptor-based factory method, the description is currently dropped silently.
  An alternative is to make that drop observable somehow (for example via a debug
  log or a `Metrics` bootstrap warning) so authors notice a description isn't being
  used. Needs input from backend authors before deciding.
- **Where `aggregate` lives for `Recorder`.** The PoC keeps `aggregate` as a separate
  parameter alongside `descriptor:` rather than folding it into `MetricDescriptor`
  itself, to avoid growing the descriptor with parameters that only apply to one
  metric kind.

## Open questions for reviewers

- `MetricDescriptor` vs `MetricDescription` naming.
- Whether `aggregate` should move inside the descriptor for `Recorder`.
- Whether a dropped `description` (unsupported backend) should be silent or surfaced.

## Implementation

A proof-of-concept implementation is up as a draft PR:
[apple/swift-metrics#239](https://github.com/apple/swift-metrics/pull/239). It
includes 22 new tests (132 total passing), a clean build under
`-warnings-as-errors -require-explicit-sendable`, and a clean `swift format lint`
(aside from two pre-existing findings on `main`).
