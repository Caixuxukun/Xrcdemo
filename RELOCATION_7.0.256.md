# Arcaea 7.0.256 地址重定位记录

本包是**静态适配候选源码**，不是已验证可安装的 IPA。未修改提供的原始 IPA；未包含游戏二进制或编译好的 dylib。

## 样本与证据范围

- 版本：7.0.256；构建：1209864；包名：moe.low.arc。
- 主程序 SHA-256：`fb91157e7c90ede63be3d0051ed2208dcc600c64e1ca53ffece25d267345416f`。
- Mach-O UUID：`FFA7AD7B-FEFE-3E87-BF28-0F99D6701FD9`；arm64；cryptid=0。
- 上游：[XingChenRS/Xrcdemo ios 分支](https://github.com/XingChenRS/Xrcdemo/tree/3d9f789313924f3b7ac6b184ea8c06251a6c564b)，以该提交为基线。
- 没有 7.0.255 原始主程序，旧地址及语义来自源码。新版依据 RTTI/虚表、字符串引用、函数边界、调用关系及反汇编定位；未做两版逐字节函数差分。
- 已同步 110 个不同地址映射，包含 40 个 BRK 站点、重放位置、判定/音频/虚表、分支目标及 profile 外的回放地址。完整数据见 `relocation.json`。

## 原先输出为何误报

旧脚本只要入口前 4 字节不等于旧版 STP，就输出 PATCHED，没有核对 ADRP/ADD/BR。
实际在这个样本的旧地址 `0x10091E684`，指令为 `ff010071`（`cmp w15,#0`），不是注入跳转。
新版只读检查核对目标 UUID、完整入口跳转、完整 v2 跳板和站点原字节。此样本结果是入口 original、BRK 0/40、dylib 缺失；不能据旧输出认定已注入。

## 核心定位

| 项目 | 新版 VA | 定位依据 |
|---|---|---|
| 判定核心 | `0x100920788` | 入口指纹、26/51/101/121 与 25/50/100/120 两组阈值；2 个直接调用点 |
| grade 落账 | `0x100ACDFA8` | 判定核心 Pure/Far 路径的 BL 目标 |
| 长条/近失落账 | `0x100ACDDCC` | 判定核心末级阈值分支的 BL 目标 |
| GameScene vptr | `0x101521DC0` | 9GameScene RTTI→typeinfo→主虚表 |
| GameScene 更新 | `0x100CAA7C0` | 主虚表槽 103 |
| 音频 vptr | `0x1014BB930` | 20AudioProviderFMODiOS RTTI |
| 音频 getpos | `0x1008E4274` | 音频虚表槽 7，内调 Channel::getPosition |
| Arc/Hold vptr | `0x1014A03A0` / `0x1014BBD00` | 对应 LogicArcNote/LogicHoldNote RTTI |
| OnlineManager vptr | `0x1014A0490` | 13OnlineManager RTTI |
| applog 发送 | `0x1006257DC` | OnlineManager 虚表槽 72，与 log_blob 引用同函数 |
| FMOD 全局对象 | `0x101652A78` | 音频构造过程传入创建函数的出参地址，后续多处读取 |
| 回放事件全局 | `0x1016781D8` | hold 被触函数和 note 注册函数的共同全局读取 |

八个判定阈值地址依次为：`0x100920824`、`0x10092082C`、`0x100920834`、`0x10092083C`、`0x10092088C`、`0x1009208D0`、`0x100920914`、`0x10092094C`。

FMOD 函数通过各自 `Channel::...` / `DSP::...` / `System::...` 调试串交叉引用，再由 LC_FUNCTION_STARTS 回查函数入口；没有把字符串引用点当入口。

## 无法直接沿用旧注入布局

- 新版 TEXT 填充可用，判定跳板为 VA/文件偏移 `0x10146C00C` / `0x146C00C`。
- DATA 中从 `0x164EF25` 开始的连续零字节仍属于 Swift hook 节；后面还有 BSS。**零字节不等于可占用空间**。已放弃把 slot 放在 `0x164EF28` 的初步候选。
- 本候选源码新增独立 `__XRC` 段，RW、16 KiB，VA `0x1016A8000`、文件偏移 `0x1650000`。
- slot：VA `0x1016A8000`、文件偏移 `0x1650000`；info：VA `0x1016A8018`、文件偏移 `0x1650018`。此处 **VA−image_base 不等于文件偏移**。
- LINKEDIT 的 VA/文件偏移分别移到 `0x1016AC000` / `0x1654000`；所有涉及的 load command 文件偏移同步调整。原 LINKEDIT 数据整体原样保留。
- 原 TEXT/DATA 段与全部原节的虚拟地址不变；原 rebase/bind 的 TEXT/DATA 段索引不变，解析检查拒绝引用被移动 LINKEDIT 的异常流。
- 运行时锚点改为扫描 `__XRC`，不能混用上游旧 dylib。新增精确 profile 标识检查，并修正 `LC_LOAD_DYLIB` 为标准 `0x0C`。
- 重布局和打桩都会使原签名失效，必须重新签名。尚未验证重签工具与真机 dyld 对本候选的接受情况。

## 指令差异与同步文件

`unlock_l1` 新址 `0x100BE70BC` 的指令是 `09c441f9`，即 `LDR X9,[X0,#0x388]`；旧源码 expect 为 `093441f9`（+0x268）。已更新 expect，并由注入器生成正确重放。
这证明“按统一差值搬地址、保持旧 expect”不可行；由于缺少旧二进制，不能断言该差异一定由这次升级引入，也可能是旧源码记录不准确。

变更文件：`inject.py`、`XRCProfile.h`、`XRCHook.m`、`XRCRuntime.m`、`XRCReplay.m`、`XRCProbe.m`。
其中回放模块的五处直接地址及诊断模块跳板地址也已同步；只改 Profile 不够。
源码保留了一部分上游历史语义注释，当前地址以宏、常量和本记录为准。

## 40 个站点

下表地址都是未加 ASLR slide 的 VA；`expected` 为小端文件字节。

| 名称 | 7.0.255 源码地址 | 7.0.256 静态定位 | expected |
|---|---|---|---|
| applog_send | `0x100623aec` | `0x1006257dc` | `eb2bb86d` |
| applog_blob | `0x1006399e4` | `0x10063b6d4` | `e0a30791` |
| unlock_l1 | `0x100be46ac` | `0x100be70bc` | `09c441f9` |
| unlock_l2 | `0x100be46ec` | `0x100be70fc` | `ff0302d1` |
| unlock_l3 | `0x100be4d38` | `0x100be7748` | `fd7bbfa9` |
| cb_ready | `0x100f43274` | `0x100f463d4` | `00a04039` |
| cb_filehash | `0x100f44f9c` | `0x100f480fc` | `21110054` |
| cb_listhash | `0x100f450b0` | `0x100f48210` | `21090054` |
| cb_wipe | `0x100f43c08` | `0x100f46d68` | `ffc301d1` |
| cb_dispatch | `0x10013c5e8` | `0x10013e2a4` | `ff0304d1` |
| cb_gate | `0x1001963d8` | `0x1001980c8` | `ffc303d1` |
| cb_fetch | `0x100815498` | `0x1008171b8` | `ffc306d1` |
| ap_ln_state | `0x10091dbc8` | `0x10091fccc` | `08904139` |
| ap_ln_tick | `0x10091dc48` | `0x10091fd4c` | `680340f9` |
| ap_note_win | `0x10091dd70` | `0x10091fe74` | `5f00086b` |
| ap_arctap_win | `0x10091df34` | `0x100920038` | `5f00086b` |
| ap_swallow_judge | `0x10091ebc8` | `0x100920ccc` | `ffc305d1` |
| ap_swallow_batch | `0x10091f688` | `0x10092178c` | `ff8302d1` |
| ap_swallow_touch | `0x100921dc4` | `0x100923ec8` | `ff0302d1` |
| ap_arc_visual | `0x10091cc84` | `0x10091ed88` | `1f200079` |
| ap_tickcnt1 | `0x10091dcbc` | `0x10091fdc0` | `fa0300aa` |
| ap_tickcnt2 | `0x10091ddbc` | `0x10091fec0` | `fa0300aa` |
| lock_fv | `0x100991508` | `0x100993668` | `f44fbea9` |
| lock_do | `0x100aae50c` | `0x100ab0958` | `ff4303d1` |
| fv_gate | `0x10099156c` | `0x1009936cc` | `ff0303d1` |
| chain_prog | `0x10098fb1c` | `0x100991c7c` | `ffc302d1` |
| lock_all | `0x100919e5c` | `0x10091bf60` | `ffc302d1` |
| play_gate | `0x100919874` | `0x10091b978` | `ff8301d1` |
| dl_play | `0x100850308` | `0x10085205c` | `f657bda9` |
| cond_unlock_a | `0x100bdc5a8` | `0x100bdefb8` | `ff4302d1` |
| cond_unlock_b | `0x100bdc8d4` | `0x100bdf2e4` | `ff8301d1` |
| jacket_lock | `0x10084ef48` | `0x100850c9c` | `a00800b7` |
| jacket_cell | `0x1008eafb4` | `0x1008ecd38` | `480100b7` |
| jacket_info | `0x10094a57c` | `0x10094c680` | `000100b7` |
| jacket_panel | `0x100b3f274` | `0x100b41a18` | `980100b6` |
| rpf_draw | `0x100b23668` | `0x100b25e0c` | `eb2b056d` |
| rpf_arctick | `0x100affc14` | `0x100b0233c` | `ed33016d` |
| rpf_arcpass | `0x100affa94` | `0x100b021bc` | `eb2b026d` |
| arc_hide_a | `0x100affb60` | `0x100b02288` | `01008052` |
| arc_hide_b | `0x100affe80` | `0x100b025a8` | `01008052` |

## 验证结果与复现

- 17 项静态检查通过：原样本识别、错误 UUID/未知入口拒绝、40 站点打桩和还原、回跳地址、损坏跳板检测、存储区互不重叠、profile 同步、LINKEDIT 完整保存、新增段幂等。
- 独立 LIEF 1.0.0 布局检查：原文件与模拟产物均有效；2052 个符号、16963 条绑定、159533 条重定位、37245 个 LIEF 函数条目及全部原节信息保持一致。
- Python 注入器语法检查通过。测试只在内存/临时副本进行，未修改原 IPA。
- **尚未进行**：Theos/iOS 编译、dylib ABI 运行验证、签名安装、真机启动、改判/自动演奏/回放/音频/内容功能回归。所有静态定位不等于功能已可用。

在源码目录运行（只读原文件）：

```text
python verify_70256.py "path/to/moe.low.arc-7.0.256-Decrypted.ipa"
python inject.py --check "path/to/Arc-mobile"
```

验证脚本只需要 Python 标准库；安装 `lief` 后会追加独立解析验证。`--check` 接收解包后的主程序，不直接接收 IPA。
后续构建需要 Theos 和 iOS SDK。请使用本包源码重新构建 `libxrcdemo.dylib`；旧版预编译 dylib 会被 profile 配对检查拒绝。此交付没有声称已经生成可用 dylib 或安装包。
