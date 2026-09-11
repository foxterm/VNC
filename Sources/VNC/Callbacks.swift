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
    /// 注册并配置 libvncclient 库的所有底层 C 回调函数
    /// - Parameter client: libvncclient 结构体指针
    func setupCallbacks(client: UnsafeMutablePointer<rfbClient>) {
        // 分配内存以绑定 self 实例指针到 C 结构的 clientData 中
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        rfbClientSetClientData(client, nil, selfPtr)

        // 1. 纯密码认证
        client.pointee.GetPassword = { client in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return nil }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            return vnc.providePassword()
        }

        // 2. VeNCrypt / 凭据认证
        client.pointee.GetCredential = { client, credType in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return nil }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            return vnc.provideCredential(type: credType)
        }

        // 3. 图像帧区域更新
        client.pointee.GotFrameBufferUpdate = { client, x, y, w, h in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            vnc.handleFrameBufferUpdate(x: x.int, y: y.int, width: w.int, height: h.int)
        }

        // 4. FinishedFrameBufferUpdate
        client.pointee.FinishedFrameBufferUpdate = { client in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            vnc.handleFinishedFrameBufferUpdate()
        }

        // 5. 剪贴板文本回调 (UTF-8 编码)
        client.pointee.GotXCutTextUTF8 = { client, text, textlen in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            let str = String(bytes: UnsafeBufferPointer(start: UnsafePointer<UInt8>(OpaquePointer(text)), count: Int(textlen)), encoding: .utf8) ?? ""
            vnc.handleXCutText(str)
        }

        // 6. 远程文本聊天消息回调
        client.pointee.HandleTextChat = { client, value, text in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            let message = text.map { String(cString: $0) } ?? ""
            vnc.handleTextChat(code: Int(value), message: message)
        }

        // 7. 远程蜂鸣/响铃提示回调
        client.pointee.Bell = { client in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            vnc.handleBell()
        }

        // 8. 单次图像帧更新完成回调
        client.pointee.FinishedFrameBufferUpdate = { client in
            guard let client, let data = rfbClientGetClientData(client, nil) else { return }
            let vnc = Unmanaged<VNC>.fromOpaque(data).takeUnretainedValue()
            vnc.handleFinishedFrameBufferUpdate()
        }
        // 9 设置 X509 证书跳过验证（防止自签名证书导致 TLS 握手终止）
        client.pointee.GetX509CertFingerprintMismatchDecision = { _, _, _, _, _, _ in
            // 默认信任服务端自签名证书（生产环境可在此检查指纹）
            1 // rfbBool true
        }
    }
}

// MARK: - VNC 回调响应函数集合

public extension VNC {
    // MARK: - 认证相关回调响应

    /// 提供纯密码 (VNC Auth)
    func providePassword() -> UnsafeMutablePointer<CChar>? {
        getPassword()
    }

    /// 提供凭据 (账号/密码/X509 证书)
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

    /// 蜂鸣提示响应（播放系统音效与触发震动）
    func handleBell() {
        DispatchQueue.main.async {
            #if os(iOS)
                // 1. iOS 播放系统默认警报音 (1052)
                AudioServicesPlaySystemSound(1052)

                // 2. 触发系统触觉反馈 (Haptic)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)

            #else
                // macOS 播放默认提示音
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

    /// 每次帧缓冲区更新完成时触发（用于实时计算 FPS 渲染帧率）
    func handleFinishedFrameBufferUpdate() {
        frameCount += 1

        let now = CFAbsoluteTimeGetCurrent()
        let elapsedTime = now - lastFPSUpdateTime

        // 超过 1 秒则结算一次 FPS 并抛出回调
        if elapsedTime >= 1.0 {
            currentFPS = Double(frameCount) / elapsedTime

            // 重置计数器与时间戳
            frameCount = 0
            lastFPSUpdateTime = now

            vncDelegate?.handleFPSChange(eps: currentFPS)
        }
    }

    /// 剪贴板文本响应 (远端同步到本地系统剪贴板)
    func handleXCutText(_ text: String) {
        guard !text.isEmpty else { return }
        cutText = text
//        DispatchQueue.main.async {
//            #if os(iOS)
//                UIPasteboard.general.string = text
//            #elseif os(macOS)
//                NSPasteboard.general.clearContents()
//                NSPasteboard.general.setString(text, forType: .string)
//            #endif
//        }
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
