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

# Bundle the engine's built-in data/external/font into the app for first-run
# seeding. XXX_RESOURCE_DIRS *flattens* a directory's contents into the bundle
# root, which does not match the engine's expected data/system.zss layout, so
# only Resources (Info.plist, icons) is flattened and the engine dirs are staged
# as real subfolders below.
IKEMENGo_RESOURCE_DIRS = Resources

# The first-launch seeder (main.m -> seedEngineData) expects "data", "external",
# and "font" subfolders inside the bundle; carry them over as true subfolders.
before-IKEMENGo-stage::
	$(info === Packaging engine data/external/font into the bundle ...)
	mkdir -p "$(_THEOS_SHARED_BUNDLE_STAGE_PATH)"
	for d in data external font; do \
		rm -rf "$(_THEOS_SHARED_BUNDLE_STAGE_PATH)/$$d"; \
		cp -R "/workspaces/ikemen-go-ios/ios/engine/$$d" "$(_THEOS_SHARED_BUNDLE_STAGE_PATH)/"; \
	done

include $(THEOS_MAKE_PATH)/application.mk