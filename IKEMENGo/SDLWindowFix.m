//
//  SDLWindowFix.m
//  I.K.E.M.E.N-Go
//
//  Created by Jesuszilla on 8/28/26.
//
//  Comments by Jesuszilla (transferred verbatim from the official ikemen-ios
//  wrapper so the upstream engine's iOS contract is matched exactly).

#import <UIKit/UIKit.h>
#import "SDLWindowFix.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <SDL2/SDL.h>
#import <SDL2/SDL_metal.h>
#import <SDL2/SDL_syswm.h>

static __weak UIWindow *sSDLWindow = nil;

UIWindow *IkemenGetSDLWindow(void) {
    return sSDLWindow;
}

static UIInterfaceOrientationMask sLockedMask = UIInterfaceOrientationMaskAll;
static BOOL sLocked = NO;

BOOL IkemenOrientationIsLocked(void) {
    return sLocked;
}
UIInterfaceOrientationMask IkemenLockedOrientationMask(void) {
    return sLockedMask;
}

@implementation MetalContainerView
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.metalLayer) {
        return;
    }
    CGSize boundsSize = self.bounds.size;
    if (boundsSize.width <= 0 || boundsSize.height <= 0) {
        // Bounds haven't resolved yet (pre-first-layout). Skip rather than
        // feed CAMetalLayer a zero-sized drawable, which can hang MoltenVK.
        return;
    }
    CGFloat scale = self.window.screen.nativeScale ?: [UIScreen mainScreen].nativeScale;

    // Portrait: render the fight only in the top band, leaving the bottom band
    // for the touch controls (IKEMEN_PORTRAIT_GAME_BAND_RATIO, shared with the
    // overlay so the bands line up). Landscape keeps the full-screen game.
    // The CAMetalLayer's drawable size defines the MoltenVK swapchain extent,
    // so shrinking the layer is what actually confines the rendering.
    CGRect layerFrame = self.bounds;
    if (boundsSize.height > boundsSize.width) {
        layerFrame.size.height = boundsSize.height * IKEMEN_PORTRAIT_GAME_BAND_RATIO;
    }
    CGSize newDrawableSize = CGSizeMake(layerFrame.size.width * scale, layerFrame.size.height * scale);
    NSLog(@"[MetalContainer] layoutSubviews: bounds=%@ layer=%@ scale=%.1f newDrawableSize=%@ oldDrawableSize=%@",
          NSStringFromCGSize(boundsSize), NSStringFromCGRect(layerFrame), scale,
          NSStringFromCGSize(newDrawableSize), NSStringFromCGSize(self.metalLayer.drawableSize));
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.metalLayer.frame = layerFrame;
    self.metalLayer.contentsScale = scale;
    self.metalLayer.drawableSize = newDrawableSize;
    [CATransaction commit];
}
@end

void IkemenLockOrientationToCurrent(void) {
    if (sLocked) {
        return;
    }
    UIInterfaceOrientation current = UIInterfaceOrientationLandscapeRight;
    for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            current = s.effectiveGeometry.interfaceOrientation;
            break;
        }
    }
    switch (current) {
        case UIInterfaceOrientationPortrait:
            sLockedMask = UIInterfaceOrientationMaskPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            sLockedMask = UIInterfaceOrientationMaskPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            sLockedMask = UIInterfaceOrientationMaskLandscapeLeft;
            break;
        default:
            sLockedMask = UIInterfaceOrientationMaskLandscapeRight;
            break;
    }
    sLocked = YES;
    IkemenEnforceLockedOrientation();
}

void IkemenEnforceLockedOrientation(void) {
    if (!sLocked) return;
    if (@available(iOS 16.0, *)) {
        for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                UIWindowSceneGeometryPreferencesIOS *pref =
                    [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:sLockedMask];
                [s requestGeometryUpdateWithPreferences:pref errorHandler:^(NSError *error) {
                    NSLog(@"[GeometryEnforce] error=%@", error);
                }];
                break;
            }
        }
    }
}

void IkemenAttachMetalLayer(uint32_t sdlWindowID) {
    NSLog(@"[SDLFix] IkemenAttachMetalLayer called, id=%u\n", sdlWindowID);

    SDL_Window *window = SDL_GetWindowFromID(sdlWindowID);
    if (!window) {
        NSLog(@"[SDLFix] SDL_GetWindowFromID returned NULL\n");
        return;
    }

    SDL_SysWMinfo wmInfo;
    SDL_VERSION(&wmInfo.version);
    if (!SDL_GetWindowWMInfo(window, &wmInfo)) {
        NSLog(@"[SDLFix] SDL_GetWindowWMInfo failed: %s\n", SDL_GetError());
        return;
    }

    UIWindow *sdlUIWindow = wmInfo.info.uikit.window;
    if (!sdlUIWindow) {
        NSLog(@"[SDLFix] wmInfo.info.uikit.window is nil\n");
        return;
    }
    sSDLWindow = sdlUIWindow;

    UIView *sdlContentView = sdlUIWindow.rootViewController.view;
    if (![sdlContentView.layer isKindOfClass:[CAMetalLayer class]]) {
        NSLog(@"[SDLFix] SDL content view's layer is not a CAMetalLayer (class=%s)\n",
                object_getClassName(sdlContentView.layer));
        return;
    }
    CAMetalLayer *ml = (CAMetalLayer *)sdlContentView.layer;

    UIWindow *hostWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w != sdlUIWindow && w.rootViewController != nil) {
            hostWindow = w;
            break;
        }
    }
    if (!hostWindow) {
        NSLog(@"[SDLFix] no host window found\n");
        return;
    }
    
    [hostWindow makeKeyAndVisible];

    UIView *hostView = hostWindow.rootViewController.view;
    ml.contentsScale = hostWindow.windowScene.screen.nativeScale;
    
    MetalContainerView *metalHostView = [[MetalContainerView alloc] initWithFrame:hostView.bounds];
//    metalHostView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    metalHostView.translatesAutoresizingMaskIntoConstraints = NO;
    metalHostView.userInteractionEnabled = NO;
    
    [ml removeFromSuperlayer];
    [metalHostView.layer addSublayer:ml];
    metalHostView.metalLayer = ml;
    ml.frame = hostView.bounds;
    [hostView insertSubview:metalHostView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [metalHostView.topAnchor constraintEqualToAnchor:hostView.topAnchor],
        [metalHostView.bottomAnchor constraintEqualToAnchor:hostView.bottomAnchor],
        [metalHostView.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor],
        [metalHostView.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor]
    ]];
}