//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

//  Sendable support helpers

#if compiler(>=5.6)
@preconcurrency public protocol _SwiftMetricsSendableProtocol: Sendable {}
#else
public protocol _SwiftMetricsSendableProtocol {}
#endif

#if compiler(>=5.6)
public typealias _SwiftMetricsSendable = Sendable
#else
public typealias _SwiftMetricsSendable = Any
#endif
