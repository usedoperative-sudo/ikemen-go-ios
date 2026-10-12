#!/usr/bin/env bash
# Cross-compile SDL2 2.32.4 for iOS (arm64) on a Linux host with CMake +
# the ios-cmake toolchain file.
#
# Relevant options baked into the prebuilt lib in deps/ios-sdl:
#   SDL_AUDIO=ON SDL_VIDEO=ON SDL_METAL=ON SDL_VULKAN=ON SDL_JOYSTICK=ON
#   SDL_STATIC=ON SDL_SHARED=OFF (static only)
#
# The UIKit driver is compiled as-is; the app links -framework CoreBluetooth
# to satisfy hid.m.o (BLE gamepad support).
#
# Usage: build-sdl-ios.sh [STAGE_DIR]
set -euo pipefail

source "$(dirname "$0")/iosenv.sh"

VER="2.32.4"
WORK="${WORK_DIR:-/tmp/opencode/build}"
SRC="$WORK/SDL2-${VER}"
STAGE="${1:-$WORK/stage-sdl}"
IOSTOOLCHAIN="${IOSTOOLCHAIN:-$WORK/ios.toolchain.cmake}"

if [ ! -f "$IOSTOOLCHAIN" ]; then
  echo "ERROR: ios.toolchain.cmake not found at $IOSTOOLCHAIN" >&2
  exit 1
fi

mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "$SRC" ]; then
  curl -sL -o "SDL2-${VER}.tar.gz" "https://github.com/libsdl-org/SDL/releases/download/release-${VER}/SDL2-${VER}.tar.gz"
  tar xf "SDL2-${VER}.tar.gz"
fi

rm -rf "$WORK/sdl2-cmake"
cmake -S "$SRC" -B "$WORK/sdl2-cmake" -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$IOSTOOLCHAIN" \
  -DCMAKE_OSX_SYSROOT="$SDKROOT" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_MIN_VERSION" \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DSDL_AUDIO=ON -DSDL_VIDEO=ON -DSDL_METAL=ON -DSDL_VULKAN=ON -DSDL_JOYSTICK=ON \
  -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST=OFF -DSDL_EXAMPLES=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  >"$WORK/sdl-configure.log" 2>&1

cmake --build "$WORK/sdl2-cmake" -j"$(nproc)" >"$WORK/sdl-make.log" 2>&1

mkdir -p "$STAGE"
(
  cd "$WORK/sdl2-cmake"
  for f in $(cat install_manifest.txt); do
    mkdir -p "$STAGE/$(dirname "${f#$WORK/sdl2-cmake/}")"
  done
)

# CMake does not build the "install" target layout automatically for plain
# -B builds without --install; install explicitly:
cmake --install "$WORK/sdl2-cmake" --prefix "$STAGE" >"$WORK/sdl-install.log" 2>&1

echo ">> SDL2 ${VER} installed to $STAGE"