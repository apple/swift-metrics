//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension MetricsSystem {
    /// Runs the given closure with a factory bound to the task-local context.
    ///
    /// Metrics created within the closure will use the specified factory instead of the global factory. The factory
    /// is captured at metric creation time and used for the metric's entire lifetime.
    ///
    /// ## Example: Testing with isolated factory
    ///
    /// ```swift
    /// @Test
    /// func testRequestHandling() async {
    ///     let testFactory = TestMetrics()
    ///     let service = await Metrics.with(factory: testFactory) {
    ///         RequestService()  // Creates metrics using testFactory
    ///     }
    ///
    ///     service.handleRequest()
    ///
    ///     let counter = try testFactory.expectCounter("requests")
    ///     #expect(counter.values == [1])
    /// }
    /// ```
    ///
    /// ## Example: Parallel tests with isolated factories
    ///
    /// ```swift
    /// @Test
    /// func testParallelRequests() async {
    ///     let factory1 = TestMetrics()
    ///     let factory2 = TestMetrics()
    ///
    ///     async let result1 = Metrics.with(factory: factory1) {
    ///         let service = RequestService()
    ///         return service.handleRequest()
    ///     }
    ///
    ///     async let result2 = Metrics.with(factory: factory2) {
    ///         let service = RequestService()
    ///         return service.handleRequest()
    ///     }
    ///
    ///     _ = try await (result1, result2)
    ///
    ///     // Each factory has isolated metrics
    ///     #expect(try factory1.expectCounter("requests").values == [1])
    ///     #expect(try factory2.expectCounter("requests").values == [1])
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - factory: The metrics factory to use for metric creation within the closure.
    ///   - operation: The closure to execute with the factory bound.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func with<Result, Failure: Error>(
        factory: MetricsFactory,
        _ operation: () throws(Failure) -> Result
    ) rethrows -> Result {
        try withTaskLocalFactory(factory, operation: operation)
    }

    /// Runs the given async closure with a factory bound to the task-local context.
    ///
    /// Async variant of `with(factory:_:)`. See that method for detailed documentation.
    ///
    /// - Parameters:
    ///   - factory: The metrics factory to use for metric creation within the closure.
    ///   - operation: The async closure to execute with the factory bound.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func with<Result, Failure: Error>(
        factory: MetricsFactory,
        _ operation: () async throws(Failure) -> Result
    ) async rethrows -> Result {
        try await withTaskLocalFactory(factory, operation: operation)
    }
}
