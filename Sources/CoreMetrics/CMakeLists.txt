##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Metrics API open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift Metrics API project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

add_library(CoreMetrics
  "Locks.swift"
  "MappingMetricsFactory.swift"
  "Metrics.swift"
  "WithMetricsFactory.swift"
)

target_compile_options(CoreMetrics PRIVATE
  "SHELL:-package-name swift-metrics")

set_target_properties(CoreMetrics PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

_install_target(CoreMetrics)
set_property(GLOBAL APPEND PROPERTY SWIFT_METRICS_EXPORTS CoreMetrics)
