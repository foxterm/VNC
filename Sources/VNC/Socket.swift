// FoxTerm | Socket.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Extension
import Foundation
import libetos
import libvncclient
import Proxy

public extension VNC {
    /// 发起标准的 TCP 直接连接
    /// 使用 libetos 库进行非阻塞/带超时的 Socket 初始化
    /// - Returns: 是否连接成功
    func connect() async -> Bool {
        fd = await io.call { [self] in
            etos_socket_connect(host, port.int32, timeout.int32 * 1000)
        }
        guard isConnected else {
            error = socketLastStrError
            return false
        }
        return true
    }

    /// 通过代理服务器发起连接
    /// 支持 SOCKS5、HTTP 代理
    /// - Parameter proxy: 代理配置信息对象
    /// - Returns: 是否连接成功
    func connect(proxy: ProxyConfiguration) async -> Bool {
        fd = await proxy.connect(host: host, port: port)
        guard isConnected else {
            error = socketLastStrError
            return false
        }
        return true
    }

    /// 检查底层 Socket 是否处于已连接状态
    var isConnected: Bool {
        etos_socket_is_connect(fd)
    }

    /// 获取底层 Socket 的错误码
    var socketLastError: Int32 {
        etos_socket_last_error()
    }

    /// 获取底层 Socket 的错误描述字符串
    var socketLastStrError: String {
        etos_socket_strerror(socketLastError).string
    }

    func pollShell() {
        SetNonBlocking(fd)
        socketShell?.cancel()
        socketShell = nil
        socketShell = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queueSocket)
        socketShell?.setEventHandler { [self] in
            guard processEvents() else {
                vncDelegate?.disconnect()
                return
            }
        }
        socketShell?.setCancelHandler {
            self.socketShell = nil
        }
        socketShell?.resume()
    }

    func freeSocket() {
        etos_socket_close(fd)
    }
}
