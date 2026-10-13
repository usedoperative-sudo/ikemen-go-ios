#!/usr/bin/env bash
#
# Stage the default Ikemen-GO runtime assets for the iOS port.
#
# The upstream engine repo (ios/engine) ships the system scripts
# (data/system.zss, data/common1.cns.zss, ...) but *not* a playable game:
# there is no screenpack, no default characters and no stages. The engine's
# default config points at `data/ikemen1/system.def` and `data/select.def`,
# so without those assets it aborts on startup.
#
# Upstream's own mobile builds solve this the same way: they clone the
# Elecbyte screenpack repo and stage the paths listed in a wrapper
# manifest.txt, resolving each path against the engine tree first and the
# screenpack second. This script mirrors that logic and produces a single
# assembled runtime tree at:
#
#   ios/assets/game/
#
# which the Theos Makefile then copies into the app bundle (as real
# subfolders) and the app seeds into Documents/ikemen-go/IkemenGo on first
# launch.
#
# Usage:
#   ios/assets/fetch-default-assets.sh
#
# Environment overrides:
#   SCREENPACK_REPO  (default https://github.com/ikemen-engine/Ikemen-GO-Screenpack.git)
#   SCREENPACK_REF   (default master)
#   GAMECONTROLLERDB_URL
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE_DIR="$REPO_ROOT/ios/engine"
STAGE_DIR="$SCRIPT_DIR/game"
CACHE_DIR="$SCRIPT_DIR/.cache"
MANIFEST="$SCRIPT_DIR/manifest.txt"

SCREENPACK_REPO="${SCREENPACK_REPO:-https://github.com/ikemen-engine/Ikemen-GO-Screenpack.git}"
SCREENPACK_REF="${SCREENPACK_REF:-master}"
GAMECONTROLLERDB_URL="${GAMECONTROLLERDB_URL:-https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/refs/heads/master/gamecontrollerdb.txt}"

download_file() {
	local url="$1" out="$2"
	mkdir -p "$(dirname "$out")"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url" -o "$out"
	elif command -v wget >/dev/null 2>&1; then
		wget -qO "$out" "$url"
	else
		echo "ERROR: need curl or wget to download $url" >&2
		return 1
	fi
}

[[ -d "$ENGINE_DIR" ]] || { echo "ERROR: engine dir not found: $ENGINE_DIR" >&2; exit 1; }
[[ -f "$MANIFEST" ]]   || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

# --- 1. Clone/update the Elecbyte screenpack -------------------------------
mkdir -p "$CACHE_DIR"
if [[ -d "$CACHE_DIR/screenpack/.git" ]]; then
	echo "==> Updating screenpack ($SCREENPACK_REF) in $CACHE_DIR/screenpack"
	( cd "$CACHE_DIR/screenpack" \
		&& git fetch --depth=1 origin "$SCREENPACK_REF" \
		&& git checkout -f FETCH_HEAD )
else
	rm -rf "$CACHE_DIR/screenpack"
	echo "==> Cloning screenpack ($SCREENPACK_REF) -> $CACHE_DIR/screenpack"
	git clone --depth=1 -b "$SCREENPACK_REF" "$SCREENPACK_REPO" "$CACHE_DIR/screenpack"
fi
SCREENPACK_DIR="$CACHE_DIR/screenpack"

# --- 2. Fresh staging dir --------------------------------------------------
echo "==> Staging runtime assets into $STAGE_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

# Paths the engine expects but that no source repo ships; generate them up
# front so the manifest loop below finds them.
mkdir -p "$STAGE_DIR/data" "$STAGE_DIR/external"

# data/system.base.def: upstream copies it from the embedded default motif.
cp -a "$ENGINE_DIR/src/resources/defaultMotif.ini" "$STAGE_DIR/data/system.base.def"

# external/gamecontrollerdb.txt: SDL's gamepad mapping database.
if [[ ! -f "$STAGE_DIR/external/gamecontrollerdb.txt" ]]; then
	echo "==> Downloading SDL GameController DB..."
	download_file "$GAMECONTROLLERDB_URL" "$STAGE_DIR/external/gamecontrollerdb.txt"
fi

# --- 3. Resolve every manifest path: engine tree first, screenpack second --
staged=0
skipped=0
while read -r p; do
	[[ -z "$p" ]] && continue
	dst="$STAGE_DIR/$p"

	# Already provided by a generated file above.
	[[ -e "$dst" ]] && { staged=$((staged + 1)); continue; }

	src="$ENGINE_DIR/$p"
	[[ ! -e "$src" && -e "$SCREENPACK_DIR/$p" ]] && src="$SCREENPACK_DIR/$p"

	if [[ -d "$src" ]]; then
		mkdir -p "$dst"
		cp -a "$src/." "$dst/"
	elif [[ -f "$src" ]]; then
		mkdir -p "$(dirname "$dst")"
		cp -a "$src" "$dst"
	elif [[ "$p" == */ ]]; then
		# Trailing slash = a directory the engine expects to exist (even empty).
		mkdir -p "$dst"
	else
		# Optional paths absent from both trees (upstream warns too).
		echo "WARNING: asset path not found in engine tree or screenpack: $p" >&2
		skipped=$((skipped + 1))
		continue
	fi
	staged=$((staged + 1))
done < <(tr -s '[:space:]' '\n' < "$MANIFEST")

echo "==> Staged $staged paths ($skipped optional paths skipped)"
echo "==> Asset tree contents:"
( cd "$STAGE_DIR" && ls -1 )
echo "==> Total size: $(du -sh "$STAGE_DIR" | cut -f1)"

# --- 4. Write a version stamp the app compares against ---------------------
# The app only merges assets into Documents when this value changes, so it
# encodes the manifest + screenpack revision (the engine tree changes are
# picked up via the manifest hash whenever they add/remove paths).
manifest_hash="$(sha1sum "$MANIFEST" | cut -c1-12)"
screenpack_rev="$(git -C "$SCREENPACK_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "${screenpack_rev}-${manifest_hash}" > "$SCRIPT_DIR/VERSION"
echo "==> Wrote asset version: $(cat "$SCRIPT_DIR/VERSION")"
