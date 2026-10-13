# IKEMEN Go for iOS

An iOS port of [Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO), an open-source fighting game engine compatible with [M.U.G.E.N](https://en.wikipedia.org/wiki/Mugen_(game_engine)) resources, written in Go.

This port tracks **pure upstream Ikemen-GO** — `ios/engine/` is a synced copy of the upstream engine with two deliberate, documented deviations: a small crash-path guard in `src/main.go` (`handlePanic`) so pre-renderer-init crashes surface as readable errors instead of nested segfaults, and a MoltenVK config override (`MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0`) to prevent issues with MoltenVK's iOS 17+ residency-set code path.

Play classic M.U.G.E.N characters, stages, and screenpacks on your iOS device with native on-screen touch controls.

## Features

- **Pure upstream engine** — `ios/engine/` is a synced copy of upstream `ikemen-engine/Ikemen-GO` (with only a lightweight crash-path guard and the MoltenVK config override).
- **Full M.U.G.E.N compatibility** — run characters, stages, screenpacks, and fonts from the M.U.G.E.N ecosystem.
- **Vulkan rendering via MoltenVK** — the engine's Vulkan renderer runs smoothly on Metal through MoltenVK, linked and resolved via `dlsym`.
- **Native on-screen controls** — virtual D-pad and attack buttons (A/B/C/X/Y/Z) plus Start and Menu, translated into a **virtual SDL game controller**. Features **haptic feedback** for button presses and D-pad direction changes.
- **Portrait and landscape play** — in landscape the fight fills the screen beneath translucent controls; in portrait the engine renders the fight in the top band and controls sit below.
- **SDL2, FFmpeg, and libxmp support** — robust multimedia handling for audio, background videos, and module music formats (MOD/XM/S3M/IT).
- **Game controller support** — MFi and GameController framework controllers work out of the box.
- **File sharing** — game data lives in `Documents/ikemen-go/IkemenGo`, fully accessible via the iOS Files app.
- **Native crash logging** — hard crashes (SIGSEGV/SIGABRT) write a native backtrace to `save/logs/native_crash.log`.

## Prerequisites

- **iOS device** (arm64, iOS 15+)
- **Theos** — iOS build system for non-Mac environments, with a compatible iPhoneOS SDK.
- **Clang** and an appropriate linker (like **`ld64.lld`**) for the Go link step.
- **Go 1.27+** — required by the upstream `go.mod`.
- **curl** and **`rsync`** for fetching dependencies and staging the app bundle.

### Installing Theos

```bash
# Clone Theos
git clone --recursive [https://github.com/theos/theos.git](https://github.com/theos/theos.git) ~/theos

# Set environment variable (add to your shell profile)
export THEOS=/opt/theos

```

## Building

### 1. Clone the repository

```bash
git clone --recursive [https://github.com/usedoperative-sudo/ikemen-go-ios.git](https://github.com/usedoperative-sudo/ikemen-go-ios.git)
cd ikemen-go-ios

```

### 2. Compile the Go engine for iOS

Run the build script to configure the iOS cross-compiler (`GOOS=ios GOARCH=arm64 CGO_ENABLED=1`, `GOEXPERIMENT=arenas`), set up the SDK flags, and generate the static library (`libengine.a`):

```bash
./ios/engine/build-ios.sh

```

### 3. Build the iOS app

```bash
cd IKEMENGo
make package

```

This generates an `.ipa` file inside `IKEMENGo/packages/`.

### 4. Install on device

Transfer the `.ipa` to your device and install it using your preferred sideloading method (e.g., AltStore, SideStore, Sideloadly).

## Adding Game Content

After the first launch, game data is copied to:

```
Documents/ikemen-go/IkemenGo/

```

### Directory structure

```
Documents/ikemen-go/IkemenGo/
├── data/          # Screenpack and engine data
├── font/          # Shared fonts
├── external/      # External scripts and resources
├── chars/         # Character folders
├── stages/        # Stage files
└── sound/         # Sound and music files

```

### Adding characters and stages

1. Drop your character folders into `Chars/` and `.def` stage files into `Stages/`.
2. Edit the select screen file in `data/` to include them.
3. Restart the app.

> **Memory note for heavy content:** iOS enforces strict memory limits per app. In Tag/Simul/Turns modes, keeping every character fully loaded in memory can cause the **Jetsam** watchdog to kill the app without warning. Avoid overly heavy custom fighters or stages with long background videos, or mitigate this by using the **GetMoreRAM** app by [hugeBlack](https://github.com/hugeBlack/GetMoreRam).

## Project Structure

```
ikemen-go-ios/
├── Ikemen-GO/             # Upstream Ikemen GO engine source
├── IKEMENGo/              # iOS app wrapper (Objective-C, Makefiles, UI controllers)
├── ios/                   # iOS-specific build tree and scripts
├── deps/                  # Pre-compiled static libraries (SDL2, libxmp, FFmpeg, MoltenVK)
├── LICENSE                # MIT License
└── README.md              # This file

```

## Credits

* **[Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO)** — upstream engine
* **[MoltenVK](https://github.com/KhronosGroup/MoltenVK)** — Vulkan on Metal
* **[M.U.G.E.N](https://www.google.com/search?q=https://mugenengine.com/kelas)** — original fighting game engine by Elecbyte
* **[Theos](https://theos.dev/)** — iOS build system
* **[SDL2](https://www.libsdl.org/)** — multimedia library
* **[FFmpeg](https://ffmpeg.org/)** — audio/video processing
* **[libxmp](https://xmp.sourceforge.net/)** — module music player

**This project is a fanmade port and is not affiliated with the official IKEMEN Go development team.**

## License

MIT License — see [LICENSE](https://www.google.com/search?q=LICENSE) for details. FFmpeg is used under LGPL v2.1.
