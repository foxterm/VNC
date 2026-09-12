// FoxTerm | FrameBuffer.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import vnc_renderer

extension VNC {
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
