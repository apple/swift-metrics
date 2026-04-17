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

import MetricsTestKit
import Testing

@testable import CoreMetrics
@testable import Metrics

struct TaskLocalMetricsFactoryTests {
    // MARK: - Counter

    @Test func counterUsesTaskLocalFactory() throws {
        let taskLocalMetrics = TestMetrics()
        let counter = withMetricsFactory(taskLocalMetrics) {
            Counter(label: "test.counter")
        }
        counter.increment(by: 42)

        let testCounter = try taskLocalMetrics.expectCounter("test.counter")
        #expect(testCounter.values == [42])
    }

    // MARK: - FloatingPointCounter

    @Test func floatingPointCounterUsesTaskLocalFactory() throws {
        let taskLocalMetrics = TestMetrics()
        let counter = withMetricsFactory(taskLocalMetrics) {
            FloatingPointCounter(label: "test.float_counter")
        }
        counter.increment(by: 3.14)

        let testCounter = try taskLocalMetrics.expectCounter("test.float_counter")
        #expect(testCounter.values.count == 1)
    }

    // MARK: - Gauge

    @Test func gaugeUsesTaskLocalFactory() throws {
        let taskLocalMetrics = TestMetrics()
        let gauge = withMetricsFactory(taskLocalMetrics) {
            Gauge(label: "test.gauge")
        }
        gauge.record(99.5)

        let testRecorder = try taskLocalMetrics.expectRecorder("test.gauge")
        #expect(testRecorder.lastValue == 99.5)
    }

    // MARK: - Meter

    @Test func meterUsesTaskLocalFactory() throws {
        let taskLocalMetrics = TestMetrics()
        let meter = withMetricsFactory(taskLocalMetrics) {
            Meter(label: "test.meter")
        }
        meter.set(42.0)

        let testMeter = try taskLocalMetrics.expectMeter("test.meter")
        #expect(testMeter.values == [42.0])
    }

    // MARK: - Recorder

    @Test func recorderUsesTaskLocalFactory() throws {
        let taskLocalMetrics = TestMetrics()
        let recorder = withMetricsFactory(taskLocalMetrics) {
            Recorder(label: "test.recorder")
        }
        recorder.record(100)

        let testRecorder = try taskLocalMetrics.expectRecorder("test.recorder")
        #expect(testRecorder.values.count == 1)
    }

    // MARK: - Timer

    @Test func timerUsesTaskLocalFactory() throws {
        let taskLocalMetrics = TestMetrics()
        let timer = withMetricsFactory(taskLocalMetrics) {
            Timer(label: "test.timer")
        }
        timer.recordNanoseconds(1_000_000)

        let testTimer = try taskLocalMetrics.expectTimer("test.timer")
        #expect(testTimer.values == [1_000_000])
    }

    // MARK: - Factory selection priority

    @Test func explicitFactoryTakesPriorityOverTaskLocal() throws {
        let taskLocalMetrics = TestMetrics()
        let explicitMetrics = TestMetrics()

        let counter = withMetricsFactory(taskLocalMetrics) {
            Counter(label: "test.priority", factory: explicitMetrics)
        }
        counter.increment()

        let testCounter = try explicitMetrics.expectCounter("test.priority")
        #expect(testCounter.values == [1])
    }

    // MARK: - Scoping

    @Test func factoryIsNotVisibleOutsideScope() {
        let taskLocalMetrics = TestMetrics()

        withMetricsFactory(taskLocalMetrics) {
            #expect(MetricsSystem.factory as AnyObject === taskLocalMetrics)
        }

        // Outside the scope, the current factory should no longer be the task-local one
        #expect(MetricsSystem.factory as AnyObject !== taskLocalMetrics)
    }

    @Test func nestedFactoriesUseInnermostScope() throws {
        let outerMetrics = TestMetrics()
        let innerMetrics = TestMetrics()

        withMetricsFactory(outerMetrics) {
            let outerCounter = Counter(label: "test.outer")
            outerCounter.increment()

            withMetricsFactory(innerMetrics) {
                let innerCounter = Counter(label: "test.inner")
                innerCounter.increment()
            }
        }

        let outerCounter = try outerMetrics.expectCounter("test.outer")
        #expect(outerCounter.values == [1])

        let innerCounter = try innerMetrics.expectCounter("test.inner")
        #expect(innerCounter.values == [1])
    }

    // MARK: - Async

    @Test func asyncWithMetricsFactory() async throws {
        let taskLocalMetrics = TestMetrics()
        await withMetricsFactory(taskLocalMetrics) {
            let counter = Counter(label: "test.async_counter")
            counter.increment(by: 5)
            // Perform an async operation so the async overload is used
            await Task.yield()
        }

        let testCounter = try taskLocalMetrics.expectCounter("test.async_counter")
        #expect(testCounter.values == [5])
    }

    // MARK: - Parallel tests with isolated factories

    @Test func parallelTestsWithIsolatedFactories() async throws {
        let factory1 = TestMetrics()
        let factory2 = TestMetrics()

        async let result1: Void = withMetricsFactory(factory1) {
            let counter = Counter(label: "test.parallel")
            counter.increment(by: 10)
            await Task.yield()
        }

        async let result2: Void = withMetricsFactory(factory2) {
            let counter = Counter(label: "test.parallel")
            counter.increment(by: 20)
            await Task.yield()
        }

        _ = await (result1, result2)

        let counter1 = try factory1.expectCounter("test.parallel")
        #expect(counter1.values == [10])

        let counter2 = try factory2.expectCounter("test.parallel")
        #expect(counter2.values == [20])
    }

    // MARK: - Error propagation

    @Test func syncWithMetricsFactoryPropagatesErrors() {
        let taskLocalMetrics = TestMetrics()

        struct TestError: Error {}

        #expect(throws: TestError.self) {
            try withMetricsFactory(taskLocalMetrics) {
                throw TestError()
            }
        }
    }

    @Test func asyncWithMetricsFactoryPropagatesErrors() async {
        let taskLocalMetrics = TestMetrics()

        struct TestError: Error {}

        await #expect(throws: TestError.self) {
            try await withMetricsFactory(taskLocalMetrics) {
                await Task.yield()
                throw TestError()
            }
        }
    }
}
