#!/usr/bin/env bash
# Fetch the MoltenVK iOS static library into deps/ios-moltenvk/.
#
# MoltenVK is ONLY linked into the iOS app (force-loaded so its exported vk*
# symbols stay visible for the engine's dlsym(RTLD_DEFAULT) lookup). The
# engine itself never links it: github.com/Eiton/vulkan bundles the Vulkan
# headers and resolves MoltenVK via dlsym at runtime.
#
# Usage: build-moltenvk-ios.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd -P)"
DEST="$REPO/deps/ios-moltenvk"
VER="${MOLTENVK_VERSION:-1.4.2}"
TAR="MoltenVK-ios.tar"
URL="https://github.com/KhronosGroup/MoltenVK/releases/download/v${VER}/$TAR"

mkdir -p "$DEST"
if [[ -f "$DEST/libMoltenVK.a" ]]; then
  echo ">> libMoltenVK.a already present"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo ">> downloading MoltenVK ${VER} ($URL)"
curl -fsSL -o "$WORK/$TAR" "$URL"
tar xf "$WORK/$TAR" -C "$WORK" \
  MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64/libMoltenVK.a \
  MoltenVK/LICENSE

cp "$WORK/MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64/libMoltenVK.a" "$DEST/libMoltenVK.a"
cp "$WORK/MoltenVK/LICENSE" "$DEST/LICENSE"

echo ">> MoltenVK ${VER} -> $DEST/libMoltenVK.a"
ls -lh "$DEST/libMoltenVK.a"