#!/bin/bash
set -euo pipefail

echo "=== Installing dependencies for target: ${TARGET_OS}-${TARGET_ARCH}-${TARGET_LIBC} ==="

apt-get update

# ---------------------------------------------------------------------------
# Common build dependencies (required by all targets)
# ---------------------------------------------------------------------------
apt-get install -y \
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

# ---------------------------------------------------------------------------
# Target-specific toolchains and dependencies
# ---------------------------------------------------------------------------
case "${TARGET_OS}" in
  linux)
    case "${TARGET_ARCH}" in
      x64)
        case "${TARGET_LIBC}" in
          gnu)
            echo "Native Linux x64 build — no extra toolchain needed"
            ;;
          musl)
            echo "Installing musl toolchain for x64..."
            apt-get install -y musl-tools
            ;;
          *)
            echo "ERROR: unknown libc '${TARGET_LIBC}'"
            exit 1
            ;;
        esac
        ;;
      arm64)
        case "${TARGET_LIBC}" in
          gnu)
            echo "Installing ARM64 glibc cross-compilation toolchain..."
            dpkg --add-architecture arm64
            apt-get update
            apt-get install -y \
                crossbuild-essential-arm64 \
                libssl-dev:arm64 \
                zlib1g-dev:arm64
            ;;
          musl)
            echo "Downloading musl ARM64 cross-compilation toolchain..."
            MUSL_URL="https://musl.cc/aarch64-linux-musl-cross.tgz"
            curl -fsSL "${MUSL_URL}" -o /tmp/musl-aarch64.tgz
            tar xzf /tmp/musl-aarch64.tgz -C /opt/
            rm -f /tmp/musl-aarch64.tgz
            echo "Musl ARM64 toolchain installed to /opt/aarch64-linux-musl-cross"
            ;;
          *)
            echo "ERROR: unknown libc '${TARGET_LIBC}'"
            exit 1
            ;;
        esac
        ;;
      *)
        echo "ERROR: unknown arch '${TARGET_ARCH}'"
        exit 1
        ;;
    esac
    ;;

  darwin)
    echo "Installing macOS cross-compilation dependencies..."
    apt-get install -y \
        clang \
        llvm \
        lld \
        cmake \
        libxml2-dev \
        libfuse2 \
        libbz2-dev \
        patch \
        uuid-dev \
        libedit-dev \
        libncurses-dev \
        libzstd-dev \
        libssl-dev \
        zlib1g-dev

    OSXCROSS_DIR="/opt/osxcross"
    SDK_VERSION="${OSXCROSS_SDK_VERSION:-14.5}"
    SDK_FILE="MacOSX${SDK_VERSION}.sdk.tar.xz"
    SDK_URL="https://github.com/phracker/MacOSX-SDKs/releases/download/15.0/${SDK_FILE}"

    echo "Cloning osxcross..."
    git clone --depth 1 https://github.com/tpoechtrager/osxcross.git "${OSXCROSS_DIR}"

    echo "Downloading macOS SDK ${SDK_VERSION}..."
    cd "${OSXCROSS_DIR}"
    mkdir -p tarballs
    curl -fsSL "${SDK_URL}" -o "tarballs/${SDK_FILE}" || {
        echo "ERROR: Failed to download macOS SDK from ${SDK_URL}"
        echo "Please provide a valid SDK URL or check network connectivity."
        exit 1
    }

    echo "Building osxcross (this may take a while)..."
    UNATTENDED=1 ./build.sh

    echo "osxcross installed to ${OSXCROSS_DIR}"

    # Make osxcross tools available globally
    echo "export PATH=${OSXCROSS_DIR}/target/bin:\$PATH" > /etc/profile.d/osxcross.sh
    ;;

  win32)
    case "${TARGET_ARCH}" in
      x64)
        echo "Installing MinGW-w64 for Windows x64 cross-compilation..."
        apt-get install -y \
            gcc-mingw-w64-x86-64 \
            g++-mingw-w64-x86-64 \
            nsis
        ;;
      arm64)
        echo "Installing Windows ARM64 cross-compilation toolchain..."
        # Prefer native Debian packages; fall back to LLVM-MinGW
        if apt-cache show gcc-mingw-w64-arm64 >/dev/null 2>&1; then
            apt-get install -y \
                gcc-mingw-w64-arm64 \
                g++-mingw-w64-arm64
        else
            echo "No native ARM64 mingw package; installing LLVM-MinGW..."
            LLVM_MINGW_VER="20240619"
            LLVM_MINGW_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VER}/llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-20.04-x86_64.tar.xz"
            curl -fsSL "${LLVM_MINGW_URL}" -o /tmp/llvm-mingw.tar.xz
            tar xJf /tmp/llvm-mingw.tar.xz -C /opt/
            rm -f /tmp/llvm-mingw.tar.xz
            LLVM_DIR=$(ls -d /opt/llvm-mingw-* | head -1)
            echo "export PATH=${LLVM_DIR}/bin:\$PATH" > /etc/profile.d/llvm-mingw.sh
            echo "LLVM-MinGW installed to ${LLVM_DIR}"
        fi
        ;;
      *)
        echo "ERROR: unknown arch '${TARGET_ARCH}'"
        exit 1
        ;;
    esac
    ;;

  *)
    echo "ERROR: unknown OS '${TARGET_OS}'"
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "=== Dependencies installed successfully ==="
