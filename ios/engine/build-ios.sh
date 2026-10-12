#!/bin/bash
# Cross-compile the Ikemen-GO engine (pure upstream) for iOS arm64 on Linux
# with the Theos iPhoneOS SDK, producing the static library the Theos app links:
#     IKEMENGo/engine/libengine.a
#
# The engine deliberately does NOT link MoltenVK: github.com/Eiton/vulkan bundles
# the Vulkan headers and resolves MoltenVK via dlsym at runtime. MoltenVK is only
# linked into the final app (see the LDFLAGS in IKEMENGo/Makefile).
#
# Requirements (all already built in this repo):
#   - deps/ios-sdl     SDL2 2.32.4 (UIKit driver, Vulkan+Metal enabled)
#   - deps/ios-ffmpeg  FFmpeg 8.0.3 (arm64 iOS static)
#   - deps/ios-libxmp  libxmp 4.7.3
#   - /opt/theos/sdks/iPhoneOS16.5.sdk (or override IOS_SDK)
#   - Go >= 1.27
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd -P)"
ENGINE="$REPO/ios/engine"
DEPS="$REPO/deps"
APP="$REPO/IKEMENGo"

SDK="${IOS_SDK:-/opt/theos/sdks/iPhoneOS16.5.sdk}"
TARGET="${IOS_TARGET:-arm64-apple-ios15.0}"
LD="${IOS_LD:-/usr/bin/ld64.lld}"
OUT_DIR="$APP/engine"

if [[ ! -s "$SDK" && ! -d "$SDK" ]]; then
    echo "ERROR: iOS SDK not found: $SDK" >&2
    exit 1
fi
if ! command -v go >/dev/null; then
    echo "ERROR: go not found" >&2
    exit 1
fi

export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export GOEXPERIMENT=arenas
export GOFLAGS=-mod=mod

export CC="clang --target=${TARGET} -isysroot ${SDK}"
export CXX="clang++ --target=${TARGET} -isysroot ${SDK}"

# -DSDL_MAIN_HANDLED: the iOS build exports SDL_main; there is no desktop main().
# The wrapper dir is on the include path because the engine's cgo uses
# SDLWindowFix.h (the Metal-layer attach contract).
export CGO_CFLAGS="-DSDL_MAIN_HANDLED \
  -I${DEPS}/ios-sdl/include -I${DEPS}/ios-sdl/include/SDL2 \
  -I${DEPS}/ios-libxmp/include \
  -I${APP} \
  -isysroot ${SDK} \
  -Wno-error=incompatible-pointer-types -Wno-incompatible-pointer-types \
  -Wno-deprecated-non-prototype -Wno-unused-command-line-argument"
export CGO_CXXFLAGS="${CGO_CFLAGS}"
export CGO_LDFLAGS="-fuse-ld=${LD} -Wl,-platform_version,ios,15.0,15.0 \
  -L${DEPS}/ios-libxmp/lib -L${DEPS}/ios-ffmpeg/lib -L${DEPS}/ios-sdl/lib"
export PKG_CONFIG_PATH="${DEPS}/ios-sdl/lib/pkgconfig:${DEPS}/ios-ffmpeg/lib/pkgconfig:${DEPS}/ios-libxmp/lib/pkgconfig"

# In-game version string. The engine draws it verbatim in the screenpack footer
# (src/motif.go: title_info.footer.version.text) and in crash reports.
#
# It is composed from explicit constants rather than `git describe`: the port
# repo carries legacy tags (e.g. a literal tag `1.0_1.0.0rc4`), so describing it
# produced strings like "1.0_1.0.0rc4-4-gbb93c64" — port version, engine version
# and a stray commit hash all glued together. Override on the command line when
# bumping either number:
#   IKEMEN_ENGINE_VERSION=<upstream Ikemen-GO release>   (default 1.0.0)
#   IKEMEN_PORT_VERSION=<this iOS port's release>        (default 1.0)
IKEMEN_ENGINE_VERSION="${IKEMEN_ENGINE_VERSION:-1.0.0}"
IKEMEN_PORT_VERSION="${IKEMEN_PORT_VERSION:-1.0}"
VERSION="${IKEMEN_PORT_VERSION}_${IKEMEN_ENGINE_VERSION}"
BUILDTIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$OUT_DIR"
cd "$ENGINE"

# MoltenVK is not linked into the engine, but the app link needs its static
# lib. Fetch it if the repo checkout doesn't carry it (it is committed at
# deps/ios-moltenvk/libMoltenVK.a, so this is normally a no-op).
if [[ ! -f "$DEPS/ios-moltenvk/libMoltenVK.a" ]]; then
    echo "==> libMoltenVK.a missing, fetching MoltenVK ..."
    "$DEPS/scripts/build-moltenvk-ios.sh"
fi

echo "==> Building libengine.a (${VERSION}) ..."
go build -buildmode=c-archive -trimpath -tags=ios \
  -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.BuildTime=${BUILDTIME}'" \
  -o "$OUT_DIR/libengine.a" ./src
echo "==> OK: $(ls -lh "$OUT_DIR/libengine.a" | awk '{print $5}') $OUT_DIR/libengine.a"
echo "==> Exported symbols: SDL_main, GetMoltenVKWindowID"