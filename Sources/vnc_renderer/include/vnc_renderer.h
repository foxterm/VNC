#ifndef VNC_RENDERER_H
#define VNC_RENDERER_H

#include <CoreGraphics/CoreGraphics.h>
#include <rfb/rfbproto.h>

// 还原图片
CGImageRef VNCCreateCGImageFromBuffer(const void *frameBuffer, int width, int height, 
                                       const rfbPixelFormat *serverFormat, 
                                       const rfbPixelFormat *clientFormat) CF_RETURNS_RETAINED;

#endif /* VNC_RENDERER_H */
