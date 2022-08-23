// swift-tools-version:5.6
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

import PackageDescription

let package = Package(
    name: "swift-metrics",
    products: [
        .library(name: "CoreMetrics", targets: ["CoreMetrics"]),
        .library(name: "Metrics", targets: ["Metrics"]),
        .library(name: "MetricsTestKit", targets: ["MetricsTestKit"]),
    ],
    dependencies: [
        // ~~~ SwiftPM Plugins ~~~
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
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
        .target(
            name: "MetricsTestKit",
            dependencies: ["Metrics"]
        ),
        .testTarget(
            name: "MetricsTests",
            dependencies: ["Metrics"]
        ),
    ]
)
