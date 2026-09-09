// FoxTerm | Callbacks.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import AudioToolbox
import Extension
import Foundation
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

import libvncclient

extension VNC {
    func setupCallbacks(client: UnsafeMutablePointer<rfbClient>) {
        // 绑定 self 到 clientData
        // 赋值

        let node = UnsafeMutablePointer<rfbClientData>.allocate(capacity: 1)
        node.pointee.tag = nil
        node.pointee.data = Unmanaged.passUnretained(self).toOpaque() // self 存在 data 里
        node.pointee.next = nil
        client.pointee.clientData = node
        //  client.pointee.clientData = Unmanaged.passUnretained(self).toOpaque().assumingMemoryBound(to: rfbClientData.self)

//        client.pointee.MallocFrameBuffer = { client in
//            print("😯😯😯😯😯😯😯😯")
//            guard let client, let dataPtr = client.pointee.clientData else { return 0 }
//            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
//
//            let width = Int(client.pointee.width)
//            let height = Int(client.pointee.height)
//            let bitsPerPixel = Int(client.pointee.format.bitsPerPixel)
//            let bytesPerPixel = bitsPerPixel / 8
//            let bufferSize = width * height * bytesPerPixel
//
//            // 1. Free existing buffer if resizing
//            if client.pointee.frameBuffer != nil {
//                free(client.pointee.frameBuffer)
//            }
//
//            // 2. Allocate memory using standard C malloc
//            guard let newBuffer = malloc(bufferSize) else {
//                return 0 // Allocation failed
//            }
//            client.pointee.frameBuffer = UnsafeMutablePointer<UInt8>(OpaquePointer(newBuffer))
//
//            // 3. Sync pixel format and encodings with the server
//            SetFormatAndEncodings(client)
//
//            // 4. Notify delegate of desktop size
//            vnc.handleDesktopSizeChange(width: width, height: height)
//
//            // 5. Request the initial full-screen update
//            SendFramebufferUpdateRequest(client, 0, 0, width.int32, height.int32, 0)
//
//            return 1 // Return 1 for success
//        }

        // 1. 纯密码认证回调
        client.pointee.GetPassword = { client in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return nil }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()

            return vnc.providePassword()
        }

        // 2. 账号+密码认证回调
        client.pointee.GetCredential = { client, credType in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return nil }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()

            return vnc.provideCredential(type: credType)
        }

        // 3. 图像帧更新回调
        client.pointee.GotFrameBufferUpdate = { client, x, y, w, h in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            vnc.handleFrameBufferUpdate(x: x.int, y: y.int, width: w.int, height: h.int)
        }

        // 4. 剪贴板文本回调 (ISO-Latin1)
        client.pointee.GotXCutText = { client, text, textlen in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            let str = String(bytes: UnsafeBufferPointer(start: UnsafePointer<UInt8>(OpaquePointer(text)), count: Int(textlen)), encoding: .isoLatin1) ?? ""
            vnc.handleXCutText(str)
        }

        // 5. 剪贴板文本回调 (UTF-8)
        client.pointee.GotXCutTextUTF8 = { client, text, textlen in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            let str = String(bytes: UnsafeBufferPointer(start: UnsafePointer<UInt8>(OpaquePointer(text)), count: Int(textlen)), encoding: .utf8) ?? ""
            vnc.handleXCutText(str)
        }

        // 6. 聊天文本回调
        client.pointee.HandleTextChat = { client, value, text in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            let message = text.map { String(cString: $0) } ?? ""
            vnc.handleTextChat(code: Int(value), message: message)
        }

        // 7. 响铃提示回调
        client.pointee.Bell = { client in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            vnc.handleBell()
        }
        client.pointee.FinishedFrameBufferUpdate = { client in
            guard let client, let node = client.pointee.clientData, let data = node.pointee.data else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            vnc.handleFinishedFrameBufferUpdate()
        }
    }

    private static let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private static let grayColorSpace = CGColorSpaceCreateDeviceGray()

    func gotFrameBufferUpdate() {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        guard let client = rawClient else { return }
        guard let frameBuffer = client.pointee.frameBuffer else { return }

        let width = client.pointee.width.int
        let height = client.pointee.height.int
        let pixelFormat = client.pointee.format
        let bitsPerPixel = pixelFormat.bitsPerPixel.int
        let bytesPerPixel = bitsPerPixel / 8
        let stride = width * bytesPerPixel
        let bufferSize = width * height * bytesPerPixel

        let colorSpace: CGColorSpace
        let bitmapInfo: CGBitmapInfo
        let bitsPerComponent: Int

        switch bitsPerPixel {
        case 32:
            colorSpace = Self.rgbColorSpace
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
            bitsPerComponent = 8
        case 16:
            colorSpace = Self.rgbColorSpace
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder16Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
            bitsPerComponent = 5
        case 8:
            colorSpace = Self.grayColorSpace
            bitmapInfo = []
            bitsPerComponent = 8
        default:
            return
        }

        guard let provider = CGDataProvider(
            dataInfo: nil,
            data: frameBuffer,
            size: bufferSize,
            releaseData: { _, _, _ in }
        ) else { return }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: stride,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return }

        vncDelegate?.buffer(vnc: self, image: cgImage)
    }
}

// MARK: - VNC 回调响应函数集合

public extension VNC {
    // MARK: - 认证相关回调响应

    /// 提供纯密码 (VNC Auth)
    func providePassword() -> UnsafeMutablePointer<CChar>? {
        getPassword()
    }

    /// 提供凭据 (账号/密码)
    func provideCredential(type: Int32) -> UnsafeMutablePointer<rfbCredential>? {
        getCredential(type)
    }

    // MARK: - 事件与数据更新回调响应

    /// 画面帧更新响应
    func handleFrameBufferUpdate(x _: Int, y _: Int, width _: Int, height _: Int) {
        if let client = rawClient {
            let currentWidth = Int(client.pointee.width)
            let currentHeight = Int(client.pointee.height)

            // 当尺寸变化时触发桌面大小变更事件
            if currentWidth != lastWidth || currentHeight != lastHeight {
                lastWidth = currentWidth
                lastHeight = currentHeight

                handleDesktopSizeChange(width: currentWidth, height: currentHeight)
            }
            gotFrameBufferUpdate()
        }
    }

    /// 聊天文本响应
    func handleTextChat(code _: Int, message _: String) {
        // 在这里写聊天消息接收逻辑
    }

    /// 蜂鸣提示响应
    func handleBell() {
        DispatchQueue.main.async {
            #if os(iOS)
                // 1. iOS 播放系统默认警报音 (1052)
                AudioServicesPlaySystemSound(1052)

                // 2. 触发系统触觉反馈 (Haptic)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)

            #else
                AudioServicesPlayAlertSound(1000)
            #endif
        }
    }

    /// 服务端分辨率动态发生变更时触发
    func handleDesktopSizeChange(width: Int, height: Int) {
        #if DEBUG
            print("VNC 桌面分辨率已变更: \(width) x \(height)")
        #endif
        vncDelegate?.handleDesktopSizeChange(width: width, height: height)
    }

    /// 每次帧缓冲区更新完成时触发（可用于计算 FPS 或性能指标）
    func handleFinishedFrameBufferUpdate() {
        frameCount += 1

        let now = CFAbsoluteTimeGetCurrent()
        let elapsedTime = now - lastFPSUpdateTime

        if elapsedTime >= 1.0 {
            currentFPS = Double(frameCount) / elapsedTime

            #if DEBUG
                print(String(format: "当前 VNC 实时帧率 FPS: %.1f", currentFPS))
            #endif

            // 重置计数器与时间戳
            frameCount = 0
            lastFPSUpdateTime = now

            vncDelegate?.handleFPSChange(eps: currentFPS)
        }
    }

    /// 剪贴板文本响应 (远端同步到本地)
    func handleXCutText(_ text: String) {
        guard !text.isEmpty else { return }
        DispatchQueue.main.async {
            #if os(iOS)
                UIPasteboard.general.string = text
            #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            #endif
        }
    }

    /// 将本地剪贴板文本同步给服务端 (客户端发送到远端)
    func sendLocalCutText(_ text: String) {
        guard let client = rawClient else { return }

        text.withCString { cStr in
            let length = Int32(strlen(cStr))
            SendClientCutText(client, UnsafeMutablePointer(mutating: cStr), length)
        }
    }
}
