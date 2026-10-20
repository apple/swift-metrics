//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// MARK: - MetricDescriptor

/// A description of a metric's identity and metadata.
///
/// A `MetricDescriptor` bundles everything needed to create a metric — its label, dimensions,
/// and optional human-readable metadata such as a ``description`` — into a single value that is
/// easy to evolve without breaking the ``MetricsFactory`` API.
///
/// Backends can map ``description`` to their native concept of metric help text, for example a
/// `HELP` line in Prometheus/OpenMetrics exposition, or the `description` field of an
/// OpenTelemetry instrument.
///
/// ```swift
/// let counter = Counter(
///     descriptor: MetricDescriptor(
///         label: "http_requests_total",
///         dimensions: [("method", "GET")],
///         description: "Total number of HTTP requests received."
///     )
/// )
/// ```
public struct MetricDescriptor: Sendable {
    /// The label (name) of the metric.
    public var label: String
    /// The dimensions of the metric, as `(name, value)` tuples.
    public var dimensions: [(String, String)]
    /// An optional human-readable description of what the metric measures.
    ///
    /// Backends are encouraged to surface this as their native help/description metadata,
    /// for example a Prometheus `HELP` line or an OpenTelemetry instrument description.
    /// The description is metadata only: it is not a dimension and does not contribute to
    /// the metric's identity or cardinality.
    public var description: String?

    /// Create a new metric descriptor.
    ///
    /// - parameters:
    ///   - label: The label (name) of the metric.
    ///   - dimensions: The dimensions of the metric, as `(name, value)` tuples.
    ///   - description: An optional human-readable description of what the metric measures.
    public init(label: String, dimensions: [(String, String)] = [], description: String? = nil) {
        self.label = label
        self.dimensions = dimensions
        self.description = description
    }
}

extension MetricDescriptor: Equatable {
    public static func == (lhs: MetricDescriptor, rhs: MetricDescriptor) -> Bool {
        lhs.label == rhs.label
            && lhs.dimensions.count == rhs.dimensions.count
            && zip(lhs.dimensions, rhs.dimensions).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
            && lhs.description == rhs.description
    }
}

// MARK: - MetricsFactory default implementations

extension MetricsFactory {
    /// Create a backing counter handler from a descriptor.
    ///
    /// The default implementation forwards the descriptor's label and dimensions to
    /// ``MetricsFactory/makeCounter(label:dimensions:)``, discarding the description.
    /// Backends that can surface metric descriptions should implement this method.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `CounterHandler`.
    public func makeCounter(descriptor: MetricDescriptor) -> CounterHandler {
        self.makeCounter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    /// Create a backing floating-point counter handler from a descriptor.
    ///
    /// The default implementation forwards the descriptor's label and dimensions to
    /// ``MetricsFactory/makeFloatingPointCounter(label:dimensions:)``, discarding the description.
    /// Backends that can surface metric descriptions should implement this method.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `FloatingPointCounterHandler`.
    public func makeFloatingPointCounter(descriptor: MetricDescriptor) -> FloatingPointCounterHandler {
        self.makeFloatingPointCounter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    /// Create a backing meter handler from a descriptor.
    ///
    /// The default implementation forwards the descriptor's label and dimensions to
    /// ``MetricsFactory/makeMeter(label:dimensions:)``, discarding the description.
    /// Backends that can surface metric descriptions should implement this method.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `MeterHandler`.
    public func makeMeter(descriptor: MetricDescriptor) -> MeterHandler {
        self.makeMeter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    /// Create a backing recorder handler from a descriptor.
    ///
    /// The default implementation forwards the descriptor's label and dimensions to
    /// ``MetricsFactory/makeRecorder(label:dimensions:aggregate:)``, discarding the description.
    /// Backends that can surface metric descriptions should implement this method.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `RecorderHandler`.
    ///   - aggregate: Whether the returned handler should summarize recorded values as a distribution.
    public func makeRecorder(descriptor: MetricDescriptor, aggregate: Bool) -> RecorderHandler {
        self.makeRecorder(label: descriptor.label, dimensions: descriptor.dimensions, aggregate: aggregate)
    }

    /// Create a backing timer handler from a descriptor.
    ///
    /// The default implementation forwards the descriptor's label and dimensions to
    /// ``MetricsFactory/makeTimer(label:dimensions:)``, discarding the description.
    /// Backends that can surface metric descriptions should implement this method.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `TimerHandler`.
    public func makeTimer(descriptor: MetricDescriptor) -> TimerHandler {
        self.makeTimer(label: descriptor.label, dimensions: descriptor.dimensions)
    }
}

// MARK: - Descriptor-based user API

extension Counter {
    /// Create a new counter from a descriptor, using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Counter`.
    ///   - factory: The custom metrics factory.
    public convenience init(descriptor: MetricDescriptor, factory: MetricsFactory) {
        let handler = factory.makeCounter(descriptor: descriptor)
        self.init(label: descriptor.label, dimensions: descriptor.dimensions, handler: handler, factory: factory)
    }

    /// Create a new counter from a descriptor.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Counter`.
    public convenience init(descriptor: MetricDescriptor) {
        self.init(descriptor: descriptor, factory: MetricsSystem.factory)
    }
}

extension FloatingPointCounter {
    /// Create a new floating-point counter from a descriptor, using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `FloatingPointCounter`.
    ///   - factory: The custom metrics factory.
    public convenience init(descriptor: MetricDescriptor, factory: MetricsFactory) {
        let handler = factory.makeFloatingPointCounter(descriptor: descriptor)
        self.init(label: descriptor.label, dimensions: descriptor.dimensions, handler: handler, factory: factory)
    }

    /// Create a new floating-point counter from a descriptor.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `FloatingPointCounter`.
    public convenience init(descriptor: MetricDescriptor) {
        self.init(descriptor: descriptor, factory: MetricsSystem.factory)
    }
}

extension Meter {
    /// Create a new meter from a descriptor, using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Meter`.
    ///   - factory: The custom metrics factory.
    public convenience init(descriptor: MetricDescriptor, factory: MetricsFactory) {
        let handler = factory.makeMeter(descriptor: descriptor)
        self.init(label: descriptor.label, dimensions: descriptor.dimensions, handler: handler, factory: factory)
    }

    /// Create a new meter from a descriptor.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Meter`.
    public convenience init(descriptor: MetricDescriptor) {
        self.init(descriptor: descriptor, factory: MetricsSystem.factory)
    }
}

extension Recorder {
    /// Create a new recorder from a descriptor, using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Recorder`.
    ///   - aggregate: A Boolean value that indicates whether to aggregate values.
    ///   - factory: The custom metrics factory.
    public convenience init(descriptor: MetricDescriptor, aggregate: Bool = true, factory: MetricsFactory) {
        let handler = factory.makeRecorder(descriptor: descriptor, aggregate: aggregate)
        self.init(
            label: descriptor.label,
            dimensions: descriptor.dimensions,
            aggregate: aggregate,
            handler: handler,
            factory: factory
        )
    }

    /// Create a new recorder from a descriptor.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Recorder`.
    ///   - aggregate: A Boolean value that indicates whether to aggregate values.
    public convenience init(descriptor: MetricDescriptor, aggregate: Bool = true) {
        self.init(descriptor: descriptor, aggregate: aggregate, factory: MetricsSystem.factory)
    }
}

extension Gauge {
    /// Create a new gauge from a descriptor, using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Gauge`.
    ///   - factory: The custom metrics factory.
    public convenience init(descriptor: MetricDescriptor, factory: MetricsFactory) {
        let handler = factory.makeRecorder(descriptor: descriptor, aggregate: false)
        self.init(
            label: descriptor.label,
            dimensions: descriptor.dimensions,
            aggregate: false,
            handler: handler,
            factory: factory
        )
    }

    /// Create a new gauge from a descriptor.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Gauge`.
    public convenience init(descriptor: MetricDescriptor) {
        self.init(descriptor: descriptor, factory: MetricsSystem.factory)
    }
}

extension Timer {
    /// Create a new timer from a descriptor, using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Timer`.
    ///   - factory: The custom factory.
    public convenience init(descriptor: MetricDescriptor, factory: MetricsFactory) {
        let handler = factory.makeTimer(descriptor: descriptor)
        self.init(label: descriptor.label, dimensions: descriptor.dimensions, handler: handler, factory: factory)
    }

    /// Create a new timer from a descriptor.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Timer`.
    public convenience init(descriptor: MetricDescriptor) {
        self.init(descriptor: descriptor, factory: MetricsSystem.factory)
    }

    /// Create a new timer from a descriptor, with a preferred display unit.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Timer`.
    ///   - displayUnit: A hint to the backend responsible for presenting the data of the preferred display unit. This is not guaranteed to be supported by all backends.
    ///   - factory: The custom factory.
    public convenience init(
        descriptor: MetricDescriptor,
        preferredDisplayUnit displayUnit: TimeUnit,
        factory: MetricsFactory
    ) {
        let handler = factory.makeTimer(descriptor: descriptor)
        handler.preferDisplayUnit(displayUnit)
        self.init(label: descriptor.label, dimensions: descriptor.dimensions, handler: handler, factory: factory)
    }

    /// Create a new timer from a descriptor, with a preferred display unit.
    ///
    /// - parameters:
    ///   - descriptor: The descriptor for the `Timer`.
    ///   - displayUnit: A hint to the backend responsible for presenting the data of the preferred display unit. This is not guaranteed to be supported by all backends.
    public convenience init(descriptor: MetricDescriptor, preferredDisplayUnit displayUnit: TimeUnit) {
        self.init(descriptor: descriptor, preferredDisplayUnit: displayUnit, factory: MetricsSystem.factory)
    }
}
