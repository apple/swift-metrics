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

@testable import CoreMetrics
@testable import class CoreMetrics.Timer
import Foundation

/// Metrics factory which allows inspecting recorded metrics programmatically.
/// Only intended for tests of the Metrics API itself.
internal final class TestMetrics: MetricsFactory {
    private let lock = NSLock()
    var counters = [String: CounterHandler]()
    var meters = [String: MeterHandler]()
    var recorders = [String: RecorderHandler]()
    var timers = [String: TimerHandler]()

    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return self.make(label: label, dimensions: dimensions, registry: &self.counters, maker: TestCounter.init)
    }

    func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        return self.make(label: label, dimensions: dimensions, registry: &self.meters, maker: TestMeter.init)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        let maker = { (label: String, dimensions: [(String, String)]) -> RecorderHandler in
            TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        return self.make(label: label, dimensions: dimensions, registry: &self.recorders, maker: maker)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return self.make(label: label, dimensions: dimensions, registry: &self.timers, maker: TestTimer.init)
    }

    private func make<Item>(label: String, dimensions: [(String, String)], registry: inout [String: Item], maker: (String, [(String, String)]) -> Item) -> Item {
        let item = maker(label, dimensions)
        return self.lock.withLock {
            registry[label] = item
            return item
        }
    }

    func destroyCounter(_ handler: CounterHandler) {
        if let testCounter = handler as? TestCounter {
            self.lock.withLock { () in
                self.counters.removeValue(forKey: testCounter.label)
            }
        }
    }

    func destroyMeter(_ handler: MeterHandler) {
        if let testMeter = handler as? TestMeter {
            self.lock.withLock { () in
                self.meters.removeValue(forKey: testMeter.label)
            }
        }
    }

    func destroyRecorder(_ handler: RecorderHandler) {
        if let testRecorder = handler as? TestRecorder {
            self.lock.withLock { () in
                self.recorders.removeValue(forKey: testRecorder.label)
            }
        }
    }

    func destroyTimer(_ handler: TimerHandler) {
        if let testTimer = handler as? TestTimer {
            self.lock.withLock { () in
                self.timers.removeValue(forKey: testTimer.label)
            }
        }
    }
}

internal final class TestCounter: CounterHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]

    let lock = NSLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = UUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func increment(by amount: Int64) {
        self.lock.withLock {
            self.values.append((Date(), amount))
        }
        print("adding \(amount) to \(self.label)")
    }

    func reset() {
        self.lock.withLock {
            self.values = []
        }
        print("reseting \(self.label)")
    }

    public static func == (lhs: TestCounter, rhs: TestCounter) -> Bool {
        return lhs.id == rhs.id
    }
}

internal final class TestMeter: MeterHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]

    let lock = NSLock()
    var values = [(Date, Double)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func set(_ value: Int64) {
        self.set(Double(value))
    }

    func set(_ value: Double) {
        self.lock.withLock {
            // this may loose precision but good enough as an example
            values.append((Date(), Double(value)))
        }
        print("setting \(value) in \(self.label)")
    }

    func increment(by amount: Double) {
        let newValue: Double = self.lock.withLock {
            let lastValue = self.values.last?.1 ?? 0
            let newValue = lastValue + amount
            values.append((Date(), Double(newValue)))
            return newValue
        }
        print("recording \(newValue) in \(self.label)")
    }

    func decrement(by amount: Double) {
        let newValue: Double = self.lock.withLock {
            let lastValue = self.values.last?.1 ?? 0
            let newValue = lastValue - amount
            values.append((Date(), Double(newValue)))
            return newValue
        }
        print("recording \(newValue) in \(self.label)")
    }

    public static func == (lhs: TestMeter, rhs: TestMeter) -> Bool {
        return lhs.id == rhs.id
    }
}

internal final class TestRecorder: RecorderHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]
    let aggregate: Bool

    let lock = NSLock()
    var values = [(Date, Double)]()

    init(label: String, dimensions: [(String, String)], aggregate: Bool) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
    }

    func record(_ value: Int64) {
        self.record(Double(value))
    }

    func record(_ value: Double) {
        self.lock.withLock {
            // this may loose precision but good enough as an example
            values.append((Date(), Double(value)))
        }
        print("recording \(value) in \(self.label)")
    }

    public static func == (lhs: TestRecorder, rhs: TestRecorder) -> Bool {
        return lhs.id == rhs.id
    }
}

internal final class TestTimer: TimerHandler, Equatable {
    let id: String
    let label: String
    var displayUnit: TimeUnit?
    let dimensions: [(String, String)]

    let lock = NSLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = UUID().uuidString
        self.label = label
        self.displayUnit = nil
        self.dimensions = dimensions
    }

    func preferDisplayUnit(_ unit: TimeUnit) {
        self.lock.withLock {
            self.displayUnit = unit
        }
    }

    func retrieveValueInPreferredUnit(atIndex i: Int) -> Double {
        return self.lock.withLock {
            let value = values[i].1
            guard let displayUnit = self.displayUnit else {
                return Double(value)
            }
            return Double(value) / Double(displayUnit.scaleFromNanoseconds)
        }
    }

    func recordNanoseconds(_ duration: Int64) {
        self.lock.withLock {
            values.append((Date(), duration))
        }
        print("recording \(duration) \(self.label)")
    }

    static func == (lhs: TestTimer, rhs: TestTimer) -> Bool {
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

// MARK: - Sendable support

#if compiler(>=5.6)
// ideally we would not be using @unchecked here, but concurrency-safety checks do not recognize locks
extension TestCounter: @unchecked Sendable {}
extension TestMeter: @unchecked Sendable {}
extension TestRecorder: @unchecked Sendable {}
extension TestTimer: @unchecked Sendable {}
#endif
