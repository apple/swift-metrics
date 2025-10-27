//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import Foundation
import MetricsTestKit
import Testing

@testable import CoreMetrics

struct SendableTest {
    @Test func sendableMetrics() async throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()

        do {
            let name = "counter-\(UUID().uuidString)"
            let value = Int.random(in: 0...1000)
            let counter = Counter(label: name, factory: metrics)

            let task = Task.detached { () -> [Int64] in
                counter.increment(by: value)
                let handler = try metrics.expectCounter(counter)
                return handler.values
            }
            let values = try await task.value
            #expect(values.count == 1, "expected number of entries to match")
            #expect(values[0] == Int64(value), "expected value to match")
        }

        do {
            let name = "floating-point-counter-\(UUID().uuidString)"
            let value = Double.random(in: 0...0.9999)
            let counter = FloatingPointCounter(label: name, factory: metrics)

            let task = Task.detached { () -> Double in
                counter.increment(by: value)
                let handler = counter._handler as! AccumulatingRoundingFloatingPointCounter
                return handler.fraction
            }
            let fraction = await task.value
            #expect(fraction == value)
        }

        do {
            let name = "recorder-\(UUID().uuidString)"
            let value = Double.random(in: -1000...1000)
            let recorder = Recorder(label: name, factory: metrics)

            let task = Task.detached { () -> [Double] in
                recorder.record(value)
                let handler = try metrics.expectRecorder(recorder)
                return handler.values
            }
            let values = try await task.value
            #expect(values.count == 1, "expected number of entries to match")
            #expect(values[0] == value, "expected value to match")
        }

        do {
            let name = "meter-\(UUID().uuidString)"
            let value = Double.random(in: -1000...1000)
            let meter = Meter(label: name, factory: metrics)

            let task = Task.detached { () -> [Double] in
                meter.set(value)
                let handler = try metrics.expectMeter(meter)
                return handler.values
            }
            let values = try await task.value
            #expect(values.count == 1, "expected number of entries to match")
            #expect(values[0] == value, "expected value to match")
        }

        do {
            let name = "timer-\(UUID().uuidString)"
            let value = Int64.random(in: 0...1000)
            let timer = Timer(label: name, factory: metrics)

            let task = Task.detached { () -> [Int64] in
                timer.recordNanoseconds(value)
                let handler = try metrics.expectTimer(timer)
                return handler.values
            }
            let values = try await task.value
            #expect(values.count == 1, "expected number of entries to match")
            #expect(values[0] == value, "expected value to match")
        }
    }
}
