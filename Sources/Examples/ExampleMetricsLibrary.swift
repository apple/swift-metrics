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
//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE
//

import Metrics

class ExampleMetricsLibrary: MetricsHandler {
    private let config: Config
    private let lock = NSLock()
    var counters = [ExampleCounter]()
    var recorders = [ExampleRecorder]()
    var gauges = [ExampleGauge]()
    var timers = [ExampleTimer]()

    init(config: Config = Config()) {
        self.config = config
    }

    func makeCounter(label: String, dimensions: [(String, String)]) -> Counter {
        return self.register(label: label, dimensions: dimensions, registry: &self.counters, maker: ExampleCounter.init)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> Recorder {
        let options = aggregate ? self.config.recorder.aggregationOptions : nil
        return self.makeRecorder(label: label, dimensions: dimensions, options: options)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], options: [AggregationOption]?) -> Recorder {
        guard let options = options else {
            return self.register(label: label, dimensions: dimensions, registry: &self.gauges, maker: ExampleGauge.init)
        }
        let maker = { (label: String, dimensions: [(String, String)]) -> ExampleRecorder in
            ExampleRecorder(label: label, dimensions: dimensions, options: options)
        }
        return self.register(label: label, dimensions: dimensions, registry: &self.recorders, maker: maker)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> Timer {
        return self.makeTimer(label: label, dimensions: dimensions, options: self.config.timer.aggregationOptions)
    }

    func makeTimer(label: String, dimensions: [(String, String)], options: [AggregationOption]) -> Timer {
        let maker = { (label: String, dimensions: [(String, String)]) -> ExampleTimer in
            ExampleTimer(label: label, dimensions: dimensions, options: options)
        }
        return self.register(label: label, dimensions: dimensions, registry: &self.timers, maker: maker)
    }

    func register<Item>(label: String, dimensions: [(String, String)], registry: inout [Item], maker: (String, [(String, String)]) -> Item) -> Item {
        let item = maker(label, dimensions)
        lock.withLock {
            registry.append(item)
        }
        return item
    }

    class Config {
        let recorder: RecorderConfig
        let timer: TimerConfig
        init(recorder: RecorderConfig = RecorderConfig(), timer: TimerConfig = TimerConfig()) {
            self.recorder = recorder
            self.timer = timer
        }
    }

    class RecorderConfig {
        let aggregationOptions: [AggregationOption]
        init(aggregationOptions: [AggregationOption]) {
            self.aggregationOptions = aggregationOptions
        }

        init() {
            self.aggregationOptions = AggregationOption.defaults
        }
    }

    class TimerConfig {
        let aggregationOptions: [AggregationOption]
        init(aggregationOptions: [AggregationOption]) {
            self.aggregationOptions = aggregationOptions
        }

        init() {
            self.aggregationOptions = AggregationOption.defaults
        }
    }
}

class ExampleCounter: Counter, CustomStringConvertible {
    let label: String
    let dimensions: [(String, String)]
    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
    }

    let lock = NSLock()
    var value: Int64 = 0
    func increment<DataType: BinaryInteger>(_ value: DataType) {
        self.lock.withLock {
            self.value += Int64(value)
        }
    }

    var description: String {
        return "counter [label: \(self.label) dimensions:\(self.dimensions) values:\(self.value)]"
    }
}

class ExampleRecorder: Recorder, CustomStringConvertible {
    let label: String
    let dimensions: [(String, String)]
    let options: [AggregationOption]
    init(label: String, dimensions: [(String, String)], options: [AggregationOption]) {
        self.label = label
        self.dimensions = dimensions
        self.options = options
    }

    private let lock = NSLock()
    var values = [(Int64, Double)]()
    func record<DataType: BinaryInteger>(_ value: DataType) {
        self.record(Double(value))
    }

    func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
        // this may loose percision, but good enough as an example
        let v = Double(value)
        // TODO: sliding window
        lock.withLock {
            values.append((Date().nanoSince1970, v))
        }
        options.forEach { option in
            switch option {
            case .count:
                self.count += 1
            case .sum:
                self.sum += v
            case .min:
                if 0 == self.min || v < self.min { self.min = v }
            case .max:
                if 0 == self.max || v > self.max { self.max = v }
            case .quantiles(let items):
                self.computeQuantiles(items)
            }
        }
    }

    var _sum: Double = 0
    var sum: Double {
        get {
            return self.lock.withLock { _sum }
        }
        set {
            self.lock.withLock { _sum = newValue }
        }
    }

    private var _count: Int = 0
    var count: Int {
        get {
            return self.lock.withLock { _count }
        }
        set {
            self.lock.withLock { _count = newValue }
        }
    }

    private var _min: Double = 0
    var min: Double {
        get {
            return self.lock.withLock { _min }
        }
        set {
            self.lock.withLock { _min = newValue }
        }
    }

    private var _max: Double = 0
    var max: Double {
        get {
            return self.lock.withLock { _max }
        }
        set {
            self.lock.withLock { _max = newValue }
        }
    }

    private var _quantiels = [Float: Double]()
    var quantiels: [Float: Double] {
        get {
            return self.lock.withLock { _quantiels }
        }
        set {
            self.lock.withLock { _quantiels = newValue }
        }
    }

    var description: String {
        return "recorder [label: \(self.label) dimensions:\(self.dimensions) count:\(self.count) sum:\(self.sum) min:\(self.min) max:\(self.max) quantiels:\(self.quantiels) values:\(self.values)]"
    }

    // TODO: offload calcs to queue
    private func computeQuantiles(_ items: [Float]) {
        self.lock.withLock {
            self._quantiels.removeAll()
            items.forEach { item in
                if let result = Sigma.quantiles.method1(self.values.map { Double($0.1) }, probability: Double(item)) {
                    self._quantiels[item] = result
                }
            }
        }
    }
}

class ExampleGauge: Recorder, CustomStringConvertible {
    let label: String
    let dimensions: [(String, String)]
    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
    }

    let lock = NSLock()
    var _value: Double = 0
    func record<DataType: BinaryInteger>(_ value: DataType) {
        self.record(Double(value))
    }

    func record<DataType: BinaryFloatingPoint>(_ value: DataType) {
        // this may loose percision but good enough as an example
        self.lock.withLock { _value = Double(value) }
    }

    var description: String {
        return "gauge [label: \(self.label) dimensions:\(self.dimensions) value:\(self._value)]"
    }
}

class ExampleTimer: ExampleRecorder, Timer {
    func recordNanoseconds(_ duration: Int64) {
        super.record(duration)
    }

    override var description: String {
        return "timer [label: \(self.label) dimensions:\(self.dimensions) count:\(self.count) sum:\(self.sum) min:\(self.min) max:\(self.max) quantiels:\(self.quantiels) values:\(self.values)]"
    }
}

enum AggregationOption {
    case count
    case sum
    case min
    case max
    case quantiles(_ items: [Float])

    public static let defaults: [AggregationOption] = [.count, .sum, .min, .max, .quantiles(defaultQuantiles)]
    public static let defaultQuantiles: [Float] = [0.25, 0.5, 0.75, 0.9, 0.95, 0.99]
}

private extension Foundation.Date {
    var nanoSince1970: Int64 {
        return Int64(self.timeIntervalSince1970 * 1_000_000_000)
    }
}

private extension Foundation.NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
