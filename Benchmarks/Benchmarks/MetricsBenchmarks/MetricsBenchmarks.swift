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
    _ body: @escaping (MetricsFactory) -> Void
) {
    let iterations = 1_000_000
    let metrics: [BenchmarkMetric] = [.instructions, .objectAllocCount]

    let metricsFactory = TestMetrics()
    MetricsSystem.bootstrap(metricsFactory)

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
        // This is used to measure the metrics init performance with Task-Local object
        MetricsSystem.withCurrent(changingFactory: metricsFactory) {
            benchmark.startMeasurement()
            body(metricsFactory)
            benchmark.stopMeasurement()
        }
    }
}


public let benchmarks: @Sendable () -> Void = {
    makeBenchmark("init") { _ in
        let timer = Timer(label: "test-timer")
        let counter = Counter(label: "test-counter")
        let gauge = Gauge(label: "test-gauge")
    }
}
