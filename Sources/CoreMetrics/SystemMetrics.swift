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

import Combine
import Foundation

@available(OSX 10.15, *)
public enum SystemMetricsProvider {
    fileprivate static let lock = ReadWriteLock()
    fileprivate static let queue = DispatchQueue(label: "com.apple.CoreMetrics.SystemMetricsProvider", qos: .background)
    fileprivate static var timeInterval: DispatchTimeInterval = .seconds(2)
    fileprivate static var cancellable: Cancellable?
    fileprivate static var systemMetricsType: SystemMetrics.Type = UnsuportedMetricsProvider.self

    public static func bootstrapSystemMetrics(pollInterval interval: DispatchTimeInterval = .seconds(2), systemMetricsType: SystemMetrics.Type? = nil) {
        self.lock.withWriterLockVoid {
            self.timeInterval = interval
            if let type = systemMetricsType {
                self.systemMetricsType = type
            } else {
                #if os(Linux)
                self.systemMetricsType = LinuxSystemMetricsProvider.self
                #else
                self.systemMetricsType = UnsuportedMetricsProvider.self
                #endif
            }
        }
        self.updateSystemMetrics()
    }

    public static func cancelSystemMetrics() {
        self.cancellable?.cancel()
    }

    fileprivate static func updateSystemMetrics() {
        let interval = self.lock.withReaderLock { self.timeInterval }
        let c = self.queue.schedule(after: .init(.now()), interval: .init(interval)) {
            let prefix = "process_"
            let pid = ProcessInfo.processInfo.processIdentifier
            let metrics = self.systemMetricsType.init(pid: "\(pid)")
            if let vmem = metrics.virtualMemory { Gauge(label: prefix + "virtual_memory_bytes").record(vmem) }
            if let rss = metrics.residentMemory { Gauge(label: prefix + "resident_memory_bytes").record(rss) }
            if let start = metrics.startTimeSeconds { Gauge(label: prefix + "start_time_seconds").record(start) }
            if let cpuSeconds = metrics.cpuSeconds { Gauge(label: prefix + "cpu_seconds_total").record(cpuSeconds) }
            if let maxFds = metrics.maxFds { Gauge(label: prefix + "max_fds").record(maxFds) }
            if let openFds = metrics.openFds { Gauge(label: prefix + "open_fds").record(openFds) }
        }
        self.lock.withWriterLockVoid {
            self.cancellable = c
        }
    }
}

public protocol SystemMetrics {
    init(pid: String)

    var virtualMemory: Int32? { get }
    var residentMemory: Int32? { get }
    var startTimeSeconds: Int32? { get }
    var cpuSeconds: Int32? { get }
    var maxFds: Int32? { get }
    var openFds: Int32? { get }
}

#if os(Linux)
private struct LinuxSystemMetricsProvider: SystemMetrics {
    let virtualMemory: Int32?
    let residentMemory: Int32?
    let startTimeSeconds: Int32?
    let cpuSeconds: Int32?
    let maxFds: Int32?
    let openFds: Int32?

    private enum SystemMetricsError: Error {
        case FileNotFound
    }

    init(pid: String) {
        let ticks = Int32(_SC_CLK_TCK)
        do {
            guard let statString =
                try String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8)
                .split(separator: ")")
                .last
            else { throw SystemMetricsError.FileNotFound }
            let stats = String(statString)
                .split(separator: " ")
                .map(String.init)
            self.virtualMemory = Int32(stats[safe: 20])
            if let rss = Int32(stats[safe: 21]) {
                self.residentMemory = rss * Int32(_SC_PAGESIZE)
            } else {
                self.residentMemory = nil
            }
            if let startTimeTicks = Int32(stats[safe: 19]) {
                self.startTimeSeconds = startTimeTicks / ticks
            } else {
                self.startTimeSeconds = nil
            }
            if let utimeTicks = Int32(stats[safe: 11]), let stimeTicks = Int32(stats[safe: 12]) {
                let utime = utimeTicks / ticks, stime = stimeTicks / ticks
                self.cpuSeconds = utime + stime
            } else {
                self.cpuSeconds = nil
            }
        } catch {
            self.virtualMemory = nil
            self.residentMemory = nil
            self.startTimeSeconds = nil
            self.cpuSeconds = nil
        }
        do {
            guard
                let line = try String(contentsOfFile: "/proc/\(pid)/limits", encoding: .utf8)
                .split(separator: "\n")
                .first(where: { $0.starts(with: "Max open file") })
                .map(String.init) else { throw SystemMetricsError.FileNotFound }
            self.maxFds = Int32(line.split(separator: " ").map(String.init)[safe: 3])
        } catch {
            self.maxFds = nil
        }
        do {
            let fm = FileManager.default,
                items = try fm.contentsOfDirectory(atPath: "/proc/\(pid)/fd")
            self.openFds = Int32(items.count)
        } catch {
            self.openFds = nil
        }
    }
}

#else
private struct UnsuportedMetricsProvider: SystemMetrics {
    let virtualMemory: Int32?
    let residentMemory: Int32?
    let startTimeSeconds: Int32?
    let cpuSeconds: Int32?
    let maxFds: Int32?
    let openFds: Int32?

    init(pid: String) {
        #warning("System Metrics are not implemented on non-Linux platforms yet.")
        self.virtualMemory = nil
        self.residentMemory = nil
        self.startTimeSeconds = nil
        self.cpuSeconds = nil
        self.maxFds = nil
        self.openFds = nil
    }
}
#endif

private extension Array where Element == String {
    subscript(safe index: Int) -> String {
        guard index >= 0, index < endIndex else {
            return ""
        }

        return self[index]
    }
}
