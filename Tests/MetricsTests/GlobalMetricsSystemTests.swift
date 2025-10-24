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

struct GlobalMetricsSystemTests {
    let metrics = TestMetrics()

    init() async throws {
        // bootstrap global system with our test metrics
        MetricsSystem.bootstrapInternal(self.metrics)
    }

    @Test func counters() throws {
        let group = DispatchGroup()
        let name = "counter-\(UUID().uuidString)"
        let counter = Counter(label: name)
        let testCounter = try metrics.expectCounter(counter)
        let total = Int.random(in: 500...1000)
        for _ in 0..<total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                defer { group.leave() }
                counter.increment(by: Int.random(in: 0...1000))
            }
        }
        group.wait()
        #expect(testCounter.values.count == total, "expected number of entries to match")
        testCounter.reset()
        #expect(testCounter.values.count == 0, "expected number of entries to match")
    }

    @Test func recorders() throws {
        let group = DispatchGroup()
        let name = "recorder-\(UUID().uuidString)"
        let recorder = Recorder(label: name)
        let testRecorder = try metrics.expectRecorder(recorder)
        let total = Int.random(in: 500...1000)
        for _ in 0..<total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                defer { group.leave() }
                recorder.record(Int.random(in: Int.min...Int.max))
            }
        }
        group.wait()
        #expect(testRecorder.values.count == total, "expected number of entries to match")
    }

    @Test func timers() throws {
        let group = DispatchGroup()
        let name = "timer-\(UUID().uuidString)"
        let timer = Timer(label: name)
        let testTimer = try metrics.expectTimer(timer)
        let total = Int.random(in: 500...1000)
        for _ in 0..<total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                defer { group.leave() }
                timer.recordNanoseconds(Int64.random(in: Int64.min...Int64.max))
            }
        }
        group.wait()
        #expect(testTimer.values.count == total, "expected number of entries to match")
    }

    @Test func gauge() throws {
        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        let gauge = Gauge(label: name)
        gauge.record(value)
        let recorder = try metrics.expectRecorder(gauge)
        #expect(recorder.values.count == 1, "expected number of entries to match")
        #expect(recorder.lastValue == value, "expected value to match")
    }

    @Test func meter() throws {
        let name = "meter-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        let meter = Meter(label: name)
        meter.set(value)
        let testMeter = try metrics.expectMeter(meter)
        #expect(testMeter.values.count == 1, "expected number of entries to match")
        #expect(testMeter.values[0] == value, "expected value to match")
    }
}
