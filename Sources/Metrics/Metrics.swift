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

extension Timer {
    /// Convenience for measuring duration of a closure.
    ///
    /// - parameters:
    ///     - label: The label for the Timer.
    ///     - dimensions: The dimensions for the Timer.
    ///     - body: Closure to run & record.
    @inlinable
    public static func measure<T>(label: String, dimensions: [(String, String)] = [], body: @escaping () throws -> T) rethrows -> T {
        let timer = Timer(label: label, dimensions: dimensions)
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let delta = DispatchTime.now().uptimeNanoseconds - start
            timer.recordNanoseconds(delta)
        }
        return try body()
    }

    /// Record the time interval (with nanosecond precision) between the passed `since` dispatch time and `end` dispatch time.
    ///
    /// - parameters:
    ///   - since: Start of the interval as `DispatchTime`.
    ///   - end: End of the interval, defaulting to `.now()`.
    public func recordInterval(since: DispatchTime, end: DispatchTime = .now()) {
        self.recordNanoseconds(end.uptimeNanoseconds - since.uptimeNanoseconds)
    }
}

extension Timer {
    /// Convenience for recording a duration based on TimeInterval.
    ///
    /// - parameters:
    ///     - duration: The duration to record.
    @inlinable
    public func record(_ duration: TimeInterval) {
        self.recordSeconds(duration)
    }

    /// Convenience for recording a duration based on DispatchTimeInterval.
    ///
    /// - parameters:
    ///     - duration: The duration to record.
    @inlinable
    public func record(_ duration: DispatchTimeInterval) {
        switch duration {
        case .nanoseconds(let value):
            self.recordNanoseconds(value)
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

#if swift(>=5.7)

public enum TimerError: Error {
    case durationToIntOverflow
}

extension Timer {
    /// Convenience for recording a duration based on ``Duration``.
    ///
    /// `Duration` will be converted to an `Int64` number of nanoseconds, and then recorded with nanosecond precision.
    ///
    /// - Parameters:
    ///     - duration: The `Duration` to record.
    ///
    /// - Throws: `TimerError.durationToIntOverflow` if conversion from `Duration` to `Int64` of Nanoseconds overflowed.
    @available(macOS 13, iOS 16, tvOS 15, watchOS 8, *)
    @inlinable
    public func record(_ duration: Duration) {
        // `Duration` doesn't have a nice way to convert it nanoseconds or seconds,
        // and manual conversion can overflow.
        let seconds = duration.components.seconds.multipliedReportingOverflow(by: 1_000_000_000)
        guard !seconds.overflow else { return self.recordNanoseconds(Int64.max) }

        let nanoseconds = seconds.partialValue.addingReportingOverflow(duration.components.attoseconds / 1_000_000_000)
        guard !nanoseconds.overflow else { return self.recordNanoseconds(Int64.max) }

        self.recordNanoseconds(nanoseconds.partialValue)
    }
}
#endif
