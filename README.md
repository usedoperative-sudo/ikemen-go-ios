# IKEMEN Go for iOS

An iOS port of [Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO), an open-source fighting game engine compatible with [M.U.G.E.N](https://en.wikipedia.org/wiki/Mugen_(game_engine)) resources, written in Go.

Play classic M.U.G.E.N characters, stages, and screenpacks on your iOS device with native on-screen touch controls.

## Features

- **Full M.U.G.E.N compatibility** -- run characters, stages, screenpacks, and fonts from the M.U.G.E.N ecosystem
- **Native on-screen controls** -- virtual D-pad (8-way) and 6 attack buttons (A/B/C/X/Y/Z) plus Start and Menu
- **OpenGL ES 3.0 rendering** -- hardware-accelerated OpenGL ES 3.0 on iOS (the engine originally requested at least Desktop OpenGL 3.3 but it was adapted to OpenGL ES 3.0 which is the latest OpenGL version supported by iOS before Apple marked it as deprecated in favor of Metal)
- **SDL2-based** -- cross-platform windowing, input, and audio via SDL2
- **FFmpeg integration** -- background video playback (WebM/Matroska with VP8/VP9/Opus/Vorbis)
- **Module music support** -- MOD/XM/S3M/IT and other tracker formats via libxmp
- **Game controller support** -- MFi and GameController framework controllers (coming soon, cannot test if added because do not have a game controller)
- **File sharing** -- game data lives in `Documents/ikemen-go/IkemenGo`, accessible via iOS Files app

## Prerequisites

- **iOS device** (arm64, iOS 15+)
- **[Theos](https://theos.dev/)** -- iOS build system (for non-Mac environments)
- **Clang 21+** -- required for modern iOS SDK (like iOS 18+ and iOS 26+ SDKs) compatibility
- **Go 1.20+** -- for compiling the engine

### Installing Theos

```bash
# Clone Theos
git clone --recursive https://github.com/theos/theos.git ~/theos

# Set environment variable (add to your shell profile)
export THEOS=/opt/theos
```

See [theos.dev](https://theos.dev/) for the full installation guide.

## Building

### 1. Clone the repository

```bash
git clone --recursive https://github.com/usedoperative-sudo/ikemen-go-ios.git
cd ikemen-go-ios
```

### 2. Compile the Go engine

The engine must be compiled as a static library for iOS (arm64):

```bash
cd ios/engine

# Set up iOS cross-compilation
export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export CC=$(which clang)
export SDKPATH=$(ls -d $THEOS/sdks/iPhoneOS*.sdk | tail -1)
export CFLAGS="-arch arm64 -isysroot $SDKPATH -miphoneos-version-min=15.0"

# Build the static library
go build -buildmode=c-archive -o ../../IKEMENGo/engine/libengine.a

cd ../..
```

### 3. Build the iOS app

```bash
cd IKEMENGo
make package
```

This produces an `.ipa` file in `IKEMENGo/packages/`.

### 4. Install on device

Transfer the `.ipa` to your device and install it using your preferred method (e.g., AltStore, SideStore, Sideloadly, or `dpkg -i` on jailbroken devices).

## Adding Game Content

After the first launch, game data is copied to:

```
Documents/ikemen-go/IkemenGo/
```

This directory is accessible via the **iOS Files app** (under "On My iPhone" > "IKEMEN Go") or through file sharing.

### Directory structure

```
Documents/ikemen-go/IkemenGo/ # Where Documents resolves to On My iPhone > IKEMEN Go folder
├── data/           # Screenpack and engine data
├── font/           # Shared fonts
├── external/       # External scripts and resources
├── chars/          # Character folders
├── stages/         # Stage files
└── sound/          # Sound and music files
```

### Adding characters

1. Place character folders in `Documents/ikemen-go/IkemenGo/chars/` (Where Documents resolves to On My iPhone > IKEMEN Go folder)
2. Edit the select screen file in `data/` to include the new characters
3. Restart the app

### Adding stages

1. Place `.def` stage files in `Documents/ikemen-go/IkemenGo/stages/`
2. Reference them in your screenpack's select definition

> **Note for adding characters**: the iOS build uses the engine's default behavior of keeping every character on a team fully loaded in memory for the whole match. In Tag/Simul/Turns modes with **heavy external fighters**, the combined sprite + sound data can push the app over iOS's memory limit (the **Jetsam** watchdog kills the process with no warning). If the app quits suddenly during a match, it is almost always this. 

## Known Limitations

- **Memory / Jetsam kills with heavy content.** iOS enforces a hard memory limit per app. This port does not perform on-demand asset unloading for standby team fighters (a change that was prototyped but reverted because it could interfere with the engine's internal fight-logic invariants). Consequences:
  - **Team modes (Tag / Simul / Turns) with large external fighters** can consume a lot of memory, because all team members remain resident.
  - On low-memory iDevices, the app may be terminated by iOS with no error dialog.
  - **Recommendation: avoid playing with very heavy fighters/packs** (particularly multiple big fighters on one team, or stages with long background videos), and keep the number of simultaneously-loaded team members low. A more capable device and fewer/lighter characters will help.
- **No graceful out-of-memory recovery** in the engine itself.

## Project Structure

```
ikemen-go-ios/
├── Ikemen-GO/              # Upstream Ikemen GO engine source (embedded copy)
│   ├── src/                # Engine source code (Go)
│   ├── build/              # Build scripts for desktop platforms
│   └── ...
├── IKEMENGo/               # iOS app
│   ├── main.m              # App entry point, engine data seeding
│   ├── OverlayControls.m   # On-screen touch controls (D-pad + buttons)
│   ├── OverlayControls.h   # Touch controls header
│   ├── Makefile            # Theos build configuration
│   ├── control             # Debian-like package metadata
│   ├── engine/             # Compiled engine output (libengine.a)
│   └── Resources/          # App bundle resources
├── ios/                    # iOS-specific engine build tree
│   └── engine/             # iOS Go source files and vendor deps
├── deps/                   # Pre-compiled iOS static libraries
│   ├── ios-sdl/            # SDL2
│   ├── ios-libxmp/         # libxmp (module music)
│   └── ios-ffmpeg/         # FFmpeg (video/audio decoding)
├── LICENSE                 # MIT License
└── README.md               # This file
```

## Credits

- **[Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO)** -- the upstream engine this project is based on
- **[M.U.G.E.N](https://mugenengine.com/)** -- the original fighting game engine by Elecbyte
- **[Theos](https://theos.dev/)** -- iOS build system for non-Mac environments
- **[SDL2](https://www.libsdl.org/)** -- cross-platform multimedia library
- **[FFmpeg](https://ffmpeg.org/)** -- audio/video processing library
- **[libxmp](https://xmp.sourceforge.net/)** -- module music player library

**This project is not linked to IKEMEN Go official development nor it creators, the development of this port is totally fanmade**

## License

This project is licensed under the **MIT License** -- see [LICENSE](LICENSE) for details.

Ikemen GO engine source is MIT licensed. FFmpeg is used under LGPL v2.1. See [LICENCE.txt](Ikemen-GO/LICENCE.txt) for details on bundled assets.
