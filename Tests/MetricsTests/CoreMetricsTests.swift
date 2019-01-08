@testable import CoreMetrics
import XCTest

class MetricsTests: XCTestCase {
    func testCounters() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        let group = DispatchGroup()
        let name = "counter-\(NSUUID().uuidString)"
        let counter = Metrics.global.makeCounter(label: name) as! TestCounter
        let total = Int.random(in: 500 ... 1000)
        for _ in 0 ... total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                counter.increment(Int.random(in: 0 ... 1000))
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(counter.values.count - 1, total, "expected number of entries to match")
    }

    func testCounterBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let name = "counter-\(NSUUID().uuidString)"
        let value = Int.random(in: Int.min ... Int.max)
        Metrics.global.withCounter(label: name) { $0.increment(value) }
        let counter = Metrics.global.makeCounter(label: name) as! TestCounter
        XCTAssertEqual(counter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(counter.values[0].1, Int64(value), "expected value to match")
    }

    func testRecorders() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        let group = DispatchGroup()
        let name = "recorder-\(NSUUID().uuidString)"
        let recorder = Metrics.global.makeRecorder(label: name) as! TestRecorder
        let total = Int.random(in: 500 ... 1000)
        for _ in 0 ... total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                recorder.record(Int.random(in: Int.min ... Int.max))
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(recorder.values.count - 1, total, "expected number of entries to match")
    }

    func testRecordersInt() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        let recorder = Metrics.global.makeRecorder(label: "test-recorder") as! TestRecorder
        let values = (0 ... 999).map { _ in Int32.random(in: Int32.min ... Int32.max) }
        for i in 0 ... values.count - 1 {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, recorder.values.count, "expected number of entries to match")
        for i in 0 ... values.count - 1 {
            XCTAssertEqual(Int32(recorder.values[i].1), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecordersFloat() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        let recorder = Metrics.global.makeRecorder(label: "test-recorder") as! TestRecorder
        let values = (0 ... 999).map { _ in Float.random(in: Float(Int32.min) ... Float(Int32.max)) }
        for i in 0 ... values.count - 1 {
            recorder.record(values[i])
        }
        XCTAssertEqual(values.count, recorder.values.count, "expected number of entries to match")
        for i in 0 ... values.count - 1 {
            XCTAssertEqual(Float(recorder.values[i].1), values[i], "expected value #\(i) to match.")
        }
    }

    func testRecorderBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let name = "recorder-\(NSUUID().uuidString)"
        let value = Double.random(in: Double(Int.min) ... Double(Int.max))
        Metrics.global.withRecorder(label: name) { $0.record(value) }
        let recorder = Metrics.global.makeRecorder(label: name) as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values[0].1, value, "expected value to match")
    }

    func testTimers() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        let group = DispatchGroup()
        let name = "timer-\(NSUUID().uuidString)"
        let timer = Metrics.global.makeTimer(label: name) as! TestTimer
        let total = Int.random(in: 500 ... 1000)
        for _ in 0 ... total {
            group.enter()
            DispatchQueue(label: "\(name)-queue").async {
                timer.recordNanoseconds(Int64.random(in: Int64.min ... Int64.max))
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(timer.values.count - 1, total, "expected number of entries to match")
    }

    func testTimerBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let name = "timer-\(NSUUID().uuidString)"
        let value = Int64.random(in: Int64.min ... Int64.max)
        Metrics.global.withTimer(label: name) { $0.recordNanoseconds(value) }
        let timer = Metrics.global.makeTimer(label: name) as! TestTimer
        XCTAssertEqual(timer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(timer.values[0].1, value, "expected value to match")
    }

    func testTimerVariants() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let timer = Metrics.global.makeTimer(label: "test-timer") as! TestTimer
        // nano
        let nano = Int64.random(in: 0 ... 5)
        timer.recordNanoseconds(nano)
        XCTAssertEqual(timer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(timer.values[0].1, nano, "expected value to match")
        // micro
        let micro = Int64.random(in: 0 ... 5)
        timer.recordMicroseconds(micro)
        XCTAssertEqual(timer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(timer.values[1].1, micro * 1000, "expected value to match")
        // milli
        let milli = Int64.random(in: 0 ... 5)
        timer.recordMilliseconds(milli)
        XCTAssertEqual(timer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(timer.values[2].1, milli * 1_000_000, "expected value to match")
        // seconds
        let sec = Int64.random(in: 0 ... 5)
        timer.recordSeconds(sec)
        XCTAssertEqual(timer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(timer.values[3].1, sec * 1_000_000_000, "expected value to match")
    }

    func testGauge() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let name = "gauge-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)
        let gauge = Metrics.global.makeGauge(label: name)
        gauge.record(value)
        let recorder = gauge as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values[0].1, value, "expected value to match")
    }

    func testGaugeBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let name = "gauge-\(NSUUID().uuidString)"
        let value = Double.random(in: -1000 ... 1000)
        Metrics.global.withGauge(label: name) { $0.record(value) }
        let recorder = Metrics.global.makeGauge(label: name) as! TestRecorder
        XCTAssertEqual(recorder.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(recorder.values[0].1, value, "expected value to match")
    }

    func testMUX() throws {
        // bootstrap with our test metrics
        let handlers = [TestMetrics(), TestMetrics(), TestMetrics()]
        Metrics.bootstrap(MultiplexMetricsHandler(handlers: handlers))
        // run the test
        let name = NSUUID().uuidString
        let value = Int.random(in: Int.min ... Int.max)
        Metrics.global.withCounter(label: name) { counter in
            counter.increment(value)
        }
        handlers.forEach { handler in
            let counter = handler.counters[name] as! TestCounter
            XCTAssertEqual(counter.values.count, 1, "expected number of entries to match")
            XCTAssertEqual(counter.values[0].1, Int64(value), "expected value to match")
        }
    }

    func testDimensions() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        Metrics.bootstrap(metrics)
        // run the test
        let name = "counter-\(NSUUID().uuidString)"
        let dimensions = [("foo", "bar"), ("baz", "quk")]
        let counter = Metrics.global.makeCounter(label: name, dimensions: dimensions) as! TestCounter
        counter.increment()

        XCTAssertEqual(counter.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(counter.values[0].1, 1, "expected value to match")
        XCTAssertEqual(counter.dimensions.description, dimensions.description, "expected dimensions to match")

        let counter2 = Metrics.global.makeCounter(label: name, dimensions: dimensions) as! TestCounter
        XCTAssertEqual(counter2, counter, "expected caching to work with dimensions")
    }
}
