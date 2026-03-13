//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2026 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public struct MappingMetricsFactory<Upstream: MetricsFactory>: Sendable {
    private let upstream: Upstream
    private let transform: @Sendable (String, [(String, String)]) -> (String, [(String, String)])

    public init(upstream: Upstream, transform: @escaping @Sendable (String, [(String, String)]) -> (String, [(String, String)])) {
        self.upstream = upstream
        self.transform = transform
    }
}

extension MetricsFactory {
    public func mappingLabelsAndDimensions(
        _ transform: @escaping @Sendable (String, [(String, String)]
    ) -> (String, [(String, String)])) -> MappingMetricsFactory<Self> {
        MappingMetricsFactory(upstream: self, transform: transform)
    }
}

extension MappingMetricsFactory: MetricsFactory {
    public func makeCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> any CounterHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeCounter(label: newLabel, dimensions: newDimensions)
    }

    public func makeFloatingPointCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> FloatingPointCounterHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeFloatingPointCounter(label: newLabel, dimensions: newDimensions)
    }

    public func makeMeter(
        label: String,
        dimensions: [(String, String)]
    ) -> MeterHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeMeter(label: newLabel, dimensions: newDimensions)
    }

    public func makeRecorder(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool
    ) -> any RecorderHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeRecorder(label: newLabel, dimensions: newDimensions, aggregate: aggregate)
    }

    public func makeTimer(
        label: String,
        dimensions: [(String, String)]
    ) -> any TimerHandler {
        let (newLabel, newDimensions) = transform(label, dimensions)
        return upstream.makeTimer(label: newLabel, dimensions: newDimensions)
    }

    public func destroyCounter(_ handler: any CounterHandler) {
        upstream.destroyCounter(handler)
    }

    public func destroyMeter(_ handler: MeterHandler) {
        upstream.destroyMeter(handler)
    }

    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        upstream.destroyFloatingPointCounter(handler)
    }

    public func destroyRecorder(_ handler: any RecorderHandler) {
        upstream.destroyRecorder(handler)
    }

    public func destroyTimer(_ handler: any TimerHandler) {
        upstream.destroyTimer(handler)
    }
}
