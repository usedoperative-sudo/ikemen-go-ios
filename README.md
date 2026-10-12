# IKEMEN Go for iOS

An iOS port of [Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO), an open-source fighting game engine compatible with [M.U.G.E.N](https://en.wikipedia.org/wiki/Mugen_(game_engine)) resources, written in Go.

This port tracks **pure upstream Ikemen-GO** (built from scratch — no fork-style patches). The upstream engine's official iOS story (Vulkan via MoltenVK on a CAMetalLayer, SDL2 UIKit driver) is replicated here on Linux with Theos, so the iOS app is the same engine the upstream macOS/Xcode flow ships — with exactly two deliberate, documented deviations: a small crash-path guard in `src/main.go` (`handlePanic`) so that pre-renderer-init crashes surface as readable errors instead of a nested segfault, and a MoltenVK config override (`MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0`) so the app wrapper never trips MoltenVK's iOS 17+ residency-set path (see *Internals* below).

Play classic M.U.G.E.N characters, stages, and screenpacks on your iOS device with native on-screen touch controls.

## Features

- **Pure upstream engine** -- `ios/engine/` is a synced copy of upstream `ikemen-engine/Ikemen-GO`; the only local engine modification is the `handlePanic` crash-path guard in `src/main.go` (see *Internals* below). The app wrapper additionally sets one MoltenVK config env var (also documented below).
- **Full M.U.G.E.N compatibility** -- run characters, stages, screenpacks, and fonts from the M.U.G.E.N ecosystem
- **Vulkan rendering via MoltenVK** -- the engine's Vulkan renderer runs on Metal through MoltenVK (statically linked, resolved via `dlsym` exactly like the official Xcode app); includes the upstream engine's Metal-layer attach bridge (`SDLWindowFix.m`)
- **Native on-screen controls** -- virtual D-pad (8-way) and 6 attack buttons (A/B/C/X/Y/Z) plus Start and Menu, translated into a **virtual SDL game controller** (same mechanism as the official ikemen-ios wrapper), so the engine's stock SDL joystick/gamecontroller input path consumes them
- **SDL2-based** -- cross-platform windowing, input, and audio via SDL2
- **FFmpeg integration** -- background video playback (WebM/Matroska with VP8/VP9/Opus/Vorbis)
- **Module music support** -- MOD/XM/S3M/IT and other tracker formats via libxmp
- **Game controller support** -- MFi and GameController framework controllers
- **File sharing** -- game data lives in `Documents/ikemen-go/IkemenGo`, accessible via iOS Files app
- **Native crash log** -- a hard crash (SIGSEGV/SIGABRT/...) writes a native backtrace to `save/logs/native_crash.log` for diagnosis

## Prerequisites

- **iOS device** (arm64, iOS 15+)
- **[Theos](https://theos.dev/)** -- iOS build system (for non-Mac environments), with the **iPhoneOS 16.5 SDK** (or adjust `IOS_SDK`/`TARGET` in `ios/engine/build-ios.sh`)
- **Clang** (the toolchain is tested on clang 22; earlier clangs work) plus **`ld64.lld`** (LLVM's Apple-Mach-O linker) for the engine's Go link step
- **Go 1.27+** -- the upstream engine's `go.mod` requires `go 1.27.0`
- Optionally **curl** (downloads MoltenVK's iOS static library automatically if `deps/ios-moltenvk` is missing) and **`rsync`** (used while assembling the app bundle)

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

### 2. Compile the Go engine for iOS

One script does everything: sets up the iOS cross-compiler (`GOOS=ios GOARCH=arm64 CGO_ENABLED=1`, `GOEXPERIMENT=arenas`), the iOS SDK flags, SDL/FFmpeg/libxmp pkg-config and include paths, injects the version into the binary, and writes the c-archive the app links:

```bash
./ios/engine/build-ios.sh
```

This produces `IKEMENGo/engine/libengine.a` (a ~18 MB static library exporting `SDL_main` and `GetMoltenVKWindowID`). Recent versions of the script also fetch and stage MoltenVK's iOS static library into `deps/ios-moltenvk/` on first run.

> The engine itself never links MoltenVK: the bundled `github.com/Eiton/vulkan` headers resolve MoltenVK's entry points with `dlsym(RTLD_DEFAULT)`. MoltenVK is linked only into the final app, force-loaded so its exported `vk*` symbols survive for that `dlsym`.

### 3. Build the iOS app

```bash
cd IKEMENGo
make package
```

This produces an `.ipa` file in `IKEMENGo/packages/`. The app bundle embeds the engine's `data/`, `external/`, and `font/` folders as real subfolders (staged via a `before-IKEMENGo-stage` hook in the Makefile, since `RESOURCE_DIRS` alone would *flatten* their contents into the bundle root); on first launch they are seeded into `Documents/ikemen-go/IkemenGo`.

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
├── data/           # Screenpack and engine data
├── font/           # Shared fonts
├── external/       # External scripts and resources
├── chars/          # Character folders
├── stages/         # Stage files
└── sound/          # Sound and music files
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
├── Ikemen-GO/              # Upstream Ikemen GO engine source (embedded copy)
│   ├── src/                # Engine source code (Go)
│   ├── build/              # Build scripts for desktop platforms
│   └── ...
├── IKEMENGo/               # iOS app
│   ├── main.m              # App entry point, native crash handler, engine-data seeding
│   ├── AppDelegate.m/h     # Legacy (non-scene) app delegate; owns the host UIWindow
│   ├── ViewController.m/h  # Host VC: overlay + launches engine via SDL_main(3, argv) with --assets
│   ├── SDLWindowFix.m/h    # Metal-layer attach bridge (IkemenAttachMetalLayer) — same contract as the official wrapper
│   ├── GoWindow.h          # Bridge decl for the engine-exported Go symbols
│   ├── MetalStubs.m/h      # Link-time stub for iOS 17-only MTLResidencySetDescriptor; kept inert by IKApplyMoltenVKConfigOverrides
│   ├── OverlayControls.m/h # On-screen touch controls -> virtual SDL game controller
│   ├── Makefile            # Theos build configuration
│   ├── control             # Debian-like package metadata
│   ├── engine/             # Compiled engine output (libengine.a)
│   └── Resources/          # App bundle resources (Info.plist, icons)
├── ios/                    # iOS-specific engine build tree
│   └── engine/             # Upstream engine source + go.mod + build-ios.sh
├── deps/                   # Pre-compiled iOS static libraries
│   ├── ios-sdl/            # SDL2 (UIKit driver, Vulkan/Metal enabled)
│   ├── ios-libxmp/         # libxmp (module music)
│   ├── ios-ffmpeg/         # FFmpeg (video/audio decoding)
│   ├── ios-moltenvk/       # MoltenVK iOS static lib (flat: libMoltenVK.a + LICENSE; app-only)
│   └── scripts/            # Recipes that rebuilt the deps from source on Linux (see the FFmpeg --nm note below)
├── LICENSE                 # MIT License
└── README.md               # This file
```

## Internals (how the pieces fit)

- **Engine** -- `ios/engine/` is a directly synced copy of upstream (see `IOS_.TXT` / `build/build.sh` for the upstream reference flow). The engine's iOS build (`src/util_ios.go`) exports `SDL_main` and reads the game dir from `--assets <dir>` on the command line, chdir'ing into it at startup.
- **iOS-only deviation from upstream (crash-path guard)** -- upstream's `handlePanic` (in `src/main.go`) calls `gfx.GetName()`/`gfx.DebugInfo()` unconditionally and then `sys.shutdown()`. If the engine crashes *before* the renderer exists (e.g. missing seeded game data at startup), the nil `gfx` interface causes a real SIGSEGV *inside* `handlePanic`, masking the actual error. The port guards those three sites with `if gfx != nil`, so a pre-init failure writes the engine's readable log (`save/logs/Ikemen_*.log`) instead. Nothing else in the engine differs from upstream.
- **App glue** -- `main.m` seeds `Documents/ikemen-go/IkemenGo` from the bundled engine folders, then `UIApplicationMain` runs legacy (non-scene) style with a custom `AppDelegate`/`ViewController`. The `ViewController` calls the engine's `SDL_main(3, argv)` with `--assets`.
- **Display** -- SDL2 creates its Vulkan window (CAMetalLayer payload). Engines' renderer init calls `IkemenAttachMetalLayer()` (via cgo, from `src/sdl_ios.go`), which reparents the single CAMetalLayer into the app's host window, under the touch overlay. MoltenVK's `vkGetInstanceProcAddr` is discovered via `dlsym(RTLD_DEFAULT)` thanks to `-force_load` in the app's link step.
- **Input** -- the overlay translates touches into a virtual SDL game controller (6 axes / 15 buttons / 1 hat). The engine's stock SDL controller path maps A→A, B→B, C→right trigger, X→X, Y→Y, Z→right shoulder, START→START, MENU→BACK; the D-pad drives both the D-pad buttons and the POV hat.
- **Linker** -- the app links with `-fuse-ld=lld` (LLVM's unified driver, which auto-selects the Mach-O flavor; `ld64.lld` by name rejects Theos' `-platform_version`/`-arch` flags as written by this toolchain). `TARGET_OS_DEPLOYMENT_VERSION = 15.0` pins `minos 15.0`. The static MoltenVK needs `-Wl,-force_load` so its exported `vk*` symbols stay visible for the engine's `dlsym(RTLD_DEFAULT)` resolution (SDL's UIKit Vulkan loader).
- **Linking hiccups fixed along the way** -- `libSystem` shims for `__isOSVersionAtLeast`/`__isPlatformVersionAtLeast` (the 16.5 SDK's `libSystem.tbd` omits them); `-framework CoreBluetooth` for SDL's BLE (`hid.m.o`); `-lz -lbz2 -liconv` for the FFmpeg codecs; a `MTLResidencySetDescriptor` stub class (iOS 17+ Metal API that MoltenVK 1.4.2 references; the 16.5 SDK lacks it, and ld64.lld supports neither `-U` nor `-weak_import` to weak-link symbols absent from the SDK). When FFmpeg's NEON assembly is rebuilt, it MUST pass `--nm=llvm-nm` to `configure`: FFmpeg detects the Mach-O underscore symbol prefix by reading a probe object with `nm`, and GNU `nm` cannot parse Mach-O, silently producing underscore-less `ff_*_neon` exports that no Mach-O linker can resolve (see `deps/scripts/build-ffmpeg-ios.sh`).

- **App-wrapper deviation (MoltenVK residency sets)** -- MoltenVK 1.4.2's release binaries are built under the Xcode 16 SDK (`MVK_XCODE_16`), which adds a block in `MVKDevice::initQueues` that creates an `MTLResidencySetDescriptor` and calls Metal's `newResidencySetWithDescriptor:error:` when two runtime conditions hold: the Metal device supports residency sets (an iOS 17+ feature) *and* MoltenVK's `_isUsingMetalArgumentBuffers` is true. `_isUsingMetalArgumentBuffers` is `descriptorSetArgumentBuffers && getMVKConfig().useMetalArgumentBuffers`, and `useMetalArgumentBuffers` is read from the `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS` env var at the first global-config read, which MoltenVK deliberately defers until `vkCreateInstance` so the app's process environment is fully populated). On an iOS 17+ device the path executes and passes the stub descriptor to Metal, which raises an NSException from the IOGPU/AGX driver (`abort` with `objc_exception_throw`), killing the app before the renderer comes up. `IKEMENGo/main.m`'s `IKApplyMoltenVKConfigOverrides()` therefore sets `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0` before the engine starts: the residency path becomes statically unreachable on every device, so the stub is never dereferenced. The engine enables no argument-buffer-dependent Vulkan features (upstream requests only swapchain/dynamic-rendering/sync2/multiview/push-descriptor; no descriptor indexing, no sparse), so this is functionally transparent.

## Credits

- **[Ikemen GO](https://github.com/ikemen-engine/Ikemen-GO)** -- the upstream engine this project is based on
- **[ikemen-ios](https://github.com/ikemen-ios/I.K.E.M.E.N-Go)** -- the official iOS wrapper whose SDLWindowFix / virtual-controller patterns are mirrored in this app
- **[MoltenVK](https://github.com/KhronosGroup/MoltenVK)** -- Vulkan on Metal
- **[M.U.G.E.N](https://mugenengine.com/)** -- the original fighting game engine by Elecbyte
- **[Theos](https://theos.dev/)** -- iOS build system for non-Mac environments
- **[SDL2](https://www.libsdl.org/)** -- cross-platform multimedia library
- **[FFmpeg](https://ffmpeg.org/)** -- audio/video processing library
- **[libxmp](https://xmp.sourceforge.net/)** -- module music player library

**This project is not linked to IKEMEN Go official development nor it creators, the development of this port is totally fanmade**

## License

This project is licensed under the **MIT License** -- see [LICENSE](LICENSE) for details.

Ikemen GO engine source is MIT licensed. FFmpeg is used under LGPL v2.1. See [LICENCE.txt](Ikemen-GO/LICENCE.txt) for details on bundled assets.