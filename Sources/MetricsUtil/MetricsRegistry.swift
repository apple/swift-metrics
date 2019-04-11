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
import CoreMetrics

public class WeakCounter<T: CounterHandler> {
    weak var reference: T?

    init(_ counter: T) {
        self.reference = counter
    }
}

public class WeakTimer<T: TimerHandler> {
    weak var reference: T?

    init(_ timer: T) {
        self.reference = timer
    }
}

public class WeakRecorder<T: RecorderHandler> {
    weak var reference: T?

    init(_ recorder: T) {
        self.reference = recorder
    }
}

public typealias CounterRegistry<T: CounterHandler> = [String: WeakCounter<T>]
public typealias TimerRegistry<T: TimerHandler> = [String: WeakTimer<T>]
public typealias RecorderRegistry<T: RecorderHandler> = [String: WeakRecorder<T>]
