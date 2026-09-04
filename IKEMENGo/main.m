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
#include "SDL.h"

extern int SDL_main(int argc, char *argv[]);
extern int SDL_UIKitRunApp(int argc, char *argv[], SDL_main_func mainFunction);

// The SDKs these toolchains ship may omit ___isOSVersionAtLeast from
// libSystem.tbd. SDL links against it, so provide a runtime implementation.
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

// The engine chdir's into the SDL pref dir and reads data/ from there. We
// place the base dir in the app's Documents/ikemen-go/IkemenGo so it's
// visible in the iOS Files app / file sharing (handy for adding custom
// stages, chars, and data). We export its path to Go via IKEMEN_BASE_DIR.
// On first launch we seed that directory from the bundled "engine" folder.
static void seedEngineData(void) {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if ([paths count] == 0) {
		return;
	}
	NSString *base = [[paths objectAtIndex:0]
		stringByAppendingPathComponent:@"ikemen-go/IkemenGo"];

	// Tell the Go engine where the game lives.
	setenv("IKEMEN_BASE_DIR", [base UTF8String], 1);

	NSString *srcRoot = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"engine"];
	NSString *marker = [base stringByAppendingPathComponent:@"data"];

	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:marker]) {
		NSLog(@"IKEMEN: engine data already present in %@", base);
		return; // already seeded
	}

	NSError *err = nil;
	[fm createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:&err];
	if (err) {
		NSLog(@"IKEMEN: seed base dir create failed: %@", err);
		return;
	}

	NSArray *entries = [fm contentsOfDirectoryAtPath:srcRoot error:&err];
	if (err || !entries) {
		NSLog(@"IKEMEN: bundle engine dir not found at %@ (%@)", srcRoot, err);
		return;
	}

	for (NSString *entry in entries) {
		NSString *src = [srcRoot stringByAppendingPathComponent:entry];
		NSString *dst = [base stringByAppendingPathComponent:entry];
		if ([fm fileExistsAtPath:dst]) {
			continue;
		}
		NSError *copyErr = nil;
		if (![fm copyItemAtPath:src toPath:dst error:&copyErr]) {
			NSLog(@"IKEMEN: seeding %@ failed: %@", entry, copyErr);
		}
	}
	NSLog(@"IKEMEN: engine data seeded into %@", base);
}

// Returns the game base directory (Documents/ikemen-go/IkemenGo) as a
// malloc'd C string. The Go engine reads this directly (instead of trusting
// an env var, which Go's runtime may not observe if set after Go init) and is
// responsible for freeing it with free(). Returns NULL if unavailable.
const char *IOSGameBaseDir(void) {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if ([paths count] == 0) {
		return NULL;
	}
	NSString *base = [[paths objectAtIndex:0]
		stringByAppendingPathComponent:@"ikemen-go/IkemenGo"];
	return strdup([base UTF8String]);
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
	const char *base = IOSGameBaseDir();
	if (base) {
		snprintf(g_nativeCrashDir, sizeof(g_nativeCrashDir), "%s", base);
		free((void *)base);
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

int main(int argc, char *argv[]) {
	@autoreleasepool {
		seedEngineData();
		IKNativeCrashInit();
		return SDL_UIKitRunApp(argc, argv, SDL_main);
	}
}