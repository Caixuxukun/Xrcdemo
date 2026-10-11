// © 雾月星辰 & MLXC · github@XingChenRS
// XRCTimelineView.h — 面板时间轴控件（Arcaea 原生风格）。
//
// 三段式拖动协议（面板据此接线）：
//   按下 onScrubBegin   → 面板冻结播放（音频 + 谱面钟）
//   移动 onScrubLive(ms)→ 实时对齐预览（轻量定位，跟手）
//   松手 onScrubEnd(ms) → 驻停在该位置；面板按回退幅度决定是否提交重播事务
// 循环区间：band 随循环开关样式切换；A/B 菱形手柄可直接拖（onLoopRangeChanged）。
#pragma once

#import <UIKit/UIKit.h>

@interface XRCTimelineView : UIView
@property (nonatomic, copy) void (^onScrubBegin)(void);
@property (nonatomic, copy) void (^onScrubLive)(uint32_t ms);
@property (nonatomic, copy) void (^onScrubEnd)(uint32_t ms);
// from/to 归一化 0..1；finished=松手（面板据此落盘）
@property (nonatomic, copy) void (^onLoopRangeChanged)(double from, double to, BOOL finished);
@property (nonatomic, assign) uint32_t lengthMs;
@property (nonatomic, assign) uint32_t positionMs;
@property (nonatomic, assign) uint32_t loopFromMs;
@property (nonatomic, assign) uint32_t loopToMs;
@property (nonatomic, assign) BOOL loopVisible;
// 设计基准 = 屏宽（全景布置时由面板传入等价换算，默认 852）
@property (nonatomic, assign) CGFloat scaleRef;
- (void)setLoopFromMs:(uint32_t)from to:(uint32_t)to visible:(BOOL)visible;
@end
