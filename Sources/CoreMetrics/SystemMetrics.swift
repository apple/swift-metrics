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

import Foundation

#if os(Windows)
public typealias ProcessId = DWORD
#else
public typealias ProcessId = pid_t
#endif

internal class SystemMetricsHandler {
    fileprivate let queue = DispatchQueue(label: "com.apple.CoreMetrics.SystemMetricsHandler", qos: .background)
    fileprivate let timeInterval: DispatchTimeInterval
    fileprivate let systemMetricsType: SystemMetrics.Type
    fileprivate let labels: SystemMetricsLabels
    fileprivate let processId: ProcessId
    fileprivate var task: DispatchWorkItem?
    
    init(pollInterval interval: DispatchTimeInterval = .seconds(2), systemMetricsType: SystemMetrics.Type? = nil, labels: SystemMetricsLabels) {
        self.timeInterval = interval
        if let systemMetricsType = systemMetricsType {
            self.systemMetricsType = systemMetricsType
        } else {
            #if os(Linux)
            self.systemMetricsType = LinuxSystemMetrics.self
            #else
            self.systemMetricsType = NOOPSystemMetrics.self
            #endif
        }
        self.labels = labels
        self.processId = ProcessInfo.processInfo.processIdentifier
        
        self.task = DispatchWorkItem(qos: .background, block: {
            let metrics = self.systemMetricsType.init(pid: self.processId)
            if let vmem = metrics.virtualMemory { Gauge(label: self.labels.label(for: \.virtualMemory)).record(vmem) }
            if let rss = metrics.residentMemory { Gauge(label: self.labels.label(for: \.residentMemory)).record(rss) }
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
    let virtualMemory: String
    let residentMemory: String
    let startTimeSeconds: String
    let cpuSecondsTotal: String
    let maxFds: String
    let openFds: String
    
    public init(prefix: String, virtualMemory: String, residentMemory: String, startTimeSeconds: String, cpuSecondsTotal: String, maxFds: String, openFds: String) {
        self.prefix = prefix
        self.virtualMemory = virtualMemory
        self.residentMemory = residentMemory
        self.startTimeSeconds = startTimeSeconds
        self.cpuSecondsTotal = cpuSecondsTotal
        self.maxFds = maxFds
        self.openFds = openFds
    }
    
    func label(for keyPath: KeyPath<SystemMetricsLabels, String>) -> String {
        return prefix + self[keyPath: keyPath]
    }
}

public protocol SystemMetrics {
    init(pid: ProcessId)

    var virtualMemory: Int32? { get }
    var residentMemory: Int32? { get }
    var startTimeSeconds: Int32? { get }
    var cpuSeconds: Int32? { get }
    var maxFds: Int32? { get }
    var openFds: Int32? { get }
}

#if os(Linux)
private struct LinuxSystemMetrics: SystemMetrics {
    let virtualMemory: Int32?
    let residentMemory: Int32?
    let startTimeSeconds: Int32?
    let cpuSeconds: Int32?
    let maxFds: Int32?
    let openFds: Int32?

    private enum SystemMetricsError: Error {
        case FileNotFound
    }

    init(pid: ProcessId) {
        let pid = "\(pid)"
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
#warning("System Metrics are not implemented on non-Linux platforms yet.")
#endif

private struct NOOPSystemMetrics: SystemMetrics {
    let virtualMemory: Int32?
    let residentMemory: Int32?
    let startTimeSeconds: Int32?
    let cpuSeconds: Int32?
    let maxFds: Int32?
    let openFds: Int32?

    init(pid: ProcessId) {
        self.virtualMemory = nil
        self.residentMemory = nil
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
