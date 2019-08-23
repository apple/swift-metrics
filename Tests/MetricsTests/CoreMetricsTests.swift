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
import XCTest

class MetricsTests: XCTestCase {
    func testCounters() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let group = DispatchGroup()
        let name = "counter-\(NSUUID().uuidString)"
        let counter = Counter(label: name)
        let testCounter = counter.handler as! TestCounter
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
        let name = "counter-\(NSUUID().uuidString)"
        let value = Int.random(in: Int.min ... Int.max)
        Counter(label: name).increment(by: value)
        let counter = metrics.counters[name] as! TestCounter
        XCTAssertEqual(counter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(counter.values[0].1, Int64(value), "expected value to match")
        counter.reset()
        XCTAssertEqual(counter.values.count, 0, "expected number of entries to match")
    }

    func testRecorders() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let group = DispatchGroup()
        let name = "recorder-\(NSUUID().uuidString)"
        let recorder = Recorder(label: name)
        let testRecorder = recorder.handler as! TestRecorder
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
        let testRecorder = recorder.handler as! TestRecorder
        let values = (0 ... 999).map { _ in Int32.random(in: Int32.min ... Int32.max) }
        for i in 0 ... values.count - 1 {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, testRecorder.values.count, "expected number of entries to match")
        for i in 0 ... values.count - 1 {
            XCTAssertEqual(Int32(testRecorder.values[i].1), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecordersFloat() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let recorder = Recorder(label: "test-recorder")
        let testRecorder = recorder.handler as! TestRecorder
        let values = (0 ... 999).map { _ in Float.random(in: Float(Int32.min) ... Float(Int32.max)) }
        for i in 0 ... values.count - 1 {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, testRecorder.values.count, "expected number of entries to match")
        for i in 0 ... values.count - 1 {
            XCTAssertEqual(Float(testRecorder.values[i].1), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecorderBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "recorder-\(NSUUID().uuidString)"
        let value = Double.random(in: Double(Int.min) ... Double(Int.max))
        Recorder(label: name).record(value)
        let recorder = metrics.recorders[name] as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values[0].1, value, "expected value to match")
    }

    func testTimers() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        let group = DispatchGroup()
        let name = "timer-\(NSUUID().uuidString)"
        let timer = Timer(label: name, storageUnit: .nanoSeconds)
        let testTimer = timer.handler as! TestTimer
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
        let name = "timer-\(NSUUID().uuidString)"
        let value = Int64.random(in: Int64.min ... Int64.max)
        Timer(label: name, storageUnit: .nanoSeconds).recordNanoseconds(value)
        let timer = metrics.timers[name] as! TestTimer
        XCTAssertEqual(timer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(timer.values[0].1, value, "expected value to match")
    }

    func testTimerVariants() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer", storageUnit: .nanoSeconds)
        let testTimer = timer.handler as! TestTimer
        // nano
        let nano = Int64.random(in: 0 ... 5)
        timer.recordNanoseconds(nano)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0].1, nano, "expected value to match")
        // micro
        let micro = Int64.random(in: 0 ... 5)
        timer.recordMicroseconds(micro)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1].1, micro * 1000, "expected value to match")
        // milli
        let milli = Int64.random(in: 0 ... 5)
        timer.recordMilliseconds(milli)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2].1, milli * 1_000_000, "expected value to match")
        // seconds
        let sec = Int64.random(in: 0 ... 5)
        timer.recordSeconds(sec)
        XCTAssertEqual(testTimer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3].1, sec * 1_000_000_000, "expected value to match")
    }

    func testTimerOverflow() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer", storageUnit: .nanoSeconds)
        let testTimer = timer.handler as! TestTimer
        // nano (integer)
        timer.recordNanoseconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0].1, Int64.max, "expected value to match")
        // micro (integer)
        timer.recordMicroseconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1].1, Int64.max, "expected value to match")
        // micro (double)
        timer.recordMicroseconds(Double(Int64.max) + 1)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1].1, Int64.max, "expected value to match")
        // milli (integer)
        timer.recordMilliseconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2].1, Int64.max, "expected value to match")
        // milli (double)
        timer.recordMilliseconds(Double(Int64.max) + 1)
        XCTAssertEqual(testTimer.values.count, 5, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2].1, Int64.max, "expected value to match")
        // seconds (integer)
        timer.recordSeconds(Int64.max)
        XCTAssertEqual(testTimer.values.count, 6, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3].1, Int64.max, "expected value to match")
        // seconds (double)
        timer.recordSeconds(Double(Int64.max) * 1)
        XCTAssertEqual(testTimer.values.count, 7, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3].1, Int64.max, "expected value to match")
    }

    func testTimerHandlesUnsignedOverflow() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer", storageUnit: .nanoSeconds)
        let testTimer = timer.handler as! TestTimer
        // nano
        timer.recordNanoseconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0].1, Int64.max, "expected value to match")
        // micro
        timer.recordMicroseconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[1].1, Int64.max, "expected value to match")
        // milli
        timer.recordMilliseconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[2].1, Int64.max, "expected value to match")
        // seconds
        timer.recordSeconds(UInt64.max)
        XCTAssertEqual(testTimer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[3].1, Int64.max, "expected value to match")
    }

    func testGauge() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "gauge-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)
        let gauge = Gauge(label: name)
        gauge.record(value)
        let recorder = gauge.handler as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values[0].1, value, "expected value to match")
    }

    func testGaugeBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "gauge-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)
        Gauge(label: name).record(value)
        let recorder = metrics.recorders[name] as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values[0].1, value, "expected value to match")
    }

    func testMUX() throws {
        // bootstrap with our test metrics
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        MetricsSystem.bootstrapInternal(MultiplexMetricsHandler(factories: factories))
        // run the test
        let name = NSUUID().uuidString
        let value = Int.random(in: Int.min ... Int.max)
        let mux = Counter(label: name)
        mux.increment(by: value)
        factories.forEach { factory in
            let counter = factory.counters.first?.1 as! TestCounter
            XCTAssertEqual(counter.label, name, "expected label to match")
            XCTAssertEqual(counter.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(counter.values[0].1, Int64(value), "expected value to match")
        }
        mux.reset()
        factories.forEach { factory in
            let counter = factory.counters.first?.1 as! TestCounter
            XCTAssertEqual(counter.values.count, 0, "expected number of entries to match")
        }
    }

    func testCustomFactory() {
        class CustomHandler: CounterHandler {
            func increment<DataType>(by: DataType) where DataType: BinaryInteger {}
            func reset() {}
        }

        let counter1 = Counter(label: "foo")
        XCTAssertFalse(counter1.handler is CustomHandler, "expected non-custom log handler")
        let counter2 = Counter(label: "foo", dimensions: [], handler: CustomHandler())
        XCTAssertTrue(counter2.handler is CustomHandler, "expected custom log handler")
    }

    func testDestroyingGauge() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "gauge-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)

        let gauge = Gauge(label: name)
        gauge.record(value)

        let recorder = gauge.handler as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values.first!.1, value, "expected value to match")
        XCTAssertEqual(metrics.recorders.count, 1, "recorder should have been stored")

        let identity = ObjectIdentifier(recorder)
        gauge.destroy()
        XCTAssertEqual(metrics.recorders.count, 0, "recorder should have been released")

        let gaugeAgain = Gauge(label: name)
        gaugeAgain.record(-value)

        let recorderAgain = gaugeAgain.handler as! TestRecorder
        XCTAssertEqual(recorderAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorderAgain.values.first!.1, -value, "expected value to match")

        let identityAgain = ObjectIdentifier(recorderAgain)
        XCTAssertNotEqual(identity, identityAgain, "since the cached metric was released, the created a new should have a different identity")
    }

    func testDestroyingCounter() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "counter-\(NSUUID().uuidString)"
        let value = Int.random(in: 0 ... 1000)

        let counter = Counter(label: name)
        counter.increment(by: value)

        let testCounter = counter.handler as! TestCounter
        XCTAssertEqual(testCounter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testCounter.values.first!.1, Int64(value), "expected value to match")
        XCTAssertEqual(metrics.counters.count, 1, "counter should have been stored")

        let identity = ObjectIdentifier(counter)
        counter.destroy()
        XCTAssertEqual(metrics.counters.count, 0, "counter should have been released")

        let counterAgain = Counter(label: name)
        counterAgain.increment(by: value)

        let testCounterAgain = counterAgain.handler as! TestCounter
        XCTAssertEqual(testCounterAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testCounterAgain.values.first!.1, Int64(value), "expected value to match")

        let identityAgain = ObjectIdentifier(counterAgain)
        XCTAssertNotEqual(identity, identityAgain, "since the cached metric was released, the created a new should have a different identity")
    }

    func testDestroyingTimer() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "timer-\(NSUUID().uuidString)"
        let value = Int64.random(in: 0 ... 1000)

        let timer = Timer(label: name, storageUnit: .nanoSeconds)
        timer.recordNanoseconds(value)

        let testTimer = timer.handler as! TestTimer
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values.first!.1, value, "expected value to match")
        XCTAssertEqual(metrics.timers.count, 1, "timer should have been stored")

        let identity = ObjectIdentifier(timer)
        timer.destroy()
        XCTAssertEqual(metrics.timers.count, 0, "timer should have been released")

        let timerAgain = Timer(label: name, storageUnit: .nanoSeconds)
        timerAgain.recordNanoseconds(value)
        let testTimerAgain = timerAgain.handler as! TestTimer
        XCTAssertEqual(testTimerAgain.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimerAgain.values.first!.1, value, "expected value to match")

        let identityAgain = ObjectIdentifier(timerAgain)
        XCTAssertNotEqual(identity, identityAgain, "since the cached metric was released, the created a new should have a different identity")
    }
    
    func testTimerUnits() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        
        let name = "timer-\(NSUUID().uuidString)"
        let value = Int64.random(in: 0 ... 1000)
        
        let timer = Timer(label: name, storageUnit: .nanoSeconds)
        timer.recordNanoseconds(value)
        
        let testTimer = timer.handler as! TestTimer
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values.first!.1, value, "expected value to match")
        XCTAssertEqual(metrics.timers.count, 1, "timer should have been stored")
        
        let secondsName = "timer-seconds-\(NSUUID().uuidString)"
        let secondsValue = Int64.random(in: 0 ... 1000)
        let secondsTimer = Timer(label: secondsName, storageUnit: .seconds)
        secondsTimer.recordSeconds(secondsValue)
        
        let testSecondsTimer = secondsTimer.handler as! TestTimer
        XCTAssertEqual(testSecondsTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testSecondsTimer.retrieveValue(atIndex: 0), secondsValue, "expected value to match")
        XCTAssertEqual(metrics.timers.count, 2, "timer should have been stored")
    }
}
