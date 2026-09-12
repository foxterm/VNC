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
    /// 支持 SOCKS5、HTTP 代理等
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

    /// 当前 Socket 的网络流量统计
    /// - Returns: 元组 (send: 已发送字节数, recv: 已接收字节数)
    var trafficStats: (send: UInt64, recv: UInt64) {
        guard fd >= 0 else { return (0, 0) }
        var stats = FdTrafficStats()
        guard etos_socket_get_traffic_stats(fd, &stats) == 0 else {
            return (0, 0)
        }
        let tx = etos_stats_get_tx(&stats)
        let rx = etos_stats_get_rx(&stats)
        return (tx, rx)
    }

    /// 启动 Socket 事件轮询监听
    /// 将 Socket 设为非阻塞模式，并基于 GCD DispatchSourceRead 监听数据可读事件
    func pollShell() {
        // 设置套接字为非阻塞模式
        SetNonBlocking(fd)
        // 重置并取消现有的监听源
        socketShell?.cancel()
        socketShell = nil

        // 创建可读事件源并绑定回调
        socketShell = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queueSocket)
        socketShell?.setEventHandler { [self] in
            if !processEvents() {
                socketShell?.cancel()
                return
            }
        }
        socketShell?.setCancelHandler { [weak self] in
            guard let self else { return }
            socketShell = nil

            // 切回主线程或相关 Queue 触发最终的断开通知/清理
            DispatchQueue.main.async {
                self.disconnect()
            }
        }
        // 启动事件监听
        socketShell?.resume()
    }

    /// 关闭并释放底层套接字资源
    func freeSocket() {
        etos_socket_close(fd)
    }
}
