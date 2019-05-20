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
public protocol CounterHandler: AnyObject {
    /// Increment the counter.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
    func increment(by: Int64)

    /// Reset the counter back to zero.
    func reset()
}

/// A counter is a cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero.
/// For example, you can use a counter to represent the number of requests served, tasks completed, or errors.
///
/// This is the user facing Counter API.
///
/// Its behavior depends on the `CounterHandler` implementation.
public class Counter {
    @usableFromInline
    var handler: CounterHandler
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new `Counter`, while providing an explicit `CounterHandler`.
    ///
    /// This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    /// We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
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
        self.handler = handler
    }

    /// Increment the counter.
    ///
    /// - parameters:
    ///     - by: Amount to increment by.
    @inlinable
    public func increment<DataType: BinaryInteger>(by amount: DataType) {
        self.handler.increment(by: Int64(amount))
    }

    /// Increment the counter by one.
    @inlinable
    public func increment() {
        self.increment(by: 1)
    }

    /// Reset the counter back to zero.
    @inlinable
    public func reset() {
        self.handler.reset()
    }
}

public extension Counter {
    /// Create a new `Counter`.
    ///
    /// - parameters:
    ///     - label: The label for the `Counter`.
    ///     - dimensions: The dimensions for the `Counter`.
    convenience init(label: String, dimensions: [(String, String)] = []) {
        let handler = MetricsSystem.factory.makeCounter(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler)
    }

    /// Signal the underlying metrics library that this counter will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `Counter`.
    @inlinable
    func destroy() {
        MetricsSystem.factory.destroyCounter(self.handler)
    }
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
public protocol RecorderHandler: AnyObject {
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

/// A recorder collects observations within a time window (usually things like response sizes) and *can* provide aggregated information about the data sample, for example, count, sum, min, max and various quantiles.
///
/// This is the user facing Recorder API.
///
/// Its behavior depends on the `RecorderHandler` implementation.
public class Recorder {
    @usableFromInline
    var handler: RecorderHandler
    public let label: String
    public let dimensions: [(String, String)]
    public let aggregate: Bool

    /// Alternative way to create a new `Recorder`, while providing an explicit `RecorderHandler`.
    ///
    /// This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    /// We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
    ///
    /// - SeeAlso: Use `init(label:dimensions:)` to create `Recorder` instances using the configured metrics backend.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    ///     - handler: The custom backend.
    public init(label: String, dimensions: [(String, String)], aggregate: Bool, handler: RecorderHandler) {
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
        self.handler = handler
    }

    /// Record a value.
    ///
    /// - parameters:
    ///     - value: Value to record.
    @inlinable
    public func record<DataType: BinaryInteger>(_ value: DataType) {
        self.handler.record(Int64(value))
    }

    /// Record a value.
    ///
    /// - parameters:
    ///     - value: Value to record.
    @inlinable
    public func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
        self.handler.record(Double(value))
    }
}

public extension Recorder {
    /// Create a new `Recorder`.
    ///
    /// - parameters:
    ///     - label: The label for the `Recorder`.
    ///     - dimensions: The dimensions for the `Recorder`.
    convenience init(label: String, dimensions: [(String, String)] = [], aggregate: Bool = true) {
        let handler = MetricsSystem.factory.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        self.init(label: label, dimensions: dimensions, aggregate: aggregate, handler: handler)
    }

    /// Signal the underlying metrics library that this recorder will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `Recorder`.
    @inlinable
    func destroy() {
        MetricsSystem.factory.destroyRecorder(self.handler)
    }
}

/// A gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
/// Gauges are typically used for measured values like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads.
/// Gauges are modeled as `Recorder` with a sample size of 1 and that does not perform any aggregation.
public class Gauge: Recorder {
    /// Create a new `Gauge`.
    ///
    /// - parameters:
    ///     - label: The label for the `Gauge`.
    ///     - dimensions: The dimensions for the `Gauge`.
    public convenience init(label: String, dimensions: [(String, String)] = []) {
        self.init(label: label, dimensions: dimensions, aggregate: false)
    }
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
public protocol TimerHandler: AnyObject {
    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
    func recordNanoseconds(_ duration: Int64)
}

/// A timer collects observations within a time window (usually things like request durations) and provides aggregated information about the data sample,
/// for example, min, max and various quantiles. It is similar to a `Recorder` but specialized for values that represent durations.
///
/// This is the user facing Timer API.
///
/// Its behavior depends on the `TimerHandler` implementation.
public class Timer {
    @usableFromInline
    var handler: TimerHandler
    public let label: String
    public let dimensions: [(String, String)]

    /// Alternative way to create a new `Timer`, while providing an explicit `TimerHandler`.
    ///
    /// This initializer provides an escape hatch for situations where one must use a custom factory instead of the global one.
    /// We do not expect this API to be used in normal circumstances, so if you find yourself using it make sure it's for a good reason.
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
        self.handler = handler
    }

    /// Record a duration in nanoseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
    @inlinable
    public func recordNanoseconds(_ duration: Int64) {
        self.handler.recordNanoseconds(duration)
    }

    /// Record a duration in microseconds.
    ///
    /// - parameters:
    ///     - value: Duration to record.
    @inlinable
    public func recordMicroseconds<DataType: BinaryInteger>(_ duration: DataType) {
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

public extension Timer {
    /// Create a new `Timer`.
    ///
    /// - parameters:
    ///     - label: The label for the `Timer`.
    ///     - dimensions: The dimensions for the `Timer`.
    convenience init(label: String, dimensions: [(String, String)] = []) {
        let handler = MetricsSystem.factory.makeTimer(label: label, dimensions: dimensions)
        self.init(label: label, dimensions: dimensions, handler: handler)
    }

    /// Signal the underlying metrics library that this timer will never be updated again.
    /// In response the library MAY decide to eagerly release any resources held by this `Timer`.
    @inlinable
    func destroy() {
        MetricsSystem.factory.destroyTimer(self.handler)
    }
}

/// The `MetricsFactory` is the bridge between the `MetricsSystem` and the metrics backend implementation.
/// `MetricsFactory`'s role is to initialize concrete implementations of the various metric types:
/// * `Counter` -> `CounterHandler`
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
public protocol MetricsFactory {
    /// Create a backing `CounterHandler`.
    ///
    /// - parameters:
    ///     - label: The label for the `CounterHandler`.
    ///     - dimensions: The dimensions for the `CounterHandler`.
    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler

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

/// The `MetricsSystem` is a global facility where the default metrics backend implementation (`MetricsFactory`) can be
/// configured. `MetricsSystem` is set up just once in a given program to set up the desired metrics backend
/// implementation.
public enum MetricsSystem {
    fileprivate static let lock = ReadWriteLock()
    fileprivate static var _factory: MetricsFactory = NOOPMetricsHandler.instance
    fileprivate static var initialized = false

    /// `bootstrap` is an one-time configuration function which globally selects the desired metrics backend
    /// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behaviour, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A factory that given an identifier produces instances of metrics handlers such as `CounterHandler`, `RecorderHandler` and `TimerHandler`.
    public static func bootstrap(_ factory: MetricsFactory) {
        self.lock.withWriterLock {
            precondition(!self.initialized, "metrics system can only be initialized once per process. currently used factory: \(self.factory)")
            self._factory = factory
            self.initialized = true
        }
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(_ factory: MetricsFactory) {
        self.lock.withWriterLock {
            self._factory = factory
        }
    }

    /// Returns a reference to the configured factory.
    public static var factory: MetricsFactory {
        return self.lock.withReaderLock { self._factory }
    }
}

/// A pseudo-metrics handler that can be used to send messages to multiple other metrics handlers.
public final class MultiplexMetricsHandler: MetricsFactory {
    private let factories: [MetricsFactory]
    public init(factories: [MetricsFactory]) {
        self.factories = factories
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return MuxCounter(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        return MuxRecorder(factories: self.factories, label: label, dimensions: dimensions, aggregate: aggregate)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return MuxTimer(factories: self.factories, label: label, dimensions: dimensions)
    }

    public func destroyCounter(_ handler: CounterHandler) {
        for factory in self.factories {
            factory.destroyCounter(handler)
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

    private class MuxCounter: CounterHandler {
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

    private class MuxRecorder: RecorderHandler {
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

    private class MuxTimer: TimerHandler {
        let timers: [TimerHandler]
        public init(factories: [MetricsFactory], label: String, dimensions: [(String, String)]) {
            self.timers = factories.map { $0.makeTimer(label: label, dimensions: dimensions) }
        }

        func recordNanoseconds(_ duration: Int64) {
            self.timers.forEach { $0.recordNanoseconds(duration) }
        }
    }
}

/// Ships with the metrics module, used for initial bootstrapping.
public final class NOOPMetricsHandler: MetricsFactory, CounterHandler, RecorderHandler, TimerHandler {
    public static let instance = NOOPMetricsHandler()

    private init() {}

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return self
    }
    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        return self
    }
    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return self
    }

    public func destroyCounter(_: CounterHandler) {}
    public func destroyRecorder(_: RecorderHandler) {}
    public func destroyTimer(_: TimerHandler) {}

    public func increment(by: Int64) {}
    public func reset() {}
    public func record(_: Int64) {}
    public func record(_: Double) {}
    public func recordNanoseconds(_: Int64) {}
}
