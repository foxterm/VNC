#include "vnc_renderer.h"
#include <Accelerate/Accelerate.h>
#include <CoreGraphics/CoreGraphics.h>
#include <pthread.h>

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

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

static inline uint32_t swap32(uint32_t v) {
  return ((v >> 24) & 0xFF) | ((v >> 8) & 0xFF00) | ((v << 8) & 0xFF0000) | ((v << 24) & 0xFF000000);
}

static inline uint16_t swap16(uint16_t v) {
  return (v >> 8) | (v << 8);
}

static void convert32to32(const uint32_t *src, uint32_t *dst, size_t totalPixels,
                          const rfbPixelFormat *srcFmt, const rfbPixelFormat *dstFmt) {
  uint32_t srcRedMax = srcFmt->redMax;
  uint32_t srcGreenMax = srcFmt->greenMax;
  uint32_t srcBlueMax = srcFmt->blueMax;
  uint8_t srcRedShift = srcFmt->redShift;
  uint8_t srcGreenShift = srcFmt->greenShift;
  uint8_t srcBlueShift = srcFmt->blueShift;
  int srcBigEndian = srcFmt->bigEndian;

  uint32_t dstRedMax = dstFmt->redMax;
  uint32_t dstGreenMax = dstFmt->greenMax;
  uint32_t dstBlueMax = dstFmt->blueMax;
  uint8_t dstRedShift = dstFmt->redShift;
  uint8_t dstGreenShift = dstFmt->greenShift;
  uint8_t dstBlueShift = dstFmt->blueShift;

  for (size_t i = 0; i < totalPixels; i++) {
    uint32_t pixel = src[i];
    if (srcBigEndian) pixel = swap32(pixel);

    uint32_t r = ((pixel >> srcRedShift) & srcRedMax);
    uint32_t g = ((pixel >> srcGreenShift) & srcGreenMax);
    uint32_t b = ((pixel >> srcBlueShift) & srcBlueMax);

    if (srcRedMax != dstRedMax) r = r * dstRedMax / srcRedMax;
    if (srcGreenMax != dstGreenMax) g = g * dstGreenMax / srcGreenMax;
    if (srcBlueMax != dstBlueMax) b = b * dstBlueMax / srcBlueMax;

    uint32_t outPixel = (r << dstRedShift) | (g << dstGreenShift) | (b << dstBlueShift);
    if (dstFmt->bigEndian) outPixel = swap32(outPixel);

    dst[i] = outPixel;
  }
}

static void convert16to32(const uint16_t *src, uint32_t *dst, size_t totalPixels,
                          const rfbPixelFormat *srcFmt, const rfbPixelFormat *dstFmt) {
  uint32_t srcRedMax = srcFmt->redMax;
  uint32_t srcGreenMax = srcFmt->greenMax;
  uint32_t srcBlueMax = srcFmt->blueMax;
  uint8_t srcRedShift = srcFmt->redShift;
  uint8_t srcGreenShift = srcFmt->greenShift;
  uint8_t srcBlueShift = srcFmt->blueShift;
  int srcBigEndian = srcFmt->bigEndian;

  uint32_t dstRedMax = dstFmt->redMax;
  uint32_t dstGreenMax = dstFmt->greenMax;
  uint32_t dstBlueMax = dstFmt->blueMax;
  uint8_t dstRedShift = dstFmt->redShift;
  uint8_t dstGreenShift = dstFmt->greenShift;
  uint8_t dstBlueShift = dstFmt->blueShift;

  for (size_t i = 0; i < totalPixels; i++) {
    uint16_t pixel = src[i];
    if (srcBigEndian) pixel = swap16(pixel);

    uint32_t r = ((pixel >> srcRedShift) & srcRedMax);
    uint32_t g = ((pixel >> srcGreenShift) & srcGreenMax);
    uint32_t b = ((pixel >> srcBlueShift) & srcBlueMax);

    if (srcRedMax != dstRedMax) r = r * dstRedMax / srcRedMax;
    if (srcGreenMax != dstGreenMax) g = g * dstGreenMax / srcGreenMax;
    if (srcBlueMax != dstBlueMax) b = b * dstBlueMax / srcBlueMax;

    uint32_t outPixel = (r << dstRedShift) | (g << dstGreenShift) | (b << dstBlueShift);
    if (dstFmt->bigEndian) outPixel = swap32(outPixel);

    dst[i] = outPixel;
  }
}

CGImageRef VNCCreateCGImageFromBuffer(const void *frameBuffer, int width, int height,
                                       const rfbPixelFormat *serverFormat,
                                       const rfbPixelFormat *clientFormat) {
  if (!frameBuffer || width <= 0 || height <= 0 || !serverFormat || !clientFormat)
    return NULL;

  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  CGImageRef image = NULL;
  size_t totalPixels = (size_t)width * (size_t)height;

  int serverBpp = serverFormat->bitsPerPixel;
  int clientBpp = clientFormat->bitsPerPixel;

  int formatsMatch = (serverBpp == clientBpp &&
                      serverFormat->redShift == clientFormat->redShift &&
                      serverFormat->greenShift == clientFormat->greenShift &&
                      serverFormat->blueShift == clientFormat->blueShift &&
                      serverFormat->redMax == clientFormat->redMax &&
                      serverFormat->greenMax == clientFormat->greenMax &&
                      serverFormat->blueMax == clientFormat->blueMax &&
                      serverFormat->bigEndian == clientFormat->bigEndian);

  // -------------------------------------------------------------
  // 1. 32 bpp: 格式匹配时零拷贝直接渲染
  // -------------------------------------------------------------
  if (serverBpp == 32 && formatsMatch) {
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, frameBuffer, totalPixels * 4, NULL);
    if (provider) {
      image = CGImageCreate(width, height, 8, 32, width * 4, colorSpace,
                            kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                            provider, NULL, false, kCGRenderingIntentDefault);
      CGDataProviderRelease(provider);
    }
    CGColorSpaceRelease(colorSpace);
    return image;
  }

  size_t finalSize = totalPixels * 4;
  uint32_t *finalBuffer = (uint32_t *)malloc(finalSize);
  if (!finalBuffer) {
    CGColorSpaceRelease(colorSpace);
    return NULL;
  }

  // -------------------------------------------------------------
  // 2. 32 bpp: 格式不匹配时需要转换
  // -------------------------------------------------------------
  if (serverBpp == 32) {
    convert32to32((const uint32_t *)frameBuffer, finalBuffer, totalPixels, serverFormat, clientFormat);
  }
  // -------------------------------------------------------------
  // 3. 16 bpp: 格式匹配时使用 vImage 快速转换
  // -------------------------------------------------------------
  else if (serverBpp == 16 && formatsMatch) {
    vImage_Buffer srcBuf = {(void *)frameBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 2};
    vImage_Buffer destBuf = {finalBuffer, (vImagePixelCount)height, (vImagePixelCount)width, width * 4};
    vImageConvert_RGB565toARGB8888(255, &srcBuf, &destBuf, kvImageNoFlags);
    const uint8_t permuteMap[4] = {3, 2, 1, 0};
    vImagePermuteChannels_ARGB8888(&destBuf, &destBuf, permuteMap, kvImageNoFlags);
  }
  // -------------------------------------------------------------
  // 4. 16 bpp: 格式不匹配时通用转换
  // -------------------------------------------------------------
  else if (serverBpp == 16) {
    convert16to32((const uint16_t *)frameBuffer, finalBuffer, totalPixels, serverFormat, clientFormat);
  }
  // -------------------------------------------------------------
  // 5. 8 bpp (RGB332): LUT 快速转换
  // -------------------------------------------------------------
  else if (serverBpp == 8) {
    pthread_once(&g_lut_once, init_rgb332_lut);
    const uint8_t *src = (const uint8_t *)frameBuffer;
    size_t i = 0;
#if defined(__ARM_NEON)
    for (; i + 3 < totalPixels; i += 4) {
      uint32x4_t v = {
        g_rgb332_lut[src[i + 0]],
        g_rgb332_lut[src[i + 1]],
        g_rgb332_lut[src[i + 2]],
        g_rgb332_lut[src[i + 3]]
      };
      vst1q_u32(&finalBuffer[i], v);
    }
#endif
    for (; i < totalPixels; i++) {
      finalBuffer[i] = g_rgb332_lut[src[i]];
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
