//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Cluster Membership open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Cluster Membership project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Cluster Membership project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CoreMetrics
import Metrics
import XCTest

/// Taken directly from `swift-cluster-memberships`'s own test target package, which
/// adopts the `TestMetrics` from `swift-metrics`.
///
/// Metrics factory which allows inspecting recorded metrics programmatically.
/// Only intended for tests of the Metrics API itself.
///
/// Created Handlers will store Metrics until they are explicitly destroyed.
///
public final class TestMetrics: MetricsFactory {
    private let lock = NSLock()

    public typealias Label = String
    public typealias Dimensions = String

    public struct FullKey {
        let label: Label
        let dimensions: [(String, String)]
    }

    private var counters = [FullKey: CounterHandler]()
    private var recorders = [FullKey: RecorderHandler]()
    private var gauges = [FullKey: GaugeHandler]()
    private var timers = [FullKey: TimerHandler]()

    public init() {
        // nothing to do
    }

    /// Reset method to destroy all created ``TestCounter``, ``TestRecorder`` and ``TestTimer``.
    /// Invoke this method in between test runs to verify that Counters are created as needed.
    public func reset() {
        self.lock.withLock {
            self.counters = [:]
            self.recorders = [:]
            self.timers = [:]
        }
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return self.lock.withLock { () -> CounterHandler in
            if let existing = self.counters[.init(label: label, dimensions: dimensions)] {
                return existing
            }
            let item = TestCounter(label: label, dimensions: dimensions)
            self.counters[.init(label: label, dimensions: dimensions)] = item
            return item
        }
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        return self.lock.withLock { () -> RecorderHandler in
            if let existing = self.recorders[.init(label: label, dimensions: dimensions)] {
                return existing
            }
            let item = TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
            self.recorders[.init(label: label, dimensions: dimensions)] = item
            return item
        }
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return self.lock.withLock { () -> TimerHandler in
            if let existing = self.timers[.init(label: label, dimensions: dimensions)] {
                return existing
            }
            let item = TestTimer(label: label, dimensions: dimensions)
            self.timers[.init(label: label, dimensions: dimensions)] = item
            return item
        }
    }

    public func destroyCounter(_ handler: CounterHandler) {
        if let testCounter = handler as? TestCounter {
            self.lock.withLock { () in
                self.counters.removeValue(forKey: testCounter.key)
            }
        }
    }

    public func destroyRecorder(_ handler: RecorderHandler) {
        if let testRecorder = handler as? TestRecorder {
            self.lock.withLock { () in
                self.recorders.removeValue(forKey: testRecorder.key)
            }
        }
    }

    public func destroyTimer(_ handler: TimerHandler) {
        if let testTimer = handler as? TestTimer {
            self.lock.withLock { () in
                self.timers.removeValue(forKey: testTimer.key)
            }
        }
    }
}

extension TestMetrics.FullKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.label.hash(into: &hasher)
        self.dimensions.forEach { dim in
            dim.0.hash(into: &hasher)
            dim.1.hash(into: &hasher)
        }
    }

    public static func == (lhs: TestMetrics.FullKey, rhs: TestMetrics.FullKey) -> Bool {
        return lhs.label == rhs.label &&
            Dictionary(uniqueKeysWithValues: lhs.dimensions) == Dictionary(uniqueKeysWithValues: rhs.dimensions)
    }
}

// MARK: - Assertions

extension TestMetrics {
    // MARK: - Counter

    public func expectCounter(_ metric: Counter) throws -> TestCounter {
        guard let counter = metric._handler as? TestCounter else {
            throw TestMetricsError.illegalMetricType(metric: metric._handler, expected: "\(TestCounter.self)")
        }
        return counter
    }

    public func expectCounter(_ label: String, _ dimensions: [(String, String)] = []) throws -> TestCounter {
        let maybeItem = self.lock.withLock {
            self.counters[.init(label: label, dimensions: dimensions)]
        }
        guard let maybeCounter = maybeItem else {
            throw TestMetricsError.missingMetric(label: label, dimensions: dimensions)
        }
        guard let testCounter = maybeCounter as? TestCounter else {
            throw TestMetricsError.illegalMetricType(metric: maybeCounter, expected: "\(TestCounter.self)")
        }
        return testCounter
    }

    // MARK: - Gauge

    @available(*, deprecated)
    public func expectGauge(_ metric: Gauge) throws -> TestRecorder {
        return try self.expectRecorder(metric)
    }

    @available(*, deprecated)
    public func expectGauge(_ label: String, _ dimensions: [(String, String)] = []) throws -> TestRecorder {
        return try self.expectRecorder(label, dimensions)
    }

    public func expectGauge2(_ metric: Gauge2) throws -> TestGauge {
        guard let gauge = metric._handler as? TestGauge else {
            throw TestMetricsError.illegalMetricType(metric: metric._handler, expected: "\(TestGauge.self)")
        }
        return gauge
    }

    public func expectGauge2(_ label: String, _ dimensions: [(String, String)] = []) throws -> TestGauge {
        let maybeItem = self.lock.withLock {
            self.gauges[.init(label: label, dimensions: dimensions)]
        }
        guard let maybeGauge = maybeItem else {
            throw TestMetricsError.missingMetric(label: label, dimensions: dimensions)
        }
        guard let testGauge = maybeGauge as? TestGauge else {
            throw TestMetricsError.illegalMetricType(metric: maybeGauge, expected: "\(TestGauge.self)")
        }
        return testGauge
    }

    // MARK: - Recorder

    public func expectRecorder(_ metric: Recorder) throws -> TestRecorder {
        guard let recorder = metric._handler as? TestRecorder else {
            throw TestMetricsError.illegalMetricType(metric: metric._handler, expected: "\(TestRecorder.self)")
        }
        return recorder
    }

    public func expectRecorder(_ label: String, _ dimensions: [(String, String)] = []) throws -> TestRecorder {
        let maybeItem = self.lock.withLock {
            self.recorders[.init(label: label, dimensions: dimensions)]
        }
        guard let maybeRecorder = maybeItem else {
            throw TestMetricsError.missingMetric(label: label, dimensions: dimensions)
        }
        guard let testRecorder = maybeRecorder as? TestRecorder else {
            throw TestMetricsError.illegalMetricType(metric: maybeRecorder, expected: "\(TestRecorder.self)")
        }
        return testRecorder
    }

    // MARK: - Timer

    public func expectTimer(_ metric: CoreMetrics.Timer) throws -> TestTimer {
        guard let timer = metric._handler as? TestTimer else {
            throw TestMetricsError.illegalMetricType(metric: metric._handler, expected: "\(TestTimer.self)")
        }
        return timer
    }

    public func expectTimer(_ label: String, _ dimensions: [(String, String)] = []) throws -> TestTimer {
        let maybeItem = self.lock.withLock {
            self.timers[.init(label: label, dimensions: dimensions)]
        }
        guard let maybeTimer = maybeItem else {
            throw TestMetricsError.missingMetric(label: label, dimensions: dimensions)
        }
        guard let testTimer = maybeTimer as? TestTimer else {
            throw TestMetricsError.illegalMetricType(metric: maybeTimer, expected: "\(TestTimer.self)")
        }
        return testTimer
    }
}

// MARK: - Metric type implementations

public protocol TestMetric {
    associatedtype Value

    var key: TestMetrics.FullKey { get }

    var lastValue: Value? { get }
    var last: (Date, Value)? { get }
}

public final class TestCounter: TestMetric, CounterHandler, Equatable {
    public let id: String
    public let label: String
    public let dimensions: [(String, String)]

    public var key: TestMetrics.FullKey {
        return TestMetrics.FullKey(label: self.label, dimensions: self.dimensions)
    }

    let lock = NSLock()
    private var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = UUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    public func increment(by amount: Int64) {
        self.lock.withLock {
            self.values.append((Date(), amount))
        }
    }

    public func reset() {
        return self.lock.withLock {
            self.values = []
        }
    }

    public var lastValue: Int64? {
        return self.lock.withLock {
            return values.last?.1
        }
    }

    public var totalValue: Int64 {
        return self.lock.withLock {
            return values.map { $0.1 }.reduce(0, +)
        }
    }

    public var last: (Date, Int64)? {
        return self.lock.withLock {
            values.last
        }
    }

    public static func == (lhs: TestCounter, rhs: TestCounter) -> Bool {
        return lhs.id == rhs.id
    }
}

public final class TestRecorder: TestMetric, RecorderHandler, Equatable {
    public let id: String
    public let label: String
    public let dimensions: [(String, String)]
    public let aggregate: Bool

    public var key: TestMetrics.FullKey {
        return TestMetrics.FullKey(label: self.label, dimensions: self.dimensions)
    }

    let lock = NSLock()
    private var values = [(Date, Double)]()

    init(label: String, dimensions: [(String, String)], aggregate: Bool) {
        self.id = UUID().uuidString
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
    }

    public func record(_ value: Int64) {
        self.record(Double(value))
    }

    public func record(_ value: Double) {
        self.lock.withLock {
            // this may loose precision but good enough as an example
            values.append((Date(), Double(value)))
        }
    }

    public var lastValue: Double? {
        return self.lock.withLock {
            values.last?.1
        }
    }

    public var last: (Date, Double)? {
        return self.lock.withLock {
            values.last
        }
    }

    public static func == (lhs: TestRecorder, rhs: TestRecorder) -> Bool {
        return lhs.id == rhs.id
    }
}

public final class TestGauge: TestMetric, GaugeHandler, Equatable {
    public let id: String
    public let label: String
    public let dimensions: [(String, String)]

    public var key: TestMetrics.FullKey {
        return TestMetrics.FullKey(label: self.label, dimensions: self.dimensions)
    }

    let lock = NSLock()
    private var values = [(Date, Double)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    public func set(_ value: Int64) {
        self.set(Double(value))
    }

    public func set(_ value: Double) {
        self.lock.withLock {
            // this may loose precision but good enough as an example
            values.append((Date(), Double(value)))
        }
    }

    public func increment(by amount: Double) {
        self.lock.withLock {
            let lastValue = self.values.last?.1 ?? 0
            let newValue = lastValue - amount
            values.append((Date(), Double(newValue)))
        }
    }

    public func decrement(by amount: Double) {
        self.lock.withLock {
            let lastValue = self.values.last?.1 ?? 0
            let newValue = lastValue - amount
            values.append((Date(), Double(newValue)))
        }
    }

    public var lastValue: Double? {
        return self.lock.withLock {
            values.last?.1
        }
    }

    public var last: (Date, Double)? {
        return self.lock.withLock {
            values.last
        }
    }

    public static func == (lhs: TestGauge, rhs: TestGauge) -> Bool {
        return lhs.id == rhs.id
    }
}

public final class TestTimer: TestMetric, TimerHandler, Equatable {
    public let id: String
    public let label: String
    public var displayUnit: TimeUnit?
    public let dimensions: [(String, String)]

    public var key: TestMetrics.FullKey {
        return TestMetrics.FullKey(label: self.label, dimensions: self.dimensions)
    }

    let lock = NSLock()
    private var _values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = UUID().uuidString
        self.label = label
        self.displayUnit = nil
        self.dimensions = dimensions
    }

    public func preferDisplayUnit(_ unit: TimeUnit) {
        self.lock.withLock {
            self.displayUnit = unit
        }
    }

    func retrieveValueInPreferredUnit(atIndex i: Int) -> Double {
        return self.lock.withLock {
            let value = _values[i].1
            guard let displayUnit = self.displayUnit else {
                return Double(value)
            }
            return Double(value) / Double(displayUnit.scaleFromNanoseconds)
        }
    }

    public func recordNanoseconds(_ duration: Int64) {
        self.lock.withLock {
            _values.append((Date(), duration))
        }
    }

    public var lastValue: Int64? {
        return self.lock.withLock {
            return _values.last?.1
        }
    }

    public var values: [Int64] {
        return self.lock.withLock {
            return _values.map { $0.1 }
        }
    }

    public var last: (Date, Int64)? {
        return self.lock.withLock {
            return _values.last
        }
    }

    public static func == (lhs: TestTimer, rhs: TestTimer) -> Bool {
        return lhs.id == rhs.id
    }
}

extension NSLock {
    @discardableResult
    fileprivate func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}

// MARK: - Errors

#if compiler(>=5.6)
public enum TestMetricsError: Error {
    case missingMetric(label: String, dimensions: [(String, String)])
    case illegalMetricType(metric: Sendable, expected: String)
}

#else
public enum TestMetricsError: Error {
    case missingMetric(label: String, dimensions: [(String, String)])
    case illegalMetricType(metric: Any, expected: String)
}
#endif

// MARK: - Sendable support

#if compiler(>=5.6)
// ideally we would not be using @unchecked here, but concurrency-safety checks do not recognize locks
extension TestMetrics: @unchecked Sendable {}
extension TestCounter: @unchecked Sendable {}
extension TestRecorder: @unchecked Sendable {}
extension TestGauge: @unchecked Sendable {}
extension TestTimer: @unchecked Sendable {}
#endif
