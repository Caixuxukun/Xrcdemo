// © 雾月星辰 & MLXC · github@XingChenRS
// XRCTheme.h — 面板 v4「原生风格」素材 / 字体 / 量纲的单一来源。
//
// 素材与字体全部取自游戏包（mainBundle，与游戏同进程同文件）：
//   · 九宫格素材按原始像素导出（1.5× 类），统一以 scale=1.5 还原为逻辑点后使用；
//   · 字体经 CoreText 注册后按 PostScript 名引用（Exo-SemiBold.ttf 的 PS 名是
//     Exo-DemiBold，其余与文件名一致）；
//   · 量纲换算：设计值（1280 设计宽）→ 屏上点 = ×(屏宽pt/852)（852pt 对应 1280 设计宽
//     的横屏设备；非 852 宽的机型按同比例缩放）。
#pragma once

#import <UIKit/UIKit.h>

// 量纲
CGFloat xrc_theme_scale(void);                 // 屏宽pt / 852（首次取值后缓存，主线程用）
static inline CGFloat xrc_theme_px(CGFloat designPx) { return designPx * xrc_theme_scale(); }

// 字体（幂等；designPx 为设计值，内部完成量纲换算；缺失时回退系统字体）
void   xrc_theme_ensure_fonts(void);
UIFont *xrc_theme_font(NSString *psName, CGFloat designPx);

// 素材（相对 mainBundle 的路径，如 @"layouts/1080/pause/pause_backing.png"）
UIImage *xrc_theme_img(NSString *relPath);
// 九宫格：insets 传**素材像素**（引擎 capInsets 原值），内部 ÷1.5 转为逻辑点
UIImage *xrc_theme_img9(NSString *relPath, CGFloat lPx, CGFloat tPx, CGFloat rPx, CGFloat bPx);

// 色板（与 UI 稿 v4 一致）
#define XRC_TXT      [UIColor whiteColor]
#define XRC_DIM      [UIColor colorWithRed:206/255.0 green:198/255.0 blue:224/255.0 alpha:0.74]
#define XRC_DIM2     [UIColor colorWithRed:190/255.0 green:182/255.0 blue:208/255.0 alpha:0.52]
#define XRC_LAV      [UIColor colorWithRed:215/255.0 green:205/255.0 blue:236/255.0 alpha:1.0]
#define XRC_OFF      [UIColor colorWithRed:168/255.0 green:158/255.0 blue:186/255.0 alpha:0.92]
#define XRC_DANGER   [UIColor colorWithRed:217/255.0 green:138/255.0 blue:138/255.0 alpha:1.0]
#define XRC_BAND     [UIColor colorWithRed:126/255.0 green:100/255.0 blue:172/255.0 alpha:0.40]
#define XRC_BAND_EDG [UIColor colorWithRed:196/255.0 green:178/255.0 blue:232/255.0 alpha:0.65]
