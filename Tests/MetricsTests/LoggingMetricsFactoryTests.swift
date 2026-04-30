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
import Foundation
import Logging
import Metrics
import MetricsTestKit
import Testing

// MARK: - Test infrastructure

/// A minimal `LogHandler` that captures every emitted log line in memory, sufficient for asserting
/// the metadata payloads emitted by `LoggingMetricsFactory`.
private struct CapturingLogHandler: LogHandler {
    struct Entry: Sendable {
        var level: Logger.Level
        var message: Logger.Message
        var metadata: Logger.Metadata
    }

    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace
    private let storage = Storage()

    var entries: [Entry] {
        self.storage.entries
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.storage.append(Entry(level: level, message: message, metadata: metadata ?? [:]))
    }

    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var _entries: [Entry] = []

        func append(_ entry: Entry) {
            self.lock.lock()
            defer { self.lock.unlock() }
            self._entries.append(entry)
        }

        var entries: [Entry] {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self._entries
        }
    }
}

/// Build a `Logger` backed by a `CapturingLogHandler` configured at `level`.
private func makeLoggerAndHandler(level: Logger.Level = .trace) -> (Logger, CapturingLogHandler) {
    var handler = CapturingLogHandler()
    handler.logLevel = level
    let logger = Logger(label: "test") { _ in handler }
    return (logger, handler)
}

// MARK: - Metadata extraction helpers

/// Read the rendered string for a metadata key (works for both `.string` and `.stringConvertible`).
private func metadataString(_ entry: CapturingLogHandler.Entry, _ key: String) -> String? {
    entry.metadata[key]?.description
}

/// Parse a metadata value as a `Double` so assertions are robust to numeric formatting.
private func metadataDouble(_ entry: CapturingLogHandler.Entry, _ key: String) -> Double? {
    metadataString(entry, key).flatMap(Double.init)
}

/// Approximate-equality check for floating-point assertions — shields against any future changes
/// to `Double.description`'s rendering while still exercising the real numeric path.
private func metadataDouble(
    _ entry: CapturingLogHandler.Entry,
    _ key: String,
    approximately expected: Double,
    tolerance: Double = 1e-9
) -> Bool {
    guard let actual = metadataDouble(entry, key) else { return false }
    if expected.isNaN { return actual.isNaN }
    return abs(actual - expected) <= tolerance
}

/// Parse a metadata value as a `Bool`.
private func metadataBool(_ entry: CapturingLogHandler.Entry, _ key: String) -> Bool? {
    switch metadataString(entry, key) {
    case "true": return true
    case "false": return false
    default: return nil
    }
}

/// Decode the `metric.dimensions` array of two-element `[key, value]` arrays back into
/// `(String, String)` pairs.
private func metadataDimensions(_ entry: CapturingLogHandler.Entry) -> [(String, String)]? {
    guard case .array(let pairs)? = entry.metadata["metric.dimensions"] else { return nil }
    var result: [(String, String)] = []
    for pair in pairs {
        guard case .array(let kv) = pair, kv.count == 2,
            case .string(let key) = kv[0],
            case .string(let value) = kv[1]
        else {
            return nil
        }
        result.append((key, value))
    }
    return result
}

/// Compare a captured dimension list against the expected `(key, value)` pairs.
private func dimensionsEqual(
    _ actual: [(String, String)]?,
    _ expected: [(String, String)]
) -> Bool {
    guard let actual, actual.count == expected.count else { return false }
    return zip(actual, expected).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
}

// MARK: - Tests

struct LoggingMetricsFactoryTests {
    @Test func counterIncrementLogsOneMessage() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        Counter(label: "requests", dimensions: [("method", "GET")], factory: metrics).increment(by: 5)

        let entries = handler.entries
        #expect(entries.count == 1)
        #expect(entries[0].message == "increment counter")
        #expect(metadataString(entries[0], "metric.name") == "requests")
        #expect(dimensionsEqual(metadataDimensions(entries[0]), [("method", "GET")]))
        #expect(metadataString(entries[0], "metric.amount") == "5")
    }

    @Test func counterResetLogsMessage() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        Counter(label: "errors", factory: metrics).reset()

        let entries = handler.entries
        #expect(entries.count == 1)
        #expect(entries[0].message == "reset counter")
        #expect(metadataString(entries[0], "metric.name") == "errors")
        #expect(entries[0].metadata["metric.dimensions"] == nil)
    }

    @Test func counterPreservesAllDimensionsIncludingDuplicateKeys() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        // Deliberate duplicate `method` key — rendering dimensions as an array of `[key, value]`
        // pairs (rather than a dictionary) preserves them as-passed.
        Counter(
            label: "requests",
            dimensions: [("method", "GET"), ("path", "/api"), ("method", "HEAD")],
            factory: metrics
        ).increment()

        let entries = handler.entries
        #expect(entries.count == 1)
        #expect(
            dimensionsEqual(
                metadataDimensions(entries[0]),
                [("method", "GET"), ("path", "/api"), ("method", "HEAD")]
            )
        )
    }

    @Test func floatingPointCounterFractionalIncrementAndResetAreLogged() throws {
        // Regression guard: the default `AccumulatingRoundingFloatingPointCounter` wrapper would
        // accumulate fractional increments and only emit a log line after crossing an integer
        // boundary, which would violate the "log every call as-is" contract. The dedicated
        // handler must log every call.
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        let counter = FloatingPointCounter(label: "requests", factory: metrics)
        counter.increment(by: 0.3)
        counter.reset()

        let entries = handler.entries
        #expect(entries.count == 2)
        #expect(entries[0].message == "increment floating-point counter")
        #expect(metadataDouble(entries[0], "metric.amount", approximately: 0.3))
        #expect(entries[1].message == "reset floating-point counter")
        #expect(metadataString(entries[1], "metric.name") == "requests")
    }

    @Test func meterSetExercisesBothOverloads() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        let meter = Meter(label: "queue_depth", factory: metrics)
        meter.set(Int64(7))
        meter.set(0.8)

        let entries = handler.entries
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.message == "set meter" })
        #expect(metadataString(entries[0], "metric.value") == "7")
        #expect(metadataDouble(entries[1], "metric.value", approximately: 0.8))
    }

    @Test func meterIncrementAndDecrementEmitDelta() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        let meter = Meter(label: "queue_depth", factory: metrics)
        meter.increment(by: 3)
        meter.decrement(by: 1)

        let entries = handler.entries
        #expect(entries.count == 2)
        #expect(entries[0].message == "increment meter")
        #expect(metadataDouble(entries[0], "metric.delta", approximately: 3))
        #expect(entries[1].message == "decrement meter")
        #expect(metadataDouble(entries[1], "metric.delta", approximately: 1))
    }

    @Test func meterLogsNaNAsIs() throws {
        // Every call is logged as-is — pin the documented "transparent observer" contract for
        // values a real backend would silently drop.
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        Meter(label: "queue_depth", factory: metrics).increment(by: Double.nan)

        let entries = handler.entries
        #expect(entries.count == 1)
        #expect(entries[0].message == "increment meter")
        #expect(metadataDouble(entries[0], "metric.delta", approximately: .nan))
    }

    @Test func recorderRecordExercisesBothOverloads() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        let recorder = Recorder(label: "latency_ms", factory: metrics)
        recorder.record(Int64(42))
        recorder.record(12.5)

        let entries = handler.entries
        #expect(entries.count == 2)
        #expect(metadataString(entries[0], "metric.value") == "42")
        #expect(metadataDouble(entries[1], "metric.value", approximately: 12.5))
    }

    @Test func recorderAggregateFlagIsLogged() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        Recorder(label: "latency_ms", aggregate: true, factory: metrics).record(10)
        Recorder(label: "memory_mb", aggregate: false, factory: metrics).record(256)

        let entries = handler.entries
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.message == "record value" })
        #expect(metadataBool(entries[0], "metric.aggregate") == true)
        #expect(metadataBool(entries[1], "metric.aggregate") == false)
        // Neither recorder was given any dimensions — `metric.aggregate` must still land.
        #expect(entries[0].metadata["metric.dimensions"] == nil)
        #expect(entries[1].metadata["metric.dimensions"] == nil)
    }

    @Test func timerRecordsInNanoseconds() throws {
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        CoreMetrics.Timer(label: "request_duration", factory: metrics).recordNanoseconds(1_500_000)

        let entries = handler.entries
        #expect(entries.count == 1)
        #expect(entries[0].message == "record duration")
        #expect(metadataString(entries[0], "metric.nanoseconds") == "1500000")
    }

    @Test func timerIgnoresPreferDisplayUnit() throws {
        // `preferDisplayUnit` is a backend hint, not a recorded value. The factory deliberately
        // does not override it, leaving the protocol's no-op default in effect — pinning the
        // contract here so nobody silently re-adds an emission.
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        _ = CoreMetrics.Timer(
            label: "request_duration",
            preferredDisplayUnit: .milliseconds,
            factory: metrics
        )

        #expect(handler.entries.isEmpty)
    }

    @Test func baseMetadataIsNotMutatedAcrossCalls() throws {
        // Each mutation must copy `baseMetadata` before inserting its per-mutation key. If the
        // base were mutated in place, the first entry would retroactively gain the second call's
        // key. Guards the copy-on-write contract.
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        let meter = Meter(label: "queue_depth", factory: metrics)
        meter.increment(by: 3)
        meter.set(0.8)

        let entries = handler.entries
        #expect(entries.count == 2)
        // Entry 0 was an increment — must have `metric.delta`, must NOT have `metric.value`.
        #expect(entries[0].metadata["metric.delta"] != nil)
        #expect(entries[0].metadata["metric.value"] == nil)
        // Entry 1 was a set — must have `metric.value`, must NOT have `metric.delta`.
        #expect(entries[1].metadata["metric.value"] != nil)
        #expect(entries[1].metadata["metric.delta"] == nil)
    }

    @Test func levelGatingMatrix() throws {
        // Default `.debug` emits at `.debug`.
        do {
            let (logger, handler) = makeLoggerAndHandler()
            Counter(label: "requests", factory: LoggingMetricsFactory(logger: logger))
                .increment()
            #expect(handler.entries.count == 1)
            #expect(handler.entries[0].level == .debug)
        }

        // Explicit `.info` emits at `.info`.
        do {
            let (logger, handler) = makeLoggerAndHandler()
            Counter(label: "requests", factory: LoggingMetricsFactory(logger: logger, level: .info))
                .increment()
            #expect(handler.entries.count == 1)
            #expect(handler.entries[0].level == .info)
        }

        // A logger filtered above the factory's level suppresses the output.
        do {
            let (logger, handler) = makeLoggerAndHandler(level: .warning)
            Counter(label: "requests", factory: LoggingMetricsFactory(logger: logger))
                .increment()
            #expect(handler.entries.isEmpty)
        }
    }

    @Test func destroyMethodsAreNoOps() throws {
        // The factory is stateless, so each `destroy*` method should do nothing — no log line,
        // no crash, no follow-on effect on subsequent mutations through sibling handlers.
        let (logger, handler) = makeLoggerAndHandler()
        let metrics = LoggingMetricsFactory(logger: logger)

        let counter = metrics.makeCounter(label: "c", dimensions: [])
        let fpCounter = metrics.makeFloatingPointCounter(label: "fp", dimensions: [])
        let meter = metrics.makeMeter(label: "m", dimensions: [])
        let recorder = metrics.makeRecorder(label: "r", dimensions: [], aggregate: true)
        let timer = metrics.makeTimer(label: "t", dimensions: [])

        metrics.destroyCounter(counter)
        metrics.destroyFloatingPointCounter(fpCounter)
        metrics.destroyMeter(meter)
        metrics.destroyRecorder(recorder)
        metrics.destroyTimer(timer)

        // Nothing should have been emitted by the destroy calls themselves.
        #expect(handler.entries.isEmpty)

        // And the destroyed handlers should still emit on subsequent mutations — `destroy*` is
        // advisory for a stateless factory; the caller might still hold a reference.
        counter.increment(by: 1)
        meter.set(Int64(1))
        recorder.record(Int64(1))
        timer.recordNanoseconds(1)
        #expect(handler.entries.count == 4)
    }
}
