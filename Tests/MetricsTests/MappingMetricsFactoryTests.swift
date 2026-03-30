//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2026 Apple Inc. and the Swift Metrics API project authors
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

struct MappingMetricsFactoryTests {
    // MARK: - All metric types

    @Test func counter() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions + [("env", "test")])
        }
        let counter = Counter(label: "requests", dimensions: [("method", "GET")], factory: mapped)
        counter.increment()
        let testCounter = try upstream.expectCounter("prefix.requests", [("method", "GET"), ("env", "test")])
        #expect(testCounter.lastValue == 1)
    }

    @Test func floatingPointCounter() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions + [("env", "test")])
        }
        let counter = FloatingPointCounter(label: "bytes", dimensions: [("direction", "in")], factory: mapped)
        counter.increment(by: 1.5)

        // FloatingPointCounter uses the default implementation which wraps a regular counter.
        // Verify it reached the upstream factory with the transformed label.
        let testCounter = try upstream.expectCounter(
            "prefix.bytes",
            [("direction", "in"), ("env", "test")]
        )
        #expect(testCounter.totalValue == 1)
    }

    @Test func meter() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions + [("env", "test")])
        }
        let meter = Meter(label: "temperature", dimensions: [("unit", "celsius")], factory: mapped)
        meter.set(42)
        let testMeter = try upstream.expectMeter("prefix.temperature", [("unit", "celsius"), ("env", "test")])
        #expect(testMeter.lastValue == 42.0)
    }

    @Test func recorder() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions + [("env", "test")])
        }
        let recorder = Recorder(label: "latency", dimensions: [("path", "/api")], factory: mapped)
        recorder.record(100)
        let testRecorder = try upstream.expectRecorder(
            "prefix.latency",
            [("path", "/api"), ("env", "test")]
        )
        #expect(testRecorder.lastValue == 100.0)
    }

    @Test func timer() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions + [("env", "test")])
        }
        let timer = Timer(label: "duration", dimensions: [("op", "query")], factory: mapped)
        timer.recordNanoseconds(500)
        let testTimer = try upstream.expectTimer("prefix.duration", [("op", "query"), ("env", "test")])
        #expect(testTimer.lastValue == 500)
    }

    // MARK: - Destroy lifecycle

    @Test func destroyCounter() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions)
        }
        let counter = Counter(label: "requests", factory: mapped)
        counter.increment()
        #expect(upstream.counters.count == 1)
        counter.destroy()
        #expect(upstream.counters.isEmpty)
    }

    @Test func destroyMeter() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions)
        }
        let meter = Meter(label: "temperature", factory: mapped)
        meter.set(42)
        #expect(upstream.meters.count == 1)
        meter.destroy()
        #expect(upstream.meters.isEmpty)
    }

    @Test func destroyRecorder() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions)
        }
        let recorder = Recorder(label: "latency", factory: mapped)
        recorder.record(100)
        #expect(upstream.recorders.count == 1)
        recorder.destroy()
        #expect(upstream.recorders.isEmpty)
    }

    @Test func destroyTimer() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            ("prefix.\(label)", dimensions)
        }
        let timer = Timer(label: "duration", factory: mapped)
        timer.recordNanoseconds(500)
        #expect(upstream.timers.count == 1)
        timer.destroy()
        #expect(upstream.timers.isEmpty)
    }

    // MARK: - Chaining

    @Test func chainingTransforms() throws {
        let upstream = TestMetrics()
        let mapped =
            upstream
            .mappingLabelsAndDimensions { label, dimensions in
                ("app.\(label)", dimensions)
            }
            .mappingLabelsAndDimensions { label, dimensions in
                (label, dimensions + [("region", "us-east-1")])
            }
        let counter = Counter(label: "requests", factory: mapped)
        counter.increment()
        let testCounter = try upstream.expectCounter("app.requests", [("region", "us-east-1")])
        #expect(testCounter.lastValue == 1)
    }

    // MARK: - Identity transform

    @Test func identityTransform() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            (label, dimensions)
        }
        let counter = Counter(label: "requests", dimensions: [("method", "GET")], factory: mapped)
        counter.increment()
        let testCounter = try upstream.expectCounter("requests", [("method", "GET")])
        #expect(testCounter.lastValue == 1)
    }
}
