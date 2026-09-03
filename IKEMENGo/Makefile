TARGET := iphone:clang:26.5
ARCHS = arm64
PACKAGE_FORMAT = ipa
INSTALL_TARGET_PROCESSES = IKEMENGo

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IKEMENGo

IKEMENGo_FILES = main.m OverlayControls.m
IKEMENGo_CFLAGS = -fobjc-arc -Wno-error -I/workspaces/ikemen-go-ios/deps/ios-sdl/include/SDL2
IKEMENGo_LDFLAGS = \
	engine/libengine.a \
	-L/workspaces/ikemen-go-ios/deps/ios-sdl/lib -lSDL2 \
	-L/workspaces/ikemen-go-ios/deps/ios-libxmp/lib -lxmp \
	-L/workspaces/ikemen-go-ios/deps/ios-ffmpeg/lib -lavfilter -lswscale -lavformat -lavcodec -lswresample -lavutil \
	-framework AudioToolbox \
	-framework AVFoundation \
	-framework CoreAudio \
	-framework CoreFoundation \
	-framework CoreGraphics \
	-framework CoreMedia \
	-framework CoreMotion \
	-framework CoreVideo \
	-framework Foundation \
	-framework Metal \
	-framework OpenGLES \
	-framework QuartzCore \
	-framework UIKit \
	-weak_framework GameController \
	-weak_framework CoreHaptics \
	-pthread \
	-Wl,-no_compact_unwind

include $(THEOS_MAKE_PATH)/application.mk