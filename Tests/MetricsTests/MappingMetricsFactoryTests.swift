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

import Foundation
import MetricsTestKit
import Testing

@testable import CoreMetrics

struct MappingMetricsFactoryTests {
    @Test func mapping() throws {
        let upstream = TestMetrics()
        let mapped = upstream.mappingLabelsAndDimensions { label, dimensions in
            return (String(label.reversed()), dimensions.map { (String($0.reversed()), $1) })
        }
        Counter(
            label: "foo_bar",
            dimensions: [("dim1", "abcd")],
            factory: mapped
        ).increment()
        let counter = try #require(upstream.counters.first)
        #expect(counter.label == "rab_oof")
        let firstDimension = try #require(counter.dimensions.first)
        #expect(firstDimension == ("1mid", "abcd"))
    }
}