//
//  AppDelegate.m
//  IKEMENGo
//
//  Legacy (non-scene) app delegate: owns the host UIWindow whose root view
//  becomes the Metal host for the engine's CAMetalLayer (see SDLWindowFix.m).
#import "AppDelegate.h"
#import "ViewController.h"
#import <SDL2/SDL.h>

// Called by the Go engine once the renderer is fully initialized.
void IKSetEngineStarted(int started) {
	IKEngineStarted = started ? YES : NO;
}

// Polled by the renderer every frame. This is the authoritative source for
// whether the Metal layer can be used; it does not rely on SDL/UIKit events.
// UIApplicationStateInactive is common during transitions and while the app
// is covering another app; the Metal layer is still usable then.
// Only the Background state must stop rendering.
int IKIsAppActive(void) {
	return [UIApplication sharedApplication].applicationState != UIApplicationStateBackground ? 1 : 0;
}

static void IKPushSDLLifecycleEvent(Uint32 type) {
	SDL_Event event;
	SDL_zero(event);
	event.type = type;
	SDL_PushEvent(&event);
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.rootViewController = [[ViewController alloc] init];
	[self.window makeKeyAndVisible];
	return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	if (IKEngineStarted) {
		IKPushSDLLifecycleEvent(SDL_APP_DIDENTERBACKGROUND);
	}
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	if (IKEngineStarted) {
		IKPushSDLLifecycleEvent(SDL_APP_DIDENTERFOREGROUND);
	}
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	if (IKEngineStarted) {
		// Extra nudge in case the willEnterForeground notification was missed
		// while SDL was pumping the UIKit run loop. The renderer ignores a
		// duplicate foreground event when it is already active.
		IKPushSDLLifecycleEvent(SDL_APP_DIDENTERFOREGROUND);
	}
}

@end
