ARG swift_version=5.7
ARG ubuntu_version=focal
ARG base_image=swift:$swift_version-$ubuntu_version
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version
ARG ubuntu_version

# set as UTF-8
RUN apt-get update && apt-get install -y locales locales-all
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# dependencies
RUN apt-get update && apt-get install -y wget
RUN apt-get update && apt-get install -y lsof dnsutils netcat-openbsd net-tools curl jq # used by integration tests

# ruby and jazzy for docs generation
RUN apt-get update && apt-get install -y ruby ruby-dev libsqlite3-dev build-essential

# tools
RUN mkdir -p $HOME/.tools
RUN echo 'export PATH="$HOME/.tools:$PATH"' >> $HOME/.profile

# swiftformat (until part of the toolchain)

ARG swiftformat_version=0.49.6
RUN if [ "${swift_version}" = "5.7" ]; then git clone --branch $swiftformat_version --depth 1 https://github.com/nicklockwood/SwiftFormat $HOME/.tools/swift-format; fi
RUN if [ "${swift_version}" = "5.7" ]; then cd $HOME/.tools/swift-format && swift build -c release; fi
RUN if [ "${swift_version}" = "5.7" ]; then ln -s $HOME/.tools/swift-format/.build/release/swiftformat $HOME/.tools/swiftformat; fi
