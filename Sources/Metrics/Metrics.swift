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

@_exported import CoreMetrics
@_exported import class CoreMetrics.Timer
import Foundation

public extension Timer {
    /// Convenience for measuring duration of a closure.
    ///
    /// - parameters:
    ///     - label: The label for the Timer.
    ///     - dimensions: The dimensions for the Timer.
    ///     - body: Closure to run & record.
    @inlinable
    static func measure<T>(label: String, dimensions: [(String, String)] = [], body: @escaping () throws -> T) rethrows -> T {
        let timer = Timer(label: label, dimensions: dimensions)
        let start = Date()
        defer {
            timer.record(Date().timeIntervalSince(start))
        }
        return try body()
    }
}

public extension Timer {
    /// Convenience for recording a duration based on TimeInterval.
    ///
    /// - parameters:
    ///     - duration: The duration to record.
    @inlinable
    func record(_ duration: TimeInterval) {
        self.recordSeconds(duration)
    }

    /// Convenience for recording a duration based on DispatchTimeInterval.
    ///
    /// - parameters:
    ///     - duration: The duration to record.
    @inlinable
    func record(_ duration: DispatchTimeInterval) {
        switch duration {
        case .nanoseconds(let value):
            self.recordNanoseconds(Int64(value))
        case .microseconds(let value):
            self.recordMicroseconds(value)
        case .milliseconds(let value):
            self.recordMilliseconds(value)
        case .seconds(let value):
            self.recordSeconds(value)
        case .never:
            self.record(0)
        }
    }
}
