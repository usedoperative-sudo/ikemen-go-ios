//
//  AppDelegate.m
//  IKEMENGo
//
//  Legacy (non-scene) app delegate: owns the host UIWindow whose root view
//  becomes the Metal host for the engine's CAMetalLayer (see SDLWindowFix.m).
#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end