// FoxTerm | FrameBuffer.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import vnc_renderer

extension VNC {
    func gotFrameBufferUpdate() {
        mutex.lock()
        guard let client = rawClient,
              let frameBuffer = client.pointee.frameBuffer
        else {
            mutex.unlock()
            return
        }

        let width = client.pointee.width.int
        let height = client.pointee.height.int
        let bitsPerPixel = client.pointee.format.bitsPerPixel.int

        let cgImage = VNCCreateCGImageFromBuffer(frameBuffer, width.int32, height.int32, bitsPerPixel.int32)
        mutex.unlock()

        if let cgImage {
            vncDelegate?.buffer(vnc: self, image: cgImage)
        }
    }
}
