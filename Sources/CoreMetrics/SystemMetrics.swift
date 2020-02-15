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

import Foundation

@available(macOS 10.12, *)
public enum SystemMetricsProvider {
    fileprivate static let lock = ReadWriteLock()
    fileprivate static var shouldRunSystemMetrics: Bool = false

    public static func bootstrapSystemMetrics() {
        self.lock.withWriterLockVoid {
            self.shouldRunSystemMetrics = true
        }
        DispatchQueue.global(qos: .background).async {
            print("Starting loop")
            updateSystemMetrics()
        }
    }
    
    public static func cancelSystemMetrics() {
        self.lock.withWriterLockVoid {
            self.shouldRunSystemMetrics = false
        }
    }
    
    private enum SystemMetricsError: Error {
        case FileNotFound
    }
    
    fileprivate static func updateSystemMetrics() {
//        _ = Foundation.Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { (timer) in
            print("Inside timer")
//            let shouldReturn = self.lock.withReaderLock { () -> Bool in
//                if !self.shouldRunSystemMetrics {
//                    print("invalidating timer")
//                    timer.invalidate()
//                    return true
//                }
//                return false
//            }
//            if shouldReturn { return }
            print("Starting process grabbing")
            let prefix = "process_"
            let pid = ProcessInfo.processInfo.processIdentifier
            let ticks = Int32(_SC_CLK_TCK)
//            #if os(Linux)
            do {
                print("Do one")
                guard let statString =
                    try String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8)
                        .split(separator: ")")
                        .last
                    else { throw SystemMetricsError.FileNotFound }
                let stats = String(statString)
                        .split(separator: " ")
                        .map(String.init)
                print("Stats \(stats)")
                if let vmem = Int32(stats[20]) {
                    print("vmem \(vmem)")
                    Gauge(label: prefix + "virtual_memory_bytes").record(vmem)
                }
                if let rss = Int32(stats[21]) {
                    print("rss \(rss)")
                    Gauge(label: prefix + "resident_memory_bytes").record(rss * Int32(_SC_PAGESIZE))
                }
                if let startTimeTicks = Int32(stats[19]) {
                    print("startTime \(startTimeTicks / ticks)")
                    Gauge(label: prefix + "start_time_seconds").record(startTimeTicks / ticks)
                }
                if let utimeTicks = Int32(stats[11]), let stimeTicks = Int32(stats[12]) {
                    let utime = utimeTicks / ticks, stime = stimeTicks / ticks
                    print("cpu \(utime + stime)")
                    Gauge(label: prefix + "cpu_seconds_total").record(utime + stime)
                }
            } catch { print(error) }
            do {
                print("Do two")
                guard
                    let line = try String(contentsOfFile: "/proc/\(pid)/limits", encoding: .utf8)
                        .split(separator: "\n")
                        .first(where: { $0.starts(with: "Max open file") })
                        .map(String.init),
                    let maxFds = Int32(line.split(separator: " ").map(String.init)[3])
                else { throw SystemMetricsError.FileNotFound }
                Gauge(label: prefix + "max_fds").record(maxFds)
            } catch { print(error) }
            do {
                print("Do three")
                let fm = FileManager.default
                let items = try fm.contentsOfDirectory(atPath: "/proc/\(pid)/fd")
                Gauge(label: prefix + "open_fds").record(items.count)
            } catch { print(error) }
//            #else
//            print("Not sure what to do here just yet.")
//            #endif
//        }
    }
}
