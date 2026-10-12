//
//  ViewController.m
//  IKEMENGo
//
//  Host UIViewController: owns the touch overlay and, once the app's UI is up,
//  launches the engine by calling the engine-exported SDL_main() with
//  "--assets <game base dir>" — the upstream engine's iOS contract
//  (see src/util_ios.go in the engine source).
#import "ViewController.h"
#import "OverlayControls.h"

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#import <SDL2/SDL.h>
#include <stdlib.h>
#include <string.h>
#import "GoWindow.h"

// Provided by main.m (game documents dir).
NSString *IKEMENDefaultBaseDir(void);
// Exported by libengine.a.
extern int SDL_main(int argc, char *argv[]);

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.view.multipleTouchEnabled = YES;

    IkemenOverlayView *overlay = [[IkemenOverlayView alloc] initWithFrame:self.view.bounds];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:overlay];

    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runIkemenGo];
}

- (void)runIkemenGo {
    static BOOL started = NO;
    if (started) {
        return;
    }
    started = YES;

    NSString *baseDir = IKEMENDefaultBaseDir();
    if (!baseDir) {
        NSLog(@"IKEMEN: no game base dir available, engine not started");
        return;
    }

    // argv: [0]=program, [1]=--assets, [2]=base dir, [3]=NULL
    char **argv = calloc(4, sizeof(char *));
    if (!argv) {
        return;
    }
    argv[0] = strdup("ikemen-go");
    argv[1] = strdup("--assets");
    argv[2] = strdup([baseDir fileSystemRepresentation]);
    argv[3] = NULL;
    if (!argv[0] || !argv[1] || !argv[2]) {
        for (int i = 0; i < 3; i++) {
            free(argv[i]);
        }
        free(argv);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        SDL_SetMainReady();

        NSString *dbPath = [baseDir stringByAppendingPathComponent:@"external/gamecontrollerdb.txt"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
            SDL_SetHint(SDL_HINT_GAMECONTROLLERCONFIG_FILE, [dbPath UTF8String]);
        }

        // Enable Apple's native controller subsystem (MFi)
        SDL_SetHint(SDL_HINT_JOYSTICK_MFI, "1");
        // Keep background events allowed
        SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
        // Force button labels mapping
        SDL_SetHint(SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS, "1");

        // Blocking: runs the full engine loop (engine drives the UIKit run loop's
        // event pump itself on this thread).
        int result = SDL_main(3, argv);
        (void)result;

        for (int i = 0; i < 3; i++) {
            free(argv[i]);
        }
        free(argv);
    });
}

@end