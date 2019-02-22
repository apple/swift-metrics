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

public protocol Counter: AnyObject {
    func increment<DataType: BinaryInteger>(_ value: DataType)
}

public extension Counter {
    @inlinable
    func increment() {
        self.increment(1)
    }
}

public protocol Recorder: AnyObject {
    func record<DataType: BinaryInteger>(_ value: DataType)
    func record<DataType: BinaryFloatingPoint>(_ value: DataType)
}

public protocol Timer: AnyObject {
    func recordNanoseconds(_ duration: Int64)
}

public extension Timer {
    @inlinable
    func recordMicroseconds<DataType: BinaryInteger>(_ duration: DataType) {
        self.recordNanoseconds(Int64(duration) * 1000)
    }

    @inlinable
    func recordMicroseconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(Int64(duration * 1000))
    }

    @inlinable
    func recordMilliseconds<DataType: BinaryInteger>(_ duration: DataType) {
        self.recordNanoseconds(Int64(duration) * 1_000_000)
    }

    @inlinable
    func recordMilliseconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(Int64(duration * 1_000_000))
    }

    @inlinable
    func recordSeconds<DataType: BinaryInteger>(_ duration: DataType) {
        self.recordNanoseconds(Int64(duration) * 1_000_000_000)
    }

    @inlinable
    func recordSeconds<DataType: BinaryFloatingPoint>(_ duration: DataType) {
        self.recordNanoseconds(Int64(duration * 1_000_000_000))
    }
}

public protocol MetricsHandler {
    func makeCounter(label: String, dimensions: [(String, String)]) -> Counter
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder
    func makeTimer(label: String, dimensions: [(String, String)]) -> Timer
}

public extension MetricsHandler {
    @inlinable
    func makeCounter(label: String) -> Counter {
        return self.makeCounter(label: label, dimensions: [])
    }

    @inlinable
    func makeRecorder(label: String, aggregate: Bool = true) -> Recorder {
        return self.makeRecorder(label: label, dimensions: [], aggregate: aggregate)
    }

    @inlinable
    func makeTimer(label: String) -> Timer {
        return self.makeTimer(label: label, dimensions: [])
    }
}

public extension MetricsHandler {
    @inlinable
    func makeGauge(label: String, dimensions: [(String, String)] = []) -> Recorder {
        return self.makeRecorder(label: label, dimensions: dimensions, aggregate: false)
    }
}

public extension MetricsHandler {
    @inlinable
    func withCounter(label: String, dimensions: [(String, String)] = [], then: (Counter) -> Void) {
        then(self.makeCounter(label: label, dimensions: dimensions))
    }

    @inlinable
    func withRecorder(label: String, dimensions: [(String, String)] = [], aggregate: Bool = true, then: (Recorder) -> Void) {
        then(self.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate))
    }

    @inlinable
    func withTimer(label: String, dimensions: [(String, String)] = [], then: (Timer) -> Void) {
        then(self.makeTimer(label: label, dimensions: dimensions))
    }

    @inlinable
    func withGauge(label: String, dimensions: [(String, String)] = [], then: (Recorder) -> Void) {
        then(self.makeGauge(label: label, dimensions: dimensions))
    }
}

public enum Metrics {
    private static let lock = ReadWriteLock()
    private static var _handler: MetricsHandler = NOOPMetricsHandler.instance

    public static func bootstrap(_ handler: MetricsHandler) {
        self.lock.withWriterLockVoid {
            // using a wrapper to avoid redundant and potentially expensive factory calls
            self._handler = CachingMetricsHandler.wrap(handler)
        }
    }

    public static var global: MetricsHandler {
        return self.lock.withReaderLock { self._handler }
    }
}

public extension Metrics {
    @inlinable
    func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return Metrics.global.makeCounter(label: label, dimensions: dimensions)
    }
    @inlinable
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        return Metrics.global.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
    }
    @inlinable
    func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return Metrics.global.makeTimer(label: label, dimensions: dimensions)
    }
}

private final class CachingMetricsHandler: MetricsHandler {
    private let wrapped: MetricsHandler
    private var counters = Cache<Counter>()
    private var recorders = Cache<Recorder>()
    private var timers = Cache<Timer>()

    public static func wrap(_ handler: MetricsHandler) -> CachingMetricsHandler {
        if let caching = handler as? CachingMetricsHandler {
            return caching
        } else {
            return CachingMetricsHandler(handler)
        }
    }

    private init(_ wrapped: MetricsHandler) {
        self.wrapped = wrapped
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return self.counters.getOrSet(label: label, dimensions: dimensions, maker: self.wrapped.makeCounter)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        let maker = { (label: String, dimensions: [(String, String)]) -> Recorder in
            self.wrapped.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        return self.recorders.getOrSet(label: label, dimensions: dimensions, maker: maker)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return self.timers.getOrSet(label: label, dimensions: dimensions, maker: self.wrapped.makeTimer)
    }

    private class Cache<T> {
        private var items = [String: T]()
        // using a mutex is never ideal, we will need to explore optimization options
        // once we see how real life workloads behaves
        // for example, for short opetations like hashmap lookup mutexes are worst than r/w locks in 99% reads, but better than them in mixed r/w mode
        private let lock = Lock()

        func getOrSet(label: String, dimensions: [(String, String)], maker: (String, [(String, String)]) -> T) -> T {
            let key = self.fqn(label: label, dimensions: dimensions)
            return self.lock.withLock {
                if let item = items[key] {
                    return item
                } else {
                    let item = maker(label, dimensions)
                    items[key] = item
                    return item
                }
            }
        }

        private func fqn(label: String, dimensions: [(String, String)]) -> String {
            return [[label], dimensions.compactMap { "\($0.0).\($0.1)" }].flatMap { $0 }.joined(separator: ".")
        }
    }
}

public final class MultiplexMetricsHandler: MetricsHandler {
    private let handlers: [MetricsHandler]
    public init(handlers: [MetricsHandler]) {
        self.handlers = handlers
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return MuxCounter(handlers: self.handlers, label: label, dimensions: dimensions)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        return MuxRecorder(handlers: self.handlers, label: label, dimensions: dimensions, aggregate: aggregate)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return MuxTimer(handlers: self.handlers, label: label, dimensions: dimensions)
    }

    private class MuxCounter: Counter {
        let counters: [Counter]
        public init(handlers: [MetricsHandler], label: String, dimensions: [(String, String)]) {
            self.counters = handlers.map { $0.makeCounter(label: label, dimensions: dimensions) }
        }

        func increment<DataType: BinaryInteger>(_ value: DataType) {
            self.counters.forEach { $0.increment(value) }
        }
    }

    private class MuxRecorder: Recorder {
        let recorders: [Recorder]
        public init(handlers: [MetricsHandler], label: String, dimensions: [(String, String)], aggregate: Bool) {
            self.recorders = handlers.map { $0.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate) }
        }

        func record<DataType: BinaryInteger>(_ value: DataType) {
            self.recorders.forEach { $0.record(value) }
        }

        func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
            self.recorders.forEach { $0.record(value) }
        }
    }

    private class MuxTimer: Timer {
        let timers: [Timer]
        public init(handlers: [MetricsHandler], label: String, dimensions: [(String, String)]) {
            self.timers = handlers.map { $0.makeTimer(label: label, dimensions: dimensions) }
        }

        func recordNanoseconds(_ duration: Int64) {
            self.timers.forEach { $0.recordNanoseconds(duration) }
        }
    }
}

public final class NOOPMetricsHandler: MetricsHandler, Counter, Recorder, Timer {
    public static let instance = NOOPMetricsHandler()

    private init() {}

    public func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return self
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        return self
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return self
    }

    public func increment<DataType: BinaryInteger>(_: DataType) {}
    public func record<DataType: BinaryInteger>(_: DataType) {}
    public func record<DataType: BinaryFloatingPoint>(_: DataType) {}
    public func recordNanoseconds(_: Int64) {}
}
