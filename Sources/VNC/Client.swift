// FoxTerm | Client.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Extension
import Foundation
import libetos
import libvncclient

/// VNC 认证信息数据封装类
final class VNCAuthInfo {
    /// 登录用户名
    let username: String
    /// 登录密码
    let password: String

    /// 初始化认证信息
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public extension VNC {
    /// 执行 VNC 协议握手并初始化连接
    /// - Returns: 是否完成握手并成功保持连接状态
    func handshake() async -> Bool {
        await io.call { [self] in
//            SetBlocking(fd)
//            etos_socket_set_blocking(fd, true)
            #if DEBUG
                rfbEnableClientLogging = 1 // 调试模式下开启 C 库内部日志输出
            #else
                rfbEnableClientLogging = 0 // 发布模式下关闭日志
            #endif

            // 初始化 rfbClient 实例 (指定像素大小: 8/3/4)
            guard let client = rfbGetClient(8, 3, 4) else {
                return false
            }
            // 配置客户端参数
            client.pointee.appData.compressLevel = compressLevel
            client.pointee.appData.qualityLevel = qualityLevel
            client.pointee.appData.enableJPEG = enableJPEG ? 1 : 0
            client.pointee.canHandleNewFBSize = 1
            client.pointee.appData.useRemoteCursor = 0 // 远程光标渲染控制
//            client.pointee.appData.shareDesktop = 1 // 开启多端共享桌面
            client.pointee.appData.palmVNC = 1 // 兼容 PalmVNC 扩展协议

            // 设置像素格式与各种事件回调
            setupPreferredPixelFormat(client: client)
            setupCallbacks(client: client)

            client.pointee.connectTimeout = timeout.uint32
            client.pointee.serverHost = host.bytes
            client.pointee.serverPort = port.int32

            guard rfbInitClient(client, nil, nil) != 0 else {
                rfbClientCleanup(client)
                return false
            }
            fd = client.pointee.sock

//            guard InitialiseRFBConnection(client) != 0 else {
//                rfbClientCleanup(client)
//                return false
//            }
//            guard SetFormatAndEncodings(client) != 0 else {
//                rfbClientCleanup(client)
//                return false
//            }

            SendFramebufferUpdateRequest(client, 0, 0, client.pointee.width, client.pointee.height, 0)
            rawClient = client
            pollShell()
            return isConnected
        }
    }

    /// 检查当前连接是否使用了压缩编码
    var isComp: Bool {
        guard let rawClient else { return false }
        return rawClient.pointee.appData.compressLevel > 0
    }

    /// 获取远程桌面名称
    var desktopName: String? {
        guard let rawClient else { return nil }
        return rawClient.pointee.desktopName.string
    }

    /// 获取底层原始帧缓冲区 (FrameBuffer) 数据指针
    var frameBuffer: UnsafeMutablePointer<UInt8>? {
        guard let rawClient else { return nil }
        return rawClient.pointee.frameBuffer
    }

    /// 根据配置设置客户端期望的像素格式
    /// - Parameter client: libvncclient 结构体指针
    private func setupPreferredPixelFormat(client: UnsafeMutablePointer<rfbClient>) {
        var format = client.pointee.format

        format.trueColour = 1
        format.bigEndian = 0

        switch preferredColorDepth {
        case .bit32:
            format.bitsPerPixel = 32
            format.depth = 24
            format.redMax = 255
            format.greenMax = 255
            format.blueMax = 255
            format.redShift = 16
            format.greenShift = 8
            format.blueShift = 0

        case .bit16:
            format.bitsPerPixel = 16
            format.depth = 16
            format.redMax = 31
            format.greenMax = 63
            format.blueMax = 31
            format.redShift = 11
            format.greenShift = 5
            format.blueShift = 0

        case .bit8:
            format.bitsPerPixel = 8
            format.depth = 8
            format.redMax = 7
            format.greenMax = 7
            format.blueMax = 3
            format.redShift = 5
            format.greenShift = 2
            format.blueShift = 0
        }

        client.pointee.format = format
    }

    /// 处理 VNC 消息驱动循环事件
    /// - Returns: 处理正常返回 true，出现网络异常或链接断开返回 false
    internal func processEvents() -> Bool {
        guard let rawClient else { return false }

        // 等待并检查是否有可读消息 (超时设为 50ms)
        let rc = WaitForMessage(rawClient, 50000)
        if rc < 0 {
            return false // 读取异常，连接可能已断开
        }
        if rc > 0 {
            // 解析并处理接收到的服务端协议消息
            guard HandleRFBServerMessage(rawClient) != 0 else {
                return false
            }
        }
        // SendFramebufferUpdateRequest(rawClient, 0, 0, rawClient.pointee.width, rawClient.pointee.height, 1)

        return true
    }

    /// 主动断开 VNC 连接并清理所有分配的内存与监听
    func disconnect() {
        // 关闭 Socket 双向读写通道
        etos_socket_shutdown(fd, SHUT_RDWR)

        // 取消并释放事件监听源
        socketShell?.cancel()
        socketShell = nil

        // 加锁清理资源，防止多线程竞争导致重复释放
        mutex.withLock {
            vncDelegate = nil
            if let rawClient {
                rfbClientCleanup(rawClient) // 释放 libvncclient 内存空间
            }
            rawClient = nil
        }

        // 彻底关闭并释放底层套接字句柄
//        freeSocket()
    }
}
