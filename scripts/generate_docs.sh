#!/bin/bash
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

set -e

my_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
root_path="$my_path/.."
version=$(git describe --abbrev=0 --tags || echo "0.0.0")
modules=(CoreMetrics Metrics)

if [[ "$(uname -s)" == "Linux" ]]; then
  # build code if required
  if [[ ! -d "$root_path/.build/x86_64-unknown-linux" ]]; then
    swift build
  fi
  # setup source-kitten if required
  source_kitten_source_path="$root_path/.SourceKitten"
  if [[ ! -d "$source_kitten_source_path" ]]; then
    git clone https://github.com/jpsim/SourceKitten.git "$source_kitten_source_path"
  fi
  source_kitten_path="$source_kitten_source_path/.build/x86_64-unknown-linux/debug"
  if [[ ! -d "$source_kitten_path" ]]; then
    rm -rf "$source_kitten_source_path/.swift-version"
    cd "$source_kitten_source_path" && swift build && cd "$root_path"
  fi
  # generate
  mkdir -p "$root_path/.build/sourcekitten"
  for module in "${modules[@]}"; do
    if [[ ! -f "$root_path/.build/sourcekitten/$module.json" ]]; then
      "$source_kitten_path/sourcekitten" doc --spm-module $module > "$root_path/.build/sourcekitten/$module.json"
    fi
  done
fi

[[ -d docs/$version ]] || mkdir -p docs/$version
[[ -d swift-metrics.xcodeproj ]] || swift package generate-xcodeproj

# run jazzy
if ! command -v jazzy > /dev/null; then
  gem install jazzy --no-ri --no-rdoc
fi

tmp=`mktemp -d`
mkdir -p "$tmp/docs/$version"
module_switcher="$tmp/docs/$version/README.md"
jazzy_args=(--clean
            --author 'swift-metrics team'
            --readme "$module_switcher"
            --author_url https://github.com/apple/swift-metrics
            --github_url https://github.com/apple/swift-metrics
            --theme fullwidth
            --xcodebuild-arguments -scheme,swift-metrics-Package)
cat > "$module_switcher" <<"EOF"
# swift-metrics docs

swift-metrics is a Swift metrics API package.

To get started with swift-metrics, [`import Metrics`](../CoreMetrics/index.html). The most important types are:

* [`Counter`](https://apple.github.io/swift-metrics/docs/current/CoreMetrics/Classes/Counter.html)
* [`Timer`](https://apple.github.io/swift-metrics/docs/current/CoreMetrics/Classes/Timer.html)
* [`Recorder`](https://apple.github.io/swift-metrics/docs/current/CoreMetrics/Classes/Recorder.html)
* [`Gauge`](https://apple.github.io/swift-metrics/docs/current/CoreMetrics/Classes/Gauge.html)

swift-metrics contains multiple modules:
EOF

for module in "${modules[@]}"; do
  echo " - [$module](../$module/index.html)" >> "$module_switcher"
done

for module in "${modules[@]}"; do
  echo "processing $module"
  args=("${jazzy_args[@]}" --output "$tmp/docs/$version/$module" --docset-path "$tmp/docset/$version/$module" --module "$module")
  if [[ -f "$root_path/.build/sourcekitten/$module.json" ]]; then
    args+=(--sourcekitten-sourcefile "$root_path/.build/sourcekitten/$module.json")
  fi
  jazzy "${args[@]}"
done

# push to github pages
if [[ $CI == true ]]; then
  BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
  GIT_AUTHOR=$(git --no-pager show -s --format='%an <%ae>' HEAD)
  git fetch origin +gh-pages:gh-pages
  git checkout gh-pages
  rm -rf "docs"
  cp -r "$tmp/docs" .
  cp -r "docs/$version" docs/current
  git add --all docs
  echo '<html><head><meta http-equiv="refresh" content="0; url=docs/current/CoreMetrics/index.html" /></head></html>' > index.html
  git add index.html
  touch .nojekyll
  git add .nojekyll
  changes=$(git diff-index --name-only HEAD)
  if [[ -n "$changes" ]]; then
    echo -e "changes detected\n$changes"
    git commit --author="$GIT_AUTHOR" -m "publish $version docs"
    git push origin gh-pages
  else
    echo "no changes detected"
  fi
  git checkout -f $BRANCH_NAME
fi
