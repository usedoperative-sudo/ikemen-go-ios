#import <UIKit/UIKit.h>

// Native on-screen controls for the IKEMEN engine.
//
// Owns all touch input on iOS. A floating joystick on the left and a set of
// buttons on the right translate touch into abstract input events sent to the
// Go engine through the exported IOSHandleKey() function.

// Callback into the Go engine (exported by libengine.a).
void IOSHandleKey(int keyID, int pressed);

// Installed on top of SDL's UIKit window. See IOSInstallOverlay.
@interface IkemenOverlayView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
@end
