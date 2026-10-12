TARGET := iphone:clang:16.5
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

# Bundle the engine's built-in data/external/font into the app for first-run seeding.
IKEMENGo_RESOURCE_DIRS = Resources ../ios/engine/data ../ios/engine/external ../ios/engine/font

include $(THEOS_MAKE_PATH)/application.mk