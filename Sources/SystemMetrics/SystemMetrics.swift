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

import CoreMetrics
import Dispatch

#if os(Linux)
import Glibc
#endif

extension MetricsSystem {
    fileprivate static var systemMetricsProvider: SystemMetricsProvider?

    /// `bootstrapWithSystemMetrics` is an one-time configuration function which globally selects the desired metrics backend
    /// implementation, and enables system level metrics. `bootstrapWithSystemMetrics` can be called at maximum once in any given program,
    /// calling it more than once will lead to undefined behaviour, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A factory that given an identifier produces instances of metrics handlers such as `CounterHandler`, `RecorderHandler` and `TimerHandler`.
    ///     - config: Used to configure `SystemMetrics`.
    public static func bootstrapWithSystemMetrics(_ factory: MetricsFactory, config: SystemMetrics.Configuration) {
        self.bootstrap(factory)
        self.bootstrapSystemMetrics(config)
    }

    /// `bootstrapSystemMetrics` is an one-time configuration function which globally enables system level metrics.
    /// `bootstrapSystemMetrics` can be called at maximum once in any given program, calling it more than once will lead to
    /// undefined behaviour, most likely a crash.
    ///
    /// - parameters:
    ///     - config: Used to configure `SystemMetrics`.
    public static func bootstrapSystemMetrics(_ config: SystemMetrics.Configuration) {
        self.lock.withWriterLock {
            precondition(self.systemMetricsProvider == nil, "System metrics already bootstrapped.")
            self.systemMetricsProvider = SystemMetricsProvider(config: config)
        }
    }

    internal class SystemMetricsProvider {
        fileprivate let queue = DispatchQueue(label: "com.apple.CoreMetrics.SystemMetricsHandler", qos: .background)
        fileprivate let timeInterval: DispatchTimeInterval
        fileprivate let dataProvider: SystemMetrics.DataProvider
        fileprivate let labels: SystemMetrics.Labels
        fileprivate let timer: DispatchSourceTimer

        init(config: SystemMetrics.Configuration) {
            self.timeInterval = config.interval
            self.dataProvider = config.dataProvider
            self.labels = config.labels
            self.timer = DispatchSource.makeTimerSource(queue: self.queue)

            self.timer.setEventHandler(handler: DispatchWorkItem(block: { [weak self] in
                guard let self = self, let metrics = self.dataProvider() else { return }
                Gauge(label: self.labels.label(for: \.virtualMemoryBytes)).record(metrics.virtualMemoryBytes)
                Gauge(label: self.labels.label(for: \.residentMemoryBytes)).record(metrics.residentMemoryBytes)
                Gauge(label: self.labels.label(for: \.startTimeSeconds)).record(metrics.startTimeSeconds)
                Gauge(label: self.labels.label(for: \.cpuSecondsTotal)).record(metrics.cpuSeconds)
                Gauge(label: self.labels.label(for: \.maxFileDescriptors)).record(metrics.maxFileDescriptors)
                Gauge(label: self.labels.label(for: \.openFileDescriptors)).record(metrics.openFileDescriptors)
            }))

            self.timer.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)

            if #available(OSX 10.12, *) {
                self.timer.activate()
            } else {
                self.timer.resume()
            }
        }

        deinit {
            self.timer.cancel()
        }
    }
}

public enum SystemMetrics {
    /// Provider used by `SystemMetrics` to get the requested `SystemMetrics.Data`.
    ///
    /// Defaults are currently only provided for linux. (`SystemMetrics.linuxSystemMetrics`)
    public typealias DataProvider = () -> SystemMetrics.Data?

    /// Configuration used to bootstrap `SystemMetrics`.
    ///
    /// Backend implementations are encouraged to extend `SystemMetrics.Configuration` with a static extension with
    /// defaults that suit their specific backend needs.
    public struct Configuration {
        let interval: DispatchTimeInterval
        let dataProvider: SystemMetrics.DataProvider
        let labels: SystemMetrics.Labels

        /// Create new instance of `SystemMetricsOptions`
        ///
        /// - parameters:
        ///     - pollInterval: The interval at which system metrics should be updated.
        ///     - dataProvider: The provider to get SystemMetrics data from. If none is provided this defaults to
        ///                     `SystemMetrics.linuxSystemMetrics` on Linux platforms and `SystemMetrics.noopSystemMetrics`
        ///                     on all other platforms.
        ///     - labels: The labels to use for generated system metrics.
        public init(pollInterval interval: DispatchTimeInterval = .seconds(2), dataProvider: SystemMetrics.DataProvider? = nil, labels: Labels) {
            self.interval = interval
            if let dataProvider = dataProvider {
                self.dataProvider = dataProvider
            } else {
                #if os(Linux)
                self.dataProvider = SystemMetrics.linuxSystemMetrics
                #else
                self.dataProvider = SystemMetrics.noopSystemMetrics
                #endif
            }
            self.labels = labels
        }
    }

    /// Labels for the reported System Metrics Data.
    ///
    /// Backend implementations are encouraged to provide a static extension with
    /// defaults that suit their specific backend needs.
    public struct Labels {
        /// Prefix to prefix all other labels with.
        let prefix: String
        /// Virtual memory size in bytes.
        let virtualMemoryBytes: String
        /// Resident memory size in bytes.
        let residentMemoryBytes: String
        /// Total user and system CPU time spent in seconds.
        let startTimeSeconds: String
        /// Total user and system CPU time spent in seconds.
        let cpuSecondsTotal: String
        /// Maximum number of open file descriptors.
        let maxFileDescriptors: String
        /// Number of open file descriptors.
        let openFileDescriptors: String

        /// Create a new `Labels` instance.
        ///
        /// - parameters:
        ///     - prefix: Prefix to prefix all other labels with.
        ///     - virtualMemoryBytes: Virtual memory size in bytes
        ///     - residentMemoryBytes: Resident memory size in bytes.
        ///     - startTimeSeconds: Total user and system CPU time spent in seconds.
        ///     - cpuSecondsTotal: Total user and system CPU time spent in seconds.
        ///     - maxFds: Maximum number of open file descriptors.
        ///     - openFds: Number of open file descriptors.
        public init(prefix: String, virtualMemoryBytes: String, residentMemoryBytes: String, startTimeSeconds: String, cpuSecondsTotal: String, maxFds: String, openFds: String) {
            self.prefix = prefix
            self.virtualMemoryBytes = virtualMemoryBytes
            self.residentMemoryBytes = residentMemoryBytes
            self.startTimeSeconds = startTimeSeconds
            self.cpuSecondsTotal = cpuSecondsTotal
            self.maxFileDescriptors = maxFds
            self.openFileDescriptors = openFds
        }

        func label(for keyPath: KeyPath<Labels, String>) -> String {
            return self.prefix + self[keyPath: keyPath]
        }
    }

    /// System Metric data.
    ///
    /// The current list of metrics exposed is taken from the Prometheus Client Library Guidelines
    /// https://prometheus.io/docs/instrumenting/writing_clientlibs/#standard-and-runtime-collectors
    public struct Data {
        /// Virtual memory size in bytes.
        var virtualMemoryBytes: Int
        /// Resident memory size in bytes.
        var residentMemoryBytes: Int
        /// Start time of the process since unix epoch in seconds.
        var startTimeSeconds: Int
        /// Total user and system CPU time spent in seconds.
        var cpuSeconds: Int
        /// Maximum number of open file descriptors.
        var maxFileDescriptors: Int
        /// Number of open file descriptors.
        var openFileDescriptors: Int
    }

    #if os(Linux)
    internal static func linuxSystemMetrics() -> SystemMetrics.Data? {
        class CFile {
            let path: String

            private var file: UnsafeMutablePointer<FILE>?

            init(_ path: String) {
                self.path = path
            }

            deinit {
                assert(self.file == nil)
            }

            func open() {
                guard let f = fopen(path, "r") else {
                    return
                }
                self.file = f
            }

            func close() {
                if let f = self.file {
                    self.file = nil
                    let success = fclose(f) == 0
                    assert(success)
                }
            }

            func readLine() -> String? {
                guard let f = self.file else {
                    return nil
                }
                #if compiler(>=5.1)
                let buff: [CChar] = Array(unsafeUninitializedCapacity: 1024) { ptr, size in
                    guard fgets(ptr.baseAddress, Int32(ptr.count), f) != nil else {
                        if feof(f) != 0 {
                            size = 0
                            return
                        } else {
                            preconditionFailure("Error reading line")
                        }
                    }
                    size = strlen(ptr.baseAddress!)
                }
                if buff.isEmpty { return nil }
                return String(cString: buff)
                #else
                var buff = [CChar](repeating: 0, count: 1024)
                let hasNewLine = buff.withUnsafeMutableBufferPointer { ptr -> Bool in
                    guard fgets(ptr.baseAddress, Int32(ptr.count), f) != nil else {
                        if feof(f) != 0 {
                            return false
                        } else {
                            preconditionFailure("Error reading line")
                        }
                    }
                    return true
                }
                if !hasNewLine {
                    return nil
                }
                return String(cString: buff)
                #endif
            }

            func readFull() -> String {
                var s = ""
                func loop() -> String {
                    if let l = readLine() {
                        s += l
                        return loop()
                    }
                    return s
                }
                return loop()
            }
        }

        let ticks = _SC_CLK_TCK

        let file = CFile("/proc/self/stat")
        file.open()
        defer {
            file.close()
        }

        enum StatIndices {
            static let virtualMemoryBytes = 20
            static let residentMemoryBytes = 21
            static let startTimeTicks = 19
            static let utimeTicks = 11
            static let stimeTicks = 12
        }

        guard
            let statString = file.readFull()
            .split(separator: ")")
            .last
        else { return nil }
        let stats = String(statString)
            .split(separator: " ")
            .map(String.init)
        guard
            let virtualMemoryBytes = Int(stats[safe: StatIndices.virtualMemoryBytes]),
            let rss = Int(stats[safe: StatIndices.residentMemoryBytes]),
            let startTimeTicks = Int(stats[safe: StatIndices.startTimeTicks]),
            let utimeTicks = Int(stats[safe: StatIndices.utimeTicks]),
            let stimeTicks = Int(stats[safe: StatIndices.stimeTicks])
        else { return nil }
        let residentMemoryBytes = rss * _SC_PAGESIZE
        let startTimeSeconds = startTimeTicks / ticks
        let cpuSeconds = (utimeTicks / ticks) + (stimeTicks / ticks)

        var _rlim = rlimit()

        guard withUnsafeMutablePointer(to: &_rlim, { ptr in
            getrlimit(__rlimit_resource_t(RLIMIT_NOFILE.rawValue), ptr) == 0
        }) else { return nil }

        let maxFileDescriptors = Int(_rlim.rlim_max)

        guard let dir = opendir("/proc/self/fd") else { return nil }
        defer {
            closedir(dir)
        }
        var openFileDescriptors = 0
        while readdir(dir) != nil { openFileDescriptors += 1 }

        return .init(
            virtualMemoryBytes: virtualMemoryBytes,
            residentMemoryBytes: residentMemoryBytes,
            startTimeSeconds: startTimeSeconds,
            cpuSeconds: cpuSeconds,
            maxFileDescriptors: maxFileDescriptors,
            openFileDescriptors: openFileDescriptors
        )
    }

    #else
    #warning("System Metrics are not implemented on non-Linux platforms yet.")
    #endif

    internal static func noopSystemMetrics() -> SystemMetrics.Data? {
        return nil
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
