// © 雾月星辰 & MLXC · github@XingChenRS
// XRCPracticePanel.m — 练习面板 v4（Arcaea 原生风格 · 全屏模态）。
//
// 形态与交互（设计稿：ui-mock/panel_mock.html v4）：
//   全屏：暗化层 + 玻璃卡面（pause_backing 九宫格）；标头｜时间轴带｜主区（速度列＋页签）｜底栏。
//   打开不暂停；触碰时间轴＝冻结＋实时对齐预览，松手驻停（深回退交重播引擎），
//   「继续/关闭」＝关窗并自驻停点恢复（协议见 XRCTimelineView.h）。
//   ⓘ＝说明模式（各页追加说明行）；长按任一行＝查看该项说明。
//   开关＝行内点按、状态词呈现（已开亮白 / 已关暗紫灰）；数值＝菱形 ± 步进器；
//   破坏性＝红字行；状态数字只进只读暗行。控件一律走 XRCConfig（单一事实源）。
// 素材/字体/量纲：XRCTheme（游戏包内原文件）。
#import "XRCPracticePanel.h"
#import <objc/runtime.h>
#include <string.h>
#import "XRCFloatButton.h"
#import "WHToast/WHToast.h"
#import "XRCLog.h"
#include "XRCConfig.h"
#include "XRCGameplay.h"
#include "XRCClock.h"
#include "XRCPlayer.h"
#include "XRCJudge.h"
#include "XRCProbe.h"
#include "XRCProfile.h"
#include "XRCDump.h"
#include "XRCOMLog.h"
#include "XRCNet.h"
#include "XRCHook.h"
#include "XRCStore.h"
#include "XRCAudio.h"
#include "XRCReplay.h"
#import "XRCTimelineView.h"
#import "XRCTheme.h"

// 开发构建专属区（release 下整段编译为空；常量与调用点统一以此门控）
#define XRC_DEV_SECTION (XRC_DEBUG_BUILD)

// ---------------- 说明文本（ⓘ 模式逐页展示；长按单项另见各 note） ----------------
static NSString *const kNoteLoop =
    @"设 A/B ＝ 把当前位置记入区间；循环开 ＝ 播到 B 自动回 A。时间轴上的 A/B 菱形可直接拖动改区间。\n"
    @"回跳重播开启时，回退会由重播引擎接管：音符重现、该段记分清空。";
static NSString *const kNoteJudge =
    @"四档 ±ms 阈值，只改本地判定宽容度，不动谱面；数值需递增（应用时自动夹取）。\n"
    @"自动演奏＝所有判定强制 Pure（含漏扫路径），演示/练习用。";
static NSString *const kNoteUnlock =
    @"拥有链＝三层判定恒真兜底（覆盖未授予场景）｜FV/DO 锁＝特殊曲包五难度全解｜"
    @"链门＝7.0 链系统总闸｜cb 自由化＝内容包校验恒通过且不再清树。";
#if XRC_DEV_SECTION   // 开发专属注记：不进入发布包（发布包不携带私服/开发工具文本）
static NSString *const kNoteNet =
    @"只改 API 请求的域名（路径/参数原样、不动 TLS）；关掉走官方域。私服内容的版权 /\n"
    @"数据处理 / 安全性由使用者自负；默认练习能力不强制绑定私服。";
#endif
static NSString *const kNoteStore =
    @"把 cb 内容根从 Library/Application Support 搬到 Documents/cb（同一分区，瞬间完成，不拷贝）。\n"
    @"cb/active 即资源覆盖层：同名文件按相同相对路径放入即覆盖包内资源；cb 下载也落在这里。";
static NSString *const kNoteDiag =
    @"日志档位：默认＝只记要点；详细＝全量 DEBUG；网络＝只放开网络/下载/内容。日志在 Documents/xrcdemo.log。";
#if XRC_DEV_SECTION
static NSString *const kNoteDev =
    @"转储 → Documents/xrcdemo-net/mem/；强制 applog 需二次确认；观测桩轻量＝重活停摆、只推进 PC。";
#endif
static NSString *const kNoteSpeed =
    @"点按 ±0.05，长按大步 ±0.25。音乐变速＝BGM 跟随速度且保持音高；关＝只改谱面钟。";

@interface XRCPracticePanel ()
// 结构
@property (nonatomic, strong) UIImageView *dim;
@property (nonatomic, strong) UIImageView *glass;
@property (nonatomic, strong) UIView *hdr;
@property (nonatomic, strong) XRCTimelineView *timeline;
@property (nonatomic, strong) UILabel *tcur, *tmid, *ttot;
@property (nonatomic, strong) UIButton *m5, *p5;
@property (nonatomic, strong) UILabel *speedNum;
@property (nonatomic, strong) UIView *tabStrip;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabs;
@property (nonatomic, strong) UILabel *paneHint;
@property (nonatomic, strong) UIButton *paneAct;          // 上下文动作（判定页＝应用）
@property (nonatomic, strong) UIScrollView *pane;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSInteger lowTick;
@property (nonatomic, assign) BOOL infoOn;
@property (nonatomic, assign) BOOL pendingTo;
@property (nonatomic, assign) NSInteger curTab;
// 行状态引用（重建时重新捕获；refresh 镜像引擎真值）
@property (nonatomic, strong) UILabel *stSpeedAudio, *stReplay, *stLoop, *stAutoplay;
@property (nonatomic, strong) UILabel *stOwn, *stFv, *stDo, *stGate, *stCb, *stNet, *stStore, *stStubs;
@property (nonatomic, strong) UILabel *valA, *valB, *valNet;
@property (nonatomic, strong) UILabel *netStat, *storeStat;
@property (nonatomic, strong) NSArray<UILabel *> *chips;
@property (nonatomic, strong) UILabel *patchLine, *judgeStatus;
// 判定步进（草稿：stepper 改动后置 dirty，应用时提交）
@property (nonatomic, strong) NSMutableArray<UILabel *> *judgeVals;
@property (nonatomic, assign) BOOL judgeDirty;
@property (nonatomic, strong) NSArray<UIButton *> *logBtns;   // 仅开发构建会填充；属性常驻避免门控分裂
@property (nonatomic, assign) NSInteger logSel;
@end

@implementation XRCPracticePanel

+ (instancetype)shared {
    static XRCPracticePanel *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[XRCPracticePanel alloc] init]; });
    return s;
}

#pragma mark - 基础

- (UIWindow *)keyWindow {
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows) if (w.isKeyWindow) return w;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

- (BOOL)isVisible { return self.superview != nil; }

#pragma mark - 显示 / 隐藏 / 刷新

- (void)show {
    UIWindow *w = [self keyWindow];
    if (!w) { xrc_logw(XRCLC_UI, @"panel show: no key window"); return; }
    if (!self.superview) { [w addSubview:self]; [w bringSubviewToFront:self]; }
    self.frame = w.bounds;
    [self buildIfNeeded];
    [self rebuildPane];
    if (!self.timer) {
        self.timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
    [self refresh];
    xrc_logd(XRCLC_UI, @"panel shown (v4 fullscreen)");
}

- (void)hide {
    [self.timer invalidate]; self.timer = nil;
    [self removeFromSuperview];
    xrc_gameplay_pause(false);   // 「继续/关闭」的唯一语义：关窗 + 恢复播放（幂等）
    xrc_logd(XRCLC_UI, @"panel hidden");
}

// 分频刷新：高频（位置/时长/速度）10Hz；低频（开关镜像/状态行/能力）1Hz。
- (void)tick {
    [self refreshFast];
    if (++self.lowTick >= 10) { self.lowTick = 0; [self refreshSlow]; }
}

#pragma mark - 构建

- (void)buildIfNeeded {
    if (self.subviews.count) return;
    self.backgroundColor = [UIColor clearColor];
    CGFloat S = xrc_theme_scale();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    if (W < 10) W = 852 * S, H = 393 * S;   // show 前被问到时兜底

    // 暗化层（游戏素材，四角自渐隐）
    self.dim = [[UIImageView alloc] initWithFrame:self.bounds];
    self.dim.image = xrc_theme_img(@"layouts/1080/pause/pause_background_shadow.png");
    self.dim.contentMode = UIViewContentModeScaleToFill;
    self.dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.dim];

    // 玻璃卡面（pause_backing 九宫格；素材缺失时回退深紫半透明）
    CGRect pf = CGRectInset(self.bounds, 10, 10);
    self.glass = [[UIImageView alloc] initWithFrame:pf];
    self.glass.image = xrc_theme_img9(@"layouts/1080/pause/pause_backing.png", 87, 22, 87, 22);
    self.glass.backgroundColor = self.glass.image ? [UIColor clearColor]
                                                  : [UIColor colorWithRed:37/255.0 green:23/255.0 blue:42/255.0 alpha:0.55];
    self.glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.glass.layer.cornerRadius = 12;
    self.glass.layer.masksToBounds = YES;
    [self addSubview:self.glass];

    CGFloat padL = xrc_theme_px(26), padR = xrc_theme_px(26), padT = xrc_theme_px(2), padB = xrc_theme_px(10);
    CGFloat cw = self.bounds.size.width - 20 - padL - padR;      // 卡面内容宽
    CGFloat x0 = 10 + padL, y = 10 + padT;

    // ── 标头：PRACTICE + 版本戳 ｜ ⓘ ✕ ──
    self.hdr = [[UIView alloc] initWithFrame:CGRectMake(x0, y, cw, xrc_theme_px(36))];
    self.hdr.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.glass addSubview:self.hdr];
    {
        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, xrc_theme_px(320), self.hdr.bounds.size.height)];
        t.text = @"PRACTICE";
        t.font = xrc_theme_font(@"Exo-Light", 28);
        t.textColor = XRC_TXT;
        [self.hdr addSubview:t];
        UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(150), xrc_theme_px(10), xrc_theme_px(260), xrc_theme_px(16))];
        v.text = [NSString stringWithFormat:@"%@ · %s", XRC_VERSION, XRC_BUILD_STAMP];
        v.font = xrc_theme_font(@"Exo-Regular", 12);
        v.textColor = XRC_DIM2;
        [self.hdr addSubview:v];

        UIButton *help = [UIButton buttonWithType:UIButtonTypeCustom];
        help.frame = CGRectMake(self.hdr.bounds.size.width - xrc_theme_px(70), xrc_theme_px(3), xrc_theme_px(30), xrc_theme_px(30));
        help.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [help setImage:xrc_theme_img(@"layouts/mainmenu/help_button.png") forState:UIControlStateNormal];
        [help addTarget:self action:@selector(toggleInfo) forControlEvents:UIControlEventTouchUpInside];
        [self.hdr addSubview:help];
        UIButton *x = [UIButton buttonWithType:UIButtonTypeCustom];
        x.frame = CGRectMake(self.hdr.bounds.size.width - xrc_theme_px(36), xrc_theme_px(6), xrc_theme_px(28), xrc_theme_px(28));
        x.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        UIImage *closeImg = xrc_theme_img(@"layouts/mainmenu/close.png");
        if (closeImg) [x setImage:closeImg forState:UIControlStateNormal];
        else { [x setTitle:@"✕" forState:UIControlStateNormal]; [x setTitleColor:XRC_TXT forState:UIControlStateNormal]; }
        [x addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
        [self.hdr addSubview:x];
    }
    y += self.hdr.bounds.size.height;

    // ── 时间轴带 ──
    CGFloat tzH = xrc_theme_px(74);
    CGFloat ds = xrc_theme_px(34);
    self.m5 = [self diamondButton:@"−" action:@selector(jumpBack)];
    self.m5.frame = CGRectMake(x0, y + xrc_theme_px(4), ds, ds);
    [self.glass addSubview:self.m5];
    self.p5 = [self diamondButton:@"+" action:@selector(jumpForward)];
    self.p5.frame = CGRectMake(x0 + cw - ds, y + xrc_theme_px(4), ds, ds);
    self.p5.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.glass addSubview:self.p5];

    CGFloat tw = cw - ds * 2 - xrc_theme_px(24);
    self.timeline = [[XRCTimelineView alloc] initWithFrame:CGRectMake(x0 + ds + xrc_theme_px(12), y, tw, xrc_theme_px(46))];
    self.timeline.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    __weak typeof(self) weakTL = self;
    self.timeline.onScrubBegin = ^{
        __strong typeof(self) sf = weakTL; if (!sf) return;
        if (!xrc_gameplay_in_song()) return;      // 非对局（菜单）：不冻结（timeline 有占位长度，用它判不对）
        sf.pendingTo = NO;
        xrc_gameplay_pause(true);
    };
    self.timeline.onScrubLive = ^(uint32_t ms) {
        xrc_gameplay_scrub(ms);                   // 无需节流：每帧至多落一笔
    };
    self.timeline.onScrubEnd = ^(uint32_t ms) {
        __strong typeof(self) sf = weakTL; if (!sf) return;
        if (!xrc_gameplay_in_song()) return;
        uint32_t start = xrc_player_position_ms();
        if (start > ms + 300)                     // 深回退：重播引擎接管
            xrc_gameplay_request(XRC_OP_SEEK_REPLAY, ms);
        // 浅回退/前进：位置已由 onScrubLive 落位，驻停待「继续/关闭」
    };
    self.timeline.onLoopRangeChanged = ^(double from, double to, BOOL finished) {
        __strong typeof(self) sf = weakTL; if (!sf) return;
        uint32_t len = sf.timeline.lengthMs;
        if (!len) return;
        if (finished)
            xrc_loop_set_range((uint32_t)(from * len), (uint32_t)(to * len));
        [sf refresh];
    };
    [self.glass addSubview:self.timeline];

    // 时间轴读数行：当前 ｜ A/B ｜ 总长
    {
        CGFloat my = y + xrc_theme_px(48);
        self.tcur = [self monoLabel:x0 w:xrc_theme_px(150) y:my size:17 color:XRC_TXT];
        self.tmid = [self monoLabel:x0 + xrc_theme_px(150) w:cw - xrc_theme_px(320) y:my size:12.5 color:XRC_LAV];
        self.tmid.textAlignment = NSTextAlignmentCenter;
        self.ttot = [self monoLabel:x0 + cw - xrc_theme_px(170) w:xrc_theme_px(170) y:my size:17 color:XRC_DIM2];
        self.ttot.textAlignment = NSTextAlignmentRight;
        self.ttot.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        self.tmid.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    y += tzH;

    // ── 主区 ──
    CGFloat footH = xrc_theme_px(56);
    CGFloat mainH = self.bounds.size.height - 10 - padB - y - footH;
    CGFloat speedW = xrc_theme_px(178);
    [self buildSpeedColumn:CGRectMake(x0, y, speedW, mainH)];
    [self buildTabArea:CGRectMake(x0 + speedW + xrc_theme_px(18), y,
                                  cw - speedW - xrc_theme_px(18), mainH)];

    // ── 底栏 ──
    CGFloat fy = self.bounds.size.height - 10 - padB - xrc_theme_px(46);
    UIButton *go = [UIButton buttonWithType:UIButtonTypeCustom];
    go.frame = CGRectMake(x0, fy, xrc_theme_px(228), xrc_theme_px(44));
    [go setBackgroundImage:xrc_theme_img9(@"layouts/1080/pause/resume_button.png", 15, 11, 15, 11)
                   forState:UIControlStateNormal];
    [go setBackgroundImage:xrc_theme_img9(@"layouts/1080/pause/resume_button_pressed.png", 15, 11, 15, 11)
                   forState:UIControlStateHighlighted];
    [go setTitle:@"继续" forState:UIControlStateNormal];
    go.titleLabel.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 16);
    [go setTitleColor:XRC_TXT forState:UIControlStateNormal];
    [go addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [self.glass addSubview:go];

    UIButton *rl = [UIButton buttonWithType:UIButtonTypeCustom];
    rl.frame = CGRectMake(x0 + xrc_theme_px(242), fy, xrc_theme_px(168), xrc_theme_px(42));
    [rl setBackgroundImage:xrc_theme_img9(@"layouts/1080/pause/button.png", 15, 11, 15, 11)
                   forState:UIControlStateNormal];
    [rl setBackgroundImage:xrc_theme_img9(@"layouts/1080/pause/button_pressed.png", 15, 11, 15, 11)
                   forState:UIControlStateHighlighted];
    [rl setTitle:@"复位循环" forState:UIControlStateNormal];
    rl.titleLabel.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 14.5);
    [rl setTitleColor:XRC_TXT forState:UIControlStateNormal];
    [rl addTarget:self action:@selector(resetLoop) forControlEvents:UIControlEventTouchUpInside];
    [self.glass addSubview:rl];

    UILabel *cp = [[UILabel alloc] initWithFrame:CGRectMake(x0 + cw - xrc_theme_px(280), fy + xrc_theme_px(16),
                                                            xrc_theme_px(280), xrc_theme_px(14))];
    cp.text = @"© 雾月星辰&MLXC/github@XingChenRS";
    cp.font = xrc_theme_font(@"L2-Regular", 9.5);
    cp.textColor = [UIColor colorWithRed:180/255.0 green:172/255.0 blue:200/255.0 alpha:0.5];
    cp.textAlignment = NSTextAlignmentRight;
    cp.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.glass addSubview:cp];
}

// 速度列：大数字 + ‹ › 箭头（点按 ±0.05 / 长按连续 ±0.25）+ 两个开关行
- (void)buildSpeedColumn:(CGRect)f {
    UIView *col = [[UIView alloc] initWithFrame:f];
    col.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;
    [self.glass addSubview:col];
    CGFloat ch = xrc_theme_px(44);
    UIButton *dn = [self chevronButton:NO action:@selector(speedDown:)];
    dn.frame = CGRectMake(0, xrc_theme_px(6), xrc_theme_px(30), ch);
    [col addSubview:dn];
    UIButton *up = [self chevronButton:YES action:@selector(speedUp:)];
    up.frame = CGRectMake(f.size.width - xrc_theme_px(30), xrc_theme_px(6), xrc_theme_px(30), ch);
    up.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [col addSubview:up];
    self.speedNum = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(34), xrc_theme_px(2),
                                                              f.size.width - xrc_theme_px(68), xrc_theme_px(52))];
    self.speedNum.text = @"1.00";
    self.speedNum.textAlignment = NSTextAlignmentCenter;
    self.speedNum.font = xrc_theme_font(@"GeosansLight", 56);
    self.speedNum.adjustsFontSizeToFitWidth = YES;
    self.speedNum.textColor = XRC_TXT;
    self.speedNum.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [col addSubview:self.speedNum];
    UILabel *cap = [[UILabel alloc] initWithFrame:CGRectMake(0, xrc_theme_px(54), f.size.width, xrc_theme_px(14))];
    cap.text = @"速度 · ±0.05｜长按步进 ±0.25";
    cap.textAlignment = NSTextAlignmentCenter;
    cap.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 10);
    cap.textColor = XRC_DIM2;
    cap.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [col addSubview:cap];

    CGFloat ry = xrc_theme_px(78);
    self.stSpeedAudio = [self toggleRowIn:col y:ry title:@"音乐变速" on:xrc_audio_speed_enabled()
                                    block:^{ [self toggleSpeedAudio]; } note:kNoteSpeed];
    ry += xrc_theme_px(40);
    self.stReplay = [self toggleRowIn:col y:ry title:@"回跳重播" on:xrc_replay_enabled()
                                block:^{ [self toggleReplay]; }
                                 note:@"回跳到已游玩并判定过的谱面段落时，支持重新游玩该段，同时清空分数记录。"];
}

// 页签区：页签条 + 提示行 + 可滚动内容
- (void)buildTabArea:(CGRect)f {
    UIView *area = [[UIView alloc] initWithFrame:f];
    [self.glass addSubview:area];

    self.tabStrip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, f.size.width, xrc_theme_px(31))];
    self.tabStrip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIImage *strip = xrc_theme_img(@"img/dialog_v2/tabs_background.png");
    if (strip) {
        UIImageView *bg = [[UIImageView alloc] initWithFrame:self.tabStrip.bounds];
        bg.image = strip;
        bg.contentMode = UIViewContentModeScaleToFill;
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.tabStrip addSubview:bg];
    } else {
        self.tabStrip.backgroundColor = [UIColor colorWithRed:78/255.0 green:61/255.0 blue:92/255.0 alpha:1.0];
        self.tabStrip.layer.cornerRadius = 8;
    }
    [area addSubview:self.tabStrip];

    NSArray *names = @[@"循环", @"判定", @"解锁", @"网络", @"存储", @"诊断"];
    self.tabs = [NSMutableArray array];
    CGFloat tw = f.size.width / names.count;
    for (int i = 0; i < (int)names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(tw * i, 0, tw, xrc_theme_px(31));
        [b setTitle:names[i] forState:UIControlStateNormal];
        b.titleLabel.font = xrc_theme_font(@"L2-Semibold", 13.5);
        [b setTitleColor:[UIColor colorWithRed:226/255.0 green:218/255.0 blue:242/255.0 alpha:0.62]
                forState:UIControlStateNormal];
        [b setTitleColor:XRC_TXT forState:UIControlStateSelected];
        UIImage *sel = xrc_theme_img(@"img/dialog_v2/tabs_selected.png");
        if (sel) [b setBackgroundImage:[sel resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)]
                              forState:UIControlStateSelected];
        b.tag = i;
        b.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
        [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabStrip addSubview:b];
        [self.tabs addObject:b];
    }

    CGFloat hy = xrc_theme_px(31) + xrc_theme_px(3);
    self.paneHint = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(2), hy, f.size.width - xrc_theme_px(104), xrc_theme_px(18))];
    self.paneHint.font = xrc_theme_font(@"NotoSansCJKsc-Light", 11.5);
    self.paneHint.textColor = XRC_DIM2;
    self.paneHint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [area addSubview:self.paneHint];
    self.paneAct = [UIButton buttonWithType:UIButtonTypeCustom];
    self.paneAct.frame = CGRectMake(f.size.width - xrc_theme_px(98), hy - xrc_theme_px(6), xrc_theme_px(98), xrc_theme_px(30));
    [self.paneAct setBackgroundImage:xrc_theme_img9(@"layouts/1080/pause/button.png", 15, 11, 15, 11)
                            forState:UIControlStateNormal];
    [self.paneAct setTitle:@"应用" forState:UIControlStateNormal];
    self.paneAct.titleLabel.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 12.5);
    [self.paneAct setTitleColor:XRC_TXT forState:UIControlStateNormal];
    self.paneAct.hidden = YES;
    self.paneAct.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.paneAct addTarget:self action:@selector(applyJudge) forControlEvents:UIControlEventTouchUpInside];
    [area addSubview:self.paneAct];

    CGFloat py = hy + xrc_theme_px(22);
    self.pane = [[UIScrollView alloc] initWithFrame:CGRectMake(0, py, f.size.width, f.size.height - py)];
    self.pane.showsVerticalScrollIndicator = YES;
    self.pane.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [area addSubview:self.pane];
}

#pragma mark - 小组件工厂

- (UIButton *)diamondButton:(NSString *)glyph action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setBackgroundImage:xrc_theme_img(@"layouts/songselect/settings_stepper.png") forState:UIControlStateNormal];
    [b setTitle:glyph forState:UIControlStateNormal];
    b.titleLabel.font = xrc_theme_font(@"Exo-SemiBold", 20);
    [b setTitleColor:XRC_TXT forState:UIControlStateNormal];
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (UIButton *)chevronButton:(BOOL)right action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *ar = xrc_theme_img(@"layouts/mainmenu/arrow_left.png");
    if (ar && right)
        ar = [UIImage imageWithCGImage:ar.CGImage scale:ar.scale orientation:UIImageOrientationUpMirrored];
    [b setImage:ar forState:UIControlStateNormal];
    b.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                           initWithTarget:self action:@selector(chevronLongPress:)];
    lp.minimumPressDuration = 0.4;
    [b addGestureRecognizer:lp];
    b.tag = right ? 1 : 0;
    return b;
}

- (UILabel *)monoLabel:(CGFloat)x w:(CGFloat)w y:(CGFloat)y size:(CGFloat)sz color:(UIColor *)c {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, xrc_theme_px(sz + 6))];
    l.font = xrc_theme_font(@"Exo-Regular", sz);
    l.textColor = c;
    [self.glass addSubview:l];
    return l;
}

#pragma mark - 行工厂（页签内容）

// 行底板
- (UIView *)rowBaseIn:(UIView *)parent y:(CGFloat)y title:(NSString *)title note:(NSString *)note {
    CGFloat w = MAX(parent.bounds.size.width, xrc_theme_px(160));
    UIView *r = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, xrc_theme_px(36))];
    r.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(11), 0, r.bounds.size.width - xrc_theme_px(150), xrc_theme_px(36))];
    l.text = title;
    l.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 15);
    l.textColor = [UIColor colorWithRed:244/255.0 green:241/255.0 blue:250/255.0 alpha:1.0];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [r addSubview:l];
    if (note.length) {
        [r addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
                                    initWithTarget:self action:@selector(rowNote:)]];
        objc_setAssociatedObject(r, "xrc_note", note, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return r;
}

- (void)rowNote:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSString *note = objc_getAssociatedObject(g.view, "xrc_note");
    if (note.length) [WHToast showMessage:note duration:2.6 finishHandler:^{}];
}

// 开关行：返回状态词 label
- (UILabel *)toggleRowIn:(UIView *)parent y:(CGFloat)y title:(NSString *)title on:(BOOL)on
                   block:(void (^)(void))block note:(NSString *)note {
    UIView *r = [self rowBaseIn:parent y:y title:title note:note];
    UILabel *st = [[UILabel alloc] initWithFrame:CGRectMake(r.bounds.size.width - xrc_theme_px(100), 0,
                                                            xrc_theme_px(90), xrc_theme_px(36))];
    st.text = on ? @"已开" : @"已关";
    st.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 15);
    st.textColor = on ? XRC_TXT : XRC_OFF;
    st.textAlignment = NSTextAlignmentRight;
    st.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [r addSubview:st];
    [r addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                initWithTarget:self action:@selector(rowTap:)]];
    objc_setAssociatedObject(r, "xrc_tap", block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [parent addSubview:r];
    return st;
}

// 动作行（右值 + ▸）
- (UILabel *)actionRowIn:(UIView *)parent y:(CGFloat)y title:(NSString *)title value:(NSString *)value
                    block:(void (^)(void))block note:(NSString *)note {
    UIView *r = [self rowBaseIn:parent y:y title:title note:note];
    UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(r.bounds.size.width - xrc_theme_px(230), 0,
                                                           xrc_theme_px(214), xrc_theme_px(36))];
    v.text = value;
    v.font = xrc_theme_font(@"Exo-Regular", 15);
    v.textColor = XRC_LAV;
    v.textAlignment = NSTextAlignmentRight;
    v.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [r addSubview:v];
    UILabel *mark = [[UILabel alloc] initWithFrame:CGRectMake(r.bounds.size.width - xrc_theme_px(14), 0, xrc_theme_px(12), xrc_theme_px(36))];
    mark.text = @"▸";
    mark.font = [UIFont systemFontOfSize:xrc_theme_px(11)];
    mark.textColor = XRC_DIM2;
    mark.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [r addSubview:mark];
    [r addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rowTap:)]];
    objc_setAssociatedObject(r, "xrc_tap", block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [parent addSubview:r];
    return v;
}

// 破坏性行（红字靠右）
- (void)dangerRowIn:(UIView *)parent y:(CGFloat)y title:(NSString *)title
              block:(void (^)(void))block note:(NSString *)note {
    UIView *r = [self rowBaseIn:parent y:y title:@"" note:note];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(11), 0, r.bounds.size.width - xrc_theme_px(22), xrc_theme_px(36))];
    l.text = title;
    l.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 15);
    l.textColor = XRC_DANGER;
    l.textAlignment = NSTextAlignmentRight;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [r addSubview:l];
    [r addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rowTap:)]];
    objc_setAssociatedObject(r, "xrc_tap", block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [parent addSubview:r];
}

// 步进行（菱形 ±）：返回数值 label
- (UILabel *)stepperRowIn:(UIView *)parent y:(CGFloat)y title:(NSString *)title value:(NSInteger)value
                  minus:(void (^)(void))minus plus:(void (^)(void))plus note:(NSString *)note {
    UIView *r = [self rowBaseIn:parent y:y title:title note:note];
    CGFloat ds = xrc_theme_px(26);
    UIButton *m = [self diamondButton:@"−" action:nil];
    m.frame = CGRectMake(r.bounds.size.width - xrc_theme_px(160), xrc_theme_px(5), ds, ds);
    m.titleLabel.font = xrc_theme_font(@"Exo-SemiBold", 15);
    m.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    objc_setAssociatedObject(m, "xrc_tap", minus, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [m addTarget:self action:@selector(rowTap:) forControlEvents:UIControlEventTouchUpInside];
    [r addSubview:m];
    UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(r.bounds.size.width - xrc_theme_px(128),
                                                          0, xrc_theme_px(60), xrc_theme_px(36))];
    v.text = [NSString stringWithFormat:@"%ld", (long)value];
    v.font = xrc_theme_font(@"Exo-Medium", 16);
    v.textColor = XRC_TXT;
    v.textAlignment = NSTextAlignmentCenter;
    v.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [r addSubview:v];
    UIButton *p = [self diamondButton:@"+" action:nil];
    p.frame = CGRectMake(r.bounds.size.width - xrc_theme_px(62), xrc_theme_px(5), ds, ds);
    p.titleLabel.font = xrc_theme_font(@"Exo-SemiBold", 15);
    p.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    objc_setAssociatedObject(p, "xrc_tap", plus, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [p addTarget:self action:@selector(rowTap:) forControlEvents:UIControlEventTouchUpInside];
    [r addSubview:p];
    [parent addSubview:r];
    return v;
}

// 只读暗行
- (UILabel *)statLineIn:(UIView *)parent y:(CGFloat)y text:(NSString *)text {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(2), y, MAX(self.pane.bounds.size.width, 100), xrc_theme_px(19))];
    l.text = text;
    l.font = xrc_theme_font(@"NotoSansCJKsc-Light", 11.5);
    l.textColor = [UIColor colorWithRed:202/255.0 green:194/255.0 blue:220/255.0 alpha:0.72];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [parent addSubview:l];
    return l;
}

// 说明行（仅 ⓘ 模式）；返回消耗的高度
- (CGFloat)hintLineIn:(UIView *)parent y:(CGFloat)y text:(NSString *)text {
    if (!self.infoOn || !text.length) return 0;
    UIFont *f = xrc_theme_font(@"NotoSansCJKsc-Light", 11.5);
    CGFloat w = MAX(self.pane.bounds.size.width, 100) - xrc_theme_px(6);
    CGRect r = [text boundingRectWithSize:CGSizeMake(w, 600)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{ NSFontAttributeName: f } context:nil];
    CGFloat h = ceil(r.size.height) + xrc_theme_px(8);
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(2), y, w, h)];
    l.font = f;
    l.numberOfLines = 0;
    l.textColor = XRC_DIM2;
    l.text = text;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [parent addSubview:l];
    return h;
}

// 行点击/长按共用的动作分发（动作块经关联对象挂载）
- (void)rowTap:(id)sender {
    UIView *v = [sender isKindOfClass:[UIGestureRecognizer class]] ? ((UIGestureRecognizer *)sender).view : sender;
    void (^blk)(void) = objc_getAssociatedObject(v, "xrc_tap");
    if (blk) blk();
}

#pragma mark - 页签

- (void)tabTapped:(UIButton *)b {
    self.curTab = b.tag;
    [self rebuildPane];
}

- (void)rebuildPane {
    if (!self.pane) return;
    for (UIView *v in [self.pane.subviews copy]) [v removeFromSuperview];
    self.stLoop = self.stAutoplay = nil;
    self.stOwn = self.stFv = self.stDo = self.stGate = self.stCb = self.stNet = self.stStore = self.stStubs = nil;
    self.valA = self.valB = self.valNet = nil;
    self.netStat = self.storeStat = self.judgeStatus = nil;
    self.chips = nil;
    self.logBtns = nil;
    self.judgeVals = [NSMutableArray array];
    for (UIButton *b in self.tabs) b.selected = (b.tag == self.curTab);
    self.paneAct.hidden = YES;
    self.paneAct.tag = -1;

    CGFloat y = xrc_theme_px(2);
    NSInteger t = self.curTab;

    if (t == 0) {   // 循环
        self.paneHint.text = @"设 A/B ＝ 把当前位置记入区间；循环开 ＝ 播到 B 自动回 A；A/B 菱形可直接拖动";
        uint32_t from = 0, to = 0;
        xrc_loop_get_range(&from, &to);
        __weak typeof(self) ws = self;
        self.valA = [self actionRowIn:self.pane y:y title:@"设起点 A" value:[self mmss:from] block:^{ [ws setFrom]; } note:kNoteLoop];
        y += xrc_theme_px(38);
        self.valB = [self actionRowIn:self.pane y:y title:@"设终点 B" value:[self mmss:to] block:^{ [ws setTo]; } note:kNoteLoop];
        y += xrc_theme_px(38);
        self.stLoop = [self toggleRowIn:self.pane y:y title:@"循环" on:xrc_loop_get_enabled()
                                  block:^{ [ws toggleRepeat]; } note:kNoteLoop];
        y += xrc_theme_px(38);
        [self dangerRowIn:self.pane y:y title:@"重置区间" block:^{ [ws resetLoop]; } note:@"清空 A/B 区间与循环开关。"];
        y += xrc_theme_px(38);
        y += [self hintLineIn:self.pane y:y text:kNoteLoop];
    } else if (t == 1) {   // 判定
        self.paneHint.text = @"四档 ±ms 阈值（需递增），应用后只改本地判定宽容度";
        self.paneAct.hidden = !xrc_cap_stub();
        self.paneAct.tag = 1;
        int v[4] = {0};
        xrc_judge_get_windows(&v[0], &v[1], &v[2], &v[3]);
        const char *kn[4] = { "Max", "Pure", "Far", "Lost" };
        self.judgeDirty = NO;
        for (int i = 0; i < 4; i++) {
            __weak typeof(self) ws = self;
            int idx = i;
            UILabel *vl = [self stepperRowIn:self.pane y:y title:@(kn[i]) value:v[i]
                                       minus:^{ [ws judgeStep:idx delta:-5]; }
                                        plus:^{ [ws judgeStep:idx delta:+5]; }
                                        note:kNoteJudge];
            [self.judgeVals addObject:vl];
            y += xrc_theme_px(38);
        }
        self.stAutoplay = [self toggleRowIn:self.pane y:y title:@"自动演奏" on:xrc_judge_autoplay()
                                      block:^{ [self toggleAutoplay]; } note:kNoteJudge];
        y += xrc_theme_px(38);
        self.judgeStatus = [self statLineIn:self.pane y:y text:@""];
        y += xrc_theme_px(20);
        y += [self hintLineIn:self.pane y:y text:kNoteJudge];
    } else if (t == 2) {   // 解锁
        self.paneHint.text = @"离线/未授予时才有意义";
        __weak typeof(self) ws = self;
        NSArray *titles = @[@"拥有链", @"FV 锁", @"DO 锁", @"链门（总闸）", @"cb 自由化"];
        NSArray *feats  = @[@"unlock_own", @"unlock_lock", @"unlock_lock", @"unlock_lock", @"cb_free"];
        for (int i = 0; i < 5; i++) {
            if (!xrc_feature_present([feats[i] UTF8String])) continue;
            // 不使用 switch：case 标签会跨过含弱捕获 block 的语句，构成非法跳转
            if (i == 0) {
                self.stOwn = [self toggleRowIn:self.pane y:y title:titles[i] on:xrc_brk_unlock_own()
                                         block:^{ [ws toggleOwn]; } note:nil];
            } else if (i == 1) {
                self.stFv = [self toggleRowIn:self.pane y:y title:titles[i] on:xrc_brk_unlock_fv()
                                        block:^{ [ws toggleFv]; } note:nil];
            } else if (i == 2) {
                self.stDo = [self toggleRowIn:self.pane y:y title:titles[i] on:xrc_brk_unlock_do()
                                        block:^{ [ws toggleDo]; } note:nil];
            } else if (i == 3) {
                self.stGate = [self toggleRowIn:self.pane y:y title:titles[i] on:xrc_brk_gate_open()
                                          block:^{ [ws toggleGate]; } note:nil];
            } else {
                self.stCb = [self toggleRowIn:self.pane y:y title:titles[i] on:xrc_brk_cb_bypass()
                                        block:^{ [ws toggleCb]; } note:nil];
            }
            y += xrc_theme_px(38);
        }
        y += [self hintLineIn:self.pane y:y text:kNoteUnlock];
    } else if (t == 3) {   // 网络
#if XRC_DEV_SECTION
        self.paneHint.text = @"开发构建：私服重定向（显式开启才生效；只改 API 域名，不动 TLS）";
        __weak typeof(self) ws = self;
        self.stNet = [self toggleRowIn:self.pane y:y title:@"私服" on:xrc_net_enabled()
                                  block:^{ [ws toggleNet]; } note:kNoteNet];
        y += xrc_theme_px(38);
        xrc_config_t c; xrc_config_load(&c);
        self.valNet = [self actionRowIn:self.pane y:y title:@"服务端地址" value:(c.net_base.length ? c.net_base : @"（未设置）")
                                  block:^{ [ws editNetBase]; } note:@"点按编辑服务端地址。"];
        y += xrc_theme_px(38);
        self.netStat = [self statLineIn:self.pane y:y text:@""];
        y += xrc_theme_px(22);
        y += [self hintLineIn:self.pane y:y text:kNoteNet];
#else
        self.paneHint.text = @"发布构建";
        [self statLineIn:self.pane y:y text:@"未授权构建，不提供联网功能"];
        y += xrc_theme_px(24);
#endif
    } else if (t == 4) {   // 存储
        self.paneHint.text = @"免越狱自用通道";
        __weak typeof(self) ws = self;
        self.stStore = [self toggleRowIn:self.pane y:y title:@"cb 外置" on:YES
                                    block:^{ [ws toggleStore]; } note:kNoteStore];
        {
            xrc_config_t c; xrc_config_load(&c);
            if (self.stStore) {
                self.stStore.text = c.external_cb ? @"已开" : @"已关";
                self.stStore.textColor = c.external_cb ? XRC_TXT : XRC_OFF;
            }
        }
        y += xrc_theme_px(38);
        self.storeStat = [self statLineIn:self.pane y:y text:xrc_store_cb_status()];
        y += xrc_theme_px(22);
        y += [self hintLineIn:self.pane y:y text:kNoteStore];
    } else {   // 诊断
        self.paneHint.text = @"日志 xrcdemo.log";
        NSMutableArray *chips = [NSMutableArray array];
        NSArray *cn = @[@"stub", @"v2", @"judge", @"gp", @"mtp"];
        CGFloat cx = xrc_theme_px(2);
        for (int i = 0; i < (int)cn.count; i++) {
            UILabel *ch = [[UILabel alloc] initWithFrame:CGRectMake(cx, y, xrc_theme_px(62), xrc_theme_px(17))];
            ch.textAlignment = NSTextAlignmentCenter;
            ch.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 11);
            ch.textColor = [UIColor colorWithRed:226/255.0 green:220/255.0 blue:240/255.0 alpha:0.85];
            ch.layer.borderWidth = 1;
            ch.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.26].CGColor;
            ch.layer.cornerRadius = 4;
            [self.pane addSubview:ch];
            [chips addObject:ch];
            cx += xrc_theme_px(68);
        }
        self.chips = chips;
        y += xrc_theme_px(24);
        self.patchLine = [self statLineIn:self.pane y:y text:@""];
        y += xrc_theme_px(22);
#if XRC_DEV_SECTION
        {
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(2), y, xrc_theme_px(80), xrc_theme_px(22))];
            lb.text = @"日志档位";
            lb.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 15);
            lb.textColor = [UIColor colorWithRed:244/255.0 green:241/255.0 blue:250/255.0 alpha:1.0];
            [self.pane addSubview:lb];
            NSMutableArray *btns = [NSMutableArray array];
            NSArray *ln = @[@"默认", @"详细", @"网络"];
            CGFloat bw = (MAX(self.pane.bounds.size.width, 100) - xrc_theme_px(90)) / 3.0;
            for (int i = 0; i < 3; i++) {
                UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
                b.frame = CGRectMake(xrc_theme_px(88) + bw * i, y - xrc_theme_px(2), bw, xrc_theme_px(26));
                [b setTitle:ln[i] forState:UIControlStateNormal];
                b.titleLabel.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 12);
                [b setTitleColor:[UIColor colorWithRed:226/255.0 green:218/255.0 blue:242/255.0 alpha:0.62]
                        forState:UIControlStateNormal];
                [b setTitleColor:XRC_TXT forState:UIControlStateSelected];
                UIImage *sel = xrc_theme_img(@"img/dialog_v2/tabs_selected.png");
                if (sel) [b setBackgroundImage:[sel resizableImageWithCapInsets:UIEdgeInsetsMake(8, 8, 8, 8)]
                                      forState:UIControlStateSelected];
                b.tag = i;
                b.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
                [b addTarget:self action:@selector(logBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
                [self.pane addSubview:b];
                [btns addObject:b];
            }
            self.logBtns = btns;
            self.logSel = [self logPresetIndex];
            y += xrc_theme_px(32);
        }
        y += [self hintLineIn:self.pane y:y text:kNoteDiag];
        UIView *dev = [self buildDevBlockAt:&y];
        (void)dev;
#endif
    }

    self.pane.contentSize = CGSizeMake(self.pane.bounds.size.width, y + xrc_theme_px(10));
    [self refresh];
}

#pragma mark - 诊断页：开发块

#if XRC_DEV_SECTION
- (UIView *)buildDevBlockAt:(CGFloat *)py {
    CGFloat y = *py;
    CGFloat W = MAX(self.pane.bounds.size.width, xrc_theme_px(160));
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, y, W, 10)];
    box.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIView *ln = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 1)];
    ln.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
    [box addSubview:ln];
    UILabel *bd = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(2), xrc_theme_px(6), xrc_theme_px(60), xrc_theme_px(18))];
    bd.text = @"开发";
    bd.textAlignment = NSTextAlignmentCenter;
    bd.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 10);
    bd.textColor = [UIColor colorWithRed:143/255.0 green:195/255.0 blue:195/255.0 alpha:1.0];
    bd.layer.borderWidth = 1;
    bd.layer.borderColor = [UIColor colorWithRed:143/255.0 green:195/255.0 blue:195/255.0 alpha:0.42].CGColor;
    bd.layer.cornerRadius = 4;
    [box addSubview:bd];
    UILabel *dn = [[UILabel alloc] initWithFrame:CGRectMake(xrc_theme_px(70), xrc_theme_px(6), W - xrc_theme_px(72), xrc_theme_px(18))];
    dn.text = @"以下工具随开发构建提供";
    dn.font = xrc_theme_font(@"NotoSansCJKsc-Light", 11);
    dn.textColor = XRC_DIM2;
    [box addSubview:dn];
    CGFloat by = xrc_theme_px(32);
    NSArray *bn = @[@"转储内存", @"清理转储", @"OM 探针", @"强制 applog"];
    NSArray *bs = @[@"dumpMemory", @"cleanDump", @"omProbe", @"forceApplog"];
    CGFloat bw = (W - xrc_theme_px(8)) / 2.0;
    for (int i = 0; i < 4; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake((bw + xrc_theme_px(8)) * (i % 2), by + xrc_theme_px(42) * (i / 2), bw, xrc_theme_px(38));
        [b setBackgroundImage:xrc_theme_img9(@"layouts/1080/pause/button.png", 15, 11, 15, 11)
                     forState:UIControlStateNormal];
        [b setTitle:bn[i] forState:UIControlStateNormal];
        b.titleLabel.font = xrc_theme_font(@"NotoSansCJKsc-Regular", 13);
        [b setTitleColor:XRC_TXT forState:UIControlStateNormal];
        [b addTarget:self action:NSSelectorFromString(bs[i]) forControlEvents:UIControlEventTouchUpInside];
        [box addSubview:b];
    }
    by += xrc_theme_px(42) * 2;
    xrc_config_t c; xrc_config_load(&c);
    self.stStubs = [self toggleRowIn:box y:by title:@"观测桩轻量" on:c.stubs_lite
                                block:^{ [self toggleStubsLite]; }
                                 note:@"观测桩重活停摆、只推进 PC（仍保留 SIGTRAP 成本）。"];
    by += xrc_theme_px(38);
    by += [self hintLineIn:box y:by text:kNoteDev];
    box.frame = CGRectMake(0, y, W, by + xrc_theme_px(4));
    [self.pane addSubview:box];
    *py = y + box.bounds.size.height;
    return box;
}

#endif

- (void)logBtnTapped:(UIButton *)b {
#if XRC_DEV_SECTION
    self.logSel = b.tag;
    [self applyLogPreset];
#endif
}
- (NSInteger)logPresetIndex {
    int lv = xrc_log_level();
    uint32_t cats = xrc_log_cats();
    if (lv >= 3) return (cats == (XRCLC_NET | XRCLC_DL | XRCLC_BOOT | XRCLC_CB)) ? 2 : 1;
    return 0;
}
- (void)applyLogPreset {
#if XRC_DEV_SECTION
    xrc_config_t c; xrc_config_load(&c);
    switch (self.logSel) {
        case 1: xrc_log_preset_verbose(); c.log_level = 3; c.log_cats = 0; break;
        case 2: xrc_log_preset_net(); c.log_level = 3;
                c.log_cats = (XRCLC_NET | XRCLC_DL | XRCLC_BOOT | XRCLC_CB); break;
        default: xrc_log_preset_default(); c.log_level = 2; c.log_cats = 0; break;
    }
    xrc_config_save(&c);
    for (UIButton *b in self.logBtns) b.selected = (b.tag == self.logSel);
    [WHToast showMessage:(self.logSel == 0 ? @"日志档位：默认"
                                : (self.logSel == 1 ? @"日志档位：详细" : @"日志档位：网络"))
                duration:1.0 finishHandler:^{}];
#endif
}

#pragma mark - 动作（与引擎状态机接线）

- (NSString *)mmss:(uint32_t)ms {
    uint32_t s = ms / 1000;
    return [NSString stringWithFormat:@"%02u:%02u", s / 60, s % 60];
}

- (void)toggleInfo {
    self.infoOn = !self.infoOn;
    [self rebuildPane];
}

- (void)toggleRepeat {
    if (xrc_loop_get_enabled()) {
        xrc_loop_set_enabled(false);
    } else {
        uint32_t from = 0, to = 0;
        xrc_loop_get_range(&from, &to);
        if (to <= from + 1000) {
            [WHToast showMessage:@"请先设置循环起点和终点（或直接拖时间轴上的 A/B 菱形）"
                        duration:1.6 finishHandler:^{}];
            return;
        }
        xrc_loop_set_enabled(true);
    }
    [self refresh];
}

- (void)setFrom {
    uint32_t pos = xrc_player_position_ms();
    xrc_loop_set_enabled(false);
    xrc_loop_set_range(pos, 0);
    self.pendingTo = YES;
    [WHToast showMessage:[NSString stringWithFormat:@"起点 %@，播放到终点再按 设终点 B", [self mmss:pos]]
                duration:1.6 finishHandler:^{}];
    [self refresh];
}

- (void)setTo {
    uint32_t from = 0, oldTo = 0;
    xrc_loop_get_range(&from, &oldTo);
    BOOL hasFrom = self.pendingTo || (oldTo > from + 1000) || (from > 0);
    if (!hasFrom) {
        [WHToast showMessage:@"请先播放到起点位置按 设起点 A" duration:1.4 finishHandler:^{}];
        return;
    }
    uint32_t pos = xrc_player_position_ms();
    if (pos < from + 1000) {
        [WHToast showMessage:@"终点需在起点 1 秒之后" duration:1.4 finishHandler:^{}];
        return;
    }
    xrc_loop_set_enabled(false);
    xrc_loop_set_range(from, pos);
    self.pendingTo = NO;
    [WHToast showMessage:[NSString stringWithFormat:@"循环区间 %@ - %@，可开循环",
                          [self mmss:from], [self mmss:pos]]
                duration:1.6 finishHandler:^{}];
    [self refresh];
}

- (void)resetLoop {
    xrc_loop_reset_all();
    self.pendingTo = NO;
    [WHToast showMessage:@"循环区间已重置" duration:1.0 finishHandler:^{}];
    [self refresh];
}

- (void)jumpBack    { [self jump:-1]; }
- (void)jumpForward { [self jump:+1]; }
- (void)jump:(int)dir {
    uint32_t pos = xrc_player_position_ms();
    uint32_t dur = (uint32_t)(5000 * xrc_clock_get_rate());
    uint32_t target = (dir < 0) ? (pos > dur ? pos - dur : 0) : pos + dur;
    uint32_t len = xrc_player_song_length_ms();
    if (dir > 0 && len && target > len) target = len;
    xrc_gameplay_request(XRC_OP_SEEK, target);
}

// 速度：点按 ±0.05；长按连续 ±0.25（chevronLongPress 驱动定时器）
- (void)speedDown:(id)sender { [self speedStep:-0.05]; }
- (void)speedUp:(id)sender   { [self speedStep:+0.05]; }
- (void)speedStep:(double)d {
    double r = xrc_clock_get_rate() + d;
    if (r < 0.05) r = 0.05;
    if (r > 2.0) r = 2.0;
    r = round(r * 100.0) / 100.0;
    xrc_clock_set_rate(r);
    xrc_config_set_current_speed((float)r);
    self.speedNum.text = [NSString stringWithFormat:@"%.2f", r];
}

- (void)chevronLongPress:(UILongPressGestureRecognizer *)g {
    static NSTimer *rep = nil;
    BOOL right = (g.view.tag == 1);
    if (g.state == UIGestureRecognizerStateBegan) {
        [self speedStep:(right ? 0.25 : -0.25)];
        [rep invalidate];
        rep = [NSTimer timerWithTimeInterval:0.12 repeats:YES block:^(NSTimer *t) {
            [self speedStep:(right ? 0.25 : -0.25)];
        }];
        [[NSRunLoop mainRunLoop] addTimer:rep forMode:NSRunLoopCommonModes];
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        [rep invalidate]; rep = nil;
    }
}

- (void)judgeStep:(NSInteger)idx delta:(NSInteger)d {
    if (idx < 0 || idx >= (int)self.judgeVals.count) return;
    UILabel *l = self.judgeVals[idx];
    NSInteger v = MAX(1, [l.text integerValue] + d);
    l.text = [NSString stringWithFormat:@"%ld", (long)v];
    self.judgeDirty = YES;
}

- (void)applyJudge {
    if (self.judgeVals.count < 4) return;
    if (!(g_caps.stub_present && g_caps.judge_handler_live)) {
        [WHToast showMessage:@"判定：主程序未打桩或 handler 未安装（见诊断页）"
                    duration:1.6 finishHandler:^{}];
        return;
    }
    int v[4];
    for (int i = 0; i < 4; i++) v[i] = MAX(1, [self.judgeVals[i].text intValue]);
    if (v[1] <= v[0]) v[1] = v[0] + 1;
    if (v[2] <= v[1]) v[2] = v[1] + 1;
    if (v[3] <= v[2]) v[3] = v[2] + 1;
    for (int i = 0; i < 4; i++) self.judgeVals[i].text = [NSString stringWithFormat:@"%d", v[i]];
    xrc_judge_set_windows(v[0], v[1], v[2], v[3]);
    xrc_config_t c; xrc_config_load(&c);
    c.judge_max_ms = v[0]; c.judge_pure_ms = v[1];
    c.judge_far_ms = v[2]; c.judge_lost_ms = v[3];
    xrc_config_save(&c);
    self.judgeDirty = NO;
    if (c.toast)
        [WHToast showMessage:[NSString stringWithFormat:@"判定窗口 ±%d/%d/%d/%d", v[0], v[1], v[2], v[3]]
                    duration:1.2 finishHandler:^{}];
}

// 开关：统一"读配置 → 翻转 → 保存 → 即时生效 → 刷新"路径
#define XRC_TOGGLE_SWITCH(KEY, SETTER, ONMSG, OFFMSG)                                   \
    do {                                                                                \
        xrc_config_t c; xrc_config_load(&c);                                            \
        c.KEY = !c.KEY; xrc_config_save(&c);                                            \
        SETTER(c.KEY);                                                                  \
        [WHToast showMessage:(c.KEY ? ONMSG : OFFMSG) duration:1.4 finishHandler:^{}];  \
        [self refresh];                                                                 \
    } while (0)

- (void)toggleOwn    { XRC_TOGGLE_SWITCH(unlock_own, xrc_brk_set_unlock_own, @"拥有链：三层恒真（覆盖未授予场景）", @"拥有链：恢复原判定"); }
- (void)toggleFv     { XRC_TOGGLE_SWITCH(unlock_fv,  xrc_brk_set_unlock_fv,  @"FV 锁：五难度全解", @"FV 锁：恢复原判定"); }
- (void)toggleDo     { XRC_TOGGLE_SWITCH(unlock_do,  xrc_brk_set_unlock_do,  @"DO 锁：五难度全解（显示专属曲绘）", @"DO 锁：恢复原判定"); }
- (void)toggleGate   { XRC_TOGGLE_SWITCH(gate_open,  xrc_brk_set_gate_open,  @"链门：放行（整表解锁总闸）", @"链门：恢复原判定"); }
- (void)toggleCb     { XRC_TOGGLE_SWITCH(cb_bypass,  xrc_brk_set_cb_bypass,  @"cb 自由化：校验恒通过 + 清树禁用", @"cb 校验：恢复原行为"); }
- (void)toggleReplay { XRC_TOGGLE_SWITCH(replay_arm, xrc_replay_set_enabled, @"回跳重播：开（回跳后重新游玩该段并清空分数记录）", @"回跳重播：关"); }

- (void)toggleAutoplay {
    xrc_config_t c; xrc_config_load(&c);
    c.autoplay = !c.autoplay;
    xrc_config_save(&c);
    xrc_judge_set_autoplay(c.autoplay);
    if (c.toast) {
        [WHToast showMessage:(c.autoplay ? @"自动演奏：全部判定 → Pure" : @"自动演奏：关")
                    duration:1.4 finishHandler:^{}];
    }
    [self refresh];
}

- (void)toggleStore {
    xrc_config_t c; xrc_config_load(&c);
    c.external_cb = !c.external_cb;
    xrc_config_save(&c);
    if (c.external_cb) {
        int r = xrc_store_install();
        if (c.toast) {
            [WHToast showMessage:(r == 0 ? @"cb 已搬到 Documents（瞬间完成）"
                                    : (r == 1 ? @"cb 已是外置态" : @"迁移失败，看日志"))
                        duration:1.6 finishHandler:^{}];
        }
    } else if (c.toast) {
        [WHToast showMessage:@"cb 外置已关（已建软链不会自动撤销）" duration:1.8 finishHandler:^{}];
    }
    [self refresh];
}

- (void)toggleSpeedAudio {
    xrc_config_t c; xrc_config_load(&c);
    c.speed_audio = !c.speed_audio;
    xrc_config_save(&c);
    xrc_audio_speed_set_enabled(c.speed_audio);
    if (c.toast) {
        [WHToast showMessage:(c.speed_audio ? @"音乐变速：开（BGM 跟随速度，保音高）"
                                            : @"音乐变速：关（BGM 恒 1.0x，音画会错开）")
                    duration:1.6 finishHandler:^{}];
    }
    [self refresh];
}

- (void)editNetBase {
#if XRC_DEV_SECTION
    xrc_config_t c; xrc_config_load(&c);
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"服务端地址"
                                                              message:@"如 http://192.168.1.10:8080"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = c.net_base ?: @"";
        tf.keyboardType = UIKeyboardTypeURL;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) ws = self;
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        __strong typeof(self) sf = ws; if (!sf) return;
        NSString *base = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
        xrc_config_t cc; xrc_config_load(&cc);
        cc.net_base = base.length ? base : nil;
        xrc_config_save(&cc);
        xrc_net_set_base(cc.net_base ? cc.net_base.UTF8String : NULL);
        [sf rebuildPane];
        if (cc.toast) [WHToast showMessage:[NSString stringWithFormat:@"服务端地址：%@", base.length ? base : @"(空)"]
                                  duration:1.2 finishHandler:^{}];
    }]];
    [[self keyWindow].rootViewController presentViewController:a animated:YES completion:nil];
#endif
}

- (void)toggleNet {
#if XRC_DEV_SECTION
    xrc_config_t c; xrc_config_load(&c);
    if (!c.net_enabled) {
        if (!c.net_base.length) {
            [self rebuildPane];
            [WHToast showMessage:@"请先填写服务端地址" duration:1.6 finishHandler:^{}];
            [self editNetBase];
            return;
        }
    }
    c.net_enabled = !c.net_enabled;
    xrc_config_save(&c);
    xrc_net_set_base(c.net_base ? c.net_base.UTF8String : NULL);
    xrc_net_set_enabled(c.net_enabled);
    [WHToast showMessage:c.net_enabled ? [NSString stringWithFormat:@"私服 开 → %@", c.net_base]
                                      : @"私服 关（走官方域）"
                duration:1.4 finishHandler:^{}];
    [self refresh];
#endif
}

#if XRC_DEV_SECTION
- (void)dumpMemory {
    if (xrc_dump_running()) {
        [WHToast showMessage:[NSString stringWithFormat:@"转储进行中 %d/%d",
                              xrc_dump_regions_done(), xrc_dump_regions_total()]
                    duration:1.2 finishHandler:^{}];
        return;
    }
    xrc_dump_start();
    [WHToast showMessage:@"开始转储内存（后台）" duration:1.5 finishHandler:^{}];
}

- (void)cleanDump {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *mem = [docs stringByAppendingPathComponent:@"xrcdemo-net/mem"];
    NSError *err = nil;
    [[NSFileManager defaultManager] removeItemAtPath:mem error:&err];
    [WHToast showMessage:(err ? @"清理转储失败（看日志）" : @"转储目录已清理")
                duration:1.2 finishHandler:^{}];
    if (err) xrc_logw(XRCLC_PROBE, @"clean dump failed: %@", err);
}

- (void)omProbe {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try { xrc_om_probe(); } @catch (NSException *e) { xrc_logw(XRCLC_OM, @"probe EX: %@", e); }
    });
    [WHToast showMessage:@"OM 探针已派发（后台，看日志）" duration:1.5 finishHandler:^{}];
}

- (void)forceApplog {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"强制 applog"
                                                              message:@"将直调 vtable 槽 72 真实发送一次上报。继续？"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"发送" style:UIAlertActionStyleDestructive
                                       handler:^(UIAlertAction *act) {
        @try { xrc_om_force_applog(); } @catch (NSException *e) { xrc_logw(XRCLC_OM, @"force EX: %@", e); }
    }]];
    [[self keyWindow].rootViewController presentViewController:a animated:YES completion:nil];
}

- (void)toggleStubsLite {
    xrc_config_t c; xrc_config_load(&c);
    c.stubs_lite = !c.stubs_lite;
    xrc_config_save(&c);
    xrc_arc_stubs_lite_set(c.stubs_lite);
    if (self.stStubs) { self.stStubs.text = c.stubs_lite ? @"已开" : @"已关"; self.stStubs.textColor = c.stubs_lite ? XRC_TXT : XRC_OFF; }
    [WHToast showMessage:(c.stubs_lite ? @"观测桩：轻量模式" : @"观测桩：全量") duration:1.2 finishHandler:^{}];
}
#endif

#pragma mark - 刷新

- (void)refreshFast {
    uint32_t len = xrc_player_song_length_ms();
    uint32_t pos = xrc_player_position_ms();
    if (len == 0) len = MAX(pos, 1000);
    self.timeline.lengthMs = len;
    self.timeline.positionMs = pos;
    uint32_t from = 0, to = 0;
    xrc_loop_get_range(&from, &to);
    [self.timeline setLoopFromMs:from to:to visible:xrc_loop_get_enabled()];

    if (!xrc_cap_player()) {
        self.tcur.text = @"--:--"; self.ttot.text = @"--:--";
    } else {
        self.tcur.text = [NSString stringWithFormat:@"%u:%02u.%03u",
                          pos / 60000, (pos / 1000) % 60, pos % 1000];
        self.ttot.text = [NSString stringWithFormat:@"%u:%02u.%03u",
                          len / 60000, (len / 1000) % 60, len % 1000];
    }
    if (to > from) {
        self.tmid.text = [NSString stringWithFormat:@"A %@　B %@", [self mmss:from], [self mmss:to]];
        self.tmid.textColor = xrc_loop_get_enabled() ? XRC_LAV : XRC_DIM2;
    } else {
        self.tmid.text = @"";
    }
    double r = xrc_clock_get_rate();
    self.speedNum.text = [NSString stringWithFormat:@"%.2f", r];
}

- (void)refreshSlow {
    // 开关状态镜像（引擎真值 → 状态词）
    [self setState:self.stSpeedAudio on:xrc_audio_speed_enabled()];
    [self setState:self.stReplay on:xrc_replay_enabled()];
    [self setState:self.stLoop on:xrc_loop_get_enabled()];
    [self setState:self.stAutoplay on:xrc_judge_autoplay()];
    [self setState:self.stOwn on:xrc_brk_unlock_own()];
    [self setState:self.stFv on:xrc_brk_unlock_fv()];
    [self setState:self.stDo on:xrc_brk_unlock_do()];
    [self setState:self.stGate on:xrc_brk_gate_open()];
    [self setState:self.stCb on:xrc_brk_cb_bypass()];
    [self setState:self.stNet on:xrc_net_enabled()];
    {
        xrc_config_t c; xrc_config_load(&c);
        [self setState:self.stStore on:c.external_cb];
    }

    if (self.valA || self.valB) {
        uint32_t f = 0, t2 = 0;
        xrc_loop_get_range(&f, &t2);
        if (self.valA) self.valA.text = [self mmss:f];
        if (self.valB) self.valB.text = [self mmss:t2];
    }
    if (self.valNet) {
        xrc_config_t c; xrc_config_load(&c);
        self.valNet.text = c.net_base.length ? c.net_base : @"（未设置）";
    }
    if (self.netStat)
        self.netStat.text = [NSString stringWithFormat:@"改写 %llu/%llu 请求 ｜ 下载任务 %u 建 / %u 完",
                             xrc_net_rewritten(), xrc_net_requests(),
                             xrc_net_dl_created(), xrc_net_dl_done()];
    if (self.storeStat) self.storeStat.text = xrc_store_cb_status();

    // 判定：草稿未被改动时同步引擎真值；无桩时状态行给出原因
    BOOL judgeOK = g_caps.stub_present && g_caps.judge_handler_live;
    if (self.judgeVals.count == 4 && !self.judgeDirty) {
        int v[4] = {0};
        xrc_judge_get_windows(&v[0], &v[1], &v[2], &v[3]);
        for (int i = 0; i < 4; i++)
            self.judgeVals[i].text = [NSString stringWithFormat:@"%d", v[i]];
    }
    if (self.judgeStatus) {
        if (judgeOK) {
            self.judgeStatus.text = @"";
        } else if (!g_caps.stub_present) {
            self.judgeStatus.text = @"判定：主程序未打桩（仅 dylib？）";
            self.judgeStatus.textColor = [UIColor colorWithRed:1.0 green:0.63 blue:0.35 alpha:1.0];
        } else if (!g_caps.stub_v2) {
            self.judgeStatus.text = @"判定：桩为 v1 形态，请重新注入（inject.py --stub）";
            self.judgeStatus.textColor = [UIColor colorWithRed:1.0 green:0.63 blue:0.35 alpha:1.0];
        } else {
            self.judgeStatus.text = @"判定：handler 未安装（看日志）";
            self.judgeStatus.textColor = [UIColor colorWithRed:1.0 green:0.63 blue:0.35 alpha:1.0];
        }
    }

    // 诊断：徽标 / 补丁行
    if (self.chips.count == 5) {
        BOOL ok[5] = { g_caps.stub_present, g_caps.stub_v2, g_caps.judge_handler_live,
                       g_caps.gp_hook_live, g_caps.mtp_hook_live };
        NSArray *cn = @[@"stub", @"v2", @"judge", @"gp", @"mtp"];
        for (int i = 0; i < 5; i++) {
            self.chips[i].text = [NSString stringWithFormat:@"%@ %@", cn[i], ok[i] ? @"✓" : @"✗"];
            self.chips[i].textColor = ok[i]
                ? [UIColor colorWithRed:169/255.0 green:220/255.0 blue:185/255.0 alpha:0.95]
                : [UIColor colorWithRed:226/255.0 green:160/255.0 blue:120/255.0 alpha:0.95];
        }
    }
    if (self.patchLine) {
        NSString *netCap =
#if XRC_DEV_SECTION
            @" 网络✓";
#else
            @" 联网✗(已阻断)";
#endif
        self.patchLine.text = [NSString stringWithFormat:@"补丁：cb 自由化 %@%@",
                               xrc_brk_cb_bypass() ? @"启用" : @"原行为", netCap];
    }
#if XRC_DEV_SECTION
    if (self.logBtns) {
        NSInteger idx = [self logPresetIndex];
        self.logSel = idx;
        for (UIButton *b in self.logBtns) b.selected = (b.tag == idx);
    }
#endif
}

- (void)setState:(UILabel *)l on:(BOOL)on {
    if (!l) return;
    l.text = on ? @"已开" : @"已关";
    l.textColor = on ? XRC_TXT : XRC_OFF;
}

- (void)refresh {
    [self refreshFast];
    [self refreshSlow];
}

@end
