TARGET=$1

case "$TARGET" in

linux-x64)
CPU=x64
NOCROSS=1
export CC="clang"
export CXX="clang++"
;;

linux-arm64)
CPU=arm64
SYSROOT=/opt/sysroots/arm64
debootstrap \
  --arch=arm64 \
  --foreign \
  trixie \
  $SYSROOT \
  http://deb.debian.org/debian
cp /usr/bin/qemu-aarch64-static $SYSROOT/usr/bin/
chroot $SYSROOT /debootstrap/debootstrap --second-stage
chroot $SYSROOT apt-get update
chroot $SYSROOT apt-get install -y \
  build-essential \
  pkg-config \
  libc6-dev \
  linux-libc-dev \
  zlib1g-dev \
  libssl-dev
export CC="clang --sysroot=$SYSROOT --target=aarch64-linux-gnu --gcc-toolchain=/usr/aarch64-linux-gnu"
export CXX="clang++ --sysroot=$SYSROOT --target=aarch64-linux-gnu --gcc-toolchain=/usr/aarch64-linux-gnu"
;;

linuxstatic-x64|alpine-x64)
TRIPLE=x86_64-linux-musl
CPU=x64
NOCROSS=1
;;

linuxstatic-arm64|alpine-arm64)
TRIPLE=aarch64-linux-musl
CPU=arm64
;;

linuxstatic-armv7)
TRIPLE=armv7-linux-musleabihf
CPU=arm
;;

win-x64)
TRIPLE=x86_64-w64-windows-gnu
CPU=x64
;;

win-arm64)
TRIPLE=aarch64-w64-windows-gnu
CPU=arm64
;;

macos-x64)
TRIPLE=x86_64-apple-darwin
CPU=x64
;;

macos-arm64)
TRIPLE=arm64-apple-darwin
CPU=arm64
;;

esac

export CC_host=clang
export CXX_host=clang++

echo "CPU=\"$CPU\"" >> /etc/environment
echo "NOCROSS=\"$NOCROSS\"" >> /etc/environment

echo "=============================="
echo "Config: $TARGET (cross-compile: ${NOCROSS:-0})"
echo "CC: $CC"
echo "CXX: $CXX"
echo "=============================="

if [ "${NOCROSS:-0}" -eq 1 ]; then
  echo "Compiling native"
  ./configure --dest-cpu=$CPU
else
  echo "Compiling cross-compile"
  ./configure --dest-cpu=$CPU --cross-compiling
fi

make -j$(nproc)
