// FoxTerm | VNC.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import libvncclient
import Sync

public class VNC {
    public internal(set) var rawClient: UnsafeMutablePointer<rfbClient>?
    /// 底层 TCP 套接字文件描述符
    public internal(set) var fd: Int32 = -1
    /// 记录最近一次发生的错误描述
    public internal(set) var error: String?
    let queueSocket: DispatchQueue = .main
    var socketShell: DispatchSourceRead?

    // 缓存桌面上一次的宽高，用于判定分辨率变化
    public internal(set) var lastWidth: Int = 0
    public internal(set) var lastHeight: Int = 0
    let mutex: Mutex = .init()
    public var preferredColorDepth: ColorDepth = .bit32
    public var enableJPEG = true
    public var qualityLevel: Int32 = 9
    public var compressLevel: Int32 = 6
    public var isCursor = true
    // public var viewOnly = false

    public var vncDelegate: VNCDelegate?

    public let host: String
    public let port: Int
    public let username: String
    public let password: String
    public let timeout: Int

    public init(host: String, port: Int, username: String = "", password: String = "", timeout: Int = 10) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.timeout = timeout
    }

    deinit {
        rawClient = nil
        #if DEBUG
            print("♻️♻️♻️♻️", "VNC")
        #endif
    }
}
