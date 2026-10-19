// FoxTerm | FrameBuffer.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
#if !COCOAPODS
import vnc_renderer
#endif
extension VNC {
    /// 从帧缓冲区提取当前画面并生成 CGImage，通过代理通知上层渲染
    ///
    /// 在每次 `FinishedFrameBufferUpdate` 回调时调用，加锁读取底层像素数据，
    /// 委托 C 层 `VNCCreateCGImageFromBuffer` 完成像素格式转换与图像构建。
    func gotFrameBufferUpdate() {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        guard let client = rawClient,
              let frameBuffer = client.pointee.frameBuffer
        else {
            return
        }

        let width = client.pointee.width.int32
        let height = client.pointee.height.int32
        let bitsPerPixel = client.pointee.format.bitsPerPixel.int32

        let cgImage = VNCCreateCGImageFromBuffer(frameBuffer, width, height, bitsPerPixel)

        if let cgImage {
            vncDelegate?.buffer(vnc: self, image: cgImage)
        }
    }
}
