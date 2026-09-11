// FoxTerm | VNC.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import libvncclient
import Sync

/// VNC 客户端核心控制类
public class VNC {
    /// 内部版本号
    public static let version: String = LIBVNCSERVER_VERSION
    /// libvncclient 底层客户端结构体指针
    public internal(set) var rawClient: UnsafeMutablePointer<rfbClient>?
    /// 底层 TCP 套接字文件描述符
    public internal(set) var fd: Int32 = -1
    /// 记录最近一次发生的错误描述
    public internal(set) var error: String?

    /// 套接字事件处理队列（主线程）
    let queueSocket: DispatchQueue = .main
    /// 套接字读取事件监听源
    var socketShell: DispatchSourceRead?

    /// 缓存桌面上一次的宽，用于判定分辨率变化
    public internal(set) var lastWidth: Int = 0
    /// 缓存桌面上一次的高，用于判定分辨率变化
    public internal(set) var lastHeight: Int = 0

    /// 线程安全互斥锁
    let mutex: Mutex = .init()
    /// 首选颜色深度（默认 32 位）
    public var preferredColorDepth: ColorDepth = .bit32
    /// 是否开启 JPEG 压缩图像传输
    public var enableJPEG = true
    /// JPEG 图像质量等级 (1-9)
    public var qualityLevel: Int32 = 9
    /// 数据压缩等级 (1-9)
    public var compressLevel: Int32 = 6
    /// 是否显示/同步远程光标
    public var isCursor = true
    // public var viewOnly = false // 仅查看模式开关

    /// CA 证书文件路径 (X509 认证)
    public var caCertPath: String = ""
    /// CA 证书吊销列表文件路径 (X509 认证)
    public var caCrlPath: String = ""
    /// 客户端证书文件路径 (X509 认证)
    public var clientCertPath: String = ""
    /// 客户端私钥文件路径 (X509 认证)
    public var clientKeyPath: String = ""

    /// VNC 事件回调代理对象
    public var vncDelegate: VNCDelegate?

    /// 当前帧计数器（用于计算 FPS）
    internal(set) var frameCount: Int = 0
    /// 上一次更新 FPS 的时间戳
    internal(set) var lastFPSUpdateTime: TimeInterval = CFAbsoluteTimeGetCurrent()
    /// 实时渲染帧率 (FPS)
    internal(set) var currentFPS: Double = 0.0

    /// 服务器主机地址
    public let host: String
    /// 服务器端口号
    public let port: Int
    /// 登录用户名
    public let username: String
    /// 登录密码
    public let password: String
    /// 连接超时时间（秒）
    public let timeout: Int

    /// 初始化 VNC 实例
    /// - Parameters:
    ///   - host: 服务器主机地址
    ///   - port: 服务器端口号
    ///   - username: 登录用户名（可选）
    ///   - password: 登录密码（可选）
    ///   - timeout: 超时时间，默认 10 秒
    public init(host: String, port: Int, username: String = "", password: String = "", timeout: Int = 10) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.timeout = timeout
    }

    /// 析构函数：释放连接资源并打印日志
    deinit {
        disconnect()
        #if DEBUG
            print("♻️♻️♻️♻️", "VNC")
        #endif
    }
}
