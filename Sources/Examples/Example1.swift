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
//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE
//

import Metrics

enum Example1 {
    static func main() {
        // bootstrap with our example metrics library
        let metrics = ExampleMetricsLibrary()
        MetricsSystem.bootstrap(metrics)

        let server = Server()
        let client = Client(server: server)
        client.run(iterations: Int.random(in: 10 ... 50))

        print("-----> counters")
        metrics.counters.forEach { print("  \($0)") }
        print("-----> recorders")
        metrics.recorders.forEach { print("  \($0)") }
        print("-----> timers")
        metrics.timers.forEach { print("  \($0)") }
        print("-----> gauges")
        metrics.gauges.forEach { print("  \($0)") }
    }

    class Client {
        private let activeRequestsGauge = Gauge(label: "Client::ActiveRequests")
        private let server: Server
        init(server: Server) {
            self.server = server
        }

        func run(iterations: Int) {
            let group = DispatchGroup()
            let requestsCounter = Counter(label: "Client::TotalRequests")
            let requestTimer = Timer(label: "Client::doSomethig")
            let resultRecorder = Recorder(label: "Client::doSomethig::result")
            for _ in 0 ... iterations {
                group.enter()
                let start = Date()
                requestsCounter.increment()
                self.activeRequests += 1
                server.doSomethig { result in
                    requestTimer.record(Date().timeIntervalSince(start))
                    resultRecorder.record(result)
                    self.activeRequests -= 1
                    group.leave()
                }
            }
            group.wait()
        }

        private let lock = NSLock()
        private var _activeRequests = 0
        var activeRequests: Int {
            get {
                return self.lock.withLock { _activeRequests }
            } set {
                self.lock.withLock { _activeRequests = newValue }
                self.activeRequestsGauge.record(newValue)
            }
        }
    }

    class Server {
        let library = RandomLibrary()
        let requestsCounter = Counter(label: "Server::TotalRequests")

        func doSomethig(callback: @escaping (Int64) -> Void) {
            let timer = Timer(label: "Server::doSomethig")
            let start = Date()
            requestsCounter.increment()
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int.random(in: 5 ... 500))) {
                self.library.doSomething()
                self.library.doSomethingSlow {
                    timer.record(Date().timeIntervalSince(start))
                    callback(Int64.random(in: 0 ... 1000))
                }
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
