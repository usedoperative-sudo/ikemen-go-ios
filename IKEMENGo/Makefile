TARGET := iphone:clang:26.5
TARGET_OS_DEPLOYMENT_VERSION = 15.0
ARCHS = arm64
PACKAGE_FORMAT = ipa
INSTALL_TARGET_PROCESSES = IKEMENGo

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IKEMENGo

IKEMENGo_FILES = main.m AppDelegate.m ViewController.m OverlayControls.m SDLWindowFix.m MetalStubs.m
IKEMENGo_CFLAGS = -fobjc-arc -Wno-error \
	-I/workspaces/ikemen-go-ios/deps/ios-sdl/include \
	-I/workspaces/ikemen-go-ios/deps/ios-sdl/include/SDL2
# libengine.a is cross-compiled for iOS on Linux by ios/engine/build-ios.sh;
# MoltenVK is force-loaded so its exported vk* symbols survive for dlsym.
IKEMENGo_LDFLAGS = \
	-fuse-ld=lld \
	engine/libengine.a \
	-Wl,-force_load,/workspaces/ikemen-go-ios/deps/ios-moltenvk/libMoltenVK.a \
	-L/workspaces/ikemen-go-ios/deps/ios-sdl/lib -lSDL2 \
	-L/workspaces/ikemen-go-ios/deps/ios-libxmp/lib -lxmp \
	-L/workspaces/ikemen-go-ios/deps/ios-ffmpeg/lib -lavfilter -lswscale -lavformat -lavcodec -lswresample -lavutil \
	-lz -lbz2 -liconv \
	-framework AudioToolbox \
	-framework AVFoundation \
	-framework CoreAudio \
	-framework CoreBluetooth \
	-framework CoreFoundation \
	-framework CoreGraphics \
	-framework CoreMedia \
	-framework CoreMotion \
	-framework CoreVideo \
	-framework Foundation \
	-framework IOSurface \
	-framework Metal \
	-framework QuartzCore \
	-framework UIKit \
	-weak_framework GameController \
	-weak_framework CoreHaptics \
	-lc++ \
	-pthread \
	-Wl,-no_compact_unwind \
	-Wl,--error-limit=0

# Bundle the assembled runtime assets into the app for first-run seeding.
# XXX_RESOURCE_DIRS *flattens* a directory's contents into the bundle root,
# which does not match the engine's expected data/system.zss layout, so only
# Resources (Info.plist, icons) is flattened and the asset dirs are staged as
# real subfolders below.
IKEMENGo_RESOURCE_DIRS = Resources

# ios/assets/game/ is produced by ios/assets/fetch-default-assets.sh, which
# merges the engine tree (ios/engine) with the Elecbyte screenpack. The
# first-launch seeder (main.m -> seedEngineData) copies these subfolders from
# the bundle into Documents/ikemen-go/IkemenGo.
IKEMEN_RUNTIME_ASSETS = $(THEOS_PROJECT_DIR)/../ios/assets/game

before-IKEMENGo-stage::
	@if [ ! -d "$(IKEMEN_RUNTIME_ASSETS)" ] || [ ! -f "$(THEOS_PROJECT_DIR)/../ios/assets/VERSION" ]; then \
		echo "=== Runtime assets missing; fetching default game assets ..."; \
		"$(THEOS_PROJECT_DIR)/../ios/assets/fetch-default-assets.sh" || exit 1; \
	fi
	$(info === Packaging runtime assets into the bundle ...)
	mkdir -p "$(_THEOS_SHARED_BUNDLE_STAGE_PATH)"
	for d in data external font chars stages sound video; do \
		rm -rf "$(_THEOS_SHARED_BUNDLE_STAGE_PATH)/$$d"; \
		if [ -d "$(IKEMEN_RUNTIME_ASSETS)/$$d" ]; then \
			cp -R "$(IKEMEN_RUNTIME_ASSETS)/$$d" "$(_THEOS_SHARED_BUNDLE_STAGE_PATH)/"; \
		fi; \
	done
	cp "$(THEOS_PROJECT_DIR)/../ios/assets/VERSION" "$(_THEOS_SHARED_BUNDLE_STAGE_PATH)/ikemen-assets.version"

include $(THEOS_MAKE_PATH)/application.mk