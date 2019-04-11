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
@testable import MetricsUtil
import XCTest

class MetricsUtilTests: XCTestCase {
    func testRegistries() throws {
        // this example is not thread safe but good enough for what are testing
        class CachingMetrics: MetricsFactory {
            var counters = CounterRegistry<TestCounter>()
            var recorders = RecorderRegistry<TestRecorder>()
            var timers = TimerRegistry<TestTimer>()

            public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
                let counter = TestCounter(label: label, dimensions: dimensions)
                counters[label] = WeakCounter(counter)
                return counter
            }

            public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
                let recorder = TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
                recorders[label] = WeakRecorder(recorder)
                return recorder
            }

            public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
                let timer = TestTimer(label: label, dimensions: dimensions)
                timers[label] = WeakTimer(timer)
                return timer
            }

            public func reap() {
                self.counters = self.counters.filter { nil != $0.value.reference }
                self.recorders = self.recorders.filter { nil != $0.value.reference }
                self.timers = self.timers.filter { nil != $0.value.reference }
            }
        }

        // bootstrap with our test metrics
        let metrics = CachingMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        for i in 0 ..< 10 {
            let v1 = Int64.random(in: Int64.min ... Int64.max)
            let counter = Counter(label: "test-counter-\(i)")
            let counterRef = metrics.counters[counter.label]?.reference
            counter.increment(by: v1)
            XCTAssertNotNil(counterRef, "expected reference to be non null")
            XCTAssertEqual(counterRef!.values[0].1, v1, "expected value to match")
            
            let v2 = Double.random(in: Double(Int.min) ... Double(Int.max))
            let recorder = Recorder(label: "test-recorder-\(i)")
            let recorderRef = metrics.recorders[recorder.label]?.reference
            recorder.record(v2)
            XCTAssertNotNil(recorderRef, "expected reference to be non null")
            XCTAssertEqual(recorderRef!.values[0].1, v2, "expected value to match")
            
            let v3 = Int64.random(in: Int64.min ... Int64.max)
            let timer = Timer(label: "test-timer-\(i)")
            let timerRef = metrics.timers[timer.label]?.reference
            timer.recordNanoseconds(v3)
            XCTAssertNotNil(timerRef, "expected reference to be non null")
            XCTAssertEqual(timerRef!.values[0].1, v3, "expected value to match")
            
            metrics.reap()
            XCTAssertEqual(metrics.counters.count, 1, "expected number of entries to match")
            XCTAssertEqual(metrics.timers.count, 1, "expected number of entries to match")
            XCTAssertEqual(metrics.recorders.count, 1, "expected number of entries to match")
        }
        metrics.reap()
        XCTAssertEqual(metrics.counters.count, 0, "expected number of entries to match")
        XCTAssertEqual(metrics.timers.count, 0, "expected number of entries to match")
        XCTAssertEqual(metrics.recorders.count, 0, "expected number of entries to match")
    }


class AtLeastOnceCounterHandler: CounterHandler {
    let container: AtLeastOnceCounterContainer
    var count: Int64 = 0

    init(container: AtLeastOnceCounterContainer) {
        self.container = container
    }

    deinit {
        self.container.lastValue = self.count
    }

    func increment(by: Int64) {
        self.count += by
    }
    func reset() {
        self.count = 0
    }

}
class AtLeastOnceCounterContainer {
    weak var counter: AtLeastOnceCounterHandler? = nil
    var lastValue: Int64? = nil
}

/// This is an example of how one would implement a "always at least once expose a metric"
func testKeepAroundALittleBitRegistries() throws {
        // this example is not thread safe but good enough for what are testing
        class PrintAtLeastOnceMetrics: MetricsFactory {
            var counters: [String: AtLeastOnceCounterContainer] = [:]

            public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
                let container = AtLeastOnceCounterContainer()
                let counter = AtLeastOnceCounterHandler(container: container)
                container.counter = counter
                counters[label] = container
                return counter
            }

            public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
                fatalError()
            }

            public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
                fatalError()
            }

            // assume this is invoked periodically, on a timer (print metrics every 3 seconds) or by an external system (scrape)
            public func scrape() -> [String] {
                var s: [String] = []
                s.reserveCapacity(self.counters.count)

                for (label, container) in self.counters {
                    if let counter = container.counter {
                        // counter still has strong refs in user land
                        s.append("\(label):\(counter.count)")
                    } else {
                        // counter was released, we make sure to at least once report it
                        s.append("\(label):\(container.lastValue ?? 0) RELEASED")
                        self.counters.removeValue(forKey: label)
                    }
                }
                return s
            }
        }

        // bootstrap with our test metrics
        let metrics = PrintAtLeastOnceMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        // run the test
        func measureSomething() {
            let counter = Counter(label: "one")
            counter.increment()
        }
        measureSomething()
        // counter was released, yet we never scraped it yet; our impl guarantees that every metric will be scraped at least once
        // this matters for: some short lived resource, that we want to know how many ops it performed for example,
        // and we "did not make it in time" with scraping the data from it
        let scraped1 = metrics.scrape()
        XCTAssertEqual(scraped1.count, 1)
        XCTAssertEqual(scraped1.first ?? "", "one:1 RELEASED")

        let scraped2 = metrics.scrape()
        XCTAssertEqual(scraped2.count, 0)
    }
}
