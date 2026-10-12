#!/usr/bin/env bash
# Cross-compile libxmp 4.7.3 for iOS (arm64) on a Linux host.
#
# Usage: build-libxmp-ios.sh [STAGE_DIR]
set -euo pipefail

source "$(dirname "$0")/iosenv.sh"

VER="4.7.3"
WORK="${WORK_DIR:-/tmp/opencode/build}"
SRC="$WORK/libxmp-$VER"
STAGE="${1:-$WORK/stage-libxmp}"

mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "$SRC" ]; then
  curl -sL -o "libxmp-${VER}.tar.gz" "https://github.com/libxmp/libxmp/releases/download/libxmp-${VER}/libxmp-${VER}.tar.gz"
  tar xf "libxmp-${VER}.tar.gz"
fi

cd "$SRC"
make distclean >/dev/null 2>&1 || true

./configure \
  --prefix="$STAGE" \
  --host=arm64-apple-ios \
  CC="$CC" \
  CXX="$CXX" \
  CPP="$CPP" \
  AR="$AR" \
  RANLIB="$RANLIB" \
  NM="$NM" \
  LDFLAGS="$LDFLAGS" \
  --enable-static \
  --disable-shared \
  >"$WORK/libxmp-configure.log" 2>&1

make -j"$(nproc)" >"$WORK/libxmp-make.log" 2>&1
make install >"$WORK/libxmp-install.log" 2>&1

echo ">> libxmp ${VER} installed to $STAGE"