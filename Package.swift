// swift-tools-version:4.2
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
        .library(name: "MetricsUtil", targets: ["MetricsUtil"]),
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
            name: "MetricsUtil",
            dependencies: ["CoreMetrics"]
        ),
        .testTarget(
            name: "MetricsTests",
            dependencies: ["Metrics"]
        ),
    ]
)
