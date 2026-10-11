// © 雾月星辰 & MLXC · github@XingChenRS
// XRCTimelineView.h — 面板时间轴控件。
//
// 交互协议（三段式，面板据此接线；语义见 ios-panel-pause-seek-interplay 详档）：
//   按下 onScrubBegin   → 面板冻结播放（音频 + 谱面钟）
//   移动 onScrubLive(ms)→ 实时对齐预览（轻量定位，跟手）
//   松手 onScrubEnd(ms) → 驻停在该位置；面板按回退幅度决定是否提交重播事务
#pragma once

#import <UIKit/UIKit.h>

@interface XRCTimelineView : UIView
@property (nonatomic, copy) void (^onScrubBegin)(void);
@property (nonatomic, copy) void (^onScrubLive)(uint32_t ms);
@property (nonatomic, copy) void (^onScrubEnd)(uint32_t ms);
@property (nonatomic, assign) uint32_t lengthMs;
@property (nonatomic, assign) uint32_t positionMs;
@property (nonatomic, assign) uint32_t loopFromMs;
@property (nonatomic, assign) uint32_t loopToMs;
@property (nonatomic, assign) BOOL loopVisible;
- (void)setLoopFromMs:(uint32_t)from to:(uint32_t)to visible:(BOOL)visible;
@end
