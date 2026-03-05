//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import CoreMetrics
import MetricsTestKit
import Metrics

public func makeBenchmark(
    _ suffix: String = "",
    _ body: @escaping (Benchmark) -> Void
) {
    let iterations = 1_000_000
    let metrics: [BenchmarkMetric] = [.instructions, .objectAllocCount]

    Benchmark(
        "metrics_benchmark_\(suffix)",
        configuration: .init(
            metrics: metrics,
            maxIterations: iterations,
            thresholds: [
                .instructions: BenchmarkThresholds(
                    relative: [
                        .p90: 1.0  // we only record p90
                    ]
                ),
                .objectAllocCount: BenchmarkThresholds(
                    absolute: [
                        .p90: 0  // we only record p90
                    ]
                ),
            ]
        )
    ) { benchmark in
        body(benchmark)
    }
}


public let benchmarks: @Sendable () -> Void = {
    let metricsFactory = TestMetrics()
    MetricsSystem.bootstrap(metricsFactory)

    makeBenchmark("task-local-init") { benchmark in
        MetricsSystem.withCurrent(changingFactory: metricsFactory) {
            benchmark.startMeasurement()
            let _ = Timer(label: "test-timer")
            let _ = Counter(label: "test-counter")
            let _ = Gauge(label: "test-gauge")
            benchmark.stopMeasurement()
        }
    }
    makeBenchmark("explicit-init") { benchmark in
        benchmark.startMeasurement()
        let _ = Timer(label: "test-timer", factory: metricsFactory)
        let _ = Counter(label: "test-counter", factory: metricsFactory)
        let _ = Gauge(label: "test-gauge", factory: metricsFactory)
        benchmark.stopMeasurement()
    }
        MetricsSystem.withCurrent(changingFactory: metricsFactory) {
    makeBenchmark("explicit-init-with-current") { benchmark in
            benchmark.startMeasurement()
            let _ = Timer(label: "test-timer", factory: MetricsSystem.currentFactory)
            let _ = Counter(label: "test-counter", factory: MetricsSystem.currentFactory)
            let _ = Gauge(label: "test-gauge", factory: MetricsSystem.currentFactory)
            benchmark.stopMeasurement()
        }
    }
}
