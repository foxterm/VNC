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

  int bytesPerPixel = bitsPerPixel / 8;
  size_t srcSize = width * height * bytesPerPixel;

  void *finalBuffer = NULL;
  size_t finalBitsPerPixel = bitsPerPixel;
  size_t finalBytesPerRow = width * bytesPerPixel;
  size_t finalSize = srcSize;

  if (bitsPerPixel == 32) {
    // 32 位直接一次 malloc 深拷贝，绝不多做二次转换
    finalBuffer = malloc(srcSize);
    if (!finalBuffer)
      return NULL;
    memcpy(finalBuffer, frameBuffer, srcSize);

  } else if (bitsPerPixel == 16) {
    // RGB565 -> ARGB8888：直接分配目标 32 位空间，单次转换写入，避免二次 memcpy
    finalSize = width * height * 4;
    finalBuffer = malloc(finalSize);
    if (!finalBuffer)
      return NULL;

    vImage_Buffer srcBuf = {(void *)frameBuffer, (vImagePixelCount)height,
                            (vImagePixelCount)width, width * 2};
    vImage_Buffer destBuf = {finalBuffer, (vImagePixelCount)height,
                             (vImagePixelCount)width, width * 4};

    vImageConvert_RGB565toARGB8888(255, &srcBuf, &destBuf, kvImageNoFlags);

    finalBitsPerPixel = 32;
    finalBytesPerRow = width * 4;

  } else if (bitsPerPixel == 8) {
    // RGB332 -> ARGB8888：补充 8 位支持
    finalSize = width * height * 4;
    finalBuffer = malloc(finalSize);
    if (!finalBuffer)
      return NULL;

    vImage_Buffer srcBuf = {(void *)frameBuffer, (vImagePixelCount)height,
                            (vImagePixelCount)width, width};
    vImage_Buffer destBuf = {finalBuffer, (vImagePixelCount)height,
                             (vImagePixelCount)width, width * 4};

    vImageConvert_Planar8toARGB8888(&srcBuf, &srcBuf, &srcBuf, &srcBuf,
                                    &destBuf, kvImageNoFlags);

    finalBitsPerPixel = 32;
    finalBytesPerRow = width * 4;
  } else {
    return NULL;
  }

  // 构建 CGDataProvider
  CGDataProviderRef provider = CGDataProviderCreateWithData(
      NULL, finalBuffer, finalSize, releaseBufferCallback);
  if (!provider) {
    free(finalBuffer);
    return NULL;
  }

  // 创建 CGImage
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGBitmapInfo bitmapInfo =
      kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;

  CGImageRef image = CGImageCreate(
      width, height, 8, finalBitsPerPixel, finalBytesPerRow, colorSpace,
      bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);

  CGColorSpaceRelease(colorSpace);
  CGDataProviderRelease(provider);

  return image;
}
