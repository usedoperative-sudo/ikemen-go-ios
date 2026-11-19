//
//  AppDelegate.h
//  IKEMENGo
//
#import <UIKit/UIKit.h>
#import "EngineLifecycle.h"

// Defined in main.m; YES once the engine's renderer is ready.
extern BOOL IKEngineStarted;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;

@end