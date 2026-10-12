//
//  SDLWindowFix.h
//  I.K.E.M.E.N-Go
//
//  Created by Jesuszilla on 8/28/26.
//
// NOTE: THIS NEEDS TO BE A PART OF THE INCLUDE FOR THE iOS BUILD!!!!
//
#include <stdint.h>

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