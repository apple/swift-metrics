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
import MetricsTestKit
import Testing

struct TestMetricsDescriptionTests {
    @Test func emptyMetricsDescribesAsEmpty() {
        #expect(TestMetrics().description == "TestMetrics(empty)")
    }

    @Test func counterDescriptionShowsValuesAndTotal() throws {
        let metrics = TestMetrics()
        let counter = metrics.makeCounter(label: "requests", dimensions: [("method", "GET")])
        counter.increment(by: 10)
        counter.increment(by: 5)

        let testCounter = try metrics.expectCounter("requests", [("method", "GET")])
        #expect(
            testCounter.description
                == #"TestCounter(requests, dimensions: [("method", "GET")], values: [10, 5], total: 15)"#
        )
    }

    @Test func meterDescriptionShowsValues() throws {
        let metrics = TestMetrics()
        let meter = metrics.makeMeter(label: "queue.depth", dimensions: [])
        meter.set(3.0)
        meter.set(7.0)

        let testMeter = try metrics.expectMeter("queue.depth", [])
        #expect(testMeter.description == "TestMeter(queue.depth, dimensions: [], values: [3.0, 7.0])")
    }

    @Test func recorderDescriptionShowsAggregateAndValues() throws {
        let metrics = TestMetrics()
        let recorder = metrics.makeRecorder(label: "response.size", dimensions: [], aggregate: true)
        recorder.record(1024.0)

        let testRecorder = try metrics.expectRecorder("response.size", [])
        #expect(
            testRecorder.description
                == "TestRecorder(response.size, dimensions: [], aggregate: true, values: [1024.0])"
        )
    }

    @Test func timerDescriptionShowsRawNanosecondsIgnoringDisplayUnit() throws {
        let metrics = TestMetrics()
        let timer = metrics.makeTimer(label: "latency", dimensions: [])
        timer.recordNanoseconds(1_000_000)

        let testTimer = try metrics.expectTimer("latency", [])
        // A preferred display unit must not change the printed (stored) nanosecond values.
        testTimer.preferDisplayUnit(.milliseconds)
        #expect(testTimer.description == "TestTimer(latency, dimensions: [], unit: nanoseconds, values: [1000000])")
    }

    @Test func metricsDescriptionGroupsAndSortsDeterministically() throws {
        let metrics = TestMetrics()
        metrics.makeCounter(label: "zebra", dimensions: []).increment(by: 1)
        metrics.makeCounter(label: "alpha", dimensions: []).increment(by: 2)
        metrics.makeTimer(label: "latency", dimensions: []).recordNanoseconds(42)

        let description = metrics.description

        // The output is identical across calls — no dependence on dictionary iteration order.
        #expect(description == metrics.description)

        // Groups are ordered: counters before timers.
        let countersHeader = try #require(description.range(of: "Counters:"))
        let timersHeader = try #require(description.range(of: "Timers:"))
        #expect(countersHeader.lowerBound < timersHeader.lowerBound)

        // Within the counters group, instruments sort by label: "alpha" before "zebra".
        let alpha = try #require(description.range(of: "alpha"))
        let zebra = try #require(description.range(of: "zebra"))
        #expect(alpha.lowerBound < zebra.lowerBound)
    }

    @Test func metricsDescriptionSortsByDimensionsWhenLabelsMatch() throws {
        let metrics = TestMetrics()
        metrics.makeCounter(label: "http", dimensions: [("status", "500")]).increment(by: 1)
        metrics.makeCounter(label: "http", dimensions: [("status", "200")]).increment(by: 1)

        let description = metrics.description

        // Same label, so the dimensions break the tie: "status=200" sorts before "status=500".
        let status200 = try #require(description.range(of: "200"))
        let status500 = try #require(description.range(of: "500"))
        #expect(status200.lowerBound < status500.lowerBound)
    }
}
