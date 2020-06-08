FROM ubuntu:18.04

# Allows the caller to specify the toolchain to use.
ARG swift_tf_url=https://storage.googleapis.com/swift-tensorflow-artifacts/nightlies/latest/swift-tensorflow-DEVELOPMENT-notf-ubuntu18.04.tar.gz

ARG sccache_binary_url=https://github.com/mozilla/sccache/releases/download/0.2.13/sccache-0.2.13-x86_64-unknown-linux-musl.tar.gz

ARG key_file=""

ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true
RUN if [ -z "$key_file" ]; then \
      echo "build --remote_http_cache=https://storage.googleapis.com/gs.mak-play.com  \
      --google_default_credentials" >> ~/.bazelrc; \
    else \
      echo "$key_file" | base64 --decode > $HOME/key_file.json; \
      echo "build --remote_http_cache=https://storage.googleapis.com/gs.mak-play.com  \
        --google_credentials=$HOME/key_file.json" >> ~/.bazelrc; \
      cat $HOME/key_file.json;
    fi
    
RUN cat ~/.bazelrc;
RUN apt-get -yq update \
    && apt-get -yq install --no-install-recommends curl ca-certificates gnupg2 libxml2 \
    && apt-get clean

# Add bazel and cmake repositories.
RUN curl -qL https://apt.kitware.com/keys/kitware-archive-latest.asc | apt-key add -
RUN echo 'deb https://apt.kitware.com/ubuntu/ bionic main' >> /etc/apt/sources.list

RUN curl -qL https://bazel.build/bazel-release.pub.gpg | apt-key add -
RUN echo 'deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8' >> /etc/apt/sources.list.d/bazel.list

# Install bazel, cmake, ninja, python, and python dependencies
RUN apt-get -yq update \
 && apt-get -yq install --no-install-recommends bazel-2.0.0 cmake ninja-build git  \
 && apt-get -yq install --no-install-recommends python-setuptools python-dev python-pip  \
 && apt-get clean                                                               \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/archive/* /var/lib/apt/lists/*
RUN ln -s /usr/bin/bazel-2.0.0 /usr/bin/bazel
RUN pip install -U pip six numpy wheel setuptools mock 'future>=0.17.1'         \
 && pip install -U --no-deps keras_applications keras_preprocessing

# Download and extract S4TF
WORKDIR /swift-tensorflow-toolchain
RUN curl -fSsL $swift_tf_url -o swift.tar.gz \
    && mkdir usr \
    && tar -xzf swift.tar.gz --directory=usr --strip-components=1 \
    && rm swift.tar.gz

RUN curl -fSsL $sccache_binary_url -o sccache.tar.gz \
    && tar -xzf sccache.tar.gz --directory=usr --strip-components=1 \
    && rm sccache.tar.gz
    
# Print out swift version for better debugging for toolchain problems
RUN /swift-tensorflow-toolchain/usr/bin/swift --version

# Copy the kernel into the container
COPY . /swift-apis
WORKDIR /swift-apis

# Perform CMake based build
ENV TF_NEED_CUDA=0
ENV CTEST_OUTPUT_ON_FAILURE=1
ENV SCCACHE_GCS_RW_MODE=READ_WRITE
ENV SCCACHE_GCS_BUCKET=gs.mak-play.com
ENV SCCACHE_GCS_KEY_PATH=$HOME/key_file.json
ENV RUST_LOG=info,error,warn

RUN cmake                                                                       \
      -B /BinaryCache/tensorflow-swift-apis                                     \
      -D BUILD_SHARED_LIBS=YES                                                  \
      -D CMAKE_BUILD_TYPE=Release                                               \
      -D CMAKE_INSTALL_PREFIX=/swift-tensorflow-toolchain/usr                   \
      -D CMAKE_Swift_COMPILER=/swift-tensorflow-toolchain/usr/bin/swiftc        \
      -D BUILD_X10=YES                                                          \
      -D CMAKE_CXX_COMPILER_LAUNCHER=sccache                                    \
      -D CMAKE_C_COMPILER_LAUNCHER=sccache                                      \
      -G Ninja                                                                  \
      -S /swift-apis
      
RUN cmake --build /BinaryCache/tensorflow-swift-apis --verbose
RUN cmake --build /BinaryCache/tensorflow-swift-apis --target install
RUN cmake --build /BinaryCache/tensorflow-swift-apis --target test

# Run SwiftPM tests
# RUN /swift-tensorflow-toolchain/usr/bin/swift test
