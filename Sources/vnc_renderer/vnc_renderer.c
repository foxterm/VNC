#include "vnc_renderer.h"
#include <Accelerate/Accelerate.h>
#include <CoreGraphics/CoreGraphics.h>
#include <pthread.h>

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

// 预计算 256 色 RGB332 -> Little Endian BGRA/BGRX (0xAA000000 布局)
static uint32_t g_rgb332_lut[256];
static pthread_once_t g_lut_once = PTHREAD_ONCE_INIT;

static void init_rgb332_lut(void) {
  for (int i = 0; i < 256; i++) {
    // 扩展 3-bit Red 到 8-bit
    uint8_t r = (i & 0xE0);
    r |= (r >> 3) | (r >> 6);

    // 扩展 3-bit Green 到 8-bit
    uint8_t g = (i & 0x1C) << 3;
    g |= (g >> 3) | (g >> 6);

    // 扩展 2-bit Blue 到 8-bit
    uint8_t b = (i & 0x03) << 6;
    b |= (b >> 2) | (b >> 4) | (b >> 6);

    // 小端内存中的 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst 布局:
    // 字节 0: B, 字节 1: G, 字节 2: R, 字节 3: X/A
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

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGImageRef image = NULL;

  // -------------------------------------------------------------
  // 1. 32 bpp: 零拷贝直接渲染 (0ms)
  // -------------------------------------------------------------
  if (bitsPerPixel == 32) {
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, frameBuffer, (size_t)width * height * 4, NULL);
    if (provider) {
      image = CGImageCreate(width, height, 8, 32, width * 4, colorSpace,
                            kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                            provider, NULL, false, kCGRenderingIntentDefault);
      CGDataProviderRelease(provider);
    }
    CGColorSpaceRelease(colorSpace);
    return image;
  }

  size_t finalSize = (size_t)width * (size_t)height * 4;
  uint32_t *finalBuffer = (uint32_t *)malloc(finalSize);
  if (!finalBuffer) {
    CGColorSpaceRelease(colorSpace);
    return NULL;
  }

  // -------------------------------------------------------------
  // 2. 16 bpp (RGB565): 采用正统准确的 Permute 映射
  // -------------------------------------------------------------
  if (bitsPerPixel == 16) {
    vImage_Buffer srcBuf = {(void *)frameBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 2};
    vImage_Buffer destBuf = {finalBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 4};

    // Step A: Convert RGB565 -> ARGB8888
    // (输出内存字节顺序为: [A, R, G, B])
    vImageConvert_RGB565toARGB8888(255, &srcBuf, &destBuf, kvImageNoFlags);

    // Step B: 重排为 Little Endian 下正确的 BGRA/BGRX (内存字节: [B, G, R, A])
    // 映射关系: Dst[0]=Src[3](B), Dst[1]=Src[2](G), Dst[2]=Src[1](R), Dst[3]=Src[0](A)
    const uint8_t permuteMap[4] = {3, 2, 1, 0};
    vImagePermuteChannels_ARGB8888(&destBuf, &destBuf, permuteMap, kvImageNoFlags);
  }
  // -------------------------------------------------------------
  // 3. 8 bpp (RGB332): 修正 NEON 指针索引并并行转换
  // -------------------------------------------------------------
  else if (bitsPerPixel == 8) {
    pthread_once(&g_lut_once, init_rgb332_lut);
    const uint8_t *src = (const uint8_t *)frameBuffer;
    uint32_t *dst = finalBuffer;
    size_t totalPixels = (size_t)width * (size_t)height;

    size_t i = 0;
#if defined(__ARM_NEON)
    // 展开 4 像素一组提取，修正指针正确连续取值
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
    // 剩余像素处理
    for (; i < totalPixels; i++) {
      dst[i] = g_rgb332_lut[src[i]];
    }
  } else {
    free(finalBuffer);
    CGColorSpaceRelease(colorSpace);
    return NULL;
  }

  // -------------------------------------------------------------
  // 生成 CGImageRef
  // -------------------------------------------------------------
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
