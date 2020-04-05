//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2020 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch

#if os(Linux)
import Glibc
#endif

/// Options used to bootstrap `SystemMetricsHandler`
///
/// Libraries are advised to extend `SystemMetricsOptions` with a static instance for ease of use.
public struct SystemMetricsOptions {
    let interval: DispatchTimeInterval
    let metricsType: SystemMetrics.Type?
    let labels: SystemMetricsLabels
    
    /// Create new instance of `SystemMetricsOptions`
    ///
    /// - parameters:
    ///     - pollInterval: The interval at which system metrics should be updated.
    ///     - systemMetricsType: The type of system metrics to use. If none is provided this defaults to
    ///                          `LinuxSystemMetrics` on Linux platforms and `NOOPSystemMetrics` on all other platforms.
    ///     - labels: The labels to use for generated system metrics.
    public init(pollInterval interval: DispatchTimeInterval = .seconds(2), metricsType: SystemMetrics.Type? = nil, labels: SystemMetricsLabels) {
        self.interval = interval
        self.metricsType = metricsType
        self.labels = labels
    }
}

internal class SystemMetricsHandler {
    fileprivate let queue = DispatchQueue(label: "com.apple.CoreMetrics.SystemMetricsHandler", qos: .background)
    fileprivate let timeInterval: DispatchTimeInterval
    fileprivate let systemMetricsType: SystemMetrics.Type
    fileprivate let labels: SystemMetricsLabels
    fileprivate let processId: Int
    fileprivate var task: DispatchWorkItem?

    init(options: SystemMetricsOptions) {
        self.timeInterval = options.interval
        if let systemMetricsType = options.metricsType {
            self.systemMetricsType = systemMetricsType
        } else {
            #if os(Linux)
            self.systemMetricsType = LinuxSystemMetrics.self
            #else
            self.systemMetricsType = NOOPSystemMetrics.self
            #endif
        }
        self.labels = options.labels
        #if os(Windows)
        self.processId = 0
        #else
        self.processId = Int(getpid())
        #endif

        self.task = DispatchWorkItem(qos: .background, block: {
            let metrics = self.systemMetricsType.init(pid: self.processId)
            if let vmem = metrics.virtualMemoryBytes { Gauge(label: self.labels.label(for: \.virtualMemoryBytes)).record(vmem) }
            if let rss = metrics.residentMemoryBytes { Gauge(label: self.labels.label(for: \.residentMemoryBytes)).record(rss) }
            if let start = metrics.startTimeSeconds { Gauge(label: self.labels.label(for: \.startTimeSeconds)).record(start) }
            if let cpuSeconds = metrics.cpuSeconds { Gauge(label: self.labels.label(for: \.cpuSecondsTotal)).record(cpuSeconds) }
            if let maxFds = metrics.maxFds { Gauge(label: self.labels.label(for: \.maxFds)).record(maxFds) }
            if let openFds = metrics.openFds { Gauge(label: self.labels.label(for: \.openFds)).record(openFds) }
        })

        self.updateSystemMetrics()
    }

    internal func cancelSystemMetrics() {
        self.task?.cancel()
        self.task = nil
    }

    internal func updateSystemMetrics() {
        self.queue.asyncAfter(deadline: .now() + self.timeInterval) {
            guard let task = self.task else { return }
            task.perform()
            self.updateSystemMetrics()
        }
    }
}

public struct SystemMetricsLabels {
    let prefix: String
    let virtualMemoryBytes: String
    let residentMemoryBytes: String
    let startTimeSeconds: String
    let cpuSecondsTotal: String
    let maxFds: String
    let openFds: String

    public init(prefix: String, virtualMemoryBytes: String, residentMemoryBytes: String, startTimeSeconds: String, cpuSecondsTotal: String, maxFds: String, openFds: String) {
        self.prefix = prefix
        self.virtualMemoryBytes = virtualMemoryBytes
        self.residentMemoryBytes = residentMemoryBytes
        self.startTimeSeconds = startTimeSeconds
        self.cpuSecondsTotal = cpuSecondsTotal
        self.maxFds = maxFds
        self.openFds = openFds
    }

    func label(for keyPath: KeyPath<SystemMetricsLabels, String>) -> String {
        return self.prefix + self[keyPath: keyPath]
    }
}

public protocol SystemMetrics {
    init(pid: Int)

    var virtualMemoryBytes: Int? { get }
    var residentMemoryBytes: Int? { get }
    var startTimeSeconds: Int? { get }
    var cpuSeconds: Int? { get }
    var maxFds: Int? { get }
    var openFds: Int? { get }
}

#if os(Linux)
internal struct LinuxSystemMetrics: SystemMetrics {
    let virtualMemoryBytes: Int?
    let residentMemoryBytes: Int?
    let startTimeSeconds: Int?
    let cpuSeconds: Int?
    let maxFds: Int?
    let openFds: Int?

    private enum SystemMetricsError: Error {
        case MetricReadError
    }
    
    init(pid: Int) {
        let pid = "\(pid)"
        let ticks = _SC_CLK_TCK
        
        do {
            guard
                let fp = fopen("/proc/\(pid)/stat", "r")
            else { throw SystemMetricsError.MetricReadError }
            var buf = [CChar](repeating: CChar(0), count: 1024)
            while fgets(&buf, 1024, fp) != nil { }
            guard fclose(fp) == 0 else { throw SystemMetricsError.MetricReadError }
            guard
                let statString = String(cString: buf)
                .split(separator: ")")
                .last
            else { throw SystemMetricsError.MetricReadError }
            let stats = String(statString)
                .split(separator: " ")
                .map(String.init)
            self.virtualMemoryBytes = Int(stats[safe: 20])
            if let rss = Int(stats[safe: 21]) {
                self.residentMemoryBytes = rss * _SC_PAGESIZE
            } else {
                self.residentMemoryBytes = nil
            }
            if let startTimeTicks = Int(stats[safe: 19]) {
                self.startTimeSeconds = startTimeTicks / ticks
            } else {
                self.startTimeSeconds = nil
            }
            if let utimeTicks = Int(stats[safe: 11]), let stimeTicks = Int(stats[safe: 12]) {
                let utime = utimeTicks / ticks, stime = stimeTicks / ticks
                self.cpuSeconds = utime + stime
            } else {
                self.cpuSeconds = nil
            }
        } catch {
            self.virtualMemoryBytes = nil
            self.residentMemoryBytes = nil
            self.startTimeSeconds = nil
            self.cpuSeconds = nil
        }
        do {
            var _rlim = rlimit()
            
            guard getrlimit(__rlimit_resource_t(RLIMIT_NOFILE.rawValue), &_rlim) == 0 else { throw SystemMetricsError.MetricReadError }
            self.maxFds = Int(_rlim.rlim_max)
        } catch {
            self.maxFds = nil
        }
        do {
            guard let dir = opendir("/proc/\(pid)/fd") else { throw SystemMetricsError.MetricReadError }
            var count = 0
            while readdir(dir) != nil { count += 1 }
            guard closedir(dir) == 0 else { throw SystemMetricsError.MetricReadError }
            self.openFds = count
        } catch {
            self.openFds = nil
        }
    }
}
#else
#warning("System Metrics are not implemented on non-Linux platforms yet.")
#endif

internal struct NOOPSystemMetrics: SystemMetrics {
    let virtualMemoryBytes: Int?
    let residentMemoryBytes: Int?
    let startTimeSeconds: Int?
    let cpuSeconds: Int?
    let maxFds: Int?
    let openFds: Int?

    init(pid: Int) {
        self.virtualMemoryBytes = nil
        self.residentMemoryBytes = nil
        self.startTimeSeconds = nil
        self.cpuSeconds = nil
        self.maxFds = nil
        self.openFds = nil
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String {
        guard index >= 0, index < endIndex else {
            return ""
        }

        return self[index]
    }
}
