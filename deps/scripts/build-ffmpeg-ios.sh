#!/usr/bin/env bash
# Cross-compile FFmpeg 8.0.3 for iOS (arm64) on a Linux host.
#
# NOTE: --nm=llvm-nm is mandatory. FFmpeg detects the Mach-O symbol prefix
# (the leading underscore) by compiling a probe object and reading it with
# `nm`. GNU nm cannot read Mach-O, so without this flag the detection yields
# an empty prefix and every NEON .S export (ff_*_neon) is emitted without the
# required underscore, making the static libs un-linkable by Mach-O linkers.
#
# Usage: build-ffmpeg-ios.sh [STAGE_DIR] [PREFIX]
set -euo pipefail

source "$(dirname "$0")/iosenv.sh"

VER="${FFMPEG_VERSION:-8.0.3}"
WORK="${WORK_DIR:-/tmp/opencode/build}"
SRC="$WORK/ffmpeg-${VER}"
STAGE="${1:-$WORK/stage-ffmpeg}"
PREFIX="${2:-$STAGE}"

mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "$SRC" ]; then
  echo ">> downloading ffmpeg ${VER}"
  curl -sL -o "ffmpeg-${VER}.tar.xz" "https://ffmpeg.org/releases/ffmpeg-${VER}.tar.xz"
  tar xf "ffmpeg-${VER}.tar.xz"
fi

cd "$SRC"

./configure \
  --prefix="$PREFIX" \
  --target-os=darwin \
  --arch=arm64 \
  --enable-cross-compile \
  --cc="$CC" \
  --cxx="$CXX" \
  --ar="$AR" \
  --ranlib="$RANLIB" \
  --strip="$STRIP" \
  --nm="$NM" \
  --sysroot="$SDKROOT" \
  --extra-cflags="-O2 -fPIC -DNDEBUG" \
  --extra-ldflags="-isysroot $SDKROOT -fuse-ld=ld64.lld -Wl,-platform_version,ios,${IOS_MIN_VERSION},${IOS_MIN_VERSION}" \
  --enable-static \
  --disable-shared \
  --disable-programs \
  --disable-doc \
  --disable-avdevice \
  --disable-videotoolbox \
  --disable-audiotoolbox \
  --disable-debug \
  >"$WORK/ffmpeg-configure.log" 2>&1
# Sanity-check the symbol prefix detection actually saw the underscore.
grep -q "Symbol prefix detected as: '_'" "$WORK/ffmpeg-configure.log" \
  || { echo "ERROR: symbol prefix detection failed (see $WORK/ffmpeg-configure.log)" >&2; exit 1; }
grep -q "^#define EXTERN_ASM _" config.h \
  || { echo "ERROR: config.h missing underline EXTERN_ASM" >&2; exit 1; }

make -j"$(nproc)" >"$WORK/ffmpeg-make.log" 2>&1
make install >"$WORK/ffmpeg-install.log" 2>&1

echo ">> ffmpeg ${VER} installed to $PREFIX"