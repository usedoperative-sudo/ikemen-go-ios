#define SDL_MAIN_HANDLED 1
#import <UIKit/UIKit.h>
#include <string.h>
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

int main(int argc, char *argv[]) {
	@autoreleasepool {
		seedEngineData();
		return SDL_UIKitRunApp(argc, argv, SDL_main);
	}
}