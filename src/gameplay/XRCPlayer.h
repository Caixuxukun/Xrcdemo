// © 雾月星辰 & MLXC · github@XingChenRS
// XRCPlayer.h — 音频：registry/player/channel/进度/曲长（单一数据源）。
#pragma once

#include <stdint.h>
#include <stdbool.h>

// 惰性解析 player（首次经 registry，此后缓存）。
void *xrc_player_get(void);

// 安装（偏移解析 + MTP getpos vtable hook）。
void xrc_player_install(uint64_t image_base);

// vtable hook 内部回调：更新位置缓存 + 换歌检测。
void xrc_player_update_position(void *self, uint32_t pos);

// 当前曲长 ms（0 = 未捕获）。
uint32_t xrc_player_song_length_ms(void);

// 当前播放位置 ms（缓存值，由 vtable hook 更新；无 hook 时降级为 0）。
uint32_t xrc_player_position_ms(void);

// 曲长捕获（换歌检测后调用一次即可）。
void xrc_player_try_capture_length(void *player);

// 位置轮询兜底（0.5s NSTimer）：channel 0 get_position。
// 注意：getpos vtable hook 只在游戏查询进度时触发，位置会过时。
void xrc_player_poll_position(void *player);

// 换歌检测（player/channels 指针变化 → 清状态）。返回是否换歌。
bool xrc_player_detect_change(void *player);

// 音频 seek（vtable 槽 0x40）。返回是否执行。
bool xrc_player_seek_ms(void *self, uint32_t ms);

// 音频暂停/恢复（vtable 槽 0x30 = setPaused(paused, index=0→默认 BGM 通道)）。
// 外部参考实现同款链路（设计纪要 §1.3/§2）。返回是否成功（FMOD_RESULT==0）。
bool xrc_player_pause(bool paused);

// 暂停持有计数（多来源共用）：任一持有者持有则暂停，全部释放才恢复；未持有时
// 释放为无害空操作。用途：面板「练习暂停」与 seek 冻结窗共用音频暂停——若各自
// 直接调 xrc_player_pause，后收口的一方会误解除先持有方（真机形态：面板暂停中
// 拖动 seek，冻结窗收口的"恢复"把音频放出来 ⇒ 谱面停、音乐响）。
bool xrc_player_pause_hold(bool hold);
