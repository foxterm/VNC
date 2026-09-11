#include "vnc_renderer.h"
#include <Accelerate/Accelerate.h>
#include <CoreGraphics/CoreGraphics.h>

static void releaseBufferCallback(void *info, const void *data, size_t size) {
  free((void *)data);
}

CGImageRef VNCCreateCGImageFromBuffer(const void *frameBuffer, int width,
                                      int height, int bitsPerPixel) {
  if (!frameBuffer || width <= 0 || height <= 0)
    return NULL;

  size_t finalSize = (size_t)width * (size_t)height * 4; // 统一转成 32 位 ARGB
  uint32_t *finalBuffer = (uint32_t *)malloc(finalSize);
  if (!finalBuffer)
    return NULL;

  if (bitsPerPixel == 32) {
    memcpy(finalBuffer, frameBuffer, finalSize);

  } else if (bitsPerPixel == 16) {
    vImage_Buffer srcBuf = {(void *)frameBuffer, (vImagePixelCount)height,
                            (vImagePixelCount)width, width * 2};
    vImage_Buffer destBuf = {finalBuffer, (vImagePixelCount)height,
                             (vImagePixelCount)width, width * 4};

    // RGB565 -> ARGB8888
    vImageConvert_RGB565toARGB8888(255, &srcBuf, &destBuf, kvImageNoFlags);

  } else if (bitsPerPixel == 8) {
    const uint8_t *src = (const uint8_t *)frameBuffer;
    uint32_t *dst = finalBuffer;
    size_t totalPixels = (size_t)width * (size_t)height;

    for (size_t i = 0; i < totalPixels; i++) {
      uint8_t pixel = src[i];
      // 提取 R3 G3 B2 并扩展到 8 bit
      uint8_t r = (pixel & 0xE0);      // R3
      uint8_t g = (pixel & 0x1C) << 3; // G3
      uint8_t b = (pixel & 0x03) << 6; // B2

      // 拼成 Little Endian BGRA/ARGB 格式 (0xFF000000 | B | G | R)
      dst[i] = (0xFF000000) | ((uint32_t)r) | ((uint32_t)g << 8) |
               ((uint32_t)b << 16);
    }
  } else {
    free(finalBuffer);
    return NULL;
  }

  CGDataProviderRef provider = CGDataProviderCreateWithData(
      NULL, finalBuffer, finalSize, releaseBufferCallback);
  if (!provider) {
    free(finalBuffer);
    return NULL;
  }

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGBitmapInfo bitmapInfo =
      kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;

  CGImageRef image =
      CGImageCreate(width, height, 8, 32, width * 4, colorSpace, bitmapInfo,
                    provider, NULL, false, kCGRenderingIntentDefault);

  CGColorSpaceRelease(colorSpace);
  CGDataProviderRelease(provider);

  return image;
}
