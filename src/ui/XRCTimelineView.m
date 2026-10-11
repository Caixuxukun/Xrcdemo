// © 雾月星辰 & MLXC · github@XingChenRS
// XRCTimelineView.m — 时间轴控件（原生风格：轨迹线 + 循环带 + A/B 菱形手柄 + 发光播放头）。
// 协议见 XRCTimelineView.h；尺寸/素材/字体统一走 XRCTheme。
#import "XRCTimelineView.h"
#import "XRCTheme.h"

@implementation XRCTimelineView {
    UITapGestureRecognizer *_tap;
    UIPanGestureRecognizer *_pan;
    NSInteger _grab;              // 本次手势捕获的手柄：0=无 1=A 2=B
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.scaleRef = 852.0;
        _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
        [self addGestureRecognizer:_tap];
        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        [self addGestureRecognizer:_pan];
    }
    return self;
}

- (uint32_t)msAtX:(CGFloat)x {
    CGFloat w = self.bounds.size.width;
    if (w <= 0 || self.lengthMs == 0) return 0;
    CGFloat t = MAX(0.0, MIN(1.0, x / w));
    return (uint32_t)(t * self.lengthMs);
}

- (BOOL)hasRange { return self.lengthMs > 0 && self.loopToMs > self.loopFromMs; }
- (CGFloat)xForMs:(uint32_t)ms {
    return self.bounds.size.width * ((CGFloat)ms / self.lengthMs);
}

// 命中：手柄区（A 优先于 B；半径 30 设计 px）
- (NSInteger)handleAt:(CGPoint)p {
    if (![self hasRange]) return 0;
    CGFloat xa = [self xForMs:self.loopFromMs];
    CGFloat xb = [self xForMs:self.loopToMs];
    CGFloat d = xrc_theme_px(30);
    if (fabs(p.x - xa) <= d && fabs(p.x - xa) <= fabs(p.x - xb)) return 1;
    if (fabs(p.x - xb) <= d) return 2;
    return 0;
}

- (void)onTap:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:self];
    if ([self handleAt:p]) return;              // 手柄区轻点不触发跳转
    uint32_t ms = [self msAtX:p.x];
    if (self.onScrubBegin) self.onScrubBegin();
    if (self.onScrubLive) self.onScrubLive(ms);
    if (self.onScrubEnd) self.onScrubEnd(ms);
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    CGPoint p = [g locationInView:self];
    if (g.state == UIGestureRecognizerStateBegan) {
        _grab = [self handleAt:p];
        if (_grab == 0 && self.onScrubBegin) self.onScrubBegin();
    }
    if (g.state == UIGestureRecognizerStateChanged) {
        if (_grab != 0) {
            CGFloat w = self.bounds.size.width;
            if (w > 0 && self.lengthMs > 0) {
                double t = MAX(0.0, MIN(1.0, p.x / w));
                double minGap = 1000.0 / (double)self.lengthMs;   // 区间需 ≥1s（引擎语义）
                if (_grab == 1) {
                    double a = MIN(t, (double)self.loopToMs / self.lengthMs - minGap);
                    self.loopFromMs = (uint32_t)(MAX(0.0, a) * self.lengthMs);
                } else {
                    double b = MAX(t, (double)self.loopFromMs / self.lengthMs + minGap);
                    self.loopToMs = (uint32_t)(MIN(1.0, b) * self.lengthMs);
                }
                [self setNeedsDisplay];
                if (self.onLoopRangeChanged)
                    self.onLoopRangeChanged((double)self.loopFromMs / self.lengthMs,
                                            (double)self.loopToMs / self.lengthMs, NO);
            }
        } else {
            self.positionMs = [self msAtX:p.x];
            if (self.onScrubLive) self.onScrubLive(self.positionMs);
        }
    }
    if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        if (_grab != 0) {
            if (self.onLoopRangeChanged)
                self.onLoopRangeChanged((double)self.loopFromMs / self.lengthMs,
                                        (double)self.loopToMs / self.lengthMs, YES);
            _grab = 0;
        } else {
            if (self.onScrubEnd) self.onScrubEnd([self msAtX:p.x]);
        }
    }
}

- (void)drawRect:(CGRect)rect {
    if (self.lengthMs == 0) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    CGFloat mid = h / 2.0;
    CGFloat lw = MAX(1.0, xrc_theme_px(3));

    // 基线
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.25].CGColor);
    CGContextSetLineWidth(ctx, lw);
    CGContextMoveToPoint(ctx, 0, mid);
    CGContextAddLineToPoint(ctx, w, mid);
    CGContextStrokePath(ctx);

    // 已播段
    CGFloat px = w * ((CGFloat)self.positionMs / self.lengthMs);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.8].CGColor);
    CGContextMoveToPoint(ctx, 0, mid);
    CGContextAddLineToPoint(ctx, px, mid);
    CGContextStrokePath(ctx);

    // 循环区间带 + A/B 手柄
    if ([self hasRange]) {
        CGFloat xa = [self xForMs:self.loopFromMs];
        CGFloat xb = [self xForMs:self.loopToMs];
        CGFloat bandH = xrc_theme_px(34);
        CGRect band = CGRectMake(xa, mid - bandH / 2, xb - xa, bandH);
        if (self.loopVisible) {
            [XRC_BAND setFill];
            UIRectFill(band);
            CGContextSetStrokeColorWithColor(ctx, XRC_BAND_EDG.CGColor);
        } else {
            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.28].CGColor);
        }
        CGContextSetLineWidth(ctx, MAX(1.0, xrc_theme_px(1.5)));
        CGContextStrokeRect(ctx, CGRectInset(band, 0, 0.5));

        UIImage *stepper = xrc_theme_img(@"layouts/songselect/settings_stepper.png");
        CGFloat hs = xrc_theme_px(27);
        if (stepper) {
            [stepper drawInRect:CGRectMake(xa - hs / 2, mid - hs / 2, hs, hs)];
            [stepper drawInRect:CGRectMake(xb - hs / 2, mid - hs / 2, hs, hs)];
        } else {
            [[UIColor colorWithRed:100/255.0 green:80/255.0 blue:100/255.0 alpha:1.0] setFill];
            UIRectFill(CGRectMake(xa - hs / 2, mid - hs / 2, hs, hs));
            UIRectFill(CGRectMake(xb - hs / 2, mid - hs / 2, hs, hs));
        }
        UIFont *lf = xrc_theme_font(@"L2-Semibold", 11);
        NSDictionary *lat = @{ NSFontAttributeName: lf, NSForegroundColorAttributeName: XRC_TXT };
        CGFloat cw = xrc_theme_px(14), ch = xrc_theme_px(16);
        [@"A" drawInRect:CGRectMake(xa - cw / 2, mid - ch / 2, cw, ch) withAttributes:lat];
        [@"B" drawInRect:CGRectMake(xb - cw / 2, mid - ch / 2, cw, ch) withAttributes:lat];
    }

    // 播放头（细线 + 发光点）
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, MAX(1.0, xrc_theme_px(2)));
    CGContextMoveToPoint(ctx, px, mid - xrc_theme_px(24));
    CGContextAddLineToPoint(ctx, px, mid + xrc_theme_px(24));
    CGContextStrokePath(ctx);
    UIImage *glow = xrc_theme_img(@"layouts/ingame/progress_glow.png");
    if (glow) {
        CGFloat gs = xrc_theme_px(26);
        [glow drawInRect:CGRectMake(px - gs / 2, mid - gs / 2, gs, gs)];
    }
}

- (void)setPositionMs:(uint32_t)positionMs {
    _positionMs = positionMs;
    [self setNeedsDisplay];
}
- (void)setLoopFromMs:(uint32_t)from to:(uint32_t)to visible:(BOOL)visible {
    _loopFromMs = from; _loopToMs = to; _loopVisible = visible;
    [self setNeedsDisplay];
}
- (void)setLengthMs:(uint32_t)lengthMs {
    _lengthMs = lengthMs;
    [self setNeedsDisplay];
}
@end
