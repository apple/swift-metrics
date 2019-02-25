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

@testable import Metrics
import XCTest

class MetricsExtensionsTests: XCTestCase {
    func testTimerBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let name = "timer-\(NSUUID().uuidString)"
        let delay = 0.05
        Metrics.global.timed(label: name) {
            Thread.sleep(forTimeInterval: delay)
        }
        let timer = metrics.timers[name] as! TestTimer
        XCTAssertEqual(1, timer.values.count, "expected number of entries to match")
        XCTAssertGreaterThan(timer.values[0].1, Int64(delay * 1_000_000_000), "expected delay to match")
    }

    func testTimerWithTimeInterval() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let timer = Metrics.global.makeTimer(label: "test-timer") as! TestTimer
        let timeInterval = TimeInterval(Double.random(in: 1 ... 500))
        timer.record(timeInterval)
        XCTAssertEqual(1, timer.values.count, "expected number of entries to match")
        XCTAssertEqual(timer.values[0].1, Int64(timeInterval * 1_000_000_000), "expected value to match")
    }

    func testTimerWithDispatchTime() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let timer = Metrics.global.makeTimer(label: "test-timer") as! TestTimer
        // nano
        let nano = DispatchTimeInterval.nanoseconds(Int.random(in: 1 ... 500))
        timer.record(nano)
        XCTAssertEqual(timer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(.nanoseconds(Int(timer.values[0].1)), nano, "expected value to match")
        // micro
        let micro = DispatchTimeInterval.microseconds(Int.random(in: 1 ... 500))
        timer.record(micro)
        XCTAssertEqual(timer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(.nanoseconds(Int(timer.values[1].1)), micro, "expected value to match")
        // milli
        let milli = DispatchTimeInterval.milliseconds(Int.random(in: 1 ... 500))
        timer.record(milli)
        XCTAssertEqual(timer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(.nanoseconds(Int(timer.values[2].1)), milli, "expected value to match")
        // seconds
        let sec = DispatchTimeInterval.seconds(Int.random(in: 1 ... 500))
        timer.record(sec)
        XCTAssertEqual(timer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(.nanoseconds(Int(timer.values[3].1)), sec, "expected value to match")
        // never
        timer.record(DispatchTimeInterval.never)
        XCTAssertEqual(timer.values.count, 5, "expected number of entries to match")
        XCTAssertEqual(timer.values[4].1, 0, "expected value to match")
    }
}
