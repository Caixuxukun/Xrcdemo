// © 雾月星辰 & MLXC · github@XingChenRS
// XRCTheme.m — 素材 / 字体 / 量纲实现（说明见 XRCTheme.h）。
#import "XRCTheme.h"
#import <CoreText/CoreText.h>
#import "XRCLog.h"

CGFloat xrc_theme_scale(void) {
    static CGFloat s = 0;
    if (s <= 0) {
        CGRect b = [UIScreen mainScreen].bounds;
        CGFloat w = MAX(b.size.width, b.size.height);   // 横屏锁定时取长边
        s = w / 852.0;
    }
    return s;
}

static void s_register_font(const char *rel, unsigned long long *done, const char *what) {
    NSString *path = [[[NSBundle mainBundle] bundlePath]
                         stringByAppendingPathComponent:@(rel)];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        xrc_logd(XRCLC_UI, @"[theme] 字体缺失：%s（回退系统字体）", what);
        return;
    }
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CFErrorRef err = NULL;
    if (!CTFontManagerRegisterFontsForURL(url, kCTFontManagerScopeProcess, &err)) {
        xrc_logd(XRCLC_UI, @"[theme] 字体注册失败：%s", what);
    }
    *done += 1;
}

void xrc_theme_ensure_fonts(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unsigned long long n = 0;
        s_register_font("Fonts/Exo-Light.ttf", &n, "Exo-Light");
        s_register_font("Fonts/Exo-Regular.ttf", &n, "Exo-Regular");
        s_register_font("Fonts/Exo-Medium.ttf", &n, "Exo-Medium");
        s_register_font("Fonts/Exo-SemiBold.ttf", &n, "Exo-DemiBold");
        s_register_font("Fonts/L2-Light.ttf", &n, "L2-Light");
        s_register_font("Fonts/L2-Regular.ttf", &n, "L2-Regular");
        s_register_font("Fonts/L2-Semibold.ttf", &n, "L2-Semibold");
        s_register_font("Fonts/GeosansLight.ttf", &n, "GeosansLight");
        s_register_font("Fonts/NotoSansCJKsc-Light.otf", &n, "NotoSC-Light");
        s_register_font("Fonts/NotoSansCJKsc-Regular.otf", &n, "NotoSC-Regular");
        s_register_font("Fonts/NotoSansCJKsc-Bold.otf", &n, "NotoSC-Bold");
        xrc_logi(XRCLC_UI, @"[theme] 包内字体注册 %llu/11", n);
    });
}

UIFont *xrc_theme_font(NSString *psName, CGFloat designPx) {
    xrc_theme_ensure_fonts();
    UIFont *f = [UIFont fontWithName:psName size:xrc_theme_px(designPx)];
    return f ?: [UIFont systemFontOfSize:xrc_theme_px(designPx)];
}

// 素材缓存（相对路径 → UIImage，scale=1.5）
static NSMutableDictionary<NSString *, UIImage *> *s_img_cache(void) {
    static NSMutableDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary dictionary]; });
    return d;
}

UIImage *xrc_theme_img(NSString *relPath) {
    if (!relPath.length) return nil;
    UIImage *cached = s_img_cache()[relPath];
    if (cached) return cached == (UIImage *)[NSNull null] ? nil : cached;
    NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:relPath];
    UIImage *raw = [UIImage imageWithContentsOfFile:path];
    UIImage *out = nil;
    if (raw.CGImage) {
        // 素材为 1.5× 类导出：以 scale=1.5 还原，size 即设计点
        out = [[UIImage alloc] initWithCGImage:raw.CGImage scale:1.5 orientation:UIImageOrientationUp];
    } else {
        xrc_logd(XRCLC_UI, @"[theme] 素材缺失：%@", relPath);
    }
    s_img_cache()[relPath] = out ?: (UIImage *)[NSNull null];
    return out;
}

UIImage *xrc_theme_img9(NSString *relPath, CGFloat lPx, CGFloat tPx, CGFloat rPx, CGFloat bPx) {
    UIImage *im = xrc_theme_img(relPath);
    if (!im) return nil;
    return [im resizableImageWithCapInsets:UIEdgeInsetsMake(tPx / 1.5, lPx / 1.5, bPx / 1.5, rPx / 1.5)];
}

UIImage *xrc_theme_img9_crop(NSString *relPath, CGRect cropPx,
                             CGFloat lPx, CGFloat tPx, CGFloat rPx, CGFloat bPx) {
    if (!relPath.length) return nil;
    NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:relPath];
    UIImage *raw = [UIImage imageWithContentsOfFile:path];
    if (!raw.CGImage) {
        xrc_logd(XRCLC_UI, @"[theme] 素材缺失：%@", relPath);
        return nil;
    }
    CGImageRef sub = CGImageCreateWithImageInRect(raw.CGImage, cropPx);
    if (!sub) return nil;
    UIImage *im = [[UIImage alloc] initWithCGImage:sub scale:1.5 orientation:UIImageOrientationUp];
    CGImageRelease(sub);
    return [im resizableImageWithCapInsets:UIEdgeInsetsMake(tPx / 1.5, lPx / 1.5, bPx / 1.5, rPx / 1.5)];
}
