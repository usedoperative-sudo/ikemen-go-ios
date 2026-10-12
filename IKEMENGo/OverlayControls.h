#import <UIKit/UIKit.h>

// On-screen controls for the IKEMEN engine (upstream/Vulkan build).
//
// Owns all touch input on iOS. A floating D-pad on the left and a set of
// buttons on the right translate touch into a *virtual SDL game controller* —
// the same mechanism the official ikemen-ios wrapper uses — so the engine's
// standard SDL joystick/gamecontroller input path consumes them with no
// engine-side customization.
@interface IkemenOverlayView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
@end