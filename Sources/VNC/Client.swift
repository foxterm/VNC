// FoxTerm | Client.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Extension
import Foundation
import libvncclient

final class VNCAuthInfo {
    let username: String
    let password: String
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public extension VNC {
    func handshake() async -> Bool {
        await io.call { [self] in
            guard let client = rfbGetClient(8, 3, 4) else {
                return false
            }
            client.pointee.appData.compressLevel = compressLevel
            client.pointee.appData.qualityLevel = qualityLevel
            client.pointee.appData.enableJPEG = enableJPEG ? 1 : 0
            client.pointee.sock = fd
//            client.pointee.canHandleNewFBSize = 1
//            client.pointee.listenSpecified = 1

            setupPreferredPixelFormat(client: client)
            setupCallbacks(client: client)

            guard InitialiseRFBConnection(client) != 0 else {
                rfbClientCleanup(client)
                return false
            }
            guard SetFormatAndEncodings(client) != 0 else {
                rfbClientCleanup(client)
                return false
            }

            SendFramebufferUpdateRequest(client, 0, 0, client.pointee.width, client.pointee.height, 0)

            rawClient = client
            pollShell()
            return isConnected
        }
    }

    var isComp: Bool {
        guard let rawClient else { return false }
        return rawClient.pointee.appData.compressLevel > 0
    }

    var desktopName: String? {
        guard let rawClient else { return nil }
        return rawClient.pointee.desktopName.string
    }

    /// 获取帧缓冲区数据
    var frameBuffer: UnsafeMutablePointer<UInt8>? {
        guard let rawClient else { return nil }
        return rawClient.pointee.frameBuffer
    }

    private func setupPreferredPixelFormat(client: UnsafeMutablePointer<rfbClient>) {
        // 配置客户端期望的像素格式
        var format = client.pointee.format

        // 始终请求 真彩色 模式并强制使用小端序
        format.trueColour = 1
        format.bigEndian = 0 // 小端序更适合现代CPU架构

        // 根据首选色深优化像素格式
        switch preferredColorDepth {
        case .bit32:
            // 32位模式优化为BGRA8888 (现代GPU最佳格式)
            format.bitsPerPixel = 32
            format.depth = 24 // 实际色彩深度
            format.redMax = 255
            format.greenMax = 255
            format.blueMax = 255

            // 优化为BGRA排列 (Core Graphics最佳格式)
            format.redShift = 16
            format.greenShift = 8
            format.blueShift = 0

        case .bit16:
            // 16位模式优化为RGB565 (内存效率最高的16位格式)
            format.bitsPerPixel = 16
            format.depth = 16
            format.redMax = 31 // 5位 (32级)
            format.greenMax = 63 // 6位 (64级)
            format.blueMax = 31 // 5位 (32级)

            // RGB565排列 (小端序)
            format.redShift = 11 // bits [11-15]
            format.greenShift = 5 // bits [5-10]
            format.blueShift = 0 // bits [0-4]

        case .bit8:
            // 8位模式 - 尽可能使用RGB332格式
            format.bitsPerPixel = 8
            format.depth = 8
            format.redMax = 7 // 3位 (8级)
            format.greenMax = 7 // 3位 (8级)
            format.blueMax = 3 // 2位 (4级)
            // RGB332排列 (3:3:2)
            format.redShift = 5 // bits [5-7]
            format.greenShift = 2 // bits [2-4]
            format.blueShift = 0 // bits [0-1]
        }

        // 更新客户端格式并设置自动转换标志
        client.pointee.format = format

        // 允许服务器进行格式转换
        client.pointee.appData.useRemoteCursor = 1
    }

    /// 处理事件循环
    internal func processEvents() -> Bool {
        guard let rawClient else { return false }

        let rc = WaitForMessage(rawClient, 50)
        if rc < 0 {
            return false // 连接错误断开
        }
        if rc > 0 {
            guard HandleRFBServerMessage(rawClient) != 0 else {
                return false
            }
        }
        return true
    }

    func disconnect() {
        socketShell?.cancel()
        if rawClient != nil {
            rfbClientCleanup(rawClient)
        }
        rawClient = nil
        freeSocket()
    }
}
