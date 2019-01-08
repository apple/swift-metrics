@_exported import CoreMetrics
@_exported import protocol CoreMetrics.Timer
@_exported import Foundation

public extension MetricsHandler {
    @inlinable
    func timed<T>(label: String, dimensions: [(String, String)] = [], body: @escaping () throws -> T) rethrows -> T {
        let timer = self.makeTimer(label: label, dimensions: dimensions)
        let start = Date()
        defer {
            timer.record(Date().timeIntervalSince(start))
        }
        return try body()
    }
}

public extension Timer {
    @inlinable
    func record(_ duration: TimeInterval) {
        self.recordSeconds(duration)
    }

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
