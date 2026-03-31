//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2026 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A metrics factory that transforms labels and dimensions before forwarding to an upstream factory.
///
/// `MappingMetricsFactory` wraps an existing ``MetricsFactory`` and applies a transformation to the label
/// and dimensions of every metric before creating it in the upstream factory. This is useful for adding
/// common dimensions (e.g. service name, environment), renaming labels, or filtering dimensions across
/// all metrics created through this factory.
///
/// ```swift
/// let factory = upstream.withLabelAndDimensionsMapping { label, dimensions in
///     (label, dimensions + [("service", "my-service")])
/// }
/// let counter = Counter(label: "request_count", dimensions: [("method", "GET")], factory: factory)
/// counter.increment()
/// // The upstream factory sees dimensions [("method", "GET"), ("service", "my-service")]
/// ```
///
/// - Note: The transformation only affects what the upstream factory receives. The metric object itself
///   (e.g. `Counter.label`, `Counter.dimensions`) retains the original values passed at creation time.
///   This means the label you see on the metric handle may differ from the label stored in the backend.
///   When debugging, inspect the metric directly in the backend rather than relying on the metric
///   handle's `.label` property.
public struct MappingMetricsFactory<Upstream: MetricsFactory>: Sendable {
    private let upstream: Upstream
    private let transform: @Sendable (String, [(String, String)]) -> (String, [(String, String)])

    /// Create a new `MappingMetricsFactory`.
    ///
    /// - parameters:
    ///   - upstream: The upstream ``MetricsFactory`` to forward metric creation to after transformation.
    ///   - transform: A closure that maps the label and dimensions to new values before forwarding
    ///     to the upstream factory.
    public init(
        upstream: Upstream,
        transform: @escaping @Sendable (String, [(String, String)]) -> (String, [(String, String)])
    ) {
        self.upstream = upstream
        self.transform = transform
    }
}

extension MetricsFactory {
    /// Create a new ``MappingMetricsFactory`` that applies the given transformation to all metrics
    /// created through it.
    ///
    /// - parameters:
    ///   - transform: A closure that maps the label and dimensions to new values.
    /// - returns: A ``MappingMetricsFactory`` wrapping this factory with the given transformation.
    public func withLabelAndDimensionsMapping(
        _ transform:
            @escaping @Sendable (
                String, [(String, String)]
            ) -> (String, [(String, String)])
    ) -> MappingMetricsFactory<Self> {
        MappingMetricsFactory(upstream: self, transform: transform)
    }
}

extension MappingMetricsFactory: MetricsFactory {
    /// Create a backing counter handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `CounterHandler`.
    ///   - dimensions: The dimensions for the `CounterHandler`.
    public func makeCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> CounterHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeCounter(label: newLabel, dimensions: newDimensions)
    }

    /// Create a backing floating-point counter handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `FloatingPointCounterHandler`.
    ///   - dimensions: The dimensions for the `FloatingPointCounterHandler`.
    public func makeFloatingPointCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> FloatingPointCounterHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeFloatingPointCounter(label: newLabel, dimensions: newDimensions)
    }

    /// Create a backing meter handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `MeterHandler`.
    ///   - dimensions: The dimensions for the `MeterHandler`.
    public func makeMeter(
        label: String,
        dimensions: [(String, String)]
    ) -> MeterHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeMeter(label: newLabel, dimensions: newDimensions)
    }

    /// Create a backing recorder handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `RecorderHandler`.
    ///   - dimensions: The dimensions for the `RecorderHandler`.
    ///   - aggregate: A Boolean value that indicates whether to aggregate values.
    public func makeRecorder(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool
    ) -> RecorderHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeRecorder(label: newLabel, dimensions: newDimensions, aggregate: aggregate)
    }

    /// Create a backing timer handler with transformed label and dimensions.
    ///
    /// - parameters:
    ///   - label: The label for the `TimerHandler`.
    ///   - dimensions: The dimensions for the `TimerHandler`.
    public func makeTimer(
        label: String,
        dimensions: [(String, String)]
    ) -> TimerHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeTimer(label: newLabel, dimensions: newDimensions)
    }

    /// Invoked when the corresponding counter's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyCounter(_ handler: CounterHandler) {
        upstream.destroyCounter(handler)
    }

    /// Invoked when the corresponding meter's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyMeter(_ handler: MeterHandler) {
        upstream.destroyMeter(handler)
    }

    /// Invoked when the corresponding floating-point counter's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        upstream.destroyFloatingPointCounter(handler)
    }

    /// Invoked when the corresponding recorder's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyRecorder(_ handler: RecorderHandler) {
        upstream.destroyRecorder(handler)
    }

    /// Invoked when the corresponding timer's `destroy()` function is invoked.
    ///
    /// - parameters:
    ///   - handler: The handler to be destroyed.
    public func destroyTimer(_ handler: TimerHandler) {
        upstream.destroyTimer(handler)
    }
}
