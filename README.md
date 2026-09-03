# IKEMEN Go for iOS

An iOS port of [Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO), an open-source fighting game engine compatible with [M.U.G.E.N](https://en.wikipedia.org/wiki/Mugen_(game_engine)) resources, written in Go.

Play classic M.U.G.E.N characters, stages, and screenpacks on your jailbroken iOS device with native on-screen touch controls.

## Features

- **Full M.U.G.E.N compatibility** -- run characters, stages, screenpacks, and fonts from the M.U.G.E.N ecosystem
- **Native on-screen controls** -- virtual D-pad (8-way) and 6 attack buttons (A/B/C/X/Y/Z) plus Start and Menu
- **Multiple rendering backends** -- OpenGL ES 3.2 (iOS default), Vulkan, and OpenGL 3.3
- **SDL2-based** -- cross-platform windowing, input, and audio via SDL2
- **FFmpeg integration** -- background video playback (WebM/Matroska with VP8/VP9/Opus/Vorbis)
- **Module music support** -- MOD/XM/S3M/IT and other tracker formats via libxmp
- **Game controller support** -- MFi and GameController framework controllers (when available)
- **File sharing** -- game data lives in `Documents/ikemen-go/IkemenGo`, accessible via iOS Files app

## Prerequisites

- **Jailbroken iOS device** (arm64, iOS 15+)
- **[Theos](https://theos.dev/)** -- iOS build system
- **Xcode** with command-line tools (provides `clang` and iOS SDK)
- **Go 1.20+** -- for compiling the engine

### Installing Theos

```bash
# Clone Theos
git clone --recursive https://github.com/theos/theos.git ~/theos

# Set environment variable (add to your shell profile)
export THEOS=~/theos
```

See [theos.dev](https://theos.dev/) for the full installation guide.

## Building

### 1. Clone the repository

```bash
git clone --recursive https://github.com/your-username/ikemen-go-ios.git
cd ikemen-go-ios
```

### 2. Compile the Go engine

The engine must be compiled as a static library for iOS (arm64):

```bash
cd ios/engine

# Set up iOS cross-compilation (adjust SDK path as needed)
export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export CC=$(xcrun --sdk iphoneos --find clang)
export CFLAGS="-arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=15.0"

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

Transfer the `.ipa` to your device and install it using your preferred package manager (e.g., Sileo, Cydia, or `dpkg -i`).

## Adding Game Content

After the first launch, game data is copied to:

```
Documents/ikemen-go/IkemenGo/
```

This directory is accessible via the **iOS Files app** (under "On My iPhone" > "IKEMEN Go") or through file sharing.

### Directory structure

```
Documents/ikemen-go/IkemenGo/
├── data/           # Screenpack and engine data
├── font/           # Shared fonts
├── external/       # External scripts and resources
├── chars/          # Character folders
├── stages/         # Stage files
└── sound/          # Sound and music files
```

### Adding characters

1. Place character folders in `Documents/ikemen-go/IkemenGo/chars/`
2. Edit the select screen file in `data/` to include the new characters
3. Restart the app

### Adding stages

1. Place `.def` stage files in `Documents/ikemen-go/IkemenGo/stages/`
2. Reference them in your screenpack's select definition

## Project Structure

```
ikemen-go-ios/
├── Ikemen-GO/              # Upstream Ikemen GO engine source (embedded copy)
│   ├── src/                # Engine source code (Go)
│   ├── build/              # Build scripts for desktop platforms
│   └── ...
├── IKEMENGo/               # iOS app (Theos project)
│   ├── main.m              # App entry point, engine data seeding
│   ├── OverlayControls.m   # On-screen touch controls (D-pad + buttons)
│   ├── OverlayControls.h   # Touch controls header
│   ├── Makefile            # Theos build configuration
│   ├── control             # Debian package metadata
│   ├── engine/             # Compiled engine output (libengine.a)
│   └── Resources/          # App bundle resources
├── ios/                    # iOS-specific engine build tree
│   └── engine/             # iOS Go source files and vendor deps
├── deps/                   # Pre-compiled iOS static libraries
│   ├── ios-sdl/            # SDL2
│   ├── ios-libxmp/         # libxmp (module music)
│   └── ios-ffmpeg/         # FFmpeg (video/audio decoding)
├── LICENSE                 # MIT License
└── README.md               # This file
```

## Credits

- **[Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO)** -- the upstream engine this project is based on
- **[M.U.G.E.N](https://mugenengine.com/)** -- the original fighting game engine by Elecbyte
- **[Theos](https://theos.dev/)** -- iOS build system for jailbreak development
- **[SDL2](https://www.libsdl.org/)** -- cross-platform multimedia library
- **[FFmpeg](https://ffmpeg.org/)** -- audio/video processing library
- **[libxmp](https://xmp.sourceforge.net/)** -- module music player library

## License

This project is licensed under the **MIT License** -- see [LICENSE](LICENSE) for details.

Ikemen GO engine source is MIT licensed. FFmpeg is used under LGPL v2.1. See [LICENCE.txt](Ikemen-GO/LICENCE.txt) for details on bundled assets.
