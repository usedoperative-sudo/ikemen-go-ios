#define SDL_MAIN_HANDLED 1
#import <UIKit/UIKit.h>
#include <execinfo.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "AppDelegate.h"

// The SDKs these toolchains ship may omit ___isOSVersionAtLeast and
// ___isPlatformVersionAtLeast from libSystem.tbd. SDL and MoltenVK link
// against them, so provide runtime implementations.
int __isOSVersionAtLeast(unsigned major, unsigned minor, unsigned patch) {
	NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
	if (v.majorVersion != (NSInteger)major) {
		return v.majorVersion > (NSInteger)major;
	}
	if (v.minorVersion != (NSInteger)minor) {
		return v.minorVersion > (NSInteger)minor;
	}
	return v.patchVersion >= (NSInteger)patch;
}

int __isPlatformVersionAtLeast(unsigned major, unsigned minor, unsigned patch) {
	return __isOSVersionAtLeast(major, minor, patch);
}

// The game base dir lives in the app's Documents/ikemen-go/IkemenGo so it's
// visible in the iOS Files app / file sharing (handy for adding custom stages,
// chars, and data). The engine receives it as the --assets argv argument.
NSString *IKEMENDefaultBaseDir(void) {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if ([paths count] == 0) {
		return nil;
	}
	return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"ikemen-go/IkemenGo"];
}

// Recursively copy src -> dst, creating anything missing but never replacing
// an existing file. This lets a new build fill in game files that older
// versions never shipped (e.g. the screenpack) while preserving user edits
// such as a customised data/select.def or extra chars.
static void IKCopyMissing(NSString *src, NSString *dst, NSFileManager *fm) {
	BOOL dstIsDir = NO;
	BOOL dstExists = [fm fileExistsAtPath:dst isDirectory:&dstIsDir];
	if (!dstExists) {
		NSError *err = nil;
		if (![fm copyItemAtPath:src toPath:dst error:&err]) {
			NSLog(@"IKEMEN: seeding %@ failed: %@", src, err);
		}
		return;
	}
	if (!dstIsDir) {
		return; // a file already lives here; keep it
	}
	NSError *listErr = nil;
	NSArray<NSString *> *children = [fm contentsOfDirectoryAtPath:src error:&listErr];
	if (listErr) {
		return;
	}
	for (NSString *child in children) {
		IKCopyMissing([src stringByAppendingPathComponent:child],
		              [dst stringByAppendingPathComponent:child], fm);
	}
}

// On first launch (or after the bundled assets change) seed the base dir from
// the runtime assets staged in the app ("data", "external", "font", "chars",
// "stages", "sound", "video"). Seeding is a merge: existing files, including
// user edits, are preserved and only missing files are added.
static void seedEngineData(void) {
	NSString *base = IKEMENDefaultBaseDir();
	if (!base) {
		return;
	}

	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *err = nil;
	[fm createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:&err];
	if (err) {
		NSLog(@"IKEMEN: seed base dir create failed: %@", err);
		return;
	}

	// The bundled stamp changes whenever the default assets change. If it
	// matches the marker already in Documents, there is nothing to do.
	NSString *bundleVersionPath = [[[NSBundle mainBundle] resourcePath]
		stringByAppendingPathComponent:@"ikemen-assets.version"];
	NSString *bundleVersion = [NSString stringWithContentsOfFile:bundleVersionPath
		encoding:NSUTF8StringEncoding error:NULL];
	if (bundleVersion.length == 0) {
		// Defensive: a stamp-less build still seeds once instead of on every launch.
		bundleVersion = @"unversioned";
	}
	NSString *stampPath = [base stringByAppendingPathComponent:@".ikemen-assets-version"];
	NSString *stamp = [NSString stringWithContentsOfFile:stampPath
		encoding:NSUTF8StringEncoding error:NULL];

	NSString *screenpackMarker = [base stringByAppendingPathComponent:@"data/ikemen1/system.def"];
	BOOL needsSeed = YES;
	if ([stamp isEqualToString:bundleVersion]
		&& [fm fileExistsAtPath:screenpackMarker]) {
		needsSeed = NO;
	}
	if (!needsSeed) {
		return;
	}

	NSArray *entries = @[ @"data", @"external", @"font", @"chars", @"stages", @"sound", @"video" ];
	NSString *res = [[NSBundle mainBundle] resourcePath];
	for (NSString *entry in entries) {
		NSString *src = [res stringByAppendingPathComponent:entry];
		if (![fm fileExistsAtPath:src]) {
			continue; // not bundled (e.g. an empty optional dir was omitted)
		}
		IKCopyMissing(src, [base stringByAppendingPathComponent:entry], fm);
	}

	if (bundleVersion.length > 0) {
		NSError *writeErr = nil;
		if (![bundleVersion writeToFile:stampPath atomically:YES
			encoding:NSUTF8StringEncoding error:&writeErr]) {
			NSLog(@"IKEMEN: writing asset stamp failed: %@", writeErr);
		}
	}
	NSLog(@"IKEMEN: runtime assets merged into %@ (%@)", base, bundleVersion);
}

// Crash log directory, resolved once at startup so the signal handler can use
// only async-signal-safe calls (open/write/backtrace/strsignal). ObjC/NSLog are
// NOT safe from inside a signal handler, so avoid them here.
static char g_nativeCrashDir[4096];

// Captures a native crash (SIGSEGV/SIGABRT/SIGBUS/...) that Go's recover() never
// gets to see (it only catches Go panics), writing the signal + a native stack
// trace into the engine's save/logs folder so it's curl-able for diagnosis.
static void IKNativeCrashHandler(int sig, siginfo_t *info, void *uctx) {
	(void)uctx;
	static volatile sig_atomic_t inHandler = 0;
	if (inHandler) {
		_exit(128 + sig);
	}
	inHandler = 1;

	char path[8192];
	snprintf(path, sizeof(path), "%s/save/logs/native_crash.log", g_nativeCrashDir);

	int fd = open(path, O_CREAT | O_WRONLY | O_APPEND, 0644);
	if (fd >= 0) {
		char header[512];
		int n = snprintf(header, sizeof(header),
			"===== NATIVE CRASH =====\n"
			"Signal: %d (%s)\n"
			"Faulting address: %p\n"
			"Stack trace:\n",
			sig, strsignal(sig), (void *)(info ? info->si_addr : NULL));
		if (n > 0) {
			write(fd, header, (size_t)n);
		}
		void *frames[128];
		int count = backtrace(frames, 128);
		if (count > 0) {
			backtrace_symbols_fd(frames, count, fd);
		}
		write(fd, "\n===== END NATIVE CRASH =====\n", 30);
		close(fd);
	}

	_exit(128 + sig);
}

static void IKNativeCrashInit(void) {
	// Resolve the Documents base dir once (normal context, Foundation is
	// safe here) and keep only the plain path for the signal handler.
	NSString *base = IKEMENDefaultBaseDir();
	if (base) {
		snprintf(g_nativeCrashDir, sizeof(g_nativeCrashDir), "%s", [base UTF8String]);
	} else {
		strncpy(g_nativeCrashDir, ".", sizeof(g_nativeCrashDir) - 1);
	}

	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_sigaction = IKNativeCrashHandler;
	sa.sa_flags = SA_SIGINFO | SA_RESETHAND; // restore default after first hit
	sigemptyset(&sa.sa_mask);
	sigaction(SIGSEGV, &sa, NULL);
	sigaction(SIGABRT, &sa, NULL);
	sigaction(SIGBUS, &sa, NULL);
	sigaction(SIGILL, &sa, NULL);
	sigaction(SIGFPE, &sa, NULL);
}

// MoltenVK 1.4.2's device init (MVKDevice::initQueues, built under the Xcode 16
// SDK) creates an MTLResidencySetDescriptor when Metal argument buffers are in use
// and the device supports residency sets (iOS 17+). The iPhoneOS16.5 SDK cannot
// link that class, so it is provided by MetalStubs.m; passing the stub to Metal's
// newResidencySetWithDescriptor:error: raises an NSException that aborts the app.
// MoltenVK gates the residency-set path on _isUsingMetalArgumentBuffers (and it
// reads this config member from the MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS env var
// lazily, at first config use during vkCreateInstance). Forcing it off makes the
// residency path unreachable, so the stub is never exercised at runtime. The
// engine enables no argument-buffer-dependent Vulkan features (no descriptor
// indexing, no sparse), so this is functionally transparent. Upstream ikemen
// would crash here on iOS 17+; this is the documented deviation.
static void IKApplyMoltenVKConfigOverrides(void) {
	setenv("MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", "0", 1);
	NSLog(@"IKEMENGo: set MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0 "
	      @"(avoid MoltenVK MTLResidencySetDescriptor stub deref)");
}

int main(int argc, char *argv[]) {
	@autoreleasepool {
		IKNativeCrashInit();
		IKApplyMoltenVKConfigOverrides();
		seedEngineData();
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}