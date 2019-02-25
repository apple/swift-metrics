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

class RandomLibrary {
    let methodCallsCounter = Counter(label: "RandomLibrary::TotalMethodCalls")

    func doSomething() {
        self.methodCallsCounter.increment()
    }

    func doSomethingSlow(callback: @escaping () -> Void) {
        self.methodCallsCounter.increment()
        let timer = Timer(label: "RandomLibrary::doSomethingSlow")
        let start = Date()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int.random(in: 5 ... 500))) {
            timer.record(Date().timeIntervalSince(start))
            callback()
        }
    }
}
