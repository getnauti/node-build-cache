TARGET=$1

case "$TARGET" in

linux-x64)
TRIPLE=x86_64-linux-gnu
CPU=x64
NOCROSS=1
;;

linux-arm64)
TRIPLE=aarch64-linux-gnu
CPU=arm64
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

CC="clang --target=$TRIPLE"
CXX="clang++ --target=$TRIPLE"

echo "TRIPLE=\"$TRIPLE\"" >> /etc/environment
echo "CPU=\"$CPU\"" >> /etc/environment
echo "NOCROSS=\"$NOCROSS\"" >> /etc/environment

echo "=============================="
echo "Config: $TARGET (cross-compile: ${NOCROSS:-0})"
echo "TRIPLE: $TRIPLE"
echo "CPU: $CPU"
echo "CC: $CC"
echo "CXX: $CXX"
echo "=============================="

if [ $NOCROSS -eq 1 ]; then
  echo "Compiling native"
  ./configure --dest-cpu=$CPU
else
  echo "Compiling cross-compile"
  ./configure --dest-cpu=$CPU --cross-compiling
fi

make -j$(nproc)
