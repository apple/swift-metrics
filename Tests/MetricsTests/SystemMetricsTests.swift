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

@testable import CoreMetrics
import XCTest
#if os(Linux)
import Glibc
#endif

class SystemMetricsTest: XCTestCase {
    func testSystemMetricsGeneration() throws {
        #if os(Linux)
        let metrics = LinuxSystemMetrics(pid: Int(getpid()))
        #else
        let metrics = NOOPSystemMetrics(pid: 0)
        throw XCTSkip()
        #endif
        XCTAssertNotNil(metrics.virtualMemoryBytes)
        XCTAssertNotNil(metrics.residentMemoryBytes)
        XCTAssertNotNil(metrics.startTimeSeconds)
        XCTAssertNotNil(metrics.cpuSeconds)
        XCTAssertNotNil(metrics.maxFds)
        XCTAssertNotNil(metrics.openFds)
    }
}
