// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetricsBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MetricsBenchmarks", targets: ["MetricsBenchmarks"])
    ],
    dependencies: [
        // swift-metrics
        .package(name: "swift-metrics", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .executableTarget(
            name: "MetricsBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "CoreMetrics", package: "swift-metrics"),
                .product(name: "MetricsTestKit", package: "swift-metrics"),
            ],
            path: "Benchmarks/MetricsBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
