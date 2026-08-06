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

set(SWIFT_METRICS_EXPORTS_FILE ${CMAKE_CURRENT_BINARY_DIR}/SwiftMetricsExports.cmake)
configure_file(SwiftMetricsConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/SwiftMetricsConfig.cmake)

get_property(SWIFT_METRICS_EXPORTS GLOBAL PROPERTY SWIFT_METRICS_EXPORTS)
export(TARGETS ${SWIFT_METRICS_EXPORTS} FILE ${SWIFT_METRICS_EXPORTS_FILE})
