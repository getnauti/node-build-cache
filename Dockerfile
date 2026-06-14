FROM debian:trixie

COPY ./scripts /tmp/scripts

ARG NODE_VERSION=v24.9.0
ARG TARGET=linux-x64

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_VERSION=${NODE_VERSION} \
    TARGET=${TARGET}

RUN chmod +x /tmp/scripts/*.sh
RUN apt-get update
RUN apt-get install -y \
    build-essential \
    clang \
    python3 \
    git \
    curl \
    ca-certificates \
    ccache \
    pkg-config \
    ninja-build \
    nasm \
    llvm \
    lld \
    llvm-dev \
    liblld-dev \
    libtool \
    autoconf \
    automake \
    libssl-dev \
    zlib1g-dev \
    libuv1-dev \
    libnghttp2-dev \
    libbrotli-dev \
    libc-ares-dev \
    libicu-dev

WORKDIR /usr/src

RUN git clone --depth 1 --branch ${NODE_VERSION} https://github.com/nodejs/node.git node

WORKDIR /usr/src/node

ENV AR=llvm-ar
ENV NM=llvm-nm
ENV OBJCOPY=llvm-objcopy
ENV OBJDUMP=llvm-objdump
ENV STRIP=llvm-strip
ENV RANLIB=llvm-ranlib
ENV LD=ld.lld

RUN /tmp/scripts/build.sh $TARGET

WORKDIR /usr/src/node
CMD ["/bin/bash"]
