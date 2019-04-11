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
// MetricsTests+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension MetricsExtensionsTests {
    static var allTests: [(String, (MetricsExtensionsTests) -> () throws -> Void)] {
        return [
            ("testTimerBlock", testTimerBlock),
            ("testTimerWithTimeInterval", testTimerWithTimeInterval),
            ("testTimerWithDispatchTime", testTimerWithDispatchTime),
        ]
    }
}
