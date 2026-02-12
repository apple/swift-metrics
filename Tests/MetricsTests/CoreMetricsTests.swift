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

#if canImport(Dispatch)
import Dispatch
#endif

struct MetricsTests {
    #if canImport(Dispatch)
    @Test func counters() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let group = DispatchGroup()
        let name = "counter-\(UUID().uuidString)"
        let counter = Counter(label: name, factory: metrics)
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
    #endif

    @Test func counterBlock() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "counter-\(UUID().uuidString)"
        let value = Int.random(in: Int.min...Int.max)
        Counter(label: name, factory: metrics).increment(by: value)
        let counter = try metrics.expectCounter(name)
        #expect(counter.values.count == 1, "expected number of entries to match")
        #expect(counter.values[0] == Int64(value), "expected value to match")
        counter.reset()
        #expect(counter.values.count == 0, "expected number of entries to match")
    }

    @Test func defaultFloatingPointCounter_ignoresNan() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label, factory: metrics)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: Double.nan)
        fpCounter.increment(by: Double.signalingNaN)
        #expect(counter.values.count == 0, "expected nan values to be ignored")
    }

    @Test func defaultFloatingPointCounter_ignoresInfinity() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label, factory: metrics)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: Double.infinity)
        fpCounter.increment(by: -Double.infinity)
        #expect(counter.values.count == 0, "expected infinite values to be ignored")
    }

    @Test func defaultFloatingPointCounter_ignoresNegativeValues() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label, factory: metrics)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: -100)
        #expect(counter.values.count == 0, "expected negative values to be ignored")
    }

    @Test func defaultFloatingPointCounter_ignoresZero() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label, factory: metrics)
        let counter = try metrics.expectCounter(label)
        fpCounter.increment(by: 0)
        fpCounter.increment(by: -0)
        #expect(counter.values.count == 0, "expected zero values to be ignored")
    }

    @Test func defaultFloatingPointCounter_ceilsExtremeValues() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label, factory: metrics)
        let counter = try metrics.expectCounter(label)
        // Just larger than Int64
        fpCounter.increment(by: Double(sign: .plus, exponent: 63, significand: 1))
        // Much larger than Int64
        fpCounter.increment(by: Double.greatestFiniteMagnitude)
        let values = counter.values
        #expect(values.count == 2, "expected number of entries to match")
        #expect(values == [Int64.max, Int64.max], "expected extremely large values to be replaced with Int64.max")
    }

    @Test func defaultFloatingPointCounter_accumulatesFloatingPointDecimalValues() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let label = "\(#function)-fp-counter-\(UUID())"
        let fpCounter = FloatingPointCounter(label: label, factory: metrics)
        let rawFpCounter = fpCounter._handler as! AccumulatingRoundingFloatingPointCounter
        let counter = try metrics.expectCounter(label)

        // Increment by a small value (perfectly representable)
        fpCounter.increment(by: 0.75)
        #expect(counter.values.count == 0, "expected number of entries to match")

        // Increment by a small value that should grow the accumulated buffer past 1.0 (perfectly representable)
        fpCounter.increment(by: 1.5)
        var values = counter.values
        #expect(values.count == 1, "expected number of entries to match")
        #expect(values == [2], "expected entries to match")
        #expect(rawFpCounter.fraction == 0.25, "")

        // Increment by a large value that should leave a fraction in the accumulator
        // 1110506744053.76
        fpCounter.increment(by: Double(sign: .plus, exponent: 40, significand: 1.01))
        values = counter.values
        #expect(values.count == 2, "expected number of entries to match")
        #expect(values == [2, 1_110_506_744_054], "expected entries to match")
        #expect(rawFpCounter.fraction == 0.010009765625, "expected fractional accumulated value")
    }

    #if canImport(Dispatch)
    @Test func recorders() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let group = DispatchGroup()
        let name = "recorder-\(UUID().uuidString)"
        let recorder = Recorder(label: name, factory: metrics)
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
    #endif

    @Test func recordersInt() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let recorder = Recorder(label: "test-recorder", factory: metrics)
        let testRecorder = try metrics.expectRecorder(recorder)
        let values = (0...999).map { _ in Int32.random(in: Int32.min...Int32.max) }
        for i in 0..<values.count {
            recorder.record(values[i])
        }
        #expect(values.count == testRecorder.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            #expect(Int32(testRecorder.values[i]) == values[i], "expected value #\(i) to match.")
        }
    }

    @Test func recordersFloat() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let recorder = Recorder(label: "test-recorder", factory: metrics)
        let testRecorder = try metrics.expectRecorder(recorder)
        let values = (0...999).map { _ in Float.random(in: Float(Int32.min)...Float(Int32.max)) }
        for i in 0..<values.count {
            recorder.record(values[i])
        }
        #expect(values.count == testRecorder.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            #expect(Float(testRecorder.values[i]) == values[i], "expected value #\(i) to match.")
        }
    }

    @Test func recorderBlock() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "recorder-\(UUID().uuidString)"
        let value = Double.random(in: Double(Int.min)...Double(Int.max))
        Recorder(label: name, factory: metrics).record(value)
        let recorder = try metrics.expectRecorder(name)
        #expect(recorder.values.count == 1, "expected number of entries to match")
        #expect(recorder.lastValue == value, "expected value to match")
    }

    #if canImport(Dispatch)
    @Test func timers() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let group = DispatchGroup()
        let name = "timer-\(UUID().uuidString)"
        let timer = Timer(label: name, factory: metrics)
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
    #endif

    @Test func timerBlock() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "timer-\(UUID().uuidString)"
        let value = Int64.random(in: Int64.min...Int64.max)
        Timer(label: name, factory: metrics).recordNanoseconds(value)
        let timer = try metrics.expectTimer(name)
        #expect(timer.values.count == 1, "expected number of entries to match")
        #expect(timer.values[0] == value, "expected value to match")
    }

    @Test func timerVariants() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let timer = Timer(label: "test-timer", factory: metrics)
        let testTimer = try metrics.expectTimer(timer)
        // nano
        let nano = Int64.random(in: 0...5)
        timer.recordNanoseconds(nano)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(testTimer.values[0] == nano, "expected value to match")
        // micro
        let micro = Int64.random(in: 0...5)
        timer.recordMicroseconds(micro)
        #expect(testTimer.values.count == 2, "expected number of entries to match")
        #expect(testTimer.values[1] == micro * 1000, "expected value to match")
        // milli
        let milli = Int64.random(in: 0...5)
        timer.recordMilliseconds(milli)
        #expect(testTimer.values.count == 3, "expected number of entries to match")
        #expect(testTimer.values[2] == milli * 1_000_000, "expected value to match")
        // seconds
        let sec = Int64.random(in: 0...5)
        timer.recordSeconds(sec)
        #expect(testTimer.values.count == 4, "expected number of entries to match")
        #expect(testTimer.values[3] == sec * 1_000_000_000, "expected value to match")
    }

    @Test func timerOverflow() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let timer = Timer(label: "test-timer", factory: metrics)
        let testTimer = try metrics.expectTimer(timer)
        // nano (integer)
        timer.recordNanoseconds(Int64.max)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(testTimer.values[0] == Int64.max, "expected value to match")
        // micro (integer)
        timer.recordMicroseconds(Int64.max)
        #expect(testTimer.values.count == 2, "expected number of entries to match")
        #expect(testTimer.values[1] == Int64.max, "expected value to match")
        // micro (double)
        timer.recordMicroseconds(Double(Int64.max) + 1)
        #expect(testTimer.values.count == 3, "expected number of entries to match")
        #expect(testTimer.values[1] == Int64.max, "expected value to match")
        // milli (integer)
        timer.recordMilliseconds(Int64.max)
        #expect(testTimer.values.count == 4, "expected number of entries to match")
        #expect(testTimer.values[2] == Int64.max, "expected value to match")
        // milli (double)
        timer.recordMilliseconds(Double(Int64.max) + 1)
        #expect(testTimer.values.count == 5, "expected number of entries to match")
        #expect(testTimer.values[2] == Int64.max, "expected value to match")
        // seconds (integer)
        timer.recordSeconds(Int64.max)
        #expect(testTimer.values.count == 6, "expected number of entries to match")
        #expect(testTimer.values[3] == Int64.max, "expected value to match")
        // seconds (double)
        timer.recordSeconds(Double(Int64.max) * 1)
        #expect(testTimer.values.count == 7, "expected number of entries to match")
        #expect(testTimer.values[3] == Int64.max, "expected value to match")
    }

    @Test func timerHandlesUnsignedOverflow() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let timer = Timer(label: "test-timer", factory: metrics)
        let testTimer = try metrics.expectTimer(timer)
        // nano
        timer.recordNanoseconds(UInt64.max)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(testTimer.values[0] == Int64.max, "expected value to match")
        // micro
        timer.recordMicroseconds(UInt64.max)
        #expect(testTimer.values.count == 2, "expected number of entries to match")
        #expect(testTimer.values[1] == Int64.max, "expected value to match")
        // milli
        timer.recordMilliseconds(UInt64.max)
        #expect(testTimer.values.count == 3, "expected number of entries to match")
        #expect(testTimer.values[2] == Int64.max, "expected value to match")
        // seconds
        timer.recordSeconds(UInt64.max)
        #expect(testTimer.values.count == 4, "expected number of entries to match")
        #expect(testTimer.values[3] == Int64.max, "expected value to match")
    }

    @Test func gauge() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        let gauge = Gauge(label: name, factory: metrics)
        gauge.record(value)
        let recorder = try metrics.expectRecorder(gauge)
        #expect(recorder.values.count == 1, "expected number of entries to match")
        #expect(recorder.lastValue == value, "expected value to match")
    }

    @Test func gaugeBlock() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        Gauge(label: name, factory: metrics).record(value)
        let recorder = try metrics.expectRecorder(name)
        #expect(recorder.values.count == 1, "expected number of entries to match")
        #expect(recorder.lastValue == value, "expected value to match")
    }

    @Test func meter() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        let meter = Meter(label: name, factory: metrics)
        meter.set(value)
        let testMeter = try metrics.expectMeter(meter)
        #expect(testMeter.values.count == 1, "expected number of entries to match")
        #expect(testMeter.values[0] == value, "expected value to match")
    }

    @Test func meterBlock() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)
        Meter(label: name, factory: metrics).set(value)
        let testMeter = try metrics.expectMeter(name)
        #expect(testMeter.values.count == 1, "expected number of entries to match")
        #expect(testMeter.values[0] == value, "expected value to match")
    }

    @Test func meterInt() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
        let testMeter = try metrics.expectMeter(meter)
        let values = (0...999).map { _ in Int32.random(in: Int32.min...Int32.max) }
        for i in 0..<values.count {
            meter.set(values[i])
        }
        #expect(values.count == testMeter.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            #expect(Int32(testMeter.values[i]) == values[i], "expected value #\(i) to match.")
        }
    }

    @Test func meterFloat() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
        let testMeter = try metrics.expectMeter(meter)
        let values = (0...999).map { _ in Float.random(in: Float(Int32.min)...Float(Int32.max)) }
        for i in 0..<values.count {
            meter.set(values[i])
        }
        #expect(values.count == testMeter.values.count, "expected number of entries to match")
        for i in 0..<values.count {
            #expect(Float(testMeter.values[i]) == values[i], "expected value #\(i) to match.")
        }
    }

    #if canImport(Dispatch)
    @Test func meterIncrement() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let group = DispatchGroup()
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
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
        #expect(testMeter.values.count == values.count, "expected number of entries to match")

        // The suggested way for comparing float numbers is to use swift-numerics,
        // but this would add a dependency. Instead, as we fully control the values
        // used in tests, we can get away with the simple `abs(x - y) < accuracy`.
        // See https://developer.apple.com/documentation/testing/migratingfromxctest
        #expect(abs(testMeter.values.last! - values.reduce(0.0, +)) < 0.1, "expected total value to match")
    }

    @Test func meterDecrement() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let group = DispatchGroup()
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
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
        #expect(testMeter.values.count == values.count, "expected number of entries to match")

        // The suggested way for comparing float numbers is to use swift-numerics,
        // but this would add a dependency. Instead, as we fully control the values
        // used in tests, we can get away with the simple `abs(x - y) < accuracy`.
        // See https://developer.apple.com/documentation/testing/migratingfromxctest
        #expect(abs(testMeter.values.last! - values.reduce(0.0, -)) < 0.1, "expected total value to match")
    }
    #endif

    @Test func defaultMeterIgnoresNan() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: Double.nan)
        meter.increment(by: Double.signalingNaN)
        #expect(testMeter.values.count == 0, "expected nan values to be ignored")
    }

    @Test func defaultMeterIgnoresInfinity() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: Double.infinity)
        meter.increment(by: -Double.infinity)
        #expect(testMeter.values.count == 0, "expected infinite values to be ignored")
    }

    @Test func defaultMeterIgnoresNegativeValues() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: -100)
        #expect(testMeter.values.count == 0, "expected negative values to be ignored")
    }

    @Test func defaultMeterIgnoresZero() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let metrics = TestMetrics()
        // run the test
        let name = "meter-\(UUID().uuidString)"
        let meter = Meter(label: name, factory: metrics)
        let testMeter = try metrics.expectMeter(meter)
        meter.increment(by: 0)
        meter.increment(by: -0)
        #expect(testMeter.values.count == 0, "expected zero values to be ignored")
    }

    @Test func mUX_Counter() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        let multiplexFactory = MultiplexMetricsHandler(factories: factories)
        // run the test
        let name = UUID().uuidString
        let value = Int.random(in: Int.min...Int.max)
        let muxCounter = Counter(label: name, factory: multiplexFactory)
        muxCounter.increment(by: value)
        for factory in factories {
            let counter = factory.counters.first
            #expect(counter?.label == name, "expected label to match")
            #expect(counter?.values.count == 1, "expected number of entries to match")
            #expect(counter?.lastValue == Int64(value), "expected value to match")
        }
        muxCounter.reset()
        for factory in factories {
            let counter = factory.counters.first
            #expect(counter?.values.count == 0, "expected number of entries to match")
        }
    }

    @Test func mUX_Meter() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        let multiplexFactory = MultiplexMetricsHandler(factories: factories)
        // run the test
        let name = UUID().uuidString
        let value = Double.random(in: 0...1)
        let muxMeter = Meter(label: name, factory: multiplexFactory)
        muxMeter.set(value)
        for factory in factories {
            let meter = factory.meters.first
            #expect(meter?.label == name, "expected label to match")
            #expect(meter?.values.count == 1, "expected number of entries to match")
            #expect(meter?.values[0] == value, "expected value to match")
        }
    }

    @Test func mUX_Recorder() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        let multiplexFactory = MultiplexMetricsHandler(factories: factories)
        // run the test
        let name = UUID().uuidString
        let value = Double.random(in: 0...1)
        let muxRecorder = Recorder(label: name, factory: multiplexFactory)
        muxRecorder.record(value)
        for factory in factories {
            let recorder = factory.recorders.first
            #expect(recorder?.label == name, "expected label to match")
            #expect(recorder?.values.count == 1, "expected number of entries to match")
            #expect(recorder?.values[0] == value, "expected value to match")
        }
    }

    @Test func mUX_Timer() throws {
        // create our test metrics, avoid bootstrapping global MetricsSystem
        let factories = [TestMetrics(), TestMetrics(), TestMetrics()]
        let multiplexFactory = MultiplexMetricsHandler(factories: factories)
        // run the test
        let name = UUID().uuidString
        let seconds = Int.random(in: 1...10)
        let muxTimer = Timer(label: name, preferredDisplayUnit: .minutes, factory: multiplexFactory)
        muxTimer.recordSeconds(seconds)
        for factory in factories {
            let timer = factory.timers.first
            #expect(timer?.label == name, "expected label to match")
            #expect(timer?.values.count == 1, "expected number of entries to match")
            #expect(timer?.values[0] == Int64(seconds * 1_000_000_000), "expected value to match")
            #expect(timer?.displayUnit == .minutes, "expected value to match")
            #expect(
                timer?.valueInPreferredUnit(atIndex: 0) == Double(seconds) / 60.0,
                "seconds should be returned as minutes"
            )
        }
    }

    @Test func customHandler() {
        final class CustomHandler: CounterHandler {
            func increment<DataType>(by: DataType) where DataType: BinaryInteger {}
            func reset() {}
        }

        let counter1 = Counter(label: "foo")
        #expect(!(counter1._handler is CustomHandler), "expected non-custom log handler")
        let counter2 = Counter(label: "foo", dimensions: [], handler: CustomHandler())
        #expect(counter2._handler is CustomHandler, "expected custom log handler")
    }

    @Test func customFactory() {
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
                #expect(
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

        #expect(!factory.didCallDestroyCounter)
        do {
            let counter1 = Counter(label: "foo", factory: factory)
            #expect(counter1._handler is CustomFactory.CustomHandler, "expected a custom metrics handler")
            #expect(counter1._factory is CustomFactory, "expected a custom metrics factory")
            counter1.destroy()
        }
        #expect(factory.didCallDestroyCounter)
    }

    @Test func destroyingGauge() throws {
        let metrics = TestMetrics()

        let name = "gauge-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)

        let gauge = Gauge(label: name, factory: metrics)
        gauge.record(value)

        let recorder = try metrics.expectRecorder(gauge)
        #expect(recorder.values.count == 1, "expected number of entries to match")
        #expect(recorder.values.first == value, "expected value to match")
        #expect(metrics.recorders.count == 1, "recorder should have been stored")

        let identity = ObjectIdentifier(recorder)
        gauge.destroy()
        #expect(metrics.recorders.count == 0, "recorder should have been released")

        let gaugeAgain = Gauge(label: name, factory: metrics)
        gaugeAgain.record(-value)

        let recorderAgain = try metrics.expectRecorder(gaugeAgain)
        #expect(recorderAgain.values.count == 1, "expected number of entries to match")
        #expect(recorderAgain.values.first == -value, "expected value to match")

        let identityAgain = ObjectIdentifier(recorderAgain)
        #expect(
            identity != identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    @Test func destroyingMeter() throws {
        let metrics = TestMetrics()

        let name = "meter-\(UUID().uuidString)"
        let value = Double.random(in: -1000...1000)

        let meter = Meter(label: name, factory: metrics)
        meter.set(value)

        let testMeter = try metrics.expectMeter(meter)
        #expect(testMeter.values.count == 1, "expected number of entries to match")
        #expect(testMeter.values.first == value, "expected value to match")
        #expect(metrics.meters.count == 1, "recorder should have been stored")

        let identity = ObjectIdentifier(testMeter)
        meter.destroy()
        #expect(metrics.recorders.count == 0, "recorder should have been released")

        let meterAgain = Meter(label: name, factory: metrics)
        meterAgain.set(-value)

        let testMeterAgain = try metrics.expectMeter(meterAgain)
        #expect(testMeterAgain.values.count == 1, "expected number of entries to match")
        #expect(testMeterAgain.values.first == -value, "expected value to match")

        let identityAgain = ObjectIdentifier(testMeterAgain)
        #expect(
            identity != identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    @Test func destroyingCounter() throws {
        let metrics = TestMetrics()

        let name = "counter-\(UUID().uuidString)"
        let value = Int.random(in: 0...1000)

        let counter = Counter(label: name, factory: metrics)
        counter.increment(by: value)

        let testCounter = try metrics.expectCounter(counter)
        #expect(testCounter.values.count == 1, "expected number of entries to match")
        #expect(testCounter.values.first == Int64(value), "expected value to match")
        #expect(metrics.counters.count == 1, "counter should have been stored")

        let identity = ObjectIdentifier(counter)
        counter.destroy()
        #expect(metrics.counters.count == 0, "counter should have been released")

        let counterAgain = Counter(label: name, factory: metrics)
        counterAgain.increment(by: value)

        let testCounterAgain = try metrics.expectCounter(counterAgain)
        #expect(testCounterAgain.values.count == 1, "expected number of entries to match")
        #expect(testCounterAgain.values.first == Int64(value), "expected value to match")

        let identityAgain = ObjectIdentifier(counterAgain)
        #expect(
            identity != identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    @Test func destroyingTimer() throws {
        let metrics = TestMetrics()

        let name = "timer-\(UUID().uuidString)"
        let value = Int64.random(in: 0...1000)

        let timer = Timer(label: name, factory: metrics)
        timer.recordNanoseconds(value)

        let testTimer = try metrics.expectTimer(timer)
        #expect(testTimer.values.count == 1, "expected number of entries to match")
        #expect(testTimer.values.first == value, "expected value to match")
        #expect(metrics.timers.count == 1, "timer should have been stored")

        let identity = ObjectIdentifier(timer)
        timer.destroy()
        #expect(metrics.timers.count == 0, "timer should have been released")

        let timerAgain = Timer(label: name, factory: metrics)
        timerAgain.recordNanoseconds(value)
        let testTimerAgain = try metrics.expectTimer(timerAgain)
        #expect(testTimerAgain.values.count == 1, "expected number of entries to match")
        #expect(testTimerAgain.values.first == value, "expected value to match")

        let identityAgain = ObjectIdentifier(timerAgain)
        #expect(
            identity != identityAgain,
            "since the cached metric was released, the created a new should have a different identity"
        )
    }

    @Test func descriptions() throws {
        let metrics = TestMetrics()

        let counter = Counter(label: "hello.counter", factory: metrics)
        #expect("\(counter)" == "Counter(hello.counter, dimensions: [])")

        let gauge = Gauge(label: "hello.gauge", factory: metrics)
        #expect("\(gauge)" == "Gauge(hello.gauge, dimensions: [], aggregate: false)")

        let meter = Meter(label: "hello.meter", factory: metrics)
        #expect("\(meter)" == "Meter(hello.meter, dimensions: [])")

        let timer = Timer(label: "hello.timer", factory: metrics)
        #expect("\(timer)" == "Timer(hello.timer, dimensions: [])")

        let recorder = Recorder(label: "hello.recorder", factory: metrics)
        #expect("\(recorder)" == "Recorder(hello.recorder, dimensions: [], aggregate: true)")
    }
}
