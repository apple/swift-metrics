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
/// For example, you can use a counter to represent the number of requests served, tasks completed, or errors.
///
/// This is the user-facing Counter API.
///
/// Its behavior depends on the `CounterHandler` implementation.
public final class Counter {
    /// ``_handler`` is only public to allow access from `MetricsTestKit`. Do not consider it part of the public API.
    public let _handler: CounterHandler
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new `Counter`, while providing an explicit `CounterHandler`.
    ///
    /// - warning: This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    ///            We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Counter` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Counter`.
    ///     - dimensions: The dimensions for the `Counter`.
    ///     - handler: The custom backend.
    public init(label: String, dimensions: [(String, String)], handler: CounterHandler) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
    }

    /// Increment the counter.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
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
    /// Create a new `Counter`.
    ///
    /// - parameters:
    ///     - label: The label for the `Counter`.
    ///     - dimensions: The dimensions for the `Counter`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        let handler = MetricsSystem.factory.makeCounter(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler)
    }

    /// Signal the underlying metrics library that this counter will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `Counter`.
    @inlinable
    public func destroy() {
        MetricsSystem.factory.destroyCounter(self._handler)
    }
}

extension Counter: CustomStringConvertible {
    public var description: String {
        return "Counter(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - FloatingPointCounter

/// A FloatingPointCounter is a cumulative metric that represents a single monotonically increasing FloatingPointCounter whose value can only increase or be reset to zero.
/// For example, you can use a FloatingPointCounter to represent the number of requests served, tasks completed, or errors.
/// FloatingPointCounter is not supported by all metrics backends, however a default implementation is provided which accumulates floating point values and records increments to a standard Counter after crossing integer boundaries.
///
/// This is the user-facing FloatingPointCounter API.
///
/// Its behavior depends on the `FloatingCounterHandler` implementation.
public final class FloatingPointCounter {
    /// ``_handler`` is only public to allow access from `MetricsTestKit`. Do not consider it part of the public API.
    public let _handler: FloatingPointCounterHandler
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new `FloatingPointCounter`, while providing an explicit `FloatingPointCounterHandler`.
    ///
    /// - warning: This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    ///            We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `FloatingPointCounter` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounter`.
    ///     - dimensions: The dimensions for the `FloatingPointCounter`.
    ///     - handler: The custom backend.
    public init(label: String, dimensions: [(String, String)], handler: FloatingPointCounterHandler) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
    }

    /// Increment the FloatingPointCounter.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
    @inlinable
    public func increment<DataType: BinaryFloatingPoint>(by amount: DataType) {
        self._handler.increment(by: Double(amount))
    }

    /// Increment the FloatingPointCounter by one.
    @inlinable
    public func increment() {
        self.increment(by: 1.0)
    }

    /// Reset the FloatingPointCounter back to zero.
    @inlinable
    public func reset() {
        self._handler.reset()
    }
}

extension FloatingPointCounter {
    /// Create a new `FloatingPointCounter`.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounter`.
    ///     - dimensions: The dimensions for the `FloatingPointCounter`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        let handler = MetricsSystem.factory.makeFloatingPointCounter(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler)
    }

    /// Signal the underlying metrics library that this FloatingPointCounter will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `FloatingPointCounter`.
    @inlinable
    public func destroy() {
        MetricsSystem.factory.destroyFloatingPointCounter(self._handler)
    }
}

extension FloatingPointCounter: CustomStringConvertible {
    public var description: String {
        return "FloatingPointCounter(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - Gauge

/// A gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
/// Gauges are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads.
/// Gauges are modeled as `Recorder` with a sample size of 1 and that does not perform any aggregation.
@available(*, deprecated, message: "replaced by Gauger")
public final class Gauge: Recorder {
    /// Create a new `Gauge`.
    ///
    /// - parameters:
    ///     - label: The label for the `Gauge`.
    ///     - dimensions: The dimensions for the `Gauge`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, aggregate: false)
    }
}

// MARK: - Gauger

/// A gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
/// Gauges are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads.
public final class Gauger {
    /// ``_handler`` is only public to allow access from `MetricsTestKit`. Do not consider it part of the public API.
    public let _handler: GaugeHandler
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new `Gauger`, while providing an explicit `GaugeHandler`.
    ///
    /// - warning: This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    ///            We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Gauger` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - handler: The custom backend.
    public init(label: String, dimensions: [(String, String)], handler: GaugeHandler) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
    }

    /// Set a value.
    ///
    /// - parameters:
    ///     - value: Value to set.
    @inlinable
    public func set<DataType: BinaryInteger>(_ value: DataType) {
        self._handler.set(Int64(value))
    }

    /// Set a value.
    ///
    /// - parameters:
    ///     - value: Value to est.
    @inlinable
    public func set<DataType: BinaryFloatingPoint>(_ value: DataType) {
        self._handler.set(Double(value))
    }
}

extension Gauger {
    /// Create a new `Gauger`.
    ///
    /// - parameters:
    ///     - label: The label for the `Gauger`.
    ///     - dimensions: The dimensions for the `Gauger`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        let handler = MetricsSystem.factory.makeGauge(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler)
    }

    /// Signal the underlying metrics library that this recorder will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `Recorder`.
    @inlinable
    public func destroy() {
        MetricsSystem.factory.destroyGauge(self._handler)
    }
}

extension Gauger: CustomStringConvertible {
    public var description: String {
        return "\(type(of: self))(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - Recorder

/// A recorder collects observations within a time window (usually things like response sizes) and *can* provide aggregated information about the data sample, for example, count, sum, min, max and various quantiles.
///
/// This is the user-facing Recorder API.
///
/// Its behavior depends on the `RecorderHandler` implementation.
public class Recorder {
    /// ``_handler`` is only public to allow access from `MetricsTestKit`. Do not consider it part of the public API.
    public let _handler: RecorderHandler
    public let label: String
    public let dimensions: [(String, String)]
    public let aggregate: Bool

    /// Alternative way to create a new `Recorder`, while providing an explicit `RecorderHandler`.
    ///
    /// - warning: This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    ///            We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Recorder` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - aggregate: aggregate recorded values to produce statistics across a sample size
    ///     - handler: The custom backend.
    public init(label: String, dimensions: [(String, String)], aggregate: Bool, handler: RecorderHandler) {
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
        self._handler = handler
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
    /// Create a new `Recorder`.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - aggregate: aggregate recorded values to produce statistics across a sample size
    public convenience init(label: String, dimensions: [(String, String)] = [], aggregate: Bool = true) {
        let handler = MetricsSystem.factory.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        self.init(label: label, dimensions: dimensions, aggregate: aggregate, handler: handler)
    }

    /// Signal the underlying metrics library that this recorder will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `Recorder`.
    @inlinable
    public func destroy() {
        MetricsSystem.factory.destroyRecorder(self._handler)
    }
}

extension Recorder: CustomStringConvertible {
    public var description: String {
        return "\(type(of: self))(\(self.label), dimensions: \(self.dimensions), aggregate: \(self.aggregate))"
    }
}

// MARK: - Timer

public struct TimeUnit: Equatable {
    private enum Code: Equatable {
        case nanoseconds
        case microseconds
        case milliseconds
        case seconds
        case minutes
        case hours
        case days
    }

    private let code: Code
    public let scaleFromNanoseconds: UInt64

    private init(code: Code, scaleFromNanoseconds: UInt64) {
        assert(scaleFromNanoseconds > 0, "invalid scale from nanoseconds")

        self.code = code
        self.scaleFromNanoseconds = scaleFromNanoseconds
    }

    public static let nanoseconds = TimeUnit(code: .nanoseconds, scaleFromNanoseconds: 1)
    public static let microseconds = TimeUnit(code: .microseconds, scaleFromNanoseconds: 1000)
    public static let milliseconds = TimeUnit(code: .milliseconds, scaleFromNanoseconds: 1000 * TimeUnit.microseconds.scaleFromNanoseconds)
    public static let seconds = TimeUnit(code: .seconds, scaleFromNanoseconds: 1000 * TimeUnit.milliseconds.scaleFromNanoseconds)
    public static let minutes = TimeUnit(code: .minutes, scaleFromNanoseconds: 60 * TimeUnit.seconds.scaleFromNanoseconds)
    public static let hours = TimeUnit(code: .hours, scaleFromNanoseconds: 60 * TimeUnit.minutes.scaleFromNanoseconds)
    public static let days = TimeUnit(code: .days, scaleFromNanoseconds: 24 * TimeUnit.hours.scaleFromNanoseconds)
}

/// A timer collects observations within a time window (usually things like request durations) and provides aggregated information about the data sample,
/// for example, min, max and various quantiles. It is similar to a `Recorder` but specialized for values that represent durations.
///
/// This is the user-facing Timer API.
///
/// Its behavior depends on the `TimerHandler` implementation.
public final class Timer {
    /// ``_handler`` is only public to allow access from `MetricsTestKit`. Do not consider it part of the public API.
    public let _handler: TimerHandler
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new `Timer`, while providing an explicit `TimerHandler`.
    ///
    /// - warning: This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    ///            We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Recorder` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    ///     - handler: The custom backend.
    public init(label: String, dimensions: [(String, String)], handler: TimerHandler) {
        self.label = label
        self.dimensions = dimensions
        self._handler = handler
    }

    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
    @inlinable
    public func recordNanoseconds(_ duration: Int64) {
        self._handler.recordNanoseconds(duration)
    }

    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
    @inlinable
    public func recordNanoseconds<DataType: BinaryInteger>(_ duration: DataType) {
        self.recordNanoseconds(duration >= Int64.max ? Int64.max : Int64(duration))
    }

    /// Record a duration in microseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
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
    ///     - value: Duration to record.
    @inlinable
    public func recordMicroseconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(Double(duration * 1000) < Double(Int64.max) ? Int64(duration * 1000) : Int64.max)
    }

    /// Record a duration in milliseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
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
    ///     - value: Duration to record.
    @inlinable
    public func recordMilliseconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(Double(duration * 1_000_000) < Double(Int64.max) ? Int64(duration * 1_000_000) : Int64.max)
    }

    /// Record a duration in seconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
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
    ///     - value: Duration to record.
    @inlinable
    public func recordSeconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(Double(duration * 1_000_000_000) < Double(Int64.max) ? Int64(duration * 1_000_000_000) : Int64.max)
    }
}

extension Timer {
    /// Create a new `Timer`.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        let handler = MetricsSystem.factory.makeTimer(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler)
    }

    /// Create a new `Timer`.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    ///     - displayUnit: A hint to the backend responsible for presenting the data of the preferred display unit. This is not guaranteed to be supported by all backends.
    public convenience init(label: String, dimensions: [(String, String)] = [], preferredDisplayUnit displayUnit: TimeUnit) {
        let handler = MetricsSystem.factory.makeTimer(label: label, dimensions: dimensions)
        handler.preferDisplayUnit(displayUnit)
        self.init(label: label, dimensions: dimensions, handler: handler)
    }

    /// Signal the underlying metrics library that this timer will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `Timer`.
    @inlinable
    public func destroy() {
        MetricsSystem.factory.destroyTimer(self._handler)
    }
}

extension Timer: CustomStringConvertible {
    public var description: String {
        return "Timer(\(self.label), dimensions: \(self.dimensions))"
    }
}

// MARK: - MetricsSystem

/// The `MetricsSystem` is a global facility where the default metrics backend implementation (`MetricsFactory`) can be
/// configured. `MetricsSystem` is set up just once in a given program to set up the desired metrics backend
/// implementation.
public enum MetricsSystem {
    private static let _factory = FactoryBox(NOOPMetricsHandler.instance)

    /// `bootstrap` is an one-time configuration function which globally selects the desired metrics backend
    /// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behavior, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A factory that given an identifier produces instances of metrics handlers such as `CounterHandler`, `RecorderHandler` and `TimerHandler`.
    public static func bootstrap(_ factory: MetricsFactory) {
        self._factory.replaceFactory(factory, validate: true)
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(_ factory: MetricsFactory) {
        self._factory.replaceFactory(factory, validate: false)
    }

    /// Returns a reference to the configured factory.
    public static var factory: MetricsFactory {
        return self._factory.underlying
    }

    /// Acquire a writer lock for the duration of the given block.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    public static func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        return try self._factory.withWriterLock(body)
    }

    private final class FactoryBox {
        private let lock = ReadWriteLock()
        fileprivate var _underlying: MetricsFactory
        private var initialized = false

        init(_ underlying: MetricsFactory) {
            self._underlying = underlying
        }

        func replaceFactory(_ factory: MetricsFactory, validate: Bool) {
            self.lock.withWriterLock {
                precondition(!validate || !self.initialized, "metrics system can only be initialized once per process. currently used factory: \(self._underlying)")
                self._underlying = factory
                self.initialized = true
            }
        }

        var underlying: MetricsFactory {
            return self.lock.withReaderLock {
                return self._underlying
            }
        }

        func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
            return try self.lock.withWriterLock(body)
        }
    }
}

// MARK: - Library SPI, intended to be implemented by backend libraries

// MARK: - MetricsFactory

/// The `MetricsFactory` is the bridge between the `MetricsSystem` and the metrics backend implementation.
/// `MetricsFactory`'s role is to initialize concrete implementations of the various metric types:
/// * `Counter` -> `CounterHandler`
/// * `FloatingPointCounter` -> `FloatingPointCounterHandler`
/// * `Recorder` -> `RecorderHandler`
/// * `Timer` -> `TimerHandler`
///
/// - warning: This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
///            To use the SwiftMetrics API, please refer to the documentation of `MetricsSystem`.
///
/// # Destroying metrics
///
/// Since _some_ metrics implementations may need to allocate (potentially "heavy") resources for metrics, destroying
/// metrics offers a signal to libraries when a metric is "known to never be updated again."
///
/// While many metrics are bound to the entire lifetime of an application and thus never need to be destroyed eagerly,
/// some metrics have well defined unique life-cycles, and it may be beneficial to release any resources held by them
/// more eagerly than awaiting the application's termination. In such cases, a library or application should invoke
/// a metric's appropriate `destroy()` method, which in turn results in the corresponding handler that it is backed by
/// to be passed to `destroyCounter(handler:)`, `destroyRecorder(handler:)` or `destroyTimer(handler:)` where the factory
/// can decide to free any corresponding resources.
///
/// While some libraries may not need to implement this destroying as they may be stateless or similar,
/// libraries using the metrics API should always assume a library WILL make use of this signal, and shall not
/// neglect calling these methods when appropriate.
public protocol MetricsFactory: _SwiftMetricsSendableProtocol {
    /// Create a backing `CounterHandler`.
    ///
    /// - parameters:
    ///     - label: The label for the `CounterHandler`.
    ///     - dimensions: The dimensions for the `CounterHandler`.
    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler

    /// Create a backing `FloatingPointCounterHandler`.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounterHandler`.
    ///     - dimensions: The dimensions for the `FloatingPointCounterHandler`.
    func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler

    /// Create a backing `GaugeHandler`.
    ///
    /// - parameters:
    ///     - label: The label for the `GaugeHandler`.
    ///     - dimensions: The dimensions for the `GaugeHandler`.
    func makeGauge(label: String, dimensions: [(String, String)]) -> GaugeHandler

    /// Create a backing `RecorderHandler`.
    ///
    /// - parameters:
    ///     - label: The label for the `RecorderHandler`.
    ///     - dimensions: The dimensions for the `RecorderHandler`.
    ///     - aggregate: Is data aggregation expected.
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler

    /// Create a backing `TimerHandler`.
    ///
    /// - parameters:
    ///     - label: The label for the `TimerHandler`.
    ///     - dimensions: The dimensions for the `TimerHandler`.
    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler

    /// Invoked when the corresponding `Counter`'s `destroy()` function is invoked.
    /// Upon receiving this signal the factory may eagerly release any resources related to this counter.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyCounter(_ handler: CounterHandler)

    /// Invoked when the corresponding `Gauge`'s `destroy()` function is invoked.
    /// Upon receiving this signal the factory may eagerly release any resources related to this recorder.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyGauge(_ handler: GaugeHandler)

    /// Invoked when the corresponding `FloatingPointCounter`'s `destroy()` function is invoked.
    /// Upon receiving this signal the factory may eagerly release any resources related to this counter.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler)

    /// Invoked when the corresponding `Recorder`'s `destroy()` function is invoked.
    /// Upon receiving this signal the factory may eagerly release any resources related to this recorder.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    func destroyRecorder(_ handler: RecorderHandler)

    /// Invoked when the corresponding `Timer`'s `destroy()` function is invoked.
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
    internal var fraction: Double = 0

    init(label: String, dimensions: [(String, String)]) {
        self.counterHandler = MetricsSystem
            .factory.makeCounter(label: label, dimensions: dimensions)
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
        MetricsSystem.factory.destroyCounter(self.counterHandler)
    }
}

/// Wraps a RecorderHandler, adding support for incrementing values by storing an accumulated  value and recording increments to the underlying CounterHandler after crossing integer boundaries.
internal final class AccumulatingCounter: GaugeHandler {
    private let recorderHandler: RecorderHandler
    // FIXME: use atomics when available
    private var value: Double = 0
    private let lock = Lock()

    init(label: String, dimensions: [(String, String)]) {
        self.recorderHandler = MetricsSystem
            .factory.makeRecorder(label: label, dimensions: dimensions, aggregate: true)
    }

    func set(_ value: Int64) {
        self._set(Double(value))
    }

    func set(_ value: Double) {
        self._set(value)
    }

    func increment(by amount: Double) {
        let newValue: Double = self.lock.withLock {
            self.value += amount
            return self.value
        }
        self.recorderHandler.record(newValue)
    }

    func decrement(by amount: Double) {
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
        MetricsSystem.factory.destroyRecorder(self.recorderHandler)
    }
}

extension MetricsFactory {
    /// Create a default backing `FloatingPointCounterHandler` for backends which do not naively support floating point counters.
    ///
    /// The created FloatingPointCounterHandler is a wrapper around a backend's CounterHandler which accumulates floating point values and records increments to an underlying CounterHandler after crossing integer boundaries.
    ///
    /// - parameters:
    ///     - label: The label for the `FloatingPointCounterHandler`.
    ///     - dimensions: The dimensions for the `FloatingPointCounterHandler`.
    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        return AccumulatingRoundingFloatingPointCounter(label: label, dimensions: dimensions)
    }

    /// Invoked when the corresponding `FloatingPointCounter`'s `destroy()` function is invoked.
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
    /// Create a default backing `GaugeHandler` for backends which do not naively support gauges.
    ///
    /// The created GaugeHandler is a wrapper around a backend's RecorderHandler which records current values.
    ///
    /// - parameters:
    ///     - label: The label for the `GaugeHandler`.
    ///     - dimensions: The dimensions for the `GaugeHandler`.
    public func makeGauge(label: String, dimensions: [(String, String)]) -> GaugeHandler {
        return AccumulatingCounter(label: label, dimensions: dimensions)
    }

    /// Invoked when the corresponding `Gauge`'s `destroy()` function is invoked.
    /// Upon receiving this signal the factory may eagerly release any resources related to this counter.
    ///
    /// `destroyGauge` must be implemented if `makeGauge` is implemented.
    ///
    /// - parameters:
    ///     - handler: The handler to be destroyed.
    public func destroyGauge(_ handler: GaugeHandler) {
        (handler as? AccumulatingCounter)?.destroy()
    }
}

// MARK: - Backend Handlers

/// A `CounterHandler` represents a backend implementation of a `Counter`.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Counter`.
///
/// # Implementation requirements
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

/// A `FloatingPointCounterHandler` represents a backend implementation of a `FloatingPointCounter`.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `FloatingPointCounter`.
///
/// # Implementation requirements
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

/// A `RecorderHandler` represents a backend implementation of a `Recorder`.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Recorder`.
///
/// # Implementation requirements
///
/// To implement your own `RecorderHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `RecorderHandler` implementation.
///
/// - The `RecorderHandler` must be a `class`.
public protocol RecorderHandler: AnyObject, _SwiftMetricsSendableProtocol {
    /// Record a value.
    ///
    /// - parameters:
    ///     - value: Value to record.
    func record(_ value: Int64)
    /// Record a value.
    ///
    /// - parameters:
    ///     - value: Value to record.
    func record(_ value: Double)
}

/// A `GaugeHandler` represents a backend implementation of a `Gauge`.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Gauge`.
///
/// # Implementation requirements
///
/// To implement your own `GaugeHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `GaugeHandler` implementation.
///
/// - The `RecorderHandler` must be a `class`.
public protocol GaugeHandler: AnyObject, _SwiftMetricsSendableProtocol {
    /// Set a value.
    ///
    /// - parameters:
    ///     - value: Value to set.
    func set(_ value: Int64)
    /// Set a value.
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

/// A `TimerHandler` represents a backend implementation of a `Timer`.
///
/// This type is an implementation detail and should not be used directly, unless implementing your own metrics backend.
/// To use the SwiftMetrics API, please refer to the documentation of `Timer`.
///
/// # Implementation requirements
///
/// To implement your own `TimerHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `TimerHandler` implementation.
///
/// - The `TimerHandler` must be a `class`.
public protocol TimerHandler: AnyObject, _SwiftMetricsSendableProtocol {
    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
    func recordNanoseconds(_ duration: Int64)

    /// Set the preferred display unit for this TimerHandler.
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
        return MuxCounter(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        return MuxFloatingPointCounter(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        return MuxRecorder(factories: self.factories, label: label, dimensions: dimensions, aggregate: aggregate)
    }

    public func makeGauge(label: String, dimensions: [(String, String)]) -> GaugeHandler {
        return MuxGauge(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return MuxTimer(factories: self.factories, label: label, dimensions: dimensions)
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
            self.counters.forEach { $0.increment(by: amount) }
        }

        func reset() {
            self.counters.forEach { $0.reset() }
        }
    }

    private final class MuxFloatingPointCounter: FloatingPointCounterHandler {
        let counters: [FloatingPointCounterHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.counters = factories.map { $0.makeFloatingPointCounter(label: label, dimensions: dimensions) }
        }

        func increment(by amount: Double) {
            self.counters.forEach { $0.increment(by: amount) }
        }

        func reset() {
            self.counters.forEach { $0.reset() }
        }
    }

    private final class MuxRecorder: RecorderHandler {
        let recorders: [RecorderHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)], aggregate: Bool) {
            self.recorders = factories.map { $0.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate) }
        }

        func record(_ value: Int64) {
            self.recorders.forEach { $0.record(value) }
        }

        func record(_ value: Double) {
            self.recorders.forEach { $0.record(value) }
        }
    }

    private final class MuxGauge: GaugeHandler {
        let gauges: [GaugeHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.gauges = factories.map { $0.makeGauge(label: label, dimensions: dimensions) }
        }

        func set(_ value: Int64) {
            self.gauges.forEach { $0.set(value) }
        }

        func set(_ value: Double) {
            self.gauges.forEach { $0.set(value) }
        }

        func increment(by amount: Double) {
            self.gauges.forEach { $0.increment(by: amount) }
        }

        func decrement(by amount: Double) {
            self.gauges.forEach { $0.decrement(by: amount) }
        }
    }

    private final class MuxTimer: TimerHandler {
        let timers: [TimerHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.timers = factories.map { $0.makeTimer(label: label, dimensions: dimensions) }
        }

        func recordNanoseconds(_ duration: Int64) {
            self.timers.forEach { $0.recordNanoseconds(duration) }
        }

        func preferDisplayUnit(_ unit: TimeUnit) {
            self.timers.forEach { $0.preferDisplayUnit(unit) }
        }
    }
}

/// Ships with the metrics module, used for initial bootstrapping.
public final class NOOPMetricsHandler: MetricsFactory, CounterHandler, FloatingPointCounterHandler, RecorderHandler, GaugeHandler, TimerHandler {
    public static let instance = NOOPMetricsHandler()

    private init() {}

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return self
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        return self
    }

    public func makeGauge(label: String, dimensions: [(String, String)]) -> GaugeHandler {
        return self
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        return self
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return self
    }

    public func destroyCounter(_: CounterHandler) {}
    public func destroyFloatingPointCounter(_: FloatingPointCounterHandler) {}
    public func destroyGauge(_: GaugeHandler) {}
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

#if compiler(>=5.6)
extension MetricsSystem: Sendable {}
extension Counter: Sendable {}
extension FloatingPointCounter: Sendable {}
// must be @unchecked since Gauge inherits Recorder :(
extension Recorder: @unchecked Sendable {}
extension Timer: Sendable {}
extension Gauger: Sendable {}
// ideally we would not be using @unchecked here, but concurrency-safety checks do not recognize locks
extension AccumulatingRoundingFloatingPointCounter: @unchecked Sendable {}
#endif

#if compiler(>=5.6)
@preconcurrency public protocol _SwiftMetricsSendableProtocol: Sendable {}
#else
public protocol _SwiftMetricsSendableProtocol {}
#endif
