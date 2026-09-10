// FoxTerm | Protocol.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import SwiftUI

/// VNC 客户端事件回调代理协议
public protocol VNCDelegate {
    /// 当 VNC 连接断开或主动关闭时触发
    func disconnect()

    /// 当帧缓冲区收到最新渲染图像时触发
    /// - Parameters:
    ///   - vnc: 触发回调的 VNC 实例对象
    ///   - image: 解码完成的桌面画面 `CGImage`，解析失败时可能为 `nil`
    func buffer(vnc: VNC, image: CGImage?)

    /// 当远程桌面分辨率（尺寸）发生变化时触发
    /// - Parameters:
    ///   - width: 新的桌面宽度（像素）
    ///   - height: 新的桌面高度（像素）
    func handleDesktopSizeChange(width: Int, height: Int)

    /// 当渲染帧率发生更新时触发
    /// - Parameter eps: 当前的每秒渲染帧率 (FPS)
    func handleFPSChange(eps: Double)
}
