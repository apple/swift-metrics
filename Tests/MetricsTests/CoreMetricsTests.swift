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
import MetricsTestKit
import XCTest

class MetricsTests: XCTestCase {
    func testCounters() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let group = DispatchGroup()
        let name = "counter-\(UUID().uuidString)"
        let counter = Counter(label: name)
        let testCounter = counter._handler as! TestCounter
        let total = Int.random(in: 500 ... 1000)
        for _ in 0 ... total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                counter.increment(by: Int.random(in: 0 ... 1000))
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(testCounter.values.count - 1, total, "expected number of entries to match")
        testCounter.reset()
        XCTAssertEqual(testCounter.values.count, 0, "expected number of entries to match")
    }

    func testCounterBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "counter-\(UUID().uuidString)"
        let value = Int.random(in: Int.min ... Int.max)
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
        let testRecorder = recorder._handler as! TestRecorder
        let total = Int.random(in: 500 ... 1000)
        for _ in 0 ... total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                recorder.record(Int.random(in: Int.min ... Int.max))
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(testRecorder.values.count - 1, total, "expected number of entries to match")
    }

    func testRecordersInt() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let recorder = Recorder(label: "test-recorder")
        let testRecorder = recorder._handler as! TestRecorder
        let values = (0 ... 999).map { _ in Int32.random(in: Int32.min ... Int32.max) }
        for i in 0 ... values.count - 1 {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, testRecorder.values.count, "expected number of entries to match")
        for i in 0 ... values.count - 1 {
            XCTAssertEqual(Int32(testRecorder.values[i]), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecordersFloat() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let recorder = Recorder(label: "test-recorder")
        let testRecorder = recorder._handler as! TestRecorder
        let values = (0 ... 999).map { _ in Float.random(in: Float(Int32.min) ... Float(Int32.max)) }
        for i in 0 ... values.count - 1 {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, testRecorder.values.count, "expected number of entries to match")
        for i in 0 ... values.count - 1 {
            XCTAssertEqual(Float(testRecorder.values[i]), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecorderBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "recorder-\(UUID().uuidString)"
        let value = Double.random(in: Double(Int.min) ... Double(Int.max))
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
        let testTimer = timer._handler as! TestTimer
        let total = Int.random(in: 500 ... 1000)
        for _ in 0 ... total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                timer.recordNanoseconds(Int64.random(in: Int64.min ... Int64.max))
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(testTimer.values.count - 1, total, "expected number of entries to match")
    }

    func testTimerBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "timer-\(UUID().uuidString)"
        let value = Int64.random(in: Int64.min ... Int64.max)
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
        let testTimer = timer._handler as! TestTimer
        // nano
        let nano = Int64.random(in: 0 ... 5)
        timer.recordNanoseconds(nano)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0], nano, "expected value to match")
        // micro
        let micro = Int64.random(in: 0 ... 5)
        timer.recordMicroseconds(micro)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1], micro * 1000, "expected value to match")
        // milli
        let milli = Int64.random(in: 0 ... 5)
        timer.recordMilliseconds(milli)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2], milli * 1_000_000, "expected value to match")
        // seconds
        let sec = Int64.random(in: 0 ... 5)
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
        let testTimer = timer._handler as! TestTimer
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
        let testTimer = timer._handler as! TestTimer
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
        let value = Double.random(in: -1000 ... 1000)
        let gauge = Gauge(label: name)
        gauge.record(value)
        let recorder = gauge._handler as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.lastValue, value, "expected value to match")
    }

    func testGaugeBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)
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
        let name = "meter-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)
        let meter = Meter(label: name)
        meter.set(value)
        let testMeter = meter._handler as! TestMeter
        XCTAssertEqual(testMeter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeter.values[0], value, "expected value to match")
    }

    func testMeterBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "meter-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)
        Meter(label: name).set(value)
        let testMeter = try metrics.expectMeter(name)
        XCTAssertEqual(testMeter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeter.values[0], value, "expected value to match")
    }

    func testMUX_Counter() throws {
        // bootstrap with our test metrics
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        MetricsSystem.bootstrapInternal(MultiplexMetricsHandler(factories: factories))
        // run the test
        let name = UUID().uuidString
        let value = Int.random(in: Int.min ... Int.max)
        let muxCounter = Counter(label: name)
        muxCounter.increment(by: value)
        factories.forEach { factory in
            let counter = factory.counters.first
            XCTAssertEqual(counter?.label, name, "expected label to match")
            XCTAssertEqual(counter?.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(counter?.lastValue, Int64(value), "expected value to match")
        }
        muxCounter.reset()
        factories.forEach { factory in
            let counter = factory.counters.first
            XCTAssertEqual(counter?.values.count, 0, "expected number of entries to match")
        }
    }

    func testMUX_Meter() throws {
        // bootstrap with our test metrics
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        MetricsSystem.bootstrapInternal(MultiplexMetricsHandler(factories: factories))
        // run the test
        let name = NSUUID().uuidString
        let value = Double.random(in: 0 ... 1)
        let muxMeter = Meter(label: name)
        muxMeter.set(value)
        factories.forEach { factory in
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
        let value = Double.random(in: 0 ... 1)
        let muxRecorder = Recorder(label: name)
        muxRecorder.record(value)
        factories.forEach { factory in
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
        let seconds = Int.random(in: 1 ... 10)
        let muxTimer = Timer(label: name, preferredDisplayUnit: .minutes)
        muxTimer.recordSeconds(seconds)
        factories.forEach { factory in
            let timer = factory.timers.first
            XCTAssertEqual(timer?.label, name, "expected label to match")
            XCTAssertEqual(timer?.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(timer?.values[0], Int64(seconds * 1_000_000_000), "expected value to match")
            XCTAssertEqual(timer?.displayUnit, .minutes, "expected value to match")
            XCTAssertEqual(timer?.valueInPreferredUnit(atIndex: 0), Double(seconds) / 60.0, "seconds should be returned as minutes")
        }
    }

    func testCustomFactory() {
        final class CustomHandler: CounterHandler {
            func increment<DataType>(by: DataType) where DataType: BinaryInteger {}
            func reset() {}
        }

        let counter1 = Counter(label: "foo")
        XCTAssertFalse(counter1._handler is CustomHandler, "expected non-custom log handler")
        let counter2 = Counter(label: "foo", dimensions: [], handler: CustomHandler())
        XCTAssertTrue(counter2._handler is CustomHandler, "expected custom log handler")
    }

    func testDestroyingGauge() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)

        let gauge = Gauge(label: name)
        gauge.record(value)

        let recorder = gauge._handler as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values.first, value, "expected value to match")
        XCTAssertEqual(metrics.recorders.count, 1, "recorder should have been stored")

        let identity = ObjectIdentifier(recorder)
        gauge.destroy()
        XCTAssertEqual(metrics.recorders.count, 0, "recorder should have been released")

        let gaugeAgain = Gauge(label: name)
        gaugeAgain.record(-value)

        let recorderAgain = gaugeAgain._handler as! TestRecorder
        XCTAssertEqual(recorderAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorderAgain.values.first, -value, "expected value to match")

        let identityAgain = ObjectIdentifier(recorderAgain)
        XCTAssertNotEqual(identity, identityAgain, "since the cached metric was released, the created a new should have a different identity")
    }

    func testDestroyingMeter() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "meter-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)

        let meter = Meter(label: name)
        meter.set(value)

        let testMeter = meter._handler as! TestMeter
        XCTAssertEqual(testMeter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeter.values.first, value, "expected value to match")
        XCTAssertEqual(metrics.meters.count, 1, "recorder should have been stored")

        let identity = ObjectIdentifier(testMeter)
        meter.destroy()
        XCTAssertEqual(metrics.recorders.count, 0, "recorder should have been released")

        let meterAgain = Meter(label: name)
        meterAgain.set(-value)

        let testMeterAgain = meterAgain._handler as! TestMeter
        XCTAssertEqual(testMeterAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testMeterAgain.values.first, -value, "expected value to match")

        let identityAgain = ObjectIdentifier(testMeterAgain)
        XCTAssertNotEqual(identity, identityAgain, "since the cached metric was released, the created a new should have a different identity")
    }

    func testDestroyingCounter() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "counter-\(UUID().uuidString)"
        let value = Int.random(in: 0 ... 1000)

        let counter = Counter(label: name)
        counter.increment(by: value)

        let testCounter = counter._handler as! TestCounter
        XCTAssertEqual(testCounter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testCounter.values.first, Int64(value), "expected value to match")
        XCTAssertEqual(metrics.counters.count, 1, "counter should have been stored")

        let identity = ObjectIdentifier(counter)
        counter.destroy()
        XCTAssertEqual(metrics.counters.count, 0, "counter should have been released")

        let counterAgain = Counter(label: name)
        counterAgain.increment(by: value)

        let testCounterAgain = counterAgain._handler as! TestCounter
        XCTAssertEqual(testCounterAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testCounterAgain.values.first, Int64(value), "expected value to match")

        let identityAgain = ObjectIdentifier(counterAgain)
        XCTAssertNotEqual(identity, identityAgain, "since the cached metric was released, the created a new should have a different identity")
    }

    func testDestroyingTimer() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "timer-\(UUID().uuidString)"
        let value = Int64.random(in: 0 ... 1000)

        let timer = Timer(label: name)
        timer.recordNanoseconds(value)

        let testTimer = timer._handler as! TestTimer
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values.first, value, "expected value to match")
        XCTAssertEqual(metrics.timers.count, 1, "timer should have been stored")

        let identity = ObjectIdentifier(timer)
        timer.destroy()
        XCTAssertEqual(metrics.timers.count, 0, "timer should have been released")

        let timerAgain = Timer(label: name)
        timerAgain.recordNanoseconds(value)
        let testTimerAgain = timerAgain._handler as! TestTimer
        XCTAssertEqual(testTimerAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimerAgain.values.first, value, "expected value to match")

        let identityAgain = ObjectIdentifier(timerAgain)
        XCTAssertNotEqual(identity, identityAgain, "since the cached metric was released, the created a new should have a different identity")
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
