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

import MetricsTestKit
import XCTest

@testable import CoreMetrics

class MetricsTests: XCTestCase {
    func testCounters() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
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
        XCTAssertEqual(testCounter.values.count, total, "expected number of entries to match")
        testCounter.reset()
        XCTAssertEqual(testCounter.values.count, 0, "expected number of entries to match")
    }

    func testCounterBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "counter-\(UUID().uuidString)"
        let value = Int.random(in: Int.min...Int.max)
        Counter(label: name).increment(by: value)
        let counter = try metrics.expectCounter(name)
        XCTAssertEqual(counter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(counter.values[0], Int64(value), "expected value to match")
        counter.reset()
        XCTAssertEqual(counter.values.count, 0, "expected number of entries to match")
    }

    func testDefaultFloatingPointCounter_ignoresNan() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: Double.nan)
        fpCounter.increment(by: Double.signalingNaN)
        XCTAssertEqual(counter.values.count, 0, "expected nan values to be ignored")
    }

    func testDefaultFloatingPointCounter_ignoresInfinity() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: Double.infinity)
        fpCounter.increment(by: -Double.infinity)
        XCTAssertEqual(counter.values.count, 0, "expected infinite values to be ignored")
    }

    func testDefaultFloatingPointCounter_ignoresNegativeValues() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: -100)
        XCTAssertEqual(counter.values.count, 0, "expected negative values to be ignored")
    }

    func testDefaultFloatingPointCounter_ignoresZero() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: 0)
        fpCounter.increment(by: -0)
        XCTAssertEqual(counter.values.count, 0, "expected zero values to be ignored")
    }

    func testDefaultFloatingPointCounter_ceilsExtremeValues() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label)
        let counter = try metrics.expectCounter(label)
        // Just larger than Int64
        fpCounter.increment(by: Double(sign: .plus, exponent: 63, significand: 1))
        // Much larger than Int64
        fpCounter.increment(by: Double.greatestFiniteMagnitude)
        let values = counter.values
        XCTAssertEqual(values.count, 2, "expected number of entries to match")
        XCTAssertEqual(values, [Int64.max, Int64.max], "expected extremely large values to be replaced with Int64.max")
    }

    func testDefaultFloatingPointCounter_accumulatesFloatingPointDecimalValues() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label)
        let rawFpCounter = fpCounter._handler as! AccumulatingRoundingFloatingPointCounter
        let counter = try metrics.expectCounter(label)

        // Increment by a small value (perfectly representable)
        fpCounter.increment(by: 0.75)
        XCTAssertEqual(counter.values.count, 0, "expected number of entries to match")

        // Increment by a small value that should grow the accumulated buffer past 1.0 (perfectly representable)
        fpCounter.increment(by: 1.5)
        var values = counter.values
        XCTAssertEqual(values.count, 1, "expected number of entries to match")
        XCTAssertEqual(values, [2], "expected entries to match")
        XCTAssertEqual(rawFpCounter.fraction, 0.25, "")

        // Increment by a large value that should leave a fraction in the accumulator
        // 1110506744053.76
        fpCounter.increment(by: Double(sign: .plus, exponent: 40, significand: 1.01))
        values = counter.values
        XCTAssertEqual(values.count, 2, "expected number of entries to match")
        XCTAssertEqual(values, [2, 1_110_506_744_054], "expected entries to match")
        XCTAssertEqual(rawFpCounter.fraction, 0.010009765625, "expected fractional accumulated value")
    }

    func testRecorders() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
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
        XCTAssertEqual(testRecorder.values.count, total, "expected number of entries to match")
    }

    func testRecordersInt() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let recorder = Recorder(label: "test-recorder")
        let testRecorder = try metrics.expectRecorder(recorder)
        let values = (0...999).map { _ in Int32.random(in: Int32.min...Int32.max) }
        for i in 0..<values.count {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, testRecorder.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            XCTAssertEqual(Int32(testRecorder.values[i]), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecordersFloat() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let recorder = Recorder(label: "test-recorder")
        let testRecorder = try metrics.expectRecorder(recorder)
        let values = (0...999).map { _ in Float.random(in: Float(Int32.min)...Float(Int32.max)) }
        for i in 0..<values.count {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, testRecorder.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            XCTAssertEqual(Float(testRecorder.values[i]), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecorderBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "recorder-\(UUID().uuidString)"
        let value = Double.random(in: Double(Int.min)...Double(Int.max))
        Recorder(label: name).record(value)
        let recorder = try metrics.expectRecorder(name)
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.lastValue, value, "expected value to match")
    }

    func testTimers() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
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
        XCTAssertEqual(testTimer.values.count, total, "expected number of entries to match")
    }

    func testTimerBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "timer-\(UUID().uuidString)"
        let value = Int64.random(in: Int64.min...Int64.max)
        Timer(label: name).recordNanoseconds(value)
        let timer = try metrics.expectTimer(name)
        XCTAssertEqual(timer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(timer.values[0], value, "expected value to match")
    }

    func testTimerVariants() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer")
        let testTimer = try metrics.expectTimer(timer)
        // nano
        let nano = Int64.random(in: 0...5)
        timer.recordNanoseconds(nano)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0], nano, "expected value to match")
        // micro
        let micro = Int64.random(in: 0...5)
        timer.recordMicroseconds(micro)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1], micro * 1000, "expected value to match")
        // milli
        let milli = Int64.random(in: 0...5)
        timer.recordMilliseconds(milli)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2], milli * 1_000_000, "expected value to match")
        // seconds
        let sec = Int64.random(in: 0...5)
        timer.recordSeconds(sec)
        XCTAssertEqual(testTimer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3], sec * 1_000_000_000, "expected value to match")
    }

    func testTimerOverflow() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer")
        let testTimer = try metrics.expectTimer(timer)
        // nano (integer)
        timer.recordNanoseconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0], Int64.max, "expected value to match")
        // micro (integer)
        timer.recordMicroseconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1], Int64.max, "expected value to match")
        // micro (double)
        timer.recordMicroseconds(Double(Int64.max) + 1)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1], Int64.max, "expected value to match")
        // milli (integer)
        timer.recordMilliseconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2], Int64.max, "expected value to match")
        // milli (double)
        timer.recordMilliseconds(Double(Int64.max) + 1)
        XCTAssertEqual(testTimer.values.count, 5, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2], Int64.max, "expected value to match")
        // seconds (integer)
        timer.recordSeconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 6, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3], Int64.max, "expected value to match")
        // seconds (double)
        timer.recordSeconds(Double(Int64.max) * 1)
        XCTAssertEqual(testTimer.values.count, 7, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3], Int64.max, "expected value to match")
    }

    func testTimerHandlesUnsignedOverflow() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer")
        let testTimer = try metrics.expectTimer(timer)
        // nano
        timer.recordNanoseconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0], Int64.max, "expected value to match")
        // micro
        timer.recordMicroseconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1], Int64.max, "expected value to match")
        // milli
        timer.recordMilliseconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2], Int64.max, "expected value to match")
        // seconds
        timer.recordSeconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3], Int64.max, "expected value to match")
    }

    func testGauge() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        let gauge = Gauge(label: name)
        gauge.record(value)
        let recorder = try metrics.expectRecorder(gauge)
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.lastValue, value, "expected value to match")
    }

    func testGaugeBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        Gauge(label: name).record(value)
        let recorder = try metrics.expectRecorder(name)
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.lastValue, value, "expected value to match")
    }

    func testMeter() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        let meter = Meter(label: name)
        meter.set(value)
        let testMeter = try metrics.expectMeter(meter)
        XCTAssertEqual(testMeter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeter.values[0], value, "expected value to match")
    }

    func testMeterBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        Meter(label: name).set(value)
        let testMeter = try metrics.expectMeter(name)
        XCTAssertEqual(testMeter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeter.values[0], value, "expected value to match")
    }

    func testMeterInt() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)
        let values = (0...999).map { _ in Int32.random(in: Int32.min...Int32.max) }
        for i in 0..<values.count {
            meter.set(values[i])
        }
        XCTAssertEqual(values.count, testMeter.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            XCTAssertEqual(Int32(testMeter.values[i]), values[i], "expected value #\(i) to match.")
        }
    }

    func testMeterFloat() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)
        let values = (0...999).map { _ in Float.random(in: Float(Int32.min)...Float(Int32.max)) }
        for i in 0..<values.count {
            meter.set(values[i])
        }
        XCTAssertEqual(values.count, testMeter.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            XCTAssertEqual(Float(testMeter.values[i]), values[i], "expected value #\(i) to match.")
        }
    }

    func testMeterIncrement() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let group = DispatchGroup()
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)
        let values = (500...1000).map { _ in Double.random(in: 0...Double(Int32.max)) }
        for i in 0..<values.count {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                defer { group.leave() }
                meter.increment(by: values[i])
            }
        }
        group.wait()
        XCTAssertEqual(testMeter.values.count, values.count, "expected number of entries to match")
        XCTAssertEqual(testMeter.values.last!, values.reduce(0.0, +), accuracy: 0.1, "expected total value to match")
    }

    func testMeterDecrement() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let group = DispatchGroup()
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)

        let values = (500...1000).map { _ in Double.random(in: 0...Double(Int32.max)) }
        for i in 0..<values.count {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                defer { group.leave() }
                meter.decrement(by: values[i])
            }
        }
        group.wait()
        XCTAssertEqual(testMeter.values.count, values.count, "expected number of entries to match")
        XCTAssertEqual(testMeter.values.last!, values.reduce(0.0, -), accuracy: 0.1, "expected total value to match")
    }

    func testDefaultMeterIgnoresNan() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: Double.nan)
        meter.increment(by: Double.signalingNaN)
        XCTAssertEqual(testMeter.values.count, 0, "expected nan values to be ignored")
    }

    func testDefaultMeterIgnoresInfinity() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: Double.infinity)
        meter.increment(by: -Double.infinity)
        XCTAssertEqual(testMeter.values.count, 0, "expected infinite values to be ignored")
    }

    func testDefaultMeterIgnoresNegativeValues() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: -100)
        XCTAssertEqual(testMeter.values.count, 0, "expected negative values to be ignored")
    }

    func testDefaultMeterIgnoresZero() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: 0)
        meter.increment(by: -0)
        XCTAssertEqual(testMeter.values.count, 0, "expected zero values to be ignored")
    }

    func testMUX_Counter() throws {
        // bootstrap with our test metrics
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        MetricsSystem.bootstrapInternal(MultiplexMetricsHandler(factories: factories))
        // run the test
        let name = UUID().uuidString
        let value = Int.random(in: Int.min...Int.max)
        let muxCounter = Counter(label: name)
        muxCounter.increment(by: value)
        for factory in factories {
            let counter = factory.counters.first
            XCTAssertEqual(counter?.label, name, "expected label to match")
            XCTAssertEqual(counter?.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(counter?.lastValue, Int64(value), "expected value to match")
        }
        muxCounter.reset()
        for factory in factories {
            let counter = factory.counters.first
            XCTAssertEqual(counter?.values.count, 0, "expected number of entries to match")
        }
    }

    func testMUX_Meter() throws {
        // bootstrap with our test metrics
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        MetricsSystem.bootstrapInternal(MultiplexMetricsHandler(factories: factories))
        // run the test
        let name = UUID().uuidString
        let value = Double.random(in: 0...1)
        let muxMeter = Meter(label: name)
        muxMeter.set(value)
        for factory in factories {
            let meter = factory.meters.first
            XCTAssertEqual(meter?.label, name, "expected label to match")
            XCTAssertEqual(meter?.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(meter?.values[0], value, "expected value to match")
        }
    }

    func testMUX_Recorder() throws {
        // bootstrap with our test metrics
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        MetricsSystem.bootstrapInternal(MultiplexMetricsHandler(factories: factories))
        // run the test
        let name = UUID().uuidString
        let value = Double.random(in: 0...1)
        let muxRecorder = Recorder(label: name)
        muxRecorder.record(value)
        for factory in factories {
            let recorder = factory.recorders.first
            XCTAssertEqual(recorder?.label, name, "expected label to match")
            XCTAssertEqual(recorder?.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(recorder?.values[0], value, "expected value to match")
        }
    }

    func testMUX_Timer() throws {
        // bootstrap with our test metrics
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        MetricsSystem.bootstrapInternal(MultiplexMetricsHandler(factories: factories))
        // run the test
        let name = UUID().uuidString
        let seconds = Int.random(in: 1...10)
        let muxTimer = Timer(label: name, preferredDisplayUnit: .minutes)
        muxTimer.recordSeconds(seconds)
        for factory in factories {
            let timer = factory.timers.first
            XCTAssertEqual(timer?.label, name, "expected label to match")
            XCTAssertEqual(timer?.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(timer?.values[0], Int64(seconds * 1_000_000_000), "expected value to match")
            XCTAssertEqual(timer?.displayUnit, .minutes, "expected value to match")
            XCTAssertEqual(
                timer?.valueInPreferredUnit(atIndex: 0),
                Double(seconds) / 60.0,
                "seconds should be returned as minutes"
            )
        }
    }

    func testCustomHandler() {
        final class CustomHandler: CounterHandler {
            func increment<DataType>(by: DataType) where DataType: BinaryInteger {}
            func reset() {}
        }

        let counter1 = Counter(label: "foo")
        XCTAssertFalse(counter1._handler is CustomHandler, "expected non-custom log handler")
        let counter2 = Counter(label: "foo", dimensions: [], handler: CustomHandler())
        XCTAssertTrue(counter2._handler is CustomHandler, "expected custom log handler")
    }

    func testCustomFactory() {
        // @unchecked Sendable is okay here - locking is done manually.
        final class CustomFactory: MetricsFactory, @unchecked Sendable {

            init(handler: CustomHandler) {
                self.handler = handler
            }

            final class CustomHandler: CounterHandler {
                func increment<DataType>(by: DataType) where DataType: BinaryInteger {}
                func reset() {}
            }
            private let handler: CustomHandler
            private let lock: NSLock = NSLock()
            private var locked_didCallDestroyCounter: Bool = false
            var didCallDestroyCounter: Bool {
                self.lock.lock()
                defer {
                    lock.unlock()
                }
                return self.locked_didCallDestroyCounter
            }

            func makeCounter(label: String, dimensions: [(String, String)]) -> any CoreMetrics.CounterHandler {
                handler
            }

            func makeRecorder(
                label: String,
                dimensions: [(String, String)],
                aggregate: Bool
            ) -> any CoreMetrics.RecorderHandler {
                fatalError("Unsupported")
            }

            func makeTimer(label: String, dimensions: [(String, String)]) -> any CoreMetrics.TimerHandler {
                fatalError("Unsupported")
            }

            func destroyCounter(_ handler: any CoreMetrics.CounterHandler) {
                XCTAssertTrue(
                    handler === self.handler,
                    "The handler to be destroyed doesn't match the expected handler."
                )
                self.lock.lock()
                defer {
                    lock.unlock()
                }
                self.locked_didCallDestroyCounter = true
            }

            func destroyRecorder(_ handler: any CoreMetrics.RecorderHandler) {
                fatalError("Unsupported")
            }

            func destroyTimer(_ handler: any CoreMetrics.TimerHandler) {
                fatalError("Unsupported")
            }
        }

        let handler = CustomFactory.CustomHandler()
        let factory = CustomFactory(handler: handler)

        XCTAssertFalse(factory.didCallDestroyCounter)
        do {
            let counter1 = Counter(label: "foo", factory: factory)
            XCTAssertTrue(counter1._handler is CustomFactory.CustomHandler, "expected a custom metrics handler")
            XCTAssertTrue(counter1._factory is CustomFactory, "expected a custom metrics factory")
            counter1.destroy()
        }
        XCTAssertTrue(factory.didCallDestroyCounter)
    }

    func testDestroyingGauge() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)

        let gauge = Gauge(label: name)
        gauge.record(value)

        let recorder = try metrics.expectRecorder(gauge)
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values.first, value, "expected value to match")
        XCTAssertEqual(metrics.recorders.count, 1, "recorder should have been stored")

        let identity = ObjectIdentifier(recorder)
        gauge.destroy()
        XCTAssertEqual(metrics.recorders.count, 0, "recorder should have been released")

        let gaugeAgain = Gauge(label: name)
        gaugeAgain.record(-value)

        let recorderAgain = try metrics.expectRecorder(gaugeAgain)
        XCTAssertEqual(recorderAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorderAgain.values.first, -value, "expected value to match")

        let identityAgain = ObjectIdentifier(recorderAgain)
        XCTAssertNotEqual(
            identity,
            identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    func testDestroyingMeter() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "meter-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)

        let meter = Meter(label: name)
        meter.set(value)

        let testMeter = try metrics.expectMeter(meter)
        XCTAssertEqual(testMeter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeter.values.first, value, "expected value to match")
        XCTAssertEqual(metrics.meters.count, 1, "recorder should have been stored")

        let identity = ObjectIdentifier(testMeter)
        meter.destroy()
        XCTAssertEqual(metrics.recorders.count, 0, "recorder should have been released")

        let meterAgain = Meter(label: name)
        meterAgain.set(-value)

        let testMeterAgain = try metrics.expectMeter(meterAgain)
        XCTAssertEqual(testMeterAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeterAgain.values.first, -value, "expected value to match")

        let identityAgain = ObjectIdentifier(testMeterAgain)
        XCTAssertNotEqual(
            identity,
            identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    func testDestroyingCounter() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "counter-\(UUID().uuidString)"
        let value = Int.random(in: 0...1000)

        let counter = Counter(label: name)
        counter.increment(by: value)

        let testCounter = try metrics.expectCounter(counter)
        XCTAssertEqual(testCounter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testCounter.values.first, Int64(value), "expected value to match")
        XCTAssertEqual(metrics.counters.count, 1, "counter should have been stored")

        let identity = ObjectIdentifier(counter)
        counter.destroy()
        XCTAssertEqual(metrics.counters.count, 0, "counter should have been released")

        let counterAgain = Counter(label: name)
        counterAgain.increment(by: value)

        let testCounterAgain = try metrics.expectCounter(counterAgain)
        XCTAssertEqual(testCounterAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testCounterAgain.values.first, Int64(value), "expected value to match")

        let identityAgain = ObjectIdentifier(counterAgain)
        XCTAssertNotEqual(
            identity,
            identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    func testDestroyingTimer() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "timer-\(UUID().uuidString)"
        let value = Int64.random(in: 0...1000)

        let timer = Timer(label: name)
        timer.recordNanoseconds(value)

        let testTimer = try metrics.expectTimer(timer)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values.first, value, "expected value to match")
        XCTAssertEqual(metrics.timers.count, 1, "timer should have been stored")

        let identity = ObjectIdentifier(timer)
        timer.destroy()
        XCTAssertEqual(metrics.timers.count, 0, "timer should have been released")

        let timerAgain = Timer(label: name)
        timerAgain.recordNanoseconds(value)
        let testTimerAgain = try metrics.expectTimer(timerAgain)
        XCTAssertEqual(testTimerAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimerAgain.values.first, value, "expected value to match")

        let identityAgain = ObjectIdentifier(timerAgain)
        XCTAssertNotEqual(
            identity,
            identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    func testDescriptions() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let counter = Counter(label: "hello.counter")
        XCTAssertEqual("\(counter)", "Counter(hello.counter, dimensions: [])")

        let gauge = Gauge(label: "hello.gauge")
        XCTAssertEqual("\(gauge)", "Gauge(hello.gauge, dimensions: [], aggregate: false)")

        let meter = Meter(label: "hello.meter")
        XCTAssertEqual("\(meter)", "Meter(hello.meter, dimensions: [])")

        let timer = Timer(label: "hello.timer")
        XCTAssertEqual("\(timer)", "Timer(hello.timer, dimensions: [])")

        let recorder = Recorder(label: "hello.recorder")
        XCTAssertEqual("\(recorder)", "Recorder(hello.recorder, dimensions: [], aggregate: true)")
    }
}
