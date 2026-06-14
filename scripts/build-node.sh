#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "Building Node.js v${NODE_VERSION}"
echo "Target: ${TARGET_OS}-${TARGET_ARCH}-${TARGET_LIBC}"
echo "============================================================"

JOBS=$(nproc)
echo "Parallel jobs: ${JOBS}"

# ---------------------------------------------------------------------------
# Set up compilation environment per target
# ---------------------------------------------------------------------------
CONFIGURE_FLAGS=()

# Host compiler (always native)
export CC_host=clang
export CXX_host=clang++

case "${TARGET_OS}" in
  linux)
    case "${TARGET_ARCH}" in
      x64)
        case "${TARGET_LIBC}" in
          gnu)
            echo "Config: native Linux x64 (glibc)"
            export CC=clang
            export CXX=clang++
            ;;
          musl)
            echo "Config: Linux x64 (musl libc)"
            export CC=musl-gcc
            export CXX=musl-g++
            CONFIGURE_FLAGS+=(--fully-static)
            ;;
        esac
        ;;
      arm64)
        case "${TARGET_LIBC}" in
          gnu)
            echo "Config: Linux ARM64 (glibc cross-compile)"
            export CC="clang --target=aarch64-linux-gnu"
            export CXX="clang++ --target=aarch64-linux-gnu"
            export AR=llvm-ar
            export NM=llvm-nm
            export OBJCOPY=llvm-objcopy
            export OBJDUMP=llvm-objdump
            export STRIP=llvm-strip
            CONFIGURE_FLAGS+=(--dest-cpu=arm64 --cross-compiling)
            ;;
          musl)
            echo "Config: Linux ARM64 (musl libc cross-compile)"
            MUSL_DIR="/opt/aarch64-linux-musl-cross"
            if [ -d "${MUSL_DIR}" ]; then
                export CC="${MUSL_DIR}/bin/aarch64-linux-musl-gcc"
                export CXX="${MUSL_DIR}/bin/aarch64-linux-musl-g++"
                export AR="${MUSL_DIR}/bin/aarch64-linux-musl-ar"
                export NM="${MUSL_DIR}/bin/aarch64-linux-musl-nm"
                export OBJCOPY="${MUSL_DIR}/bin/aarch64-linux-musl-objcopy"
                export OBJDUMP="${MUSL_DIR}/bin/aarch64-linux-musl-objdump"
                export STRIP="${MUSL_DIR}/bin/aarch64-linux-musl-strip"
                export PATH="${MUSL_DIR}/bin:${PATH}"
            else
                echo "ERROR: musl ARM64 toolchain not found at ${MUSL_DIR}"
                exit 1
            fi
            CONFIGURE_FLAGS+=(--dest-cpu=arm64 --cross-compiling --fully-static)
            ;;
        esac
        ;;
    esac
    ;;

  darwin)
    echo "Config: macOS ${TARGET_ARCH} (cross-compile via osxcross)"

    OSXCROSS_DIR="/opt/osxcross/target"
    OSXCROSS_BIN="${OSXCROSS_DIR}/bin"

    if [ ! -d "${OSXCROSS_BIN}" ]; then
        echo "ERROR: osxcross not found at ${OSXCROSS_BIN}"
        exit 1
    fi

    # Find the osxcross compiler wrappers (darwin version may vary)
    OSX_CC=$(ls "${OSXCROSS_BIN}"/x86_64-apple-darwin*-clang 2>/dev/null | head -1)
    OSX_CXX=$(ls "${OSXCROSS_BIN}"/x86_64-apple-darwin*-clang++ 2>/dev/null | head -1)
    OSX_AARCH64_CC=$(ls "${OSXCROSS_BIN}"/aarch64-apple-darwin*-clang 2>/dev/null | head -1)
    OSX_AARCH64_CXX=$(ls "${OSXCROSS_BIN}"/aarch64-apple-darwin*-clang++ 2>/dev/null | head -1)

    case "${TARGET_ARCH}" in
      x64)
        if [ -z "${OSX_CC}" ]; then
            echo "ERROR: x86_64-apple-darwin clang not found"
            exit 1
        fi
        export CC="${OSX_CC}"
        export CXX="${OSX_CXX}"
        CONFIGURE_FLAGS+=(--dest-os=mac --dest-cpu=x64 --cross-compiling)
        ;;
      arm64)
        if [ -z "${OSX_AARCH64_CC}" ]; then
            echo "ERROR: aarch64-apple-darwin clang not found"
            exit 1
        fi
        export CC="${OSX_AARCH64_CC}"
        export CXX="${OSX_AARCH64_CXX}"
        CONFIGURE_FLAGS+=(--dest-os=mac --dest-cpu=arm64 --cross-compiling)
        ;;
    esac

    export AR="${OSXCROSS_BIN}/x86_64-apple-darwin23-ar"
    export PATH="${OSXCROSS_BIN}:${PATH}"
    ;;

  win32)
    echo "Config: Windows ${TARGET_ARCH} (cross-compile)"

    case "${TARGET_ARCH}" in
      x64)
        export CC=x86_64-w64-mingw32-gcc
        export CXX=x86_64-w64-mingw32-g++
        export AR=x86_64-w64-mingw32-ar
        export NM=x86_64-w64-mingw32-nm
        export OBJCOPY=x86_64-w64-mingw32-objcopy
        export OBJDUMP=x86_64-w64-mingw32-objdump
        export STRIP=x86_64-w64-mingw32-strip
        export RC=x86_64-w64-mingw32-windres
        CONFIGURE_FLAGS+=(--dest-os=win --dest-cpu=x64 --cross-compiling)
        ;;
      arm64)
        # Try system-installed mingw ARM64 first
        if command -v aarch64-w64-mingw32-gcc &>/dev/null; then
            export CC=aarch64-w64-mingw32-gcc
            export CXX=aarch64-w64-mingw32-g++
            export AR=aarch64-w64-mingw32-ar
            export NM=aarch64-w64-mingw32-nm
            export STRIP=aarch64-w64-mingw32-strip
            export RC=aarch64-w64-mingw32-windres
        # Fall back to LLVM-MinGW
        elif command -v aarch64-w64-mingw32-clang &>/dev/null; then
            export CC=aarch64-w64-mingw32-clang
            export CXX=aarch64-w64-mingw32-clang++
            export AR=llvm-ar
            export NM=llvm-nm
            export STRIP=llvm-strip
        else
            # Search for LLVM-MinGW installation
            LLVM_DIR=$(ls -d /opt/llvm-mingw-* 2>/dev/null | head -1 || echo "")
            if [ -n "${LLVM_DIR}" ] && [ -d "${LLVM_DIR}/bin" ]; then
                export PATH="${LLVM_DIR}/bin:${PATH}"
                export CC="${LLVM_DIR}/bin/aarch64-w64-mingw32-clang"
                export CXX="${LLVM_DIR}/bin/aarch64-w64-mingw32-clang++"
                export AR="${LLVM_DIR}/bin/llvm-ar"
                export NM="${LLVM_DIR}/bin/llvm-nm"
                export STRIP="${LLVM_DIR}/bin/llvm-strip"
            else
                echo "ERROR: no Windows ARM64 cross-compiler found"
                exit 1
            fi
        fi
        CONFIGURE_FLAGS+=(--dest-os=win --dest-cpu=arm64 --cross-compiling)
        ;;
    esac
    ;;
esac

# ---------------------------------------------------------------------------
# Print compiler info for debugging
# ---------------------------------------------------------------------------
echo ""
echo "Compiler information:"
echo "  CC      = ${CC:-clang}"
echo "  CXX     = ${CXX:-clang++}"
echo "  CC_host = ${CC_host:-clang}"
echo "  CXX_host= ${CXX_host:-clang++}"
if [ -n "${AR:-}" ];  then echo "  AR      = ${AR}"; fi
if [ -n "${NM:-}" ];  then echo "  NM      = ${NM}"; fi
echo ""

# ---------------------------------------------------------------------------
# Configure
# ---------------------------------------------------------------------------
echo "Running ./configure ${CONFIGURE_FLAGS[*]}..."
./configure "${CONFIGURE_FLAGS[@]}"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo ""
echo "Running make -j${JOBS}..."
make -j"${JOBS}"

echo ""
echo "============================================================"
echo "BUILD SUCCESSFUL"
echo "Node.js binary: $(pwd)/out/Release/node"
echo "Node.js version: $(./out/Release/node --version 2>/dev/null || echo 'cross-compiled — unable to run on host')"
echo "============================================================"
