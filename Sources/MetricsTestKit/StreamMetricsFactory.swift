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

/// A `MetricsFactory` that writes one line per metric mutation to a `TextOutputStream`.
///
/// This factory is stateless — it does not retain any reported values. Use it in examples, demos, or
/// local debugging to observe what metrics a piece of code reports without standing up a real backend.
/// For test assertions on recorded values, use ``TestMetrics`` instead.
///
/// ```swift
/// let metrics = StreamMetricsFactory.standardOutput()
///
/// Counter(label: "requests", dimensions: [("method", "GET")], factory: metrics).increment(by: 5)
/// // increment counter metric.name=requests metric.dimensions=[method=GET] metric.amount=5
/// ```
///
/// Combine with `MultiplexMetricsHandler` to layer this factory on top of a remote backend during
/// debugging without losing the production reporting path.
///
/// > Note: Every recorded value is written as-is, including values that a real backend would silently
/// > drop (for example, `meter.increment(by: .nan)`).
public struct StreamMetricsFactory: MetricsFactory, Sendable {
    private let sink: Sink

    /// Create a factory that writes each metric mutation as a line to the supplied stream.
    ///
    /// Writes are serialized internally, so the supplied stream does not need to be thread-safe on
    /// its own.
    ///
    /// - Parameter stream: The stream that receives one line per metric mutation. The trailing
    ///   newline is included in the written string.
    public init(stream: any TextOutputStream & Sendable) {
        self.sink = Sink(stream: stream)
    }

    /// Create a factory that writes each metric mutation as a line to standard output.
    public static func standardOutput() -> StreamMetricsFactory {
        StreamMetricsFactory(stream: StandardOutputStream())
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        StreamCounterHandler(writer: self.makeWriter(label: label, dimensions: dimensions))
    }

    public func makeFloatingPointCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> FloatingPointCounterHandler {
        StreamFloatingPointCounterHandler(
            writer: self.makeWriter(label: label, dimensions: dimensions)
        )
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        StreamMeterHandler(writer: self.makeWriter(label: label, dimensions: dimensions))
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        StreamRecorderHandler(
            writer: self.makeWriter(label: label, dimensions: dimensions, aggregate: aggregate)
        )
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        StreamTimerHandler(writer: self.makeWriter(label: label, dimensions: dimensions))
    }

    public func destroyCounter(_ handler: CounterHandler) {}
    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {}
    public func destroyMeter(_ handler: MeterHandler) {}
    public func destroyRecorder(_ handler: RecorderHandler) {}
    public func destroyTimer(_ handler: TimerHandler) {}

    private func makeWriter(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool? = nil
    ) -> LineWriter {
        LineWriter(sink: self.sink, label: label, dimensions: dimensions, aggregate: aggregate)
    }
}

// MARK: - Sink

/// Serializes writes to a user-supplied `TextOutputStream`.
///
/// `TextOutputStream.write` is mutating, which is awkward for an existential stored in a shared
/// `Sendable` value. Holding the stream in a class lets us mutate in place under a lock rather
/// than working against copies.
private final class Sink: @unchecked Sendable {
    private let lock = NSLock()
    private var stream: any (TextOutputStream & Sendable)

    init(stream: any (TextOutputStream & Sendable)) {
        self.stream = stream
    }

    func write(_ line: String) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.stream.write(line)
    }
}

// MARK: - LineWriter

/// Builds and writes one formatted line per metric mutation.
private struct LineWriter: Sendable {
    let sink: Sink
    let label: String
    let dimensions: [(String, String)]
    let aggregate: Bool?

    func write(_ message: String) {
        self.sink.write(self.format(message: message, key: nil, value: nil))
    }

    func write(_ message: String, key: String, value: String) {
        self.sink.write(self.format(message: message, key: key, value: value))
    }

    private func format(message: String, key: String?, value: String?) -> String {
        var line = message
        line += " metric.name=\(self.label)"
        if !self.dimensions.isEmpty {
            line += " metric.dimensions=["
            line += self.dimensions.map { "\($0.0)=\($0.1)" }.joined(separator: ",")
            line += "]"
        }
        if let aggregate = self.aggregate {
            line += " metric.aggregate=\(aggregate)"
        }
        if let key, let value {
            line += " \(key)=\(value)"
        }
        line += "\n"
        return line
    }
}

// MARK: - Handlers

private final class StreamCounterHandler: CounterHandler, Sendable {
    let writer: LineWriter
    init(writer: LineWriter) { self.writer = writer }

    func increment(by amount: Int64) {
        self.writer.write("increment counter", key: "metric.amount", value: "\(amount)")
    }

    func reset() {
        self.writer.write("reset counter")
    }
}

private final class StreamFloatingPointCounterHandler: FloatingPointCounterHandler, Sendable {
    let writer: LineWriter
    init(writer: LineWriter) { self.writer = writer }

    func increment(by amount: Double) {
        self.writer.write(
            "increment floating-point counter",
            key: "metric.amount",
            value: "\(amount)"
        )
    }

    func reset() {
        self.writer.write("reset floating-point counter")
    }
}

private final class StreamMeterHandler: MeterHandler, Sendable {
    let writer: LineWriter
    init(writer: LineWriter) { self.writer = writer }

    func set(_ value: Int64) {
        self.writer.write("set meter", key: "metric.value", value: "\(value)")
    }

    func set(_ value: Double) {
        self.writer.write("set meter", key: "metric.value", value: "\(value)")
    }

    func increment(by amount: Double) {
        self.writer.write("increment meter", key: "metric.delta", value: "\(amount)")
    }

    func decrement(by amount: Double) {
        self.writer.write("decrement meter", key: "metric.delta", value: "\(amount)")
    }
}

private final class StreamRecorderHandler: RecorderHandler, Sendable {
    let writer: LineWriter
    init(writer: LineWriter) { self.writer = writer }

    func record(_ value: Int64) {
        self.writer.write("record value", key: "metric.value", value: "\(value)")
    }

    func record(_ value: Double) {
        self.writer.write("record value", key: "metric.value", value: "\(value)")
    }
}

private final class StreamTimerHandler: TimerHandler, Sendable {
    let writer: LineWriter
    init(writer: LineWriter) { self.writer = writer }

    func recordNanoseconds(_ duration: Int64) {
        self.writer.write("record duration", key: "metric.nanoseconds", value: "\(duration)")
    }
}

// MARK: - Standard streams

/// Writes to standard output via `print`, without appending an extra newline — the formatted
/// line already carries one.
private struct StandardOutputStream: TextOutputStream, Sendable {
    func write(_ string: String) {
        print(string, terminator: "")
    }
}
