// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "metrics",
    products: [
        .library(name: "CoreMetrics", targets: ["CoreMetrics"]),
        .library(name: "Metrics", targets: ["Metrics"]),
    ],
    targets: [
        .target(
            name: "CoreMetrics",
            dependencies: []
        ),
        .target(
            name: "Metrics",
            dependencies: ["CoreMetrics"]
        ),
        .testTarget(
            name: "MetricsTests",
            dependencies: ["Metrics"]
        ),
    ]
)
