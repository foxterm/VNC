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
        client.pointee.clientData = Unmanaged.passUnretained(self).toOpaque().assumingMemoryBound(to: rfbClientData.self)
        client.pointee.MallocFrameBuffer = { client in
            guard let client, let dataPtr = client.pointee.clientData else { return 1 }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()

            // 重新分配 FrameBuffer 说明分辨率或者格式发生了改变，触发事件
            vnc.handleDesktopSizeChange(
                width: Int(client.pointee.width),
                height: Int(client.pointee.height)
            )

            return 1 // 返回 1 使用默认的内存分配策略
        }
        // 1. 纯密码认证回调
        client.pointee.GetPassword = { client in
            guard let client, let dataPtr = client.pointee.clientData else { return nil }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            return vnc.providePassword()
        }

        // 2. 账号+密码认证回调
        client.pointee.GetCredential = { client, credType in
            guard let client, let dataPtr = client.pointee.clientData else { return nil }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            return vnc.provideCredential(type: Int(credType))
        }

        // 3. 图像帧更新回调
        client.pointee.GotFrameBufferUpdate = { client, x, y, w, h in
            guard let client, let dataPtr = client.pointee.clientData else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            vnc.handleFrameBufferUpdate(x: Int(x), y: Int(y), width: Int(w), height: Int(h))
        }

        // 4. 剪贴板文本回调 (ISO-Latin1)
        client.pointee.GotXCutText = { client, text, textlen in
            guard let client, let dataPtr = client.pointee.clientData, let text else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            let str = String(bytes: UnsafeBufferPointer(start: UnsafePointer<UInt8>(OpaquePointer(text)), count: Int(textlen)), encoding: .isoLatin1) ?? ""
            vnc.handleXCutText(str)
        }

        // 5. 剪贴板文本回调 (UTF-8)
        client.pointee.GotXCutTextUTF8 = { client, text, textlen in
            guard let client, let dataPtr = client.pointee.clientData, let text else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            let str = String(bytes: UnsafeBufferPointer(start: UnsafePointer<UInt8>(OpaquePointer(text)), count: Int(textlen)), encoding: .utf8) ?? ""
            vnc.handleXCutText(str)
        }

        // 6. 聊天文本回调
        client.pointee.HandleTextChat = { client, value, text in
            guard let client, let dataPtr = client.pointee.clientData else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            let message = text.map { String(cString: $0) } ?? ""
            vnc.handleTextChat(code: Int(value), message: message)
        }

        // 7. 响铃提示回调
        client.pointee.Bell = { client in
            guard let client, let dataPtr = client.pointee.clientData else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            vnc.handleBell()
        }
        client.pointee.FinishedFrameBufferUpdate = { client in
            guard let client, let dataPtr = client.pointee.clientData else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(UnsafeMutableRawPointer(dataPtr)).takeUnretainedValue()
            vnc.handleFinishedFrameBufferUpdate()
        }
    }

    func gotFrameBufferUpdate(
        x _: Int,
        y _: Int,
        w _: Int,
        h _: Int
    ) {
        guard let client = rawClient, let frameBuffer = client.pointee.frameBuffer else {
            return
        }

        let width = client.pointee.width
        let height = client.pointee.height
        let pixelFormat = client.pointee.format
        let bitsPerPixel = pixelFormat.bitsPerPixel
        let bytesPerPixel = Int32(bitsPerPixel / 8)
        let stride = width * bytesPerPixel
        let bufferSize = Int(width * height * bytesPerPixel)
        // 创建颜色空间和位图信息
        let colorSpace: CGColorSpace
        let bitmapInfo: CGBitmapInfo
        let bitsPerComponent: Int
        let actualBitsPerPixel: Int

        switch bitsPerPixel {
        case 32:
            #if os(iOS)
                colorSpace = CGColorSpaceCreateDeviceRGB()
            #else
                colorSpace = CGColorSpaceCreateDeviceRGB()
            #endif
            bitmapInfo = CGBitmapInfo(
                rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
                    CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            bitsPerComponent = 8
            actualBitsPerPixel = 32
        case 16:
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(
                rawValue: CGBitmapInfo.byteOrder16Little.rawValue |
                    CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            bitsPerComponent = 5
            actualBitsPerPixel = 16
        case 8:
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = []
            bitsPerComponent = 8
            actualBitsPerPixel = 8
        default:
            return
        }

        // 创建数据提供者
        let data = Data(bytes: frameBuffer, count: bufferSize)
        guard let provider = CGDataProvider(data: data as CFData) else { return }

        // 创建CGImage
        let cgImage = CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: actualBitsPerPixel,
            bytesPerRow: Int(stride),
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
        vncDelegate?.buffer(vnc: self, image: cgImage)
    }
}

// MARK: - VNC 回调响应函数集合

public extension VNC {
    // MARK: - 认证相关回调响应

    /// 提供纯密码 (VNC Auth)
    func providePassword() -> UnsafeMutablePointer<CChar>? {
        password.bytes
    }

    /// 提供凭据 (账号/密码)
    func provideCredential(type: Int) -> UnsafeMutablePointer<rfbCredential>? {
        let cred = UnsafeMutablePointer<rfbCredential>.allocate(capacity: 1)
        cred.initialize(to: rfbCredential())

        if type == 1 { // Username
            cred.pointee.userCredential.username = password.bytes
            return cred
        } else if type == 2 { // Password
            cred.pointee.userCredential.password = password.bytes
            return cred
        }

        cred.deallocate()
        return nil
    }

    // MARK: - 事件与数据更新回调响应

    /// 画面帧更新响应
    func handleFrameBufferUpdate(x: Int, y: Int, width: Int, height: Int) {
        if let client = rawClient {
            let currentWidth = Int(client.pointee.width)
            let currentHeight = Int(client.pointee.height)

            // 当尺寸变化时触发桌面大小变更事件
            if currentWidth != lastWidth || currentHeight != lastHeight {
                lastWidth = currentWidth
                lastHeight = currentHeight

                handleDesktopSizeChange(width: currentWidth, height: currentHeight)
            }
            gotFrameBufferUpdate(x: x, y: y, w: width, h: height)
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
        // 统计帧率 (FPS) 或触发屏幕刷新重绘操作
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
