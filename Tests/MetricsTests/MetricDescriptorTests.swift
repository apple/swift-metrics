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

import CoreMetrics
import MetricsTestKit
import Testing

struct MetricDescriptorTests {
    // MARK: - MetricDescriptor

    @Test func descriptorDefaultsToNoDimensionsAndNoDescription() {
        let descriptor = MetricDescriptor(label: "my_metric")
        #expect(descriptor.label == "my_metric")
        #expect(descriptor.dimensions.isEmpty)
        #expect(descriptor.description == nil)
    }

    @Test func descriptorEquality() {
        let lhs = MetricDescriptor(label: "l", dimensions: [("a", "b")], description: "d")
        #expect(lhs == MetricDescriptor(label: "l", dimensions: [("a", "b")], description: "d"))
        #expect(lhs != MetricDescriptor(label: "other", dimensions: [("a", "b")], description: "d"))
        #expect(lhs != MetricDescriptor(label: "l", dimensions: [("a", "c")], description: "d"))
        #expect(lhs != MetricDescriptor(label: "l", dimensions: [("a", "b")], description: nil))
    }

    // MARK: - Descriptor-based metric creation

    @Test func counterCarriesDescriptionToBackend() throws {
        let metrics = TestMetrics()
        let descriptor = MetricDescriptor(
            label: "requests_total",
            dimensions: [("method", "GET")],
            description: "Total number of requests."
        )

        let counter = Counter(descriptor: descriptor, factory: metrics)
        counter.increment(by: 5)

        let testCounter = try metrics.expectCounter("requests_total", [("method", "GET")])
        #expect(testCounter.descriptor == descriptor)
        #expect(testCounter.descriptor.description == "Total number of requests.")
        #expect(testCounter.totalValue == 5)
        #expect(counter.label == "requests_total")
    }

    @Test func meterCarriesDescriptionToBackend() throws {
        let metrics = TestMetrics()
        let descriptor = MetricDescriptor(label: "temperature", description: "Current temperature in celsius.")

        let meter = Meter(descriptor: descriptor, factory: metrics)
        meter.set(21.5)

        let testMeter = try metrics.expectMeter("temperature")
        #expect(testMeter.descriptor.description == "Current temperature in celsius.")
        #expect(testMeter.lastValue == 21.5)
    }

    @Test func recorderCarriesDescriptionToBackend() throws {
        let metrics = TestMetrics()
        let descriptor = MetricDescriptor(label: "response_size", description: "Response sizes in bytes.")

        let recorder = Recorder(descriptor: descriptor, factory: metrics)
        recorder.record(1024)

        let testRecorder = try metrics.expectRecorder("response_size")
        #expect(testRecorder.descriptor.description == "Response sizes in bytes.")
        #expect(testRecorder.aggregate)
        #expect(testRecorder.lastValue == 1024)
    }

    @Test func gaugeCarriesDescriptionToBackend() throws {
        let metrics = TestMetrics()
        let descriptor = MetricDescriptor(label: "active_threads", description: "Number of active threads.")

        let gauge = Gauge(descriptor: descriptor, factory: metrics)
        gauge.record(7)

        let testRecorder = try metrics.expectGauge("active_threads")
        #expect(testRecorder.descriptor.description == "Number of active threads.")
        #expect(!testRecorder.aggregate)
        #expect(testRecorder.lastValue == 7)
    }

    @Test func timerCarriesDescriptionToBackend() throws {
        let metrics = TestMetrics()
        let descriptor = MetricDescriptor(label: "request_duration", description: "Request durations.")

        let timer = Timer(descriptor: descriptor, factory: metrics)
        timer.recordNanoseconds(42)

        let testTimer = try metrics.expectTimer("request_duration")
        #expect(testTimer.descriptor.description == "Request durations.")
        #expect(testTimer.lastValue == 42)
    }

    @Test func timerWithPreferredDisplayUnitCarriesDescriptionToBackend() throws {
        let metrics = TestMetrics()
        let descriptor = MetricDescriptor(label: "job_duration", description: "Job durations.")

        let timer = Timer(descriptor: descriptor, preferredDisplayUnit: .seconds, factory: metrics)
        timer.recordSeconds(2)

        let testTimer = try metrics.expectTimer("job_duration")
        #expect(testTimer.descriptor.description == "Job durations.")
        #expect(testTimer.displayUnit == .seconds)
        #expect(testTimer.valueInPreferredUnit(atIndex: 0) == 2.0)
    }

    @Test func floatingPointCounterFallsBackToWrappedCounter() throws {
        // TestMetrics does not natively support floating-point counters, so the default
        // accumulating implementation kicks in and wraps a regular counter. The description is
        // dropped by the compatibility fallback, but values must still flow.
        let metrics = TestMetrics()
        let descriptor = MetricDescriptor(label: "fp_total", description: "dropped by fallback")

        let counter = FloatingPointCounter(descriptor: descriptor, factory: metrics)
        counter.increment(by: 2.5)
        counter.increment(by: 2.5)

        let testCounter = try metrics.expectCounter("fp_total")
        #expect(testCounter.descriptor.description == nil)
        #expect(testCounter.totalValue == 5)
    }

    // MARK: - Backwards compatibility

    @Test func legacyFactoryReceivesLabelAndDimensionsViaDefaultImplementation() throws {
        let legacy = LegacyOnlyFactory()
        let descriptor = MetricDescriptor(
            label: "legacy_metric",
            dimensions: [("a", "b")],
            description: "not visible to legacy backends"
        )

        let counter = Counter(descriptor: descriptor, factory: legacy)
        counter.increment()

        let handler = try #require(legacy.counter)
        #expect(handler.label == "legacy_metric")
        #expect(handler.dimensions.count == 1)
        #expect(handler.values == [1])
    }

    @Test func legacyFactoryPathCreatesMetricWithoutDescription() throws {
        let metrics = TestMetrics()

        let counter = Counter(label: "no_description", dimensions: [], factory: metrics)
        counter.increment()

        let testCounter = try metrics.expectCounter("no_description")
        #expect(testCounter.descriptor == MetricDescriptor(label: "no_description"))
        #expect(testCounter.descriptor.description == nil)
    }

    @Test func descriptorAwareFactoryReceivesFullDescriptor() {
        let factory = DescriptorRecordingFactory()
        let descriptor = MetricDescriptor(label: "observed", description: "visible to aware backends")

        _ = Counter(descriptor: descriptor, factory: factory)
        _ = Timer(descriptor: descriptor, factory: factory)

        #expect(factory.receivedDescriptors == [descriptor, descriptor])
    }

    @Test func factoryReturnsSameHandlerForSameLabelAndDimensions() {
        let metrics = TestMetrics()
        let first = metrics.makeCounter(descriptor: MetricDescriptor(label: "dup", description: "first"))
        let second = metrics.makeCounter(descriptor: MetricDescriptor(label: "dup", description: "second"))
        #expect(first === second)
        #expect((first as? TestCounter)?.descriptor.description == "first")
    }

    // MARK: - Factory combinators

    @Test func multiplexForwardsDescriptorToAllFactories() throws {
        let first = TestMetrics()
        let second = TestMetrics()
        let multiplex = MultiplexMetricsHandler(factories: [first, second])
        let descriptor = MetricDescriptor(label: "muxed", description: "seen by all backends")

        let counter = Counter(descriptor: descriptor, factory: multiplex)
        counter.increment(by: 3)

        for metrics in [first, second] {
            let testCounter = try metrics.expectCounter("muxed")
            #expect(testCounter.descriptor.description == "seen by all backends")
            #expect(testCounter.totalValue == 3)
        }
    }

    @Test func mappingFactoryTransformsIdentityAndPreservesDescription() throws {
        let upstream = TestMetrics()
        let factory = upstream.withLabelAndDimensionsMapping { label, dimensions in
            ("prefix_\(label)", dimensions + [("service", "test")])
        }
        let descriptor = MetricDescriptor(label: "mapped", description: "survives mapping")

        let counter = Counter(descriptor: descriptor, factory: factory)
        counter.increment()

        let testCounter = try upstream.expectCounter("prefix_mapped", [("service", "test")])
        #expect(testCounter.descriptor.description == "survives mapping")
    }
}

// MARK: - Test fixtures

/// A factory that only implements the pre-descriptor `MetricsFactory` requirements, proving that
/// existing backend implementations keep compiling and working when metrics are created through
/// the descriptor-based APIs.
private final class LegacyOnlyFactory: MetricsFactory, @unchecked Sendable {
    private let lock = Lock()
    private var _counter: RecordingCounter?

    var counter: RecordingCounter? {
        self.lock.withLock { self._counter }
    }

    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        let counter = RecordingCounter(label: label, dimensions: dimensions)
        self.lock.withLockVoid { self._counter = counter }
        return counter
    }

    func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        NOOPMetricsHandler.instance.makeMeter(label: label, dimensions: dimensions)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        NOOPMetricsHandler.instance.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        NOOPMetricsHandler.instance.makeTimer(label: label, dimensions: dimensions)
    }

    func destroyCounter(_ handler: CounterHandler) {}
    func destroyMeter(_ handler: MeterHandler) {}
    func destroyRecorder(_ handler: RecorderHandler) {}
    func destroyTimer(_ handler: TimerHandler) {}

    final class RecordingCounter: CounterHandler, @unchecked Sendable {
        let label: String
        let dimensions: [(String, String)]
        private let lock = Lock()
        private var _values: [Int64] = []

        var values: [Int64] {
            self.lock.withLock { self._values }
        }

        init(label: String, dimensions: [(String, String)]) {
            self.label = label
            self.dimensions = dimensions
        }

        func increment(by amount: Int64) {
            self.lock.withLockVoid { self._values.append(amount) }
        }

        func reset() {
            self.lock.withLockVoid { self._values = [] }
        }
    }
}

/// A factory that implements the descriptor-based requirements and records every descriptor it
/// receives, proving that descriptor-aware backends are dispatched to through the protocol.
private final class DescriptorRecordingFactory: MetricsFactory, @unchecked Sendable {
    private let lock = Lock()
    private var _receivedDescriptors: [MetricDescriptor] = []

    var receivedDescriptors: [MetricDescriptor] {
        self.lock.withLock { self._receivedDescriptors }
    }

    private func record(_ descriptor: MetricDescriptor) {
        self.lock.withLockVoid { self._receivedDescriptors.append(descriptor) }
    }

    func makeCounter(descriptor: MetricDescriptor) -> CounterHandler {
        self.record(descriptor)
        return self.makeCounter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    func makeMeter(descriptor: MetricDescriptor) -> MeterHandler {
        self.record(descriptor)
        return self.makeMeter(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    func makeRecorder(descriptor: MetricDescriptor, aggregate: Bool) -> RecorderHandler {
        self.record(descriptor)
        return self.makeRecorder(label: descriptor.label, dimensions: descriptor.dimensions, aggregate: aggregate)
    }

    func makeTimer(descriptor: MetricDescriptor) -> TimerHandler {
        self.record(descriptor)
        return self.makeTimer(label: descriptor.label, dimensions: descriptor.dimensions)
    }

    func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        NOOPMetricsHandler.instance.makeCounter(label: label, dimensions: dimensions)
    }

    func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        NOOPMetricsHandler.instance.makeMeter(label: label, dimensions: dimensions)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        NOOPMetricsHandler.instance.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        NOOPMetricsHandler.instance.makeTimer(label: label, dimensions: dimensions)
    }

    func destroyCounter(_ handler: CounterHandler) {}
    func destroyMeter(_ handler: MeterHandler) {}
    func destroyRecorder(_ handler: RecorderHandler) {}
    func destroyTimer(_ handler: TimerHandler) {}
}
