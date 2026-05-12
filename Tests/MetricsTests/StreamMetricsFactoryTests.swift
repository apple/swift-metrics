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
import Metrics
import MetricsTestKit
import Testing

// MARK: - Test infrastructure

/// Captures every string written to it so the emitted lines can be inspected.
private final class CapturingStream: TextOutputStream, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: String = ""

    func write(_ string: String) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.buffer.append(string)
    }

    /// Every completed line that has been written, in order.
    var lines: [String] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.buffer.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
}

private func makeFactoryAndStream() -> (StreamMetricsFactory, CapturingStream) {
    let stream = CapturingStream()
    return (StreamMetricsFactory(stream: stream), stream)
}

// MARK: - Tests

struct StreamMetricsFactoryTests {
    @Test func counterIncrementWritesOneLine() throws {
        let (metrics, stream) = makeFactoryAndStream()

        Counter(label: "requests", dimensions: [("method", "GET")], factory: metrics).increment(by: 5)

        let lines = stream.lines
        #expect(lines.count == 1)
        #expect(
            lines[0]
                == "increment counter metric.name=requests metric.dimensions=[method=GET] metric.amount=5"
        )
    }

    @Test func counterResetWritesLineWithoutDimensions() throws {
        let (metrics, stream) = makeFactoryAndStream()

        Counter(label: "errors", factory: metrics).reset()

        let lines = stream.lines
        #expect(lines.count == 1)
        #expect(lines[0] == "reset counter metric.name=errors")
        // No dimensions were passed — the key must be omitted entirely, not rendered empty.
        #expect(!lines[0].contains("metric.dimensions"))
    }

    @Test func counterPreservesAllDimensionsIncludingDuplicateKeys() throws {
        let (metrics, stream) = makeFactoryAndStream()

        // Deliberate duplicate `method` key — rendering dimensions as an ordered list (rather than
        // a dictionary) preserves them as-passed.
        Counter(
            label: "requests",
            dimensions: [("method", "GET"), ("path", "/api"), ("method", "HEAD")],
            factory: metrics
        ).increment()

        let lines = stream.lines
        #expect(lines.count == 1)
        #expect(lines[0].contains("metric.dimensions=[method=GET,path=/api,method=HEAD]"))
    }

    @Test func floatingPointCounterFractionalIncrementAndResetAreWritten() throws {
        // Regression guard: the default `AccumulatingRoundingFloatingPointCounter` wrapper would
        // accumulate fractional increments and only emit a line after crossing an integer
        // boundary, which would violate the "write every call as-is" contract. The dedicated
        // handler must write every call.
        let (metrics, stream) = makeFactoryAndStream()

        let counter = FloatingPointCounter(label: "requests", factory: metrics)
        counter.increment(by: 0.3)
        counter.reset()

        let lines = stream.lines
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("increment floating-point counter"))
        #expect(lines[0].contains("metric.amount=0.3"))
        #expect(lines[1].hasPrefix("reset floating-point counter"))
        #expect(lines[1].contains("metric.name=requests"))
    }

    @Test func meterSetExercisesBothOverloads() throws {
        let (metrics, stream) = makeFactoryAndStream()

        let meter = Meter(label: "queue_depth", factory: metrics)
        meter.set(Int64(7))
        meter.set(0.8)

        let lines = stream.lines
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.hasPrefix("set meter") })
        #expect(lines[0].contains("metric.value=7"))
        #expect(lines[1].contains("metric.value=0.8"))
    }

    @Test func meterIncrementAndDecrementEmitDelta() throws {
        let (metrics, stream) = makeFactoryAndStream()

        let meter = Meter(label: "queue_depth", factory: metrics)
        meter.increment(by: 3)
        meter.decrement(by: 1)

        let lines = stream.lines
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("increment meter"))
        #expect(lines[0].contains("metric.delta=3.0"))
        #expect(lines[1].hasPrefix("decrement meter"))
        #expect(lines[1].contains("metric.delta=1.0"))
    }

    @Test func meterWritesNaNAsIs() throws {
        // Every call is written as-is — pin the documented "transparent observer" contract for
        // values a real backend would silently drop.
        let (metrics, stream) = makeFactoryAndStream()

        Meter(label: "queue_depth", factory: metrics).increment(by: Double.nan)

        let lines = stream.lines
        #expect(lines.count == 1)
        #expect(lines[0].hasPrefix("increment meter"))
        #expect(lines[0].contains("metric.delta=nan"))
    }

    @Test func recorderRecordExercisesBothOverloads() throws {
        let (metrics, stream) = makeFactoryAndStream()

        let recorder = Recorder(label: "latency_ms", factory: metrics)
        recorder.record(Int64(42))
        recorder.record(12.5)

        let lines = stream.lines
        #expect(lines.count == 2)
        #expect(lines[0].contains("metric.value=42"))
        #expect(lines[1].contains("metric.value=12.5"))
    }

    @Test func recorderAggregateFlagIsWritten() throws {
        let (metrics, stream) = makeFactoryAndStream()

        Recorder(label: "latency_ms", aggregate: true, factory: metrics).record(10)
        Recorder(label: "memory_mb", aggregate: false, factory: metrics).record(256)

        let lines = stream.lines
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.hasPrefix("record value") })
        #expect(lines[0].contains("metric.aggregate=true"))
        #expect(lines[1].contains("metric.aggregate=false"))
        // Neither recorder was given any dimensions — `metric.aggregate` must still land.
        #expect(!lines[0].contains("metric.dimensions"))
        #expect(!lines[1].contains("metric.dimensions"))
    }

    @Test func timerRecordsInNanoseconds() throws {
        let (metrics, stream) = makeFactoryAndStream()

        CoreMetrics.Timer(label: "request_duration", factory: metrics).recordNanoseconds(1_500_000)

        let lines = stream.lines
        #expect(lines.count == 1)
        #expect(lines[0].hasPrefix("record duration"))
        #expect(lines[0].contains("metric.nanoseconds=1500000"))
    }

    @Test func timerIgnoresPreferDisplayUnit() throws {
        // `preferDisplayUnit` is a backend hint, not a recorded value. The factory deliberately
        // does not override it, leaving the protocol's no-op default in effect — pinning the
        // contract here so nobody silently re-adds an emission.
        let (metrics, stream) = makeFactoryAndStream()

        _ = CoreMetrics.Timer(
            label: "request_duration",
            preferredDisplayUnit: .milliseconds,
            factory: metrics
        )

        #expect(stream.lines.isEmpty)
    }

    @Test func perMutationKeysDoNotLeakAcrossLines() throws {
        // Each mutation must produce its own line. If the per-mutation key/value were reused
        // from a previous call, the first line would retroactively gain the second call's key.
        let (metrics, stream) = makeFactoryAndStream()

        let meter = Meter(label: "queue_depth", factory: metrics)
        meter.increment(by: 3)
        meter.set(0.8)

        let lines = stream.lines
        #expect(lines.count == 2)
        // Line 0 was an increment — must have `metric.delta`, must NOT have `metric.value`.
        #expect(lines[0].contains("metric.delta=3.0"))
        #expect(!lines[0].contains("metric.value="))
        // Line 1 was a set — must have `metric.value`, must NOT have `metric.delta`.
        #expect(lines[1].contains("metric.value=0.8"))
        #expect(!lines[1].contains("metric.delta="))
    }

    @Test func eachMutationTerminatesWithNewline() throws {
        // Pin that the factory appends a newline per mutation — otherwise lines would run
        // together when piped to a real stream.
        let stream = CapturingStream()
        let metrics = StreamMetricsFactory(stream: stream)

        Counter(label: "a", factory: metrics).increment()
        Counter(label: "b", factory: metrics).increment()

        // Two writes should produce exactly two lines when split on "\n".
        let split = stream.lines
        #expect(split.count == 2)
        #expect(split[0].hasPrefix("increment counter") && split[0].contains("metric.name=a"))
        #expect(split[1].hasPrefix("increment counter") && split[1].contains("metric.name=b"))
    }

    @Test func destroyMethodsAreNoOps() throws {
        // The factory is stateless, so each `destroy*` method should do nothing — no line,
        // no crash, no follow-on effect on subsequent mutations through sibling handlers.
        let (metrics, stream) = makeFactoryAndStream()

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

        // Nothing should have been written by the destroy calls themselves.
        #expect(stream.lines.isEmpty)

        // And the destroyed handlers should still emit on subsequent mutations — `destroy*` is
        // advisory for a stateless factory; the caller might still hold a reference.
        counter.increment(by: 1)
        meter.set(Int64(1))
        recorder.record(Int64(1))
        timer.recordNanoseconds(1)
        #expect(stream.lines.count == 4)

        // Silence unused-result warnings without affecting behavior.
        _ = fpCounter
    }
}
