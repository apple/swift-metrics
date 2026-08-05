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

cmake_minimum_required(VERSION 3.19)

project(SwiftMetrics
  LANGUAGES Swift)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

include(SwiftSupport)

option(BUILD_SHARED_LIBS "Build shared libraries by default" YES)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_Swift_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
set(CMAKE_POSITION_INDEPENDENT_CODE ${BUILD_SHARED_LIBS})

# Toolchain vended dependencies
find_package(dispatch CONFIG)
find_package(Foundation CONFIG)

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
