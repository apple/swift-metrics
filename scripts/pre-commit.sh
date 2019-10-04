#!/bin/sh
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Metrics API open source project
##
## Copyright (c) 2018-2019 Apple Inc. and the Swift Metrics API project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
#
# Checks files are correctly formatted. To enable:
#
# cp scripts/pre-commit.sh .git/hooks

set -eux

if [ -x "$(command -v swiftformat)" ]; then
    swiftformat .
else
    echo "warning: SwiftFormat not installed, download from https://github.com/nicklockwood/SwiftFormat"
    exit 1
fi

