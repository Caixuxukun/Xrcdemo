// © 雾月星辰 & MLXC · github@XingChenRS
// XRCPracticePanel.h — 练习面板（设计稿：ui-mock/panel_mock.html v4，Arcaea 原生风格）。
// 形态：全屏模态。打开**不**暂停播放；触碰时间轴＝冻结＋实时对齐预览，松手驻停，
//       「继续/关闭」才恢复播放（交互协议见 XRCTimelineView.h）。
// 分区（页签）：循环｜判定｜解锁｜网络（发布构建为阻断声明页）｜存储｜诊断。
// 素材/字体/量纲统一走 XRCTheme（包内原文件，见其头注释）。
#pragma once

#import <UIKit/UIKit.h>

@interface XRCPracticePanel : UIView

+ (instancetype)shared;
- (void)show;
- (void)hide;
- (BOOL)isVisible;

// 面板显示时的周期刷新（内部 0.1s 定时器；外部也可手动调用）。
- (void)tick;

@end
