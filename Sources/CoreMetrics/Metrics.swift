//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// MARK: - User API

// MARK: - Counter

/// A counter is a cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero.
///
/// For example, you can use a counter to represent the number of requests served, tasks completed, or errors.
///
/// This is the user-facing counter API.
/// Its behavior is defined by the ``CounterHandler`` implementation.
public final class Counter {
    /// `_handler` and `_factory` are only public to allow access from `MetricsTestKit`.
    /// Do not consider them part of the public API.
    @_documentation(visibility: internal)
    public let _handler: CounterHandler
    @_documentation(visibility: internal)
    @usableFromInline
    package let _factory: MetricsFactory
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new counter with an explicit counter handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Counter` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Counter`.
    ///     - dimensions: The dimensions for the `Counter`.
    ///     - handler: The custom backend.
    ///     - factory: The custom metrics factory.
    public init(label: String, dimensions: [(String, String)], handler: CounterHandler, factory: MetricsFactory) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
        self._factory = factory
    }

    /// Alternative way to create a new counter, with an explicit counter handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create instances of ``Counter`` using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Counter`.
    ///     - dimensions: The dimensions for the `Counter`.
    ///     - handler: The custom backend, created by the global metrics factory.
    public convenience init(label: String, dimensions: [(String, String)], handler: CounterHandler) {
        self.init(
            label: label,
            dimensions: dimensions,
            handler: handler,
            factory: MetricsSystem.factory
        )
    }

    /// Increment the counter.
    ///
    /// - parameters:
    ///     - amount: Amount to increment by.
    @inlinable
    public func increment<DataType: BinaryInteger>(by amount: DataType) {
        self._handler.increment(by: Int64(amount))
    }

    /// Increment the counter by one.
    @inlinable
    public func increment() {
        self.increment(by: 1)
    }

    /// Reset the counter back to zero.
    @inlinable
    public func reset() {
        self._handler.reset()
    }
}

extension Counter {
    /// Create a new counter.
    ///
    /// - parameters:
    ///     - label: The label for the `Counter`.
    ///     - dimensions: The dimensions for the `Counter`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, factory: MetricsSystem.factory)
    }

    /// Create a new counter using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///     - label: The label for the `Counter`.
    ///     - dimensions: The dimensions for the `Counter`.
    ///     - factory: The custom metrics factory.
    public convenience init(label: String, dimensions: [(String, String)] = [], factory: MetricsFactory) {
        let handler = factory.makeCounter(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler, factory: factory)
    }

    /// Signal the underlying metrics library that this counter will never be updated again.
    ///
    /// In response the library MAY decide to eagerly release any resources held by this counter.
    @inlinable
    public func destroy() {
        self._factory.destroyCounter(self._handler)
    }
}

extension Counter: CustomStringConvertible {
    public var description: String {
        "Counter(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - FloatingPointCounter

/// A floating-point counter is a cumulative metric that represents a single monotonically increasing floating-point counter whose value can only increase or be reset to zero.
///
/// For example, you can use a floating-point counter to represent the number of requests served, tasks completed, or errors.
/// floating-point counter is not supported by all metrics backends, however a default implementation is provided which accumulates floating point values and records increments to a standard counter after crossing integer boundaries.
///
/// This is the user-facing floating-point counter API.
/// Its behavior depends on the ``FloatingCounterHandler`` implementation.
public final class FloatingPointCounter {
    /// `_handler` and `_factory` are only public to allow access from `MetricsTestKit`.
    /// Do not consider them part of the public API.
    @_documentation(visibility: internal)
    public let _handler: FloatingPointCounterHandler
    @_documentation(visibility: internal)
    @usableFromInline
    package let _factory: MetricsFactory
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new floating-point counter, while providing an explicit floating-point counter handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create instances of ``FloatingPointCounter``using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounter`.
    ///     - dimensions: The dimensions for the `FloatingPointCounter`.
    ///     - handler: The custom backend.
    ///     - factory: The custom metrics factory.
    public init(
        label: String,
        dimensions: [(String, String)],
        handler: FloatingPointCounterHandler,
        factory: MetricsFactory
    ) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
        self._factory = factory
    }

    /// Alternative way to create a new floating-point counter, while providing an explicit floating-point counter handler..
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create instances of ``FloatingPointCounter`` using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounter`.
    ///     - dimensions: The dimensions for the `FloatingPointCounter`.
    ///     - handler: The custom backend.
    public convenience init(label: String, dimensions: [(String, String)], handler: FloatingPointCounterHandler) {
        self.init(
            label: label,
            dimensions: dimensions,
            handler: handler,
            factory: MetricsSystem.factory
        )
    }

    /// Increment the floating-point counter.
    ///
    /// - parameters:
    ///     - amount: Amount to increment by.
    @inlinable
    public func increment<DataType: BinaryFloatingPoint>(by amount: DataType) {
        self._handler.increment(by: Double(amount))
    }

    /// Increment the floating-point counter by one.
    @inlinable
    public func increment() {
        self.increment(by: 1.0)
    }

    /// Reset the floating-point counter back to zero.
    @inlinable
    public func reset() {
        self._handler.reset()
    }
}

extension FloatingPointCounter {
    /// Create a new floating-point counter.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounter`.
    ///     - dimensions: The dimensions for the `FloatingPointCounter`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, factory: MetricsSystem.factory)
    }

    /// Create a new floating-point counter using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounter`.
    ///     - dimensions: The dimensions for the `FloatingPointCounter`.
    ///     - factory: The custom metrics factory.
    public convenience init(label: String, dimensions: [(String, String)] = [], factory: MetricsFactory) {
        let handler = factory.makeFloatingPointCounter(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler, factory: factory)
    }

    /// Signal the underlying metrics library that this floating point counter will never be updated again.
    ///
    /// In response the library MAY decide to eagerly release any resources held by this `FloatingPointCounter`.
    @inlinable
    public func destroy() {
        self._factory.destroyFloatingPointCounter(self._handler)
    }
}

extension FloatingPointCounter: CustomStringConvertible {
    public var description: String {
        "FloatingPointCounter(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - Gauge

/// A gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
///
/// Gauges are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads.
/// Gauges are modeled as `Recorder` with a sample size of 1 and that does not perform any aggregation.
public final class Gauge: Recorder, @unchecked Sendable {
    /// Create a new gauge.
    ///
    /// - parameters:
    ///     - label: The label for the `Gauge`.
    ///     - dimensions: The dimensions for the `Gauge`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, aggregate: false)
    }

    /// Create a new gauge using a custom metrics factory that you provide.
    ///
    /// - parameters:
    ///     - label: The label for the `Gauge`.
    ///     - dimensions: The dimensions for the `Gauge`.
    ///     - factory: The custom metrics factory.
    public convenience init(label: String, dimensions: [(String, String)] = [], factory: MetricsFactory) {
        self.init(label: label, dimensions: dimensions, aggregate: false, factory: factory)
    }
}

// MARK: - Meter

/// A meter is similar to a gauge, it is a metric that represents a single numerical value that can arbitrarily go up and down.
///
/// Meters are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads.
public final class Meter {
    /// `_handler` and `_factory` are only public to allow access from `MetricsTestKit`.
    /// Do not consider them part of the public API.
    @_documentation(visibility: internal)
    public let _handler: MeterHandler
    @usableFromInline
    @_documentation(visibility: internal)
    package let _factory: MetricsFactory
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new meter, while providing an explicit meter handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create instances of ``Meter`` using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - handler: The custom backend.
    ///     - factory: The custom metrics factory.
    public init(label: String, dimensions: [(String, String)], handler: MeterHandler, factory: MetricsFactory) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
        self._factory = factory
    }

    /// Alternative way to create a new meter, while providing an explicit meter handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create instances of ``Meter`` using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - handler: The custom backend.
    public convenience init(label: String, dimensions: [(String, String)], handler: MeterHandler) {
        self.init(label: label, dimensions: dimensions, handler: handler, factory: MetricsSystem.factory)
    }

    /// Set an integer value.
    ///
    /// - parameters:
    ///     - value: Value to set.
    @inlinable
    public func set<DataType: BinaryInteger>(_ value: DataType) {
        self._handler.set(Int64(value))
    }

    /// Set a floating-point value.
    ///
    /// - parameters:
    ///     - value: Value to est.
    @inlinable
    public func set<DataType: BinaryFloatingPoint>(_ value: DataType) {
        self._handler.set(Double(value))
    }

    /// Increment the meter.
    ///
    /// - parameters:
    ///     - amount: Amount to increment by.
    @inlinable
    public func increment<DataType: BinaryFloatingPoint>(by amount: DataType) {
        self._handler.increment(by: Double(amount))
    }

    /// Increment the meter by one.
    @inlinable
    public func increment() {
        self.increment(by: 1.0)
    }

    /// Decrement the meter.
    ///
    /// - parameters:
    ///     - amount: Amount to decrement by.
    @inlinable
    public func decrement<DataType: BinaryFloatingPoint>(by amount: DataType) {
        self._handler.decrement(by: Double(amount))
    }

    /// Decrement the meter by one.
    @inlinable
    public func decrement() {
        self.decrement(by: 1.0)
    }
}

extension Meter {
    /// Create a new meter.
    ///
    /// - parameters:
    ///     - label: The label for the `Meter`.
    ///     - dimensions: The dimensions for the `Meter`.
    ///     - factory: The custom metrics factory.
    public convenience init(label: String, dimensions: [(String, String)] = [], factory: MetricsFactory) {
        let handler = factory.makeMeter(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler, factory: factory)
    }

    /// Create a new meter.
    ///
    /// - parameters:
    ///     - label: The label for the `Meter`.
    ///     - dimensions: The dimensions for the `Meter`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, factory: MetricsSystem.factory)
    }

    /// Signal the underlying metrics library that this recorder will never be updated again.
    ///
    /// In response the library MAY decide to eagerly release any resources held by this `Recorder`.
    @inlinable
    public func destroy() {
        self._factory.destroyMeter(self._handler)
    }
}

extension Meter: CustomStringConvertible {
    public var description: String {
        "\(type(of: self))(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - Recorder

/// A recorder collects observations within a time window.
///
/// An example is using a recorder to capture response sizes.
/// A recorder *can* provide aggregated information about the data sample such as count, sum, min, max, and various quantiles.
///
/// This is the user-facing Recorder API.
/// Its behavior depends on the ``RecorderHandler`` implementation.
public class Recorder {
    /// `_handler` and `_factory` are only public to allow access from `MetricsTestKit`.
    /// Do not consider them part of the public API.
    @_documentation(visibility: internal)
    public let _handler: RecorderHandler
    @_documentation(visibility: internal)
    @usableFromInline
    package let _factory: MetricsFactory
    public let label: String
    public let dimensions: [(String, String)]
    public let aggregate: Bool

    /// Alternative way to create a new recorder, while providing an explicit recorder handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Recorder` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - aggregate: aggregate recorded values to produce statistics across a sample size
    ///     - handler: The custom backend.
    ///     - factory: The custom metrics factory.
    public init(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool,
        handler: RecorderHandler,
        factory: MetricsFactory
    ) {
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
        self._handler = handler
        self._factory = factory
    }

    /// Alternative way to create a new recorder, while providing an explicit recorder handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Recorder` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - aggregate: aggregate recorded values to produce statistics across a sample size
    ///     - handler: The custom backend.
    public convenience init(label: String, dimensions: [(String, String)], aggregate: Bool, handler: RecorderHandler) {
        self.init(
            label: label,
            dimensions: dimensions,
            aggregate: aggregate,
            handler: handler,
            factory: MetricsSystem.factory
        )
    }

    /// Record a value.
    ///
    /// Recording a value is meant to have "set" semantics, rather than "add" semantics.
    /// This means that the value of this `Recorder` will match the passed in value, rather than accumulate and sum the values up.
    ///
    /// - parameters:
    ///     - value: Value to record.
    @inlinable
    public func record<DataType: BinaryInteger>(_ value: DataType) {
        self._handler.record(Int64(value))
    }

    /// Record a value.
    ///
    /// Recording a value is meant to have "set" semantics, rather than "add" semantics.
    /// This means that the value of this `Recorder` will match the passed in value, rather than accumulate and sum the values up.
    ///
    /// - parameters:
    ///     - value: Value to record.
    @inlinable
    public func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
        self._handler.record(Double(value))
    }
}

extension Recorder {
    /// Create a new recorder.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - aggregate: aggregate recorded values to produce statistics across a sample size
    public convenience init(label: String, dimensions: [(String, String)] = [], aggregate: Bool = true) {
        self.init(label: label, dimensions: dimensions, aggregate: aggregate, factory: MetricsSystem.factory)
    }

    /// Create a new recorder using a custom metrics factory that you provide..
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - aggregate: aggregate recorded values to produce statistics across a sample size.
    ///     - factory: The custom metrics factory.
    public convenience init(
        label: String,
        dimensions: [(String, String)] = [],
        aggregate: Bool = true,
        factory: MetricsFactory
    ) {
        let handler = factory.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        self.init(label: label, dimensions: dimensions, aggregate: aggregate, handler: handler, factory: factory)
    }

    /// Signal the underlying metrics library that this recorder will never be updated again.
    ///
    /// In response the library MAY decide to eagerly release any resources held by this `Recorder`.
    @inlinable
    public func destroy() {
        self._factory.destroyRecorder(self._handler)
    }
}

extension Recorder: CustomStringConvertible {
    public var description: String {
        "\(type(of: self))(\(self.label), dimensions: \(self.dimensions), aggregate: \(self.aggregate))"
    }
}

// MARK: - Timer

/// A unit of time.
public struct TimeUnit: Equatable, Sendable {
    private enum Code: Equatable, Sendable {
        case nanoseconds
        case microseconds
        case milliseconds
        case seconds
        case minutes
        case hours
        case days
    }

    private let code: Code
    /// The number of nanoseconds in this time unit.
    public let scaleFromNanoseconds: UInt64

    private init(code: Code, scaleFromNanoseconds: UInt64) {
        assert(scaleFromNanoseconds > 0, "invalid scale from nanoseconds")

        self.code = code
        self.scaleFromNanoseconds = scaleFromNanoseconds
    }
    
    /// A nanosecond.
    public static let nanoseconds = TimeUnit(code: .nanoseconds, scaleFromNanoseconds: 1)
    /// A microsecond.
    public static let microseconds = TimeUnit(code: .microseconds, scaleFromNanoseconds: 1000)
    /// A millisecond.
    public static let milliseconds = TimeUnit(
        code: .milliseconds,
        scaleFromNanoseconds: 1000 * TimeUnit.microseconds.scaleFromNanoseconds
    )
    /// A second.
    public static let seconds = TimeUnit(
        code: .seconds,
        scaleFromNanoseconds: 1000 * TimeUnit.milliseconds.scaleFromNanoseconds
    )
    /// A minute.
    public static let minutes = TimeUnit(
        code: .minutes,
        scaleFromNanoseconds: 60 * TimeUnit.seconds.scaleFromNanoseconds
    )
    /// An hour.
    public static let hours = TimeUnit(code: .hours, scaleFromNanoseconds: 60 * TimeUnit.minutes.scaleFromNanoseconds)
    /// A day.
    public static let days = TimeUnit(code: .days, scaleFromNanoseconds: 24 * TimeUnit.hours.scaleFromNanoseconds)
}

/// A timer collects observations that represents durations within a time window.
///
/// It is similar to a `Recorder` but specialized for values that represent durations, such as request durations.
/// A time provides  aggregated information about the data sample, such as min, max, and various quantiles.
///
/// This is the user-facing Timer API.
/// Its behavior depends on the ``TimerHandler`` implementation.
public final class Timer {
    /// `_handler` and `_factory` are only public to allow access from `MetricsTestKit`.
    /// Do not consider them part of the public API.
    @_documentation(visibility: internal)
    public let _handler: TimerHandler
    @_documentation(visibility: internal)
    @usableFromInline
    package let _factory: MetricsFactory
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new timer, while providing an explicit timer handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create instances of ``Timer`` using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    ///     - handler: The custom backend.
    ///     - factory: The custom factory.
    public init(label: String, dimensions: [(String, String)], handler: TimerHandler, factory: MetricsFactory) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
        self._factory = factory
    }

    /// Alternative way to create a new timer, while providing an explicit timer handler.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create instances of ``Timer`` using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    ///     - handler: The custom backend.
    public convenience init(label: String, dimensions: [(String, String)], handler: TimerHandler) {
        self.init(label: label, dimensions: dimensions, handler: handler, factory: MetricsSystem.factory)
    }

    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordNanoseconds(_ duration: Int64) {
        self._handler.recordNanoseconds(duration)
    }

    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordNanoseconds<DataType: BinaryInteger>(_ duration: DataType) {
        self.recordNanoseconds(duration >= Int64.max ? Int64.max : Int64(duration))
    }

    /// Record a duration in microseconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordMicroseconds<DataType: BinaryInteger>(_ duration: DataType) {
        guard duration <= Int64.max else { return self.recordNanoseconds(Int64.max) }

        let result = Int64(duration).multipliedReportingOverflow(by: 1000)
        if result.overflow {
            self.recordNanoseconds(Int64.max)
        } else {
            self.recordNanoseconds(result.partialValue)
        }
    }

    /// Record a duration in microseconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordMicroseconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(Double(duration * 1000) < Double(Int64.max) ? Int64(duration * 1000) : Int64.max)
    }

    /// Record a duration in milliseconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordMilliseconds<DataType: BinaryInteger>(_ duration: DataType) {
        guard duration <= Int64.max else { return self.recordNanoseconds(Int64.max) }

        let result = Int64(duration).multipliedReportingOverflow(by: 1_000_000)
        if result.overflow {
            self.recordNanoseconds(Int64.max)
        } else {
            self.recordNanoseconds(result.partialValue)
        }
    }

    /// Record a duration in milliseconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordMilliseconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(
            Double(duration * 1_000_000) < Double(Int64.max) ? Int64(duration * 1_000_000) : Int64.max
        )
    }

    /// Record a duration in seconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordSeconds<DataType: BinaryInteger>(_ duration: DataType) {
        guard duration <= Int64.max else { return self.recordNanoseconds(Int64.max) }

        let result = Int64(duration).multipliedReportingOverflow(by: 1_000_000_000)
        if result.overflow {
            self.recordNanoseconds(Int64.max)
        } else {
            self.recordNanoseconds(result.partialValue)
        }
    }

    /// Record a duration in seconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    @inlinable
    public func recordSeconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(
            Double(duration * 1_000_000_000) < Double(Int64.max) ? Int64(duration * 1_000_000_000) : Int64.max
        )
    }
}

extension Timer {
    /// Create a new timer.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    ///     - factory: The custom factory.
    public convenience init(label: String, dimensions: [(String, String)] = [], factory: MetricsFactory) {
        let handler = factory.makeTimer(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler, factory: factory)
    }

    /// Create a new timer using a custom metrics factory that you provide..
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, factory: MetricsSystem.factory)
    }

    /// Create a new timer.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    ///     - displayUnit: A hint to the backend responsible for presenting the data of the preferred display unit. This is not guaranteed to be supported by all backends.
    ///     - factory: The custom factory.
    public convenience init(
        label: String,
        dimensions: [(String, String)] = [],
        preferredDisplayUnit displayUnit: TimeUnit,
        factory: MetricsFactory
    ) {
        let handler = factory.makeTimer(label: label, dimensions: dimensions)
        handler.preferDisplayUnit(displayUnit)
        self.init(label: label, dimensions: dimensions, handler: handler, factory: factory)
    }

    /// Create a new timer.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    ///     - displayUnit: A hint to the backend responsible for presenting the data of the preferred display unit. This is not guaranteed to be supported by all backends.
    public convenience init(
        label: String,
        dimensions: [(String, String)] = [],
        preferredDisplayUnit displayUnit: TimeUnit
    ) {
        self.init(
            label: label,
            dimensions: dimensions,
            preferredDisplayUnit: displayUnit,
            factory: MetricsSystem.factory
        )
    }

    /// Signal the underlying metrics library that this timer will never be updated again.
    ///
    /// In response the library MAY decide to eagerly release any resources held by this `Timer`.
    @inlinable
    public func destroy() {
        self._factory.destroyTimer(self._handler)
    }
}

extension Timer: CustomStringConvertible {
    public var description: String {
        "Timer(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - MetricsSystem

/// A global facility where the default metrics backend implementation is configured.
///
/// `MetricsSystem` is set up just once in a given program to create the desired metrics backend
/// implementation using ``MetricsFactory``.
public enum MetricsSystem {
    private static let _factory = FactoryBox(NOOPMetricsHandler.instance)

    /// A one-time configuration function which globally selects the desired metrics backend
    /// implementation.
    ///
    /// `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behavior, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A factory that given an identifier produces instances of metrics handlers such as ``CounterHandler``, ``RecorderHandler``, or  ``TimerHandler``.
    public static func bootstrap(_ factory: MetricsFactory) {
        self._factory.replaceFactory(factory, validate: true)
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(_ factory: MetricsFactory) {
        self._factory.replaceFactory(factory, validate: false)
    }

    /// Returns a reference to the configured factory.
    public static var factory: MetricsFactory {
        self._factory.underlying
    }

    /// Acquire a writer lock for the duration of the given block.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    public static func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        try self._factory.withWriterLock(body)
    }

    // This can be `@unchecked Sendable` because we're manually gating access to mutable state with a lock.
    private final class FactoryBox: @unchecked Sendable {
        private let lock = ReadWriteLock()
        fileprivate var _underlying: MetricsFactory
        private var initialized = false

        init(_ underlying: MetricsFactory) {
            self._underlying = underlying
        }

        func replaceFactory(_ factory: MetricsFactory, validate: Bool) {
            self.lock.withWriterLock {
                precondition(
                    !validate || !self.initialized,
                    "metrics system can only be initialized once per process. currently used factory: \(self._underlying)"
                )
                self._underlying = factory
                self.initialized = true
            }
        }

        var underlying: MetricsFactory {
            self.lock.withReaderLock {
                self._underlying
            }
        }

        func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
            try self.lock.withWriterLock(body)
        }
    }
}

// MARK: - Library SPI, intended to be implemented by backend libraries

// MARK: - MetricsFactory

/// The `MetricsFactory` is the bridge between the `MetricsSystem` and the metrics backend implementation.
///
/// The role of `MetricsFactory` is to initialize concrete implementations of the various metric types:
/// * `Counter` -> `CounterHandler`
/// * `FloatingPointCounter` -> `FloatingPointCounterHandler`
/// * `Recorder` -> `RecorderHandler`
/// * `Timer` -> `TimerHandler`
///
/// To use the SwiftMetrics API, please refer to the documentation of `MetricsSystem`.
///
/// ### Destroying metrics
///
/// Since _some_ metrics implementations may need to allocate (potentially "heavy") resources for metrics, destroying
/// metrics offers a signal to libraries when a metric is "known to never be updated again."
///
/// While many metrics are bound to the entire lifetime of an application and thus never need to be destroyed eagerly,
/// some metrics have well defined unique life-cycles where it may be beneficial to release any resources held by them
/// more eagerly than awaiting the application's termination. In such cases, a library or application should invoke
/// a metric's appropriate `destroy()` method, which in turn results in the corresponding handler that it is backed by
/// to be passed to `destroyCounter(handler:)`, `destroyRecorder(handler:)` or `destroyTimer(handler:)` where the factory
/// can decide to free any corresponding resources.
///
/// While some libraries may not need to implement this destroying as they may be stateless or similar,
/// libraries using the metrics API should always assume a library WILL make use of this signal, and shall not
/// neglect calling these methods when appropriate.
public protocol MetricsFactory: _SwiftMetricsSendableProtocol {
    /// Create a backing counter handler.
    ///
    /// - parameters:
    ///     - label: The label for the `CounterHandler`.
    ///     - dimensions: The dimensions for the `CounterHandler`.
    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler

    /// Create a backing floating-point handler.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounterHandler`.
    ///     - dimensions: The dimensions for the `FloatingPointCounterHandler`.
    func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler

    /// Create a backing meter handler.
    ///
    /// - parameters:
    ///     - label: The label for the `MeterHandler`.
    ///     - dimensions: The dimensions for the `MeterHandler`.
    func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler

    /// Create a backing recorder handler.
    ///
    /// - parameters:
    ///     - label: The label for the `RecorderHandler`.
    ///     - dimensions: The dimensions for the `RecorderHandler`.
    ///     - aggregate: Is data aggregation expected.
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler

    /// Create a backing timer handler.
    ///
    /// - parameters:
    ///     - label: The label for the `TimerHandler`.
    ///     - dimensions: The dimensions for the `TimerHandler`.
    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler

    /// Invoked when the corresponding counter's `destroy()` function is invoked.
    ///
    /// Upon receiving this signal the factory may eagerly release any resources related to this counter.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyCounter(_ handler: CounterHandler)

    /// Invoked when the corresponding meter's `destroy()` function is invoked.
    ///
    /// Upon receiving this signal the factory may eagerly release any resources related to this recorder.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyMeter(_ handler: MeterHandler)

    /// Invoked when the corresponding floating-point counter's `destroy()` function is invoked.
    ///
    /// Upon receiving this signal the factory may eagerly release any resources related to this counter.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler)

    /// Invoked when the corresponding recorder's `destroy()` function is invoked.
    ///
    /// Upon receiving this signal the factory may eagerly release any resources related to this recorder.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyRecorder(_ handler: RecorderHandler)

    /// Invoked when the corresponding Timer's `destroy()` function is invoked.
    ///
    /// Upon receiving this signal the factory may eagerly release any resources related to this timer.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyTimer(_ handler: TimerHandler)
}

/// Wraps a CounterHandler, adding support for incrementing by floating point values by storing an accumulated floating point value and recording increments to the underlying CounterHandler after crossing integer boundaries.
internal final class AccumulatingRoundingFloatingPointCounter: FloatingPointCounterHandler {
    private let lock = Lock()
    private let counterHandler: CounterHandler
    private let factory: MetricsFactory
    internal var fraction: Double = 0

    init(label: String, dimensions: [(String, String)], factory: MetricsFactory) {
        self.counterHandler = factory.makeCounter(label: label, dimensions: dimensions)
        self.factory = factory
    }

    func increment(by amount: Double) {
        // Drop illegal values
        // - cannot increment by NaN
        guard !amount.isNaN else { return }
        // - cannot increment by infinite quantities
        guard !amount.isInfinite else { return }
        // - cannot increment by negative values
        guard amount.sign == .plus else { return }
        // - cannot increment by zero
        guard !amount.isZero else { return }

        if amount.exponent >= 63 {
            // If amount is in Int64.max..<+Inf, ceil to Int64.max
            self.lock.withLockVoid {
                self.counterHandler.increment(by: .max)
            }
        } else {
            // Split amount into integer and fraction components
            var (increment, fraction) = self.integerAndFractionComponents(of: amount)
            self.lock.withLockVoid {
                // Add the fractional component to the accumulated fraction.
                self.fraction += fraction
                // self.fraction may have cross an integer boundary, Split it
                // and add any integer component.
                let (integer, fraction) = integerAndFractionComponents(of: self.fraction)
                increment += integer
                self.fraction = fraction
                // Increment the handler by the total integer component.
                if increment > 0 {
                    self.counterHandler.increment(by: increment)
                }
            }
        }
    }

    @inline(__always)
    private func integerAndFractionComponents(of value: Double) -> (Int64, Double) {
        let integer = Int64(value)
        let fraction = value - value.rounded(.towardZero)
        return (integer, fraction)
    }

    func reset() {
        self.lock.withLockVoid {
            self.fraction = 0
            self.counterHandler.reset()
        }
    }

    func destroy() {
        self.factory.destroyCounter(self.counterHandler)
    }
}

/// Wraps a RecorderHandler, adding support for incrementing values by storing an accumulated  value and recording increments to the underlying CounterHandler after crossing integer boundaries.
/// - Note: we can annotate this class as `@unchecked Sendable` because we are manually gating access to mutable state (i.e., the `value` property) via a Lock.
internal final class AccumulatingMeter: MeterHandler, @unchecked Sendable {
    private let recorderHandler: RecorderHandler
    // FIXME: use swift-atomics when floating point support is available
    private var value: Double = 0
    private let lock = Lock()
    private let factory: MetricsFactory

    init(label: String, dimensions: [(String, String)], factory: MetricsFactory) {
        self.recorderHandler = factory.makeRecorder(label: label, dimensions: dimensions, aggregate: true)
        self.factory = factory
    }

    func set(_ value: Int64) {
        self._set(Double(value))
    }

    func set(_ value: Double) {
        self._set(value)
    }

    func increment(by amount: Double) {
        // Drop illegal values
        // - cannot increment by NaN
        guard !amount.isNaN else {
            return
        }
        // - cannot increment by infinite quantities
        guard !amount.isInfinite else {
            return
        }
        // - cannot increment by negative values
        guard amount.sign == .plus else {
            return
        }
        // - cannot increment by zero
        guard !amount.isZero else {
            return
        }

        let newValue: Double = self.lock.withLock {
            self.value += amount
            return self.value
        }
        self.recorderHandler.record(newValue)
    }

    func decrement(by amount: Double) {
        // Drop illegal values
        // - cannot decrement by NaN
        guard !amount.isNaN else {
            return
        }
        // - cannot decrement by infinite quantities
        guard !amount.isInfinite else {
            return
        }
        // - cannot decrement by negative values
        guard amount.sign == .plus else {
            return
        }
        // - cannot decrement by zero
        guard !amount.isZero else {
            return
        }

        let newValue: Double = self.lock.withLock {
            self.value -= amount
            return self.value
        }
        self.recorderHandler.record(newValue)
    }

    private func _set(_ value: Double) {
        self.lock.withLockVoid {
            self.value = value
        }
        self.recorderHandler.record(value)
    }

    func destroy() {
        self.factory.destroyRecorder(self.recorderHandler)
    }
}

extension MetricsFactory {
    /// Create a default backing floating-point counter handler for backends which do not naively support floating point counters.
    ///
    /// The created floating-point counter handler is a wrapper around a backend's counter handler which accumulates floating point values and records increments to an underlying counter handler after crossing integer boundaries.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounterHandler`.
    ///     - dimensions: The dimensions for the `FloatingPointCounterHandler`.
    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        AccumulatingRoundingFloatingPointCounter(label: label, dimensions: dimensions, factory: self)
    }

    /// Invoked when the corresponding floating-point counter's `destroy()` function is invoked.
    ///
    /// Upon receiving this signal the factory may eagerly release any resources related to this counter.
    ///
    /// `destroyFloatingPointCounter` must be implemented if `makeFloatingPointCounter` is implemented.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        (handler as? AccumulatingRoundingFloatingPointCounter)?.destroy()
    }
}

extension MetricsFactory {
    /// Create a default backing meter handler for backends which do not naively support meters.
    ///
    /// The created MeterHandler is a wrapper around a backend's RecorderHandler which records current values.
    ///
    /// - parameters:
    ///     - label: The label for the `MeterHandler`.
    ///     - dimensions: The dimensions for the `MeterHandler`.
    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        AccumulatingMeter(label: label, dimensions: dimensions, factory: self)
    }

    /// Invoked when the corresponding meter's `destroy()` function is invoked.
    ///
    /// Upon receiving this signal the factory may eagerly release any resources related to this counter.
    ///
    /// `destroyMeter` must be implemented if `makeMeter` is implemented.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    public func destroyMeter(_ handler: MeterHandler) {
        (handler as? AccumulatingMeter)?.destroy()
    }
}

// MARK: - Backend Handlers

/// A counter handler represents a backend implementation of a counter.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Counter`.
///
/// ### Implementation requirements
///
/// To implement your own `CounterHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `CounterHandler` implementation.
///
/// - The `CounterHandler` must be a `class`.
public protocol CounterHandler: AnyObject, _SwiftMetricsSendableProtocol {
    /// Increment the counter.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
    func increment(by: Int64)

    /// Reset the counter back to zero.
    func reset()
}

/// A floating-point counter handler represents a backend implementation of a floating-point counter.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `FloatingPointCounter`.
///
/// ### Implementation requirements
///
/// To implement your own `FloatingPointCounterHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `FloatingPointCounterHandler` implementation.
///
/// - The `FloatingPointCounterHandler` must be a `class`.
public protocol FloatingPointCounterHandler: AnyObject, _SwiftMetricsSendableProtocol {
    /// Increment the counter.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
    func increment(by: Double)

    /// Reset the counter back to zero.
    func reset()
}

/// A recorder handler represents a backend implementation of a recorder.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Recorder`.
///
/// ### Implementation requirements
///
/// To implement your own `RecorderHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `RecorderHandler` implementation.
///
/// - The `RecorderHandler` must be a `class`.
public protocol RecorderHandler: AnyObject, _SwiftMetricsSendableProtocol {
    /// Record an integer value.
    ///
    /// - parameters:
    ///     - value: Value to record.
    func record(_ value: Int64)
    /// Record a floating-point value.
    ///
    /// - parameters:
    ///     - value: Value to record.
    func record(_ value: Double)
}

/// A meter handler represents a backend implementation of a meter.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Meter`.
///
/// ### Implementation requirements
///
/// To implement your own `MeterHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `MeterHandler` implementation.
///
/// - The `RecorderHandler` must be a `class`.
public protocol MeterHandler: AnyObject, _SwiftMetricsSendableProtocol {
    /// Set an integer value.
    ///
    /// - parameters:
    ///     - value: Value to set.
    func set(_ value: Int64)
    /// Set a floating-point value.
    ///
    /// - parameters:
    ///     - value: Value to set.
    func set(_ value: Double)

    /// Increment the value.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
    func increment(by: Double)

    /// Decrement the value.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
    func decrement(by: Double)
}

/// A timer handler represents a backend implementation of a timer.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Timer`.
///
/// ### Implementation requirements
///
/// To implement your own `TimerHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `TimerHandler` implementation.
///
/// - The `TimerHandler` must be a `class`.
public protocol TimerHandler: AnyObject, _SwiftMetricsSendableProtocol {
    
    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - duration: Duration to record.
    func recordNanoseconds(_ duration: Int64)

    /// Set the preferred display unit for this timer handler.
    ///
    /// - parameters:
    ///     - unit: A hint to the backend responsible for presenting the data of the preferred display unit. This is not guaranteed to be supported by all backends.
    func preferDisplayUnit(_ unit: TimeUnit)
}

extension TimerHandler {
    public func preferDisplayUnit(_: TimeUnit) {
        // NOOP
    }
}

// MARK: - Predefined Metrics Handlers

/// A pseudo-metrics handler that can be used to send messages to multiple other metrics handlers.
public final class MultiplexMetricsHandler: MetricsFactory {
    private let factories: [MetricsFactory]
    public init(factories: [MetricsFactory]) {
        self.factories = factories
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        MuxCounter(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        MuxFloatingPointCounter(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        MuxMeter(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        MuxRecorder(factories: self.factories, label: label, dimensions: dimensions, aggregate: aggregate)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        MuxTimer(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func destroyCounter(_ handler: CounterHandler) {
        for factory in self.factories {
            factory.destroyCounter(handler)
        }
    }

    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        for factory in self.factories {
            factory.destroyFloatingPointCounter(handler)
        }
    }

    public func destroyMeter(_ handler: MeterHandler) {
        for factory in self.factories {
            factory.destroyMeter(handler)
        }
    }

    public func destroyRecorder(_ handler: RecorderHandler) {
        for factory in self.factories {
            factory.destroyRecorder(handler)
        }
    }

    public func destroyTimer(_ handler: TimerHandler) {
        for factory in self.factories {
            factory.destroyTimer(handler)
        }
    }

    private final class MuxCounter: CounterHandler {
        let counters: [CounterHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.counters = factories.map { $0.makeCounter(label: label, dimensions: dimensions) }
        }

        func increment(by amount: Int64) {
            for counter in self.counters { counter.increment(by: amount) }
        }

        func reset() {
            for counter in self.counters { counter.reset() }
        }
    }

    private final class MuxFloatingPointCounter: FloatingPointCounterHandler {
        let counters: [FloatingPointCounterHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.counters = factories.map { $0.makeFloatingPointCounter(label: label, dimensions: dimensions) }
        }

        func increment(by amount: Double) {
            for counter in self.counters { counter.increment(by: amount) }
        }

        func reset() {
            for counter in self.counters { counter.reset() }
        }
    }

    private final class MuxMeter: MeterHandler {
        let meters: [MeterHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.meters = factories.map { $0.makeMeter(label: label, dimensions: dimensions) }
        }

        func set(_ value: Int64) {
            for meter in self.meters { meter.set(value) }
        }

        func set(_ value: Double) {
            for meter in self.meters { meter.set(value) }
        }

        func increment(by amount: Double) {
            for meter in self.meters { meter.increment(by: amount) }
        }

        func decrement(by amount: Double) {
            for meter in self.meters { meter.decrement(by: amount) }
        }
    }

    private final class MuxRecorder: RecorderHandler {
        let recorders: [RecorderHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)], aggregate: Bool) {
            self.recorders = factories.map {
                $0.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
            }
        }

        func record(_ value: Int64) {
            for recorder in self.recorders { recorder.record(value) }
        }

        func record(_ value: Double) {
            for recorder in self.recorders { recorder.record(value) }
        }
    }

    private final class MuxTimer: TimerHandler {
        let timers: [TimerHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.timers = factories.map { $0.makeTimer(label: label, dimensions: dimensions) }
        }

        func recordNanoseconds(_ duration: Int64) {
            for timer in self.timers { timer.recordNanoseconds(duration) }
        }

        func preferDisplayUnit(_ unit: TimeUnit) {
            for timer in self.timers { timer.preferDisplayUnit(unit) }
        }
    }
}

/// A metrics handler that implements the protocols but does nothing.
///
/// The no-op metrics handler ships with the metrics module, and is used for initial bootstrapping.
public final class NOOPMetricsHandler: MetricsFactory, CounterHandler, FloatingPointCounterHandler, MeterHandler,
    RecorderHandler, TimerHandler
{
    public static let instance = NOOPMetricsHandler()

    private init() {}

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        self
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        self
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        self
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        self
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        self
    }

    public func destroyCounter(_: CounterHandler) {}
    public func destroyFloatingPointCounter(_: FloatingPointCounterHandler) {}
    public func destroyMeter(_: MeterHandler) {}
    public func destroyRecorder(_: RecorderHandler) {}
    public func destroyTimer(_: TimerHandler) {}

    public func increment(by: Int64) {}
    public func increment(by: Double) {}
    public func decrement(by: Double) {}
    public func reset() {}
    public func record(_: Int64) {}
    public func record(_: Double) {}
    public func recordNanoseconds(_: Int64) {}
    public func set(_: Int64) {}
    public func set(_: Double) {}
}

// MARK: - Sendable support helpers

extension MetricsSystem: Sendable {}
extension Counter: Sendable {}
extension FloatingPointCounter: Sendable {}
// must be @unchecked since Gauge inherits Recorder :(
extension Recorder: @unchecked Sendable {}
extension Timer: Sendable {}
extension Meter: Sendable {}
// ideally we would not be using @unchecked here, but concurrency-safety checks do not recognize locks
extension AccumulatingRoundingFloatingPointCounter: @unchecked Sendable {}

@preconcurrency public protocol _SwiftMetricsSendableProtocol: Sendable {}
