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

import CoreMetrics
import Logging

/// A `MetricsFactory` that emits one log line per metric mutation to the supplied `Logger`.
///
/// This factory is stateless — it does not retain any reported values. Use it in examples, demos, or
/// local debugging to observe what metrics a piece of code reports without standing up a real backend.
/// For test assertions on recorded values, use ``TestMetrics`` instead.
///
/// ```swift
/// var logger = Logger(label: "metrics")
/// logger.logLevel = .debug
/// let metrics = LoggingMetricsFactory(logger: logger)
///
/// Counter(label: "requests", dimensions: [("method", "GET")], factory: metrics).increment(by: 5)
/// // debug: increment counter [metric.amount=5, metric.dimensions=[[method, GET]], metric.name=requests]
/// ```
///
/// Combine with `MultiplexMetricsHandler` to layer this factory on top of a remote backend during
/// debugging without losing the production reporting path.
///
/// > Note: Every recorded value is logged as-is, including values that a real backend would silently
/// > drop (for example, `meter.increment(by: .nan)`).
public struct LoggingMetricsFactory: MetricsFactory, Sendable {
    private let logger: Logger
    private let level: Logger.Level

    /// Create a new logging metrics factory.
    ///
    /// - Parameters:
    ///   - logger: The `Logger` that receives one message per metric mutation.
    ///   - level: The log level at which mutations are emitted. Defaults to `.debug`.
    public init(logger: Logger, level: Logger.Level = .debug) {
        self.logger = logger
        self.level = level
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        LoggingCounterHandler(emitter: self.makeEmitter(label: label, dimensions: dimensions))
    }

    public func makeFloatingPointCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> FloatingPointCounterHandler {
        LoggingFloatingPointCounterHandler(
            emitter: self.makeEmitter(label: label, dimensions: dimensions)
        )
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        LoggingMeterHandler(emitter: self.makeEmitter(label: label, dimensions: dimensions))
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        LoggingRecorderHandler(
            emitter: self.makeEmitter(label: label, dimensions: dimensions, aggregate: aggregate)
        )
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        LoggingTimerHandler(emitter: self.makeEmitter(label: label, dimensions: dimensions))
    }

    public func destroyCounter(_ handler: CounterHandler) {}
    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {}
    public func destroyMeter(_ handler: MeterHandler) {}
    public func destroyRecorder(_ handler: RecorderHandler) {}
    public func destroyTimer(_ handler: TimerHandler) {}

    /// Builds the `LogEmitter` shared by every handler produced by this factory.
    private func makeEmitter(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool? = nil
    ) -> LogEmitter {
        var baseMetadata: Logger.Metadata = ["metric.name": .string(label)]
        if !dimensions.isEmpty {
            baseMetadata["metric.dimensions"] = .array(
                dimensions.map { .array([.string($0.0), .string($0.1)]) }
            )
        }
        if let aggregate {
            baseMetadata["metric.aggregate"] = .stringConvertible(aggregate)
        }
        return LogEmitter(baseMetadata: baseMetadata, logger: self.logger, level: self.level)
    }
}

// MARK: - LogEmitter

/// Shared log helpers used by every handler.
private struct LogEmitter: Sendable {
    let baseMetadata: Logger.Metadata
    let logger: Logger
    let level: Logger.Level

    /// Emit a log line carrying just the base metadata.
    func log(_ message: Logger.Message) {
        self.logger.log(level: self.level, message, metadata: self.baseMetadata)
    }

    /// Emit a log line with the base metadata plus one per-mutation key/value.
    func log(_ message: Logger.Message, key: String, value: Logger.MetadataValue) {
        var metadata = self.baseMetadata
        metadata[key] = value
        self.logger.log(level: self.level, message, metadata: metadata)
    }
}

// MARK: - Handlers

private final class LoggingCounterHandler: CounterHandler, Sendable {
    let emitter: LogEmitter
    init(emitter: LogEmitter) { self.emitter = emitter }

    func increment(by amount: Int64) {
        self.emitter.log("increment counter", key: "metric.amount", value: .stringConvertible(amount))
    }

    func reset() {
        self.emitter.log("reset counter")
    }
}

private final class LoggingFloatingPointCounterHandler: FloatingPointCounterHandler, Sendable {
    let emitter: LogEmitter
    init(emitter: LogEmitter) { self.emitter = emitter }

    func increment(by amount: Double) {
        self.emitter.log(
            "increment floating-point counter",
            key: "metric.amount",
            value: .stringConvertible(amount)
        )
    }

    func reset() {
        self.emitter.log("reset floating-point counter")
    }
}

private final class LoggingMeterHandler: MeterHandler, Sendable {
    let emitter: LogEmitter
    init(emitter: LogEmitter) { self.emitter = emitter }

    func set(_ value: Int64) {
        self.emitter.log("set meter", key: "metric.value", value: .stringConvertible(value))
    }

    func set(_ value: Double) {
        self.emitter.log("set meter", key: "metric.value", value: .stringConvertible(value))
    }

    func increment(by amount: Double) {
        self.emitter.log("increment meter", key: "metric.delta", value: .stringConvertible(amount))
    }

    func decrement(by amount: Double) {
        self.emitter.log("decrement meter", key: "metric.delta", value: .stringConvertible(amount))
    }
}

private final class LoggingRecorderHandler: RecorderHandler, Sendable {
    let emitter: LogEmitter
    init(emitter: LogEmitter) { self.emitter = emitter }

    func record(_ value: Int64) {
        self.emitter.log("record value", key: "metric.value", value: .stringConvertible(value))
    }

    func record(_ value: Double) {
        self.emitter.log("record value", key: "metric.value", value: .stringConvertible(value))
    }
}

private final class LoggingTimerHandler: TimerHandler, Sendable {
    let emitter: LogEmitter
    init(emitter: LogEmitter) { self.emitter = emitter }

    func recordNanoseconds(_ duration: Int64) {
        self.emitter.log("record duration", key: "metric.nanoseconds", value: .stringConvertible(duration))
    }
}
