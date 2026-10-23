#include "vnc_renderer.h"
#include <Accelerate/Accelerate.h>
#include <CoreGraphics/CoreGraphics.h>
#include <pthread.h>
#import <TargetConditionals.h>

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

// 预计算 256 色 RGB332 -> Little Endian BGRA/BGRX
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

CGImageRef VNCCreateCGImageFromBuffer(const void *frameBuffer, int width, int height, int bitsPerPixel) {
  if (!frameBuffer || width <= 0 || height <= 0)
    return NULL;

  // 显式使用 sRGB 色域
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  if (!colorSpace) {
    colorSpace = CGColorSpaceCreateDeviceRGB();
  }

  CGImageRef image = NULL;

  // -------------------------------------------------------------
  // 1. 32 bpp
  // -------------------------------------------------------------
  if (bitsPerPixel == 32) {
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
    // 【iOS 专有逻辑】：把服务器的 ARGB 完美转为 CGImage 需要的 BGRA
    size_t finalSize = (size_t)width * (size_t)height * 4;
    uint32_t *finalBuffer = (uint32_t *)malloc(finalSize);
    if (!finalBuffer) {
      CGColorSpaceRelease(colorSpace);
      return NULL;
    }

    vImage_Buffer srcBuf = {(void *)frameBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 4};
    vImage_Buffer destBuf = {finalBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 4};

    // ARGB -> BGRA 的准确通道映射
    const uint8_t permuteMap[4] = {3, 2, 1, 0};
    vImagePermuteChannels_ARGB8888(&srcBuf, &destBuf, permuteMap, kvImageNoFlags);

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, finalBuffer, finalSize, releaseBufferCallback);
    if (!provider) {
      free(finalBuffer);
      CGColorSpaceRelease(colorSpace);
      return NULL;
    }

    image = CGImageCreate(width, height, 8, 32, width * 4, colorSpace,
                          kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                          provider, NULL, false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return image;

#else
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, frameBuffer, (size_t)width * height * 4, NULL);
    if (provider) {
      image = CGImageCreate(width, height, 8, 32, width * 4, colorSpace,
                            kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                            provider, NULL, false, kCGRenderingIntentDefault);
      CGDataProviderRelease(provider);
    }
    CGColorSpaceRelease(colorSpace);
    return image;
#endif
  }

  // -------------------------------------------------------------
  // 2. 16 bpp & 3. 8 bpp (保持原样)
  // -------------------------------------------------------------
  size_t finalSize = (size_t)width * (size_t)height * 4;
  uint32_t *finalBuffer = (uint32_t *)malloc(finalSize);
  if (!finalBuffer) {
    CGColorSpaceRelease(colorSpace);
    return NULL;
  }

  if (bitsPerPixel == 16) {
    vImage_Buffer srcBuf = {(void *)frameBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 2};
    vImage_Buffer destBuf = {finalBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 4};

    vImageConvert_RGB565toARGB8888(255, &srcBuf, &destBuf, kvImageNoFlags);

    const uint8_t permuteMap[4] = {3, 2, 1, 0};
    vImagePermuteChannels_ARGB8888(&destBuf, &destBuf, permuteMap, kvImageNoFlags);
  }
  else if (bitsPerPixel == 8) {
    pthread_once(&g_lut_once, init_rgb332_lut);
    const uint8_t *src = (const uint8_t *)frameBuffer;
    uint32_t *dst = finalBuffer;
    size_t totalPixels = (size_t)width * (size_t)height;

    size_t i = 0;
#if defined(__ARM_NEON)
    for (; i + 3 < totalPixels; i += 4) {
      uint32x4_t v = {
        g_rgb332_lut[src[i + 0]],
        g_rgb332_lut[src[i + 1]],
        g_rgb332_lut[src[i + 2]],
        g_rgb332_lut[src[i + 3]]
      };
      vst1q_u32(&dst[i], v);
    }
#endif
    for (; i < totalPixels; i++) {
      dst[i] = g_rgb332_lut[src[i]];
    }
  } else {
    free(finalBuffer);
    CGColorSpaceRelease(colorSpace);
    return NULL;
  }

  CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, finalBuffer, finalSize, releaseBufferCallback);
  if (!provider) {
    free(finalBuffer);
    CGColorSpaceRelease(colorSpace);
    return NULL;
  }

  image = CGImageCreate(width, height, 8, 32, width * 4, colorSpace,
                        kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                        provider, NULL, false, kCGRenderingIntentDefault);

  CGColorSpaceRelease(colorSpace);
  CGDataProviderRelease(provider);

  return image;
}
