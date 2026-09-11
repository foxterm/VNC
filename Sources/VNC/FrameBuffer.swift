// FoxTerm | FrameBuffer.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Accelerate
import Foundation
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

extension VNC {
    /// 静态 RGB 色彩空间单例
    private static let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

    func gotFrameBufferUpdate() {
        let width: Int
        let height: Int
        let bitsPerPixel: Int
        let rawBufferData: Data

        mutex.lock()
        guard let client = rawClient,
              let frameBuffer = client.pointee.frameBuffer
        else {
            mutex.unlock()
            return
        }

        width = client.pointee.width.int
        height = client.pointee.height.int
        bitsPerPixel = client.pointee.format.bitsPerPixel.int
        let bytesPerPixel = bitsPerPixel / 8
        let bufferSize = width * height * bytesPerPixel

        rawBufferData = Data(bytes: frameBuffer, count: bufferSize)
        mutex.unlock()

        let cgImage: CGImage?
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)

        switch bitsPerPixel {
        case 32:
            cgImage = createImageFromData(rawBufferData, width: width, height: height, bitsPerPixel: 32, bitsPerComponent: 8, bitmapInfo: bitmapInfo)

        case 16:
            let rgb32Data = convertRGB565ToBGRA8888_vImage(data: rawBufferData, width: width, height: height)
            cgImage = createImageFromData(rgb32Data, width: width, height: height, bitsPerPixel: 32, bitsPerComponent: 8, bitmapInfo: bitmapInfo)

        case 8:
            let rgb32Data = convertRGB332ToBGRA8888_vImage(data: rawBufferData, width: width, height: height)
            cgImage = createImageFromData(rgb32Data, width: width, height: height, bitsPerPixel: 32, bitsPerComponent: 8, bitmapInfo: bitmapInfo)

        default:
            return
        }

        if let image = cgImage {
            vncDelegate?.buffer(vnc: self, image: image)
        }
    }

    /// 辅助方法：通过 Data 创建 CGImage
    private func createImageFromData(_ data: Data, width: Int, height: Int, bitsPerPixel: Int, bitsPerComponent: Int, bitmapInfo: CGBitmapInfo) -> CGImage? {
        let bytesPerRow = width * (bitsPerPixel / 8)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: Self.rgbColorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// 使用 Accelerate (vImage) 极速转 RGB565 -> BGRA8888
    private func convertRGB565ToBGRA8888_vImage(data: Data, width: Int, height: Int) -> Data {
        var destData = Data(count: width * height * 4)

        data.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
            destData.withUnsafeMutableBytes { (destRaw: UnsafeMutableRawBufferPointer) in
                guard let srcPtr = srcRaw.baseAddress,
                      let destPtr = destRaw.baseAddress else { return }

                var srcBuffer = vImage_Buffer(
                    data: UnsafeMutableRawPointer(mutating: srcPtr),
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width * 2
                )
                var destBuffer = vImage_Buffer(
                    data: destPtr,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width * 4
                )

                vImageConvert_RGB565toARGB8888(255, &srcBuffer, &destBuffer, vImage_Flags(kvImageNoFlags))
            }
        }
        return destData
    }

    /// 使用 Accelerate (vImage) 极速转 RGB332 -> BGRA8888 (全硬件加速，彻底解决卡死)
    private func convertRGB332ToBGRA8888_vImage(data: Data, width: Int, height: Int) -> Data {
        var destData = Data(count: width * height * 4)

        data.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
            destData.withUnsafeMutableBytes { (destRaw: UnsafeMutableRawBufferPointer) in
                guard let srcPtr = srcRaw.baseAddress,
                      let destPtr = destRaw.baseAddress else { return }

                var srcBuffer = vImage_Buffer(
                    data: UnsafeMutableRawPointer(mutating: srcPtr),
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width
                )
                var destBuffer = vImage_Buffer(
                    data: destPtr,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width * 4
                )

                // 使用 vImage 专用的 PlanarToARGB 转换 API
                vImageConvert_Planar8toARGB8888(
                    &srcBuffer, &srcBuffer, &srcBuffer, &srcBuffer,
                    &destBuffer,
                    vImage_Flags(kvImageNoFlags)
                )
            }
        }
        return destData
    }
}
