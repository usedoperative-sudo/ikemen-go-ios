#import "OverlayControls.h"

// Abstract M.U.G.E.N. input indices (must match iosPlayerKey / the engine).
// 0..3 directions, 4..9 the six attack buttons, 10 start, 13 menu/escape.
#define IKEMEN_ID_UP    0
#define IKEMEN_ID_DOWN  1
#define IKEMEN_ID_LEFT  2
#define IKEMEN_ID_RIGHT 3
#define IKEMEN_ID_A     4
#define IKEMEN_ID_B     5
#define IKEMEN_ID_C     6
#define IKEMEN_ID_X     7
#define IKEMEN_ID_Y     8
#define IKEMEN_ID_Z     9
#define IKEMEN_ID_START 10
#define IKEMEN_ID_MENU  13

#pragma mark - D-Pad

// 8-way digital D-pad. Tapping/gliding on it sets the four cardinal M.U.G.E.N.
// directions, with diagonals produced by pressing two cards at once.
@interface IkemenDPadView : UIView
@end

@implementation IkemenDPadView {
    CGFloat _cx, _cy; // pad center in points
    CGFloat _armLen;  // half-length of one arm
    CGFloat _barW;    // arm thickness
    BOOL _active;
    NSUInteger _tid;
    int _curDir;            // 0..7 sector, or -1
    BOOL _last[4];          // last cardinal state
    UIColor *_fill;
    UIColor *_fillActive;
    UIColor *_stroke;
}

#define DPAD_DEADZONE 6.0f

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.exclusiveTouch = NO;
        self.opaque = NO;
        _curDir = -1;
        for (int i = 0; i < 4; i++) _last[i] = NO;
        // Transparent so it doesn't obscure the fight.
        _fill = [UIColor colorWithWhite:1.0 alpha:0.16];
        _fillActive = [UIColor colorWithWhite:1.0 alpha:0.42];
        _stroke = [UIColor colorWithWhite:1.0 alpha:0.35];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Position the pad toward the bottom-left of the left-hand control zone.
    _cx = CGRectGetWidth(self.bounds) * 0.36f;
    _cy = CGRectGetHeight(self.bounds) * 0.76f;
    CGFloat m = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    _armLen = m * 0.19f;
    _barW = m * 0.10f;
    [self setNeedsDisplay];
}

- (void)setCardinal:(int)idx on:(BOOL)on {
    if (_last[idx] != on) {
        _last[idx] = on;
        IOSHandleKey(idx, on ? 1 : 0);
    }
}

// The four M.U.G.E.N. directions are up/down/left/right. A diagonal presses two.
- (void)applyDir:(int)sector {
    BOOL up = NO, down = NO, left = NO, right = NO;
    switch (sector) {
        case 0:  up = YES; break;                       // up
        case 1:  up = YES; right = YES; break;          // up-right
        case 2:  right = YES; break;                    // right
        case 3:  down = YES; right = YES; break;        // down-right
        case 4:  down = YES; break;                     // down
        case 5:  down = YES; left = YES; break;         // down-left
        case 6:  left = YES; break;                     // left
        case 7:  up = YES; left = YES; break;           // up-left
        default: break;
    }
    [self setCardinal:IKEMEN_ID_UP    on:up];
    [self setCardinal:IKEMEN_ID_DOWN  on:down];
    [self setCardinal:IKEMEN_ID_LEFT  on:left];
    [self setCardinal:IKEMEN_ID_RIGHT on:right];
}

- (void)releaseAll {
    _curDir = -1;
    for (int i = 0; i < 4; i++) [self setCardinal:i on:NO];
    [self setNeedsDisplay];
}

- (void)updateFromPoint:(CGPoint)p {
    CGFloat dx = p.x - _cx;
    CGFloat dy = p.y - _cy;
    CGFloat len = sqrtf(dx * dx + dy * dy);
    if (len < DPAD_DEADZONE) {
        if (_curDir != -1) {
            _curDir = -1;
            for (int i = 0; i < 4; i++) [self setCardinal:i on:NO];
            [self setNeedsDisplay];
        }
        return;
    }
    CGFloat ang = atan2f(dy, dx); // radians, x right / y down
    // Map to 8 sectors: angle 0 = right, going clockwise (since y is down).
    // Sector: right=2, down-right=3, down=4, down-left=5, left=6, up-left=7, up=0, up-right=1
    CGFloat deg = ang * 180.0f / M_PI;
    // Atan2 gives -180..180 with 0 = right. Converting to 0..360 clockwise (down positive).
    CGFloat a = (deg < 0) ? deg + 360.0f : deg;
    int sector;
    if      (a < 22.5f  || a >= 337.5f) sector = 2;  // right
    else if (a < 67.5f)  sector = 3;  // down-right
    else if (a < 112.5f) sector = 4;  // down
    else if (a < 157.5f) sector = 5;  // down-left
    else if (a < 202.5f) sector = 6;  // left
    else if (a < 247.5f) sector = 7;  // up-left
    else if (a < 292.5f) sector = 0;  // up
    else                 sector = 1;  // up-right

    if (sector != _curDir) {
        _curDir = sector;
        [self applyDir:sector];
        [self setNeedsDisplay];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        if (!_active) {
            _active = YES;
            _tid = (NSUInteger)[t hash];
            [self updateFromPoint:[t locationInView:self]];
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        if (_active && (NSUInteger)[t hash] == _tid) {
            [self updateFromPoint:[t locationInView:self]];
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesDone:touches];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesDone:touches];
}

- (void)touchesDone:(NSSet<UITouch *> *)touches {
    for (UITouch *t in touches) {
        if (_active && (NSUInteger)[t hash] == _tid) {
            _active = NO;
            _tid = 0;
            [self releaseAll];
        }
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (!c) return;
    CGContextSetStrokeColorWithColor(c, [_stroke CGColor]);
    CGContextSetLineWidth(c, 1.5f);
    [self armFrom:CGPointMake(_cx, _cy - _armLen) to:CGPointMake(_cx, _cy + _armLen)
            fill:_fill stroke:_stroke width:_barW context:c];
    [self armFrom:CGPointMake(_cx - _armLen, _cy) to:CGPointMake(_cx + _armLen, _cy)
            fill:_fill stroke:_stroke width:_barW context:c];
    // Diagonal tabs
    CGFloat dLen = _armLen * 0.62f;
    [self armFrom:CGPointMake(_cx, _cy) to:CGPointMake(_cx + dLen, _cy - dLen)
            fill:_fill stroke:_stroke width:_barW*0.8 context:c];
    [self armFrom:CGPointMake(_cx, _cy) to:CGPointMake(_cx + dLen, _cy + dLen)
            fill:_fill stroke:_stroke width:_barW*0.8 context:c];
    [self armFrom:CGPointMake(_cx, _cy) to:CGPointMake(_cx - dLen, _cy + dLen)
            fill:_fill stroke:_stroke width:_barW*0.8 context:c];
    [self armFrom:CGPointMake(_cx, _cy) to:CGPointMake(_cx - dLen, _cy - dLen)
            fill:_fill stroke:_stroke width:_barW*0.8 context:c];

    // Highlight the active arm
    if (_curDir >= 0) {
        CGFloat hl = _armLen * 0.95f;
        CGPoint fp, tp;
        switch (_curDir) {
            case 0: fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx, _cy - hl); break;
            case 1: fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx + hl, _cy - hl); break;
            case 2: fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx + hl, _cy); break;
            case 3: fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx + hl, _cy + hl); break;
            case 4: fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx, _cy + hl); break;
            case 5: fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx - hl, _cy + hl); break;
            case 6: fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx - hl, _cy); break;
            default:fp = CGPointMake(_cx, _cy); tp = CGPointMake(_cx - hl, _cy - hl); break;
        }
        [self armFrom:fp to:tp fill:_fillActive stroke:_stroke width:_barW context:c];
    }
}

- (void)armFrom:(CGPoint)p1 to:(CGPoint)p2 fill:(UIColor *)fill stroke:(UIColor *)stroke
        width:(CGFloat)w context:(CGContextRef)c {
    CGContextSaveGState(c);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineWidth(c, w);
    CGContextSetStrokeColorWithColor(c, [fill CGColor]);
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, p1.x, p1.y);
    CGContextAddLineToPoint(c, p2.x, p2.y);
    CGContextStrokePath(c);
    CGContextRestoreGState(c);
}

@end

#pragma mark - Overlay

@implementation IkemenOverlayView {
    IkemenDPadView *_dPad;
    NSMutableArray<UIButton *> *_buttons;
    NSMutableDictionary<NSNumber *, NSNumber *> *_btnHeld;
}

// More transparent so the controls don't obscure the action.
#define BTN_COLOR [UIColor colorWithRed:0.90 green:0.42 blue:0.22 alpha:0.42]
#define BTN_COLOR_ALT [UIColor colorWithRed:0.35 green:0.65 blue:0.92 alpha:0.42]
#define BTN_BORDER [UIColor colorWithWhite:1.0 alpha:0.40]

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        _buttons = [NSMutableArray array];
        _btnHeld = [NSMutableDictionary dictionary];

        CGFloat joyW = CGRectGetWidth(frame) * 0.50f;
        CGFloat joyH = CGRectGetHeight(frame);
        _dPad = [[IkemenDPadView alloc] initWithFrame:CGRectMake(0, 0, joyW, joyH)];
        [self addSubview:_dPad];

        [self makeButton:IKEMEN_ID_A title:@"A" alt:NO];
        [self makeButton:IKEMEN_ID_B title:@"B" alt:NO];
        [self makeButton:IKEMEN_ID_C title:@"C" alt:YES];
        [self makeButton:IKEMEN_ID_X title:@"X" alt:YES];
        [self makeButton:IKEMEN_ID_Y title:@"Y" alt:NO];
        [self makeButton:IKEMEN_ID_Z title:@"Z" alt:NO];
        [self makeButton:IKEMEN_ID_START title:@"START" alt:NO];
        [self makeButton:IKEMEN_ID_MENU title:@"MENU" alt:YES];
    }
    return self;
}

- (UIButton *)makeButton:(int)keyId title:(NSString *)title alt:(BOOL)alt {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.tag = keyId;
    b.backgroundColor = alt ? BTN_COLOR_ALT : BTN_COLOR;
    b.layer.borderColor = [BTN_BORDER CGColor];
    b.layer.borderWidth = 1.5f;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.5;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.5] forState:UIControlStateNormal];

    [b addTarget:self action:@selector(buttonDown:) forControlEvents:UIControlEventTouchDown];
    [b addTarget:self action:@selector(buttonUp:) forControlEvents:UIControlEventTouchUpInside];
    [b addTarget:self action:@selector(buttonUp:) forControlEvents:UIControlEventTouchUpOutside];
    [b addTarget:self action:@selector(buttonUp:) forControlEvents:UIControlEventTouchCancel];

    [self addSubview:b];
    [_buttons addObject:b];
    return b;
}

- (UIButton *)buttonForKey:(int)keyId {
    for (UIButton *b in _buttons) {
        if ((int)b.tag == keyId) return b;
    }
    return nil;
}

- (void)buttonDown:(UIButton *)sender {
    int id = (int)sender.tag;
    if ([_btnHeld[@(id)] boolValue]) return;
    _btnHeld[@(id)] = @YES;
    IOSHandleKey(id, 1);
}

- (void)buttonUp:(UIButton *)sender {
    int id = (int)sender.tag;
    _btnHeld[@(id)] = @NO;
    IOSHandleKey(id, 0);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    CGFloat r = W * 0.034f;
    CGFloat gapX = W * 0.088f;
    // Fight cluster shifted left so Z/C stay fully on screen.
    CGFloat col0 = W * 0.70f;
    CGFloat yTop = H * 0.78f;
    CGFloat yBot = H * 0.56f;

    CGRect padF = _dPad.frame;
    padF.size = CGSizeMake(W * 0.50f, H);
    padF.origin = CGPointZero;
    _dPad.frame = padF;

    // Six attack buttons.
    [self layoutButton:IKEMEN_ID_A x:col0        y:yTop d:r*2];
    [self layoutButton:IKEMEN_ID_B x:col0+gapX   y:yTop d:r*2];
    [self layoutButton:IKEMEN_ID_C x:col0+2*gapX y:yTop d:r*2];
    [self layoutButton:IKEMEN_ID_X x:col0        y:yBot d:r*2];
    [self layoutButton:IKEMEN_ID_Y x:col0+gapX   y:yBot d:r*2];
    [self layoutButton:IKEMEN_ID_Z x:col0+2*gapX y:yBot d:r*2];

    // Menu and Start in the top-left corner (out of the way of the fight).
    [self layoutButton:IKEMEN_ID_MENU  x:W*0.02f y:H*0.03f d:r*2];
    [self layoutButton:IKEMEN_ID_START x:W*0.11f y:H*0.03f d:r*2];
}

- (void)layoutButton:(int)keyId x:(CGFloat)x y:(CGFloat)y d:(CGFloat)d {
    UIButton *b = [self buttonForKey:keyId];
    b.frame = CGRectMake(x, y, d, d);
    b.layer.cornerRadius = d / 2.0f;
}

// Only capture touches that land on the D-pad or on a button; every other
// touch passes through to the SDL view beneath.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(_dPad.frame, point)) {
        return YES;
    }
    for (UIButton *b in _buttons) {
        if (CGRectContainsPoint(b.frame, point)) {
            return YES;
        }
    }
    return NO;
}

@end

#pragma mark - Install

// Installed by the Go engine after SDL creates its window. Marshals to the
// main thread and drops the overlay on top of the SDL UIKit window.
void IOSInstallOverlay(void *uiWindow) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = (__bridge UIWindow *)uiWindow;
        if (!win) return;
        static IkemenOverlayView *overlay = nil;
        if (overlay) {
            [overlay removeFromSuperview];
            overlay = nil;
        }
        overlay = [[IkemenOverlayView alloc] initWithFrame:win.bounds];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.translatesAutoresizingMaskIntoConstraints = YES;
        [win addSubview:overlay];
        [win bringSubviewToFront:overlay];
    });
}
