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

struct MetricRewriterFromClosure: MetricsRewriter {
    typealias Rewriter = (MetricWithDimensions) -> [MetricWithDimensions]

    let convertor: Rewriter

    init(convertor: @escaping Rewriter) {
        self.convertor = convertor
    }

    func rewrite(metric: MetricWithDimensions) -> [MetricWithDimensions] {
        return self.convertor(metric)
    }
}

struct NoOpMetricRewriter: MetricsRewriter {
    func rewrite(metric: MetricWithDimensions) -> [MetricWithDimensions] {
        return [metric]
    }
}

struct EchoMetricRewriter: MetricsRewriter {
    func rewrite(metric: MetricWithDimensions) -> [MetricWithDimensions] {
        return [metric]
    }
}

class MetricsRewriterTest: XCTestCase {
    let testMetrics = TestMetrics()

    func testNoOpTranslator() {
        let adapter = RewritingMetricsHandler(underlying: testMetrics, rewriter: NoOpMetricRewriter())
        let counter = adapter.makeCounter(label: "httpServerStartedCounter", dimensions: [])
        counter.increment(by: 1)
        XCTAssertEqual(try self.testMetrics.expectCounter("httpServerStartedCounter").totalValue, 1)

        // Shouldn't use multiwriter here
        XCTAssertNil(counter as? MultiWritingCounter)
    }

    func testEchoTranslator() {
        let adapter = RewritingMetricsHandler(underlying: testMetrics, rewriter: EchoMetricRewriter())
        let counter = adapter.makeCounter(label: "httpServerStartedCounter", dimensions: [])
        counter.increment(by: 1)
        XCTAssertEqual(try self.testMetrics.expectCounter("httpServerStartedCounter").totalValue, 1)

        // Shouldn't use multiwriter here
        XCTAssertNil(counter as? MultiWritingCounter)
    }

    func testBasicAdapter() {
        let adapter = RewritingMetricsHandler(underlying: testMetrics, rewriter: MetricRewriterFromClosure { m in
            if m.label == "httpServerStartedCounter" {
                return [MetricWithDimensions(label: "rewritten")]
            } else {
                return [m]
            }
        })
        // Rewrite for the name checked in the convertor
        self.assertCounterRewrite(
            originalMetric: MetricWithDimensions(label: "httpServerStartedCounter"),
            expectedMetrics: [MetricWithDimensions(label: "rewritten")],
            adapter: adapter,
            metrics: self.testMetrics
        )

        // No rewrite for other names
        self.assertCounterRewrite(
            originalMetric: MetricWithDimensions(label: "x"),
            expectedMetrics: [MetricWithDimensions(label: "x")],
            adapter: adapter,
            metrics: self.testMetrics
        )
    }

    /// Assert that when you send `originalMetric` to `adapter`, then `metrics` sees `expectedMetrics` instead
    func assertCounterRewrite(
        originalMetric: MetricWithDimensions,
        expectedMetrics: [MetricWithDimensions],
        adapter: MetricsFactory,
        metrics: TestMetrics,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let counter = adapter.makeCounter(label: originalMetric.label, dimensions: originalMetric.dimensions)
        counter.increment(by: 1)
        for expected in expectedMetrics {
            XCTAssertEqual(try metrics.expectCounter(expected.label, expected.dimensions).totalValue, 1, file: file, line: line)
        }
        if !expectedMetrics.contains(originalMetric) {
            XCTAssertThrowsError(try metrics.expectCounter(originalMetric.label, originalMetric.dimensions), file: file, line: line)
        }
        if expectedMetrics.count == 1 {
            // No need to use multiwriter if only one
            XCTAssertNil(counter as? MultiWritingCounter)
        } else {
            XCTAssertNotNil(counter as? MultiWritingCounter)
        }
    }

    func testDestroyCounter() {
        let adapter = RewritingMetricsHandler(underlying: testMetrics, rewriter: MetricRewriterFromClosure { _ in
            [MetricWithDimensions(label: "a"), MetricWithDimensions(label: "b")]
        })
        let counter = adapter.makeCounter(label: "x", dimensions: [])
        counter.increment(by: 1)

        // Underlying has 2 handlers
        XCTAssertNoThrow(try self.testMetrics.expectCounter("a"))
        XCTAssertNoThrow(try self.testMetrics.expectCounter("b"))

        adapter.destroyCounter(counter)
        // underlying metrics' destroy function should destroy both 'a' and 'b'
        XCTAssertThrowsError(try self.testMetrics.expectCounter("a"))
        XCTAssertThrowsError(try self.testMetrics.expectCounter("b"))
    }

    func testDestroyTimer() {
        let adapter = RewritingMetricsHandler(underlying: testMetrics, rewriter: MetricRewriterFromClosure { _ in
            [MetricWithDimensions(label: "a"), MetricWithDimensions(label: "b")]
        })
        let timer = adapter.makeTimer(label: "x", dimensions: [])
        timer.recordNanoseconds(1)

        // Underlying has 2 handlers
        XCTAssertNoThrow(try self.testMetrics.expectTimer("a"))
        XCTAssertNoThrow(try self.testMetrics.expectTimer("b"))

        adapter.destroyTimer(timer)
        // underlying metrics' destroy function should destroy both 'a' and 'b'
        XCTAssertThrowsError(try self.testMetrics.expectTimer("a"))
        XCTAssertThrowsError(try self.testMetrics.expectTimer("b"))
    }

    func testDestroyRecorder() {
        let adapter = RewritingMetricsHandler(underlying: testMetrics, rewriter: MetricRewriterFromClosure { _ in
            [MetricWithDimensions(label: "a"), MetricWithDimensions(label: "b")]
        })
        let recorder = adapter.makeRecorder(label: "x", dimensions: [], aggregate: false)
        recorder.record(1.0)

        // Underlying has 2 handlers
        XCTAssertNoThrow(try self.testMetrics.expectRecorder("a"))
        XCTAssertNoThrow(try self.testMetrics.expectRecorder("b"))

        adapter.destroyRecorder(recorder)
        // underlying metrics' destroy function should destroy both 'a' and 'b'
        XCTAssertThrowsError(try self.testMetrics.expectRecorder("a"))
        XCTAssertThrowsError(try self.testMetrics.expectRecorder("b"))
    }
}
