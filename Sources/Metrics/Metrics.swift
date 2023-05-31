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
    @available(*, deprecated, message: "Please use non-static version on an already created Timer")
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

#if (os(macOS) && swift(>=5.7.1)) || (!os(macOS) && swift(>=5.7))
extension Timer {
    /// Convenience for recording a duration based on Duration.
    ///
    /// - parameters:
    ///     - duration: The duration to record.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public func record(duration: Duration) {
        self.recordNanoseconds(duration.nanosecondsClamped)
    }

    /// Convenience for recording a duration since Instant using provided Clock
    ///
    /// - parameters:
    ///     - instant: The instant to measure duration since
    ///     - clock: The clock to measure duration with
    @inlinable
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public func recordDurationSince<C: Clock>(
        instant: C.Instant,
        clock: C = ContinuousClock.continuous
    ) where C.Duration == Duration {
        self.record(duration: instant.duration(to: clock.now))
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
internal extension Swift.Duration {
    /// The duration represented as nanoseconds, clamped to maximum expressible value.
    var nanosecondsClamped: Int64 {
        let components = self.components

        let secondsComponentNanos = components.seconds.multipliedReportingOverflow(by: 1_000_000_000)
        let attosCompononentNanos = components.attoseconds / 1_000_000_000
        let combinedNanos = secondsComponentNanos.partialValue.addingReportingOverflow(attosCompononentNanos)

        guard
            !secondsComponentNanos.overflow,
            !combinedNanos.overflow
        else {
            return .max
        }

        return combinedNanos.partialValue
    }
}

extension Timer {
    /// Convenience for measuring duration of a closure
    ///
    /// - parameters:
    ///     - body: Closure to run & record.
    @inlinable
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public func measure<T>(
        body: @escaping () throws -> T
    ) rethrows -> T {
        let start = ContinuousClock.continuous.now
        defer {
            self.recordDurationSince(instant: start, clock: ContinuousClock.continuous)
        }
        return try body()
    }

    /// Convenience for measuring duration of an async closure with a provided clock
    ///
    /// - parameters:
    ///     - clock: The clock to measure closure duration with
    ///     - body: Closure to run & record.
    @inlinable
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public func measure<T, C: Clock>(
        clock: C = ContinuousClock.continuous,
        body: @escaping () async throws -> T
    ) async rethrows -> T where C.Duration == Duration {
        let start = clock.now
        defer {
            self.recordDurationSince(instant: start, clock: clock)
        }
        return try await body()
    }
}

#endif // (os(macOS) && swift(>=5.7.1)) || (!os(macOS) && swift(>=5.7))
