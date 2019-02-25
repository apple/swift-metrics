@_exported import CoreMetrics
@_exported import class CoreMetrics.Timer
@_exported import Foundation

// Convenience for measuring duration of a closure
public extension Timer {
    @inlinable
    public static func measure<T>(label: String, dimensions: [(String, String)] = [], body: @escaping () throws -> T) rethrows -> T {
        let timer = Timer(label: label, dimensions: dimensions)
        let start = Date()
        defer {
            timer.record(Date().timeIntervalSince(start))
        }
        return try body()
    }
}

// Convenience for using Foundation and Dispatch
public extension Timer {
    @inlinable
    public func record(_ duration: TimeInterval) {
        self.recordSeconds(duration)
    }

    @inlinable
    public func record(_ duration: DispatchTimeInterval) {
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
