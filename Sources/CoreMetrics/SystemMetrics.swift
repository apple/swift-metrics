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

internal class SystemMetricsHandler {
    fileprivate let queue = DispatchQueue(label: "com.apple.CoreMetrics.SystemMetricsHandler", qos: .background)
    fileprivate let timeInterval: DispatchTimeInterval
    fileprivate let systemMetricsType: SystemMetrics.Type
    fileprivate let labels: SystemMetricsLabels
    fileprivate let processId: Int
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
        self.processId = Int(ProcessInfo.processInfo.processIdentifier)

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
private struct LinuxSystemMetrics: SystemMetrics {
    let virtualMemoryBytes: Int?
    let residentMemoryBytes: Int?
    let startTimeSeconds: Int?
    let cpuSeconds: Int?
    let maxFds: Int?
    let openFds: Int?

    private enum SystemMetricsError: Error {
        case FileNotFound
    }

    init(pid: Int) {
        let pid = "\(pid)"
        let ticks = Int(_SC_CLK_TCK)
        do {
            guard let statString =
                try String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8)
                .split(separator: ")")
                .last
            else { throw SystemMetricsError.FileNotFound }
            let stats = String(statString)
                .split(separator: " ")
                .map(String.init)
            self.virtualMemoryBytes = Int(stats[safe: 20])
            if let rss = Int(stats[safe: 21]) {
                self.residentMemoryBytes = rss * Int(_SC_PAGESIZE)
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
            guard
                let line = try String(contentsOfFile: "/proc/\(pid)/limits", encoding: .utf8)
                .split(separator: "\n")
                .first(where: { $0.starts(with: "Max open file") })
                .map(String.init) else { throw SystemMetricsError.FileNotFound }
            self.maxFds = Int(line.split(separator: " ").map(String.init)[safe: 3])
        } catch {
            self.maxFds = nil
        }
        do {
            let fm = FileManager.default,
                items = try fm.contentsOfDirectory(atPath: "/proc/\(pid)/fd")
            self.openFds = items.count
        } catch {
            self.openFds = nil
        }
    }
}
#else
#warning("System Metrics are not implemented on non-Linux platforms yet.")
#endif

private struct NOOPSystemMetrics: SystemMetrics {
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
