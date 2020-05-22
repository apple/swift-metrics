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

extension MetricsSystem {
    /// `bootstrapSystemMetrics` is an one-time configuration function which globally enables system level metrics.
    /// `bootstrapSystemMetrics` can be only called once, unless cancelled usung `cancelSystemMetrics`, calling it more
    /// than once without cancelling will lead to undefined behaviour, most likely a crash.
    /// There is no need to call `bootstrapSystemMetrics` if `SystemMetricsOptions` were provided to `bootstrap`.
    ///
    /// - parameters:
    ///     - options: Options to configure `SystemMetricsHandler`
    public static func bootstrapWithSystemMetrics(_ factory: MetricsFactory, options: SystemMetrics.Options) {
        let factory = SystemMetricsFactory(factory: factory, options: options)
        self.bootstrap(factory)
        self.systemMetrics!.poll()
    }
    
    /// Cancels the collection of system metrics. Calling this unlocks `bootstrapSystemMetrics` so it can be
    /// called again.
    public static func cancelSystemMetrics() {
        self.systemMetrics?.cancelSystemMetrics()
    }
    
    internal class SystemMetricsFactory: MetricsFactory {
        fileprivate let queue = DispatchQueue(label: "com.apple.CoreMetrics.SystemMetricsHandler", qos: .background)
        fileprivate let timeInterval: DispatchTimeInterval
        fileprivate let systemMetricsType: SystemMetricsProvider.Type
        fileprivate let labels: SystemMetrics.Labels
        fileprivate var task: DispatchWorkItem?
        internal let underlying: MetricsFactory

        init(factory: MetricsFactory, options: SystemMetrics.Options) {
            self.underlying = factory
            self.timeInterval = options.interval
            if let systemMetricsType = options.metricsType {
                self.systemMetricsType = systemMetricsType
            } else {
                #if os(Linux)
                self.systemMetricsType = SystemMetrics.LinuxProvider.self
                #else
                self.systemMetricsType = SystemMetrics.NOOPProvider.self
                #endif
            }
            self.labels = options.labels

            self.task = DispatchWorkItem(qos: .background, block: {
                guard let metrics = self.systemMetricsType.readSystemMetrics() else { return }
                Gauge(label: self.labels.label(for: \.virtualMemoryBytes)).record(metrics.virtualMemoryBytes)
                Gauge(label: self.labels.label(for: \.residentMemoryBytes)).record(metrics.residentMemoryBytes)
                Gauge(label: self.labels.label(for: \.startTimeSeconds)).record(metrics.startTimeSeconds)
                Gauge(label: self.labels.label(for: \.cpuSecondsTotal)).record(metrics.cpuSeconds)
                Gauge(label: self.labels.label(for: \.maxFileDescriptors)).record(metrics.maxFileDescriptors)
                Gauge(label: self.labels.label(for: \.openFileDescriptors)).record(metrics.openFileDescriptors)
            })
        }

        internal func cancelSystemMetrics() {
            self.task?.cancel()
            self.task = nil
        }

        internal func poll() {
            self.queue.asyncAfter(deadline: .now() + self.timeInterval) {
                guard let task = self.task else { return }
                task.perform()
                self.poll()
            }
        }
        
        func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
            self.underlying.makeCounter(label: label, dimensions: dimensions)
        }
        
        func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
            self.underlying.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        
        func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
            self.underlying.makeTimer(label: label, dimensions: dimensions)
        }
        
        func destroyCounter(_ handler: CounterHandler) {
            self.underlying.destroyCounter(handler)
        }
        
        func destroyRecorder(_ handler: RecorderHandler) {
            self.underlying.destroyRecorder(handler)
        }
        
        func destroyTimer(_ handler: TimerHandler) {
            self.underlying.destroyTimer(handler)
        }
    }
}

public protocol SystemMetricsProvider {
    static func readSystemMetrics() -> SystemMetrics.Data?
}

public enum SystemMetrics {
    /// Options used to bootstrap `SystemMetricsHandler`
    ///
    /// Libraries are advised to extend `SystemMetricsOptions` with a static instance for ease of use.
    public struct Options {
        let interval: DispatchTimeInterval
        let metricsType: SystemMetricsProvider.Type?
        let labels: Labels
        
        /// Create new instance of `SystemMetricsOptions`
        ///
        /// - parameters:
        ///     - pollInterval: The interval at which system metrics should be updated.
        ///     - systemMetricsType: The type of system metrics to use. If none is provided this defaults to
        ///                          `LinuxSystemMetrics` on Linux platforms and `NOOPSystemMetrics` on all other platforms.
        ///     - labels: The labels to use for generated system metrics.
        public init(pollInterval interval: DispatchTimeInterval = .seconds(2), metricsType: SystemMetricsProvider.Type? = nil, labels: Labels) {
            self.interval = interval
            self.metricsType = metricsType
            self.labels = labels
        }
    }

    /// Labels for the reported System Metrics.
    ///
    /// Backend implementations are encouraged to provide a static extension to this type with
    /// defaults that suit their specific backend needs.
    public struct Labels {
        /// Prefix to prefix all other labels with.
        let prefix: String
        /// Virtual memory size in bytes
        let virtualMemoryBytes: String
        /// Resident memory size in bytes
        let residentMemoryBytes: String
        /// Total user and system CPU time spent in seconds
        let startTimeSeconds: String
        /// Total user and system CPU time spent in seconds
        let cpuSecondsTotal: String
        /// Maximum number of open file descriptors
        let maxFileDescriptors: String
        /// Number of open file descriptors
        let openFileDescriptors: String

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
        /// Virtual memory size in bytes
        var virtualMemoryBytes: Int
        /// Resident memory size in bytes
        var residentMemoryBytes: Int
        /// Start time of the process since unix epoch in seconds
        var startTimeSeconds: Int
        /// Total user and system CPU time spent in seconds
        var cpuSeconds: Int
        /// Maximum number of open file descriptors
        var maxFileDescriptors: Int
        /// Number of open file descriptors
        var openFileDescriptors: Int
    }

//    #if os(Linux)
    internal struct LinuxProvider: SystemMetricsProvider {
        
        fileprivate class CFile {
            let path: String
            
            private var file: UnsafeMutablePointer<FILE>? = nil
            
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
                let buff: [CChar] = Array(unsafeUninitializedCapacity: 1024) { (ptr, size) in
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

        static func readSystemMetrics() -> SystemMetrics.Data? {
            let ticks = _SC_CLK_TCK
            
            let file = CFile("/proc/self/stat")
            file.open()
            defer {
                file.close()
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
                let virtualMemoryBytes = Int(stats[safe: 20]),
                let rss = Int(stats[safe: 21]),
                let startTimeTicks = Int(stats[safe: 19]),
                let utimeTicks = Int(stats[safe: 11]),
                let stimeTicks = Int(stats[safe: 12])
            else { return nil }
            let residentMemoryBytes = rss * _SC_PAGESIZE
            let startTimeSeconds = startTimeTicks / ticks
            let cpuSeconds = (utimeTicks / ticks) + (stimeTicks / ticks)

            var _rlim = rlimit()
            
            guard withUnsafeMutablePointer(to: &_rlim, { (ptr) in
                return getrlimit(__rlimit_resource_t(RLIMIT_NOFILE.rawValue), ptr) == 0
            }) else { return nil }
            
            let maxFileDescriptors = Int(_rlim.rlim_max)

            guard let dir = opendir("/proc/self/fd") else { return nil }
            defer {
                closedir(dir)
            }
            var openFileDescriptors = 0
            while readdir(dir) != nil { openFileDescriptors += 1 }
            
            return .init(virtualMemoryBytes: virtualMemoryBytes, residentMemoryBytes: residentMemoryBytes, startTimeSeconds: startTimeSeconds, cpuSeconds: cpuSeconds, maxFileDescriptors: maxFileDescriptors, openFileDescriptors: openFileDescriptors)
        }
    }
//    #else
//    #warning("System Metrics are not implemented on non-Linux platforms yet.")
//    #endif
    
    internal struct NOOPProvider: SystemMetricsProvider {
        static func readSystemMetrics() -> SystemMetrics.Data? {
            return nil
        }
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
