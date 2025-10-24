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

import Foundation
import MetricsTestKit
import Testing

@testable import CoreMetrics
@testable import Metrics

struct MetricsExtensionsTests {
    @Test func timerBlock() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "timer-\(UUID().uuidString)"
        let delay = 0.05
        Timer.measure(label: name, factory: metrics) {
            Thread.sleep(forTimeInterval: delay)
        }
        let timer = try metrics.expectTimer(name)
        #expect(timer.values.count == 1, "expected number of entries to match")
        #expect(timer.values[0] > Int64(delay * 1_000_000_000), "expected delay to match")
    }

    @Test func timerWithTimeInterval() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let timer = Timer(label: "test-timer", factory: metrics)
        let testTimer = try metrics.expectTimer(timer)
        let timeInterval = TimeInterval(Double.random(in: 1...500))
        timer.record(timeInterval)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(testTimer.values[0] == Int64(timeInterval * 1_000_000_000), "expected value to match")
    }

    @Test func timerWithDispatchTime() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let timer = Timer(label: "test-timer", factory: metrics)
        let testTimer = try metrics.expectTimer(timer)
        // nano
        let nano = DispatchTimeInterval.nanoseconds(Int.random(in: 1...500))
        timer.record(nano)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(Int(testTimer.values[0]) == nano.nano(), "expected value to match")
        // micro
        let micro = DispatchTimeInterval.microseconds(Int.random(in: 1...500))
        timer.record(micro)
        #expect(testTimer.values.count == 2, "expected number of entries to match")
        #expect(Int(testTimer.values[1]) == micro.nano(), "expected value to match")
        // milli
        let milli = DispatchTimeInterval.milliseconds(Int.random(in: 1...500))
        timer.record(milli)
        #expect(testTimer.values.count == 3, "expected number of entries to match")
        #expect(Int(testTimer.values[2]) == milli.nano(), "expected value to match")
        // seconds
        let sec = DispatchTimeInterval.seconds(Int.random(in: 1...500))
        timer.record(sec)
        #expect(testTimer.values.count == 4, "expected number of entries to match")
        #expect(Int(testTimer.values[3]) == sec.nano(), "expected value to match")
        // never
        timer.record(DispatchTimeInterval.never)
        #expect(testTimer.values.count == 5, "expected number of entries to match")
        #expect(testTimer.values[4] == 0, "expected value to match")
    }

    @Test func timerWithDispatchTimeInterval() throws {
        let metrics = TestMetrics()

        let name = "timer-\(UUID().uuidString)"

        let timer = Timer(label: name, factory: metrics)
        let start = DispatchTime.now()
        let end = DispatchTime(uptimeNanoseconds: start.uptimeNanoseconds + 1000 * 1000 * 1000)
        timer.recordInterval(since: start, end: end)

        let testTimer = try metrics.expectTimer(timer)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(
            UInt64(testTimer.values.first!) == end.uptimeNanoseconds - start.uptimeNanoseconds,
            "expected value to match"
        )
        #expect(metrics.timers.count == 1, "timer should have been stored")
    }

    @Test func timerDuration() throws {
        let metrics = TestMetrics()

        let name = "timer-\(UUID().uuidString)"
        let timer = Timer(label: name, factory: metrics)

        let duration = Duration(secondsComponent: 3, attosecondsComponent: 123_000_000_000_000_000)
        let nanoseconds = duration.components.seconds * 1_000_000_000 + duration.components.attoseconds / 1_000_000_000
        timer.record(duration: duration)

        // Record a Duration that would overflow,
        // expect Int64.max to be recorded.
        timer.record(duration: Duration(secondsComponent: 10_000_000_000, attosecondsComponent: 123))

        let testTimer = try metrics.expectTimer(timer)
        #expect(testTimer.values.count == 2, "expected number of entries to match")
        #expect(testTimer.values.first == nanoseconds, "expected value to match")
        #expect(testTimer.values[1] == Int64.max, "expected to record Int64.max if Durataion overflows")
        #expect(metrics.timers.count == 1, "timer should have been stored")
    }

    @Test func timerUnits() throws {
        let metrics = TestMetrics()

        let name = "timer-\(UUID().uuidString)"
        let value = Int64.random(in: 0...1000)

        let timer = Timer(label: name, factory: metrics)
        timer.recordNanoseconds(value)

        let testTimer = try metrics.expectTimer(timer)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(testTimer.values.first == value, "expected value to match")
        #expect(metrics.timers.count == 1, "timer should have been stored")

        let secondsName = "timer-seconds-\(UUID().uuidString)"
        let secondsValue = Int64.random(in: 0...1000)
        let secondsTimer = Timer(label: secondsName, preferredDisplayUnit: .seconds, factory: metrics)
        secondsTimer.recordSeconds(secondsValue)

        let testSecondsTimer = try metrics.expectTimer(secondsTimer)
        #expect(testSecondsTimer.values.count == 1, "expected number of entries to match")
        #expect(metrics.timers.count == 2, "timer should have been stored")
    }

    @Test func preferDisplayUnit() throws {
        let metrics = TestMetrics()

        let value = Double.random(in: 0...1000)
        let timer = Timer(label: "test", preferredDisplayUnit: .seconds, factory: metrics)
        timer.recordSeconds(value)

        let testTimer = try metrics.expectTimer(timer)

        // The suggested way for comparing float numbers is to use swift-numerics,
        // but this would add a dependency. Instead, as we fully control the values
        // used in tests, we can get away with the simple `abs(x - y) < accuracy`.
        // See https://developer.apple.com/documentation/testing/migratingfromxctest

        testTimer.preferDisplayUnit(.nanoseconds)
        #expect(
            abs(testTimer.valueInPreferredUnit(atIndex: 0) - value * 1000 * 1000 * 1000) < 1.0,
            "expected value to match"
        )

        testTimer.preferDisplayUnit(.microseconds)
        #expect(
            abs(testTimer.valueInPreferredUnit(atIndex: 0) - value * 1000 * 1000) < 0.1,
            "expected value to match"
        )

        testTimer.preferDisplayUnit(.milliseconds)
        #expect(
            abs(testTimer.valueInPreferredUnit(atIndex: 0) - value * 1000) < 0.1,
            "expected value to match"
        )

        testTimer.preferDisplayUnit(.seconds)
        #expect(
            abs(testTimer.valueInPreferredUnit(atIndex: 0) - value) < 0.000000001,
            "expected value to match"
        )

        testTimer.preferDisplayUnit(.minutes)
        #expect(
            abs(testTimer.valueInPreferredUnit(atIndex: 0) - value / 60) < 0.000000001,
            "expected value to match"
        )

        testTimer.preferDisplayUnit(.hours)
        #expect(
            abs(testTimer.valueInPreferredUnit(atIndex: 0) - value / (60 * 60)) < 0.000000001,
            "expected value to match"
        )

        testTimer.preferDisplayUnit(.days)
        #expect(
            abs(testTimer.valueInPreferredUnit(atIndex: 0) - value / (60 * 60 * 24)) < 0.000000001,
            "expected value to match"
        )
    }

    @Test func timerMeasure() async throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "timer-\(UUID().uuidString)"
        let delay = Duration.milliseconds(5)
        let timer = Timer(label: name, factory: metrics)
        try await timer.measure {
            try await Task.sleep(for: delay)
        }

        let expectedTimer = try metrics.expectTimer(name)
        #expect(expectedTimer.values.count == 1, "expected number of entries to match")
        #expect(expectedTimer.values[0] > delay.nanosecondsClamped, "expected delay to match")
    }

    @MainActor
    @Test func timerMeasureFromMainActor() async throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "timer-\(UUID().uuidString)"
        let delay = Duration.milliseconds(5)
        let timer = Timer(label: name, factory: metrics)
        try await timer.measure {
            try await Task.sleep(for: delay)
        }

        let expectedTimer = try metrics.expectTimer(name)
        #expect(expectedTimer.values.count == 1, "expected number of entries to match")
        #expect(expectedTimer.values[0] > delay.nanosecondsClamped, "expected delay to match")
    }
}

// https://bugs.swift.org/browse/SR-6310
extension DispatchTimeInterval {
    func nano() -> Int {
        // This wrapping in a optional is a workaround because DispatchTimeInterval
        // is a non-frozen public enum and Dispatch is built with library evolution
        // mode turned on.
        // This means we should have an `@unknown default` case, but this breaks
        // on non-Darwin platforms.
        // Switching over an optional means that the `.none` case will map to
        // `default` (which means we'll always have a valid case to go into
        // the default case), but in reality this case will never exist as this
        // optional will never be nil.
        let interval = Optional(self)
        switch interval {
        case .nanoseconds(let value):
            return value
        case .microseconds(let value):
            return value * 1000
        case .milliseconds(let value):
            return value * 1_000_000
        case .seconds(let value):
            return value * 1_000_000_000
        case .never:
            return 0
        default:
            return 0
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Swift.Duration {
    fileprivate var nanosecondsClamped: Int64 {
        let components = self.components

        let secondsComponentNanos = components.seconds.multipliedReportingOverflow(by: 1_000_000_000)
        let attosCompononentNanos = components.attoseconds / 1_000_000_000
        let combinedNanos = secondsComponentNanos.partialValue.addingReportingOverflow(attosCompononentNanos)

        guard
            !secondsComponentNanos.overflow,
            !combinedNanos.overflow
        else {
            return .max
        }

        return combinedNanos.partialValue
    }
}
