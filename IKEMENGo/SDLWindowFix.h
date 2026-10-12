//
//  SDLWindowFix.h
//  I.K.E.M.E.N-Go
//
//  Created by Jesuszilla on 8/28/26.
//
// NOTE: THIS NEEDS TO BE A PART OF THE INCLUDE FOR THE iOS BUILD!!!!
//
#include <stdint.h>

// Portrait ("vertical") gameplay layout: in portrait the engine's Metal layer is
// confined to the top band of the screen so the fight renders *above* the
// on-screen controls, which occupy the bottom band. This ratio is shared between
// MetalContainerView (which sizes the layer) and IkemenOverlayView (which places
// the controls) so the two bands can never disagree.
#define IKEMEN_PORTRAIT_GAME_BAND_RATIO 0.60f

#ifndef __OBJC__
void IkemenAttachMetalLayer(uint32_t sdlWindowID);
#else
@interface MetalContainerView : UIView
@property (nonatomic, weak) CAMetalLayer *metalLayer;
@end
BOOL IkemenOrientationIsLocked(void);
void IkemenLockOrientationToCurrent(void);
void IkemenEnforceLockedOrientation(void);
UIInterfaceOrientationMask IkemenLockedOrientationMask(void);
UIWindow *IkemenGetSDLWindow(void);
#endif