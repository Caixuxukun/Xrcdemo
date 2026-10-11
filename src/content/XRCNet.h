// © 雾月星辰 & MLXC · github@XingChenRS
// XRCNet.h — 私服接入：把游戏 API 请求改指向自有服务端 + 全量请求日志。
//
// ⚠ 构建模式规则（本注释为单一出处，iOS / Android 通用，沿线沿用）：
//   · 发布构建（默认编译）**不包含私服功能**（不编译安装点、面板无「网络」分区）；
//   · 只有编译时处于开发模式、且用户显式开启「私服」条目，才启用该功能；
//   · 私服内容的版权 / 数据处理 / 安全性由使用者自负；
//     本插件默认的练习能力不强制绑定私服。
//
// 设计依据（真机内存转储分析）：
//   · 游戏 API base = https://arcapi-v4.lowiro.com/coordinatedballetclock/42/<endpoint>
//     host 与端点之间还有一层 codename + 版本号，且该 codename 不存在于静态二进制。
//   · 游戏网络栈走 NSURLConnection（HttpAsynConnection 封装），不是 NSURLSession。
//   · pin 表按域名查询；换到自有域名后不在表内 → DomainNotPinned → 放行。
//
// 因此最小可行方案：**在 NSURLConnection 建连前改写 URL 的 scheme/host/port，
// 保留 path 与 query**。服务端因此能看到完整原始路径（含 codename），
// 对调试最有利；同时不碰任何 TLS/pin 逻辑。
#pragma once

#include <stdint.h>
#include <stdbool.h>

// 安装 hook（URL 改写 + 请求日志）。幂等。
void xrc_net_install(void);

// 运行期配置入口（面板/配置读取后调用）
void xrc_net_set_enabled(bool on);
void xrc_net_set_base(const char *base);     // 如 "http://192.168.1.10:8080"；空 = 不改写
void xrc_net_set_match(const char *hosts);   // 逗号分隔的需要改写的 host；空 = 用默认

bool   xrc_net_enabled(void);
// 统计
unsigned long long xrc_net_requests(void);
unsigned long long xrc_net_rewritten(void);
uint32_t xrc_net_dl_created(void);  // cocos 下载栈：建任务次数
uint32_t xrc_net_dl_done(void);     // cocos 下载栈：完结次数
