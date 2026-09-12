#include "vnc_renderer.h"
#include <Accelerate/Accelerate.h>
#include <CoreGraphics/CoreGraphics.h>
#include <pthread.h>

// 预计算 256 色 RGB332 -> Little Endian BGRX
static uint32_t g_rgb332_lut[256];
static pthread_once_t g_lut_once = PTHREAD_ONCE_INIT;

static void init_rgb332_lut(void) {
  for (int i = 0; i < 256; i++) {
    uint8_t r = (i & 0xE0);
    r |= (r >> 3) | (r >> 6);
    uint8_t g = (i & 0x1C) << 3;
    g |= (g >> 3) | (g >> 6);
    uint8_t b = (i & 0x03) << 6;
    b |= (b >> 2) | (b >> 4) | (b >> 6);

    uint8_t *bytes = (uint8_t *)&g_rgb332_lut[i];
    bytes[0] = b;
    bytes[1] = g;
    bytes[2] = r;
    bytes[3] = 0xFF;
  }
}

static void releaseBufferCallback(void *info, const void *data, size_t size) {
  free((void *)data);
}

CGImageRef VNCCreateCGImageFromBuffer(const void *frameBuffer, int width,
                                      int height, int bitsPerPixel) {
  if (!frameBuffer || width <= 0 || height <= 0)
    return NULL;

  size_t finalSize = (size_t)width * (size_t)height * 4;
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

    // 1. RGB565 -> ARGB8888
    vImageConvert_RGB565toARGB8888(255, &srcBuf, &destBuf, kvImageNoFlags);

    // 2. 16 位转换出来的 ARGB 需要重排为小端序 BGRA
    const uint8_t permuteMap[4] = {3, 2, 1, 0};
    vImagePermuteChannels_ARGB8888(&destBuf, &destBuf, permuteMap,
                                   kvImageNoFlags);
  } else if (bitsPerPixel == 8) {
    pthread_once(&g_lut_once, init_rgb332_lut);
    const uint8_t *src = (const uint8_t *)frameBuffer;
    uint32_t *dst = finalBuffer;
    size_t totalPixels = (size_t)width * (size_t)height;

    for (size_t i = 0; i < totalPixels; i++) {
      dst[i] = g_rgb332_lut[src[i]];
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
