#ifndef VNC_RENDERER_H
#define VNC_RENDERER_H

#include <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern "C" {
#endif

// 添加 CF_RETURNS_RETAINED 宏告诉 Swift ARC 自动接管内存
CGImageRef VNCCreateCGImageFromBuffer(const void *frameBuffer, int width,
                                      int height,
                                      int bitsPerPixel) CF_RETURNS_RETAINED;

#ifdef __cplusplus
}
#endif

#endif /* VNC_RENDERER_H */
