// FoxTerm | Type.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation

/// VNC 图像颜色深度枚举
public enum ColorDepth: String, CaseIterable {
    /// 32位真彩色 (24位色彩 + 8位保留/ Alpha)
    case bit32
    /// 16位高彩色 (通常为 RGB565 / RGB555)
    case bit16
    /// 8位伪彩色 / 256色
    case bit8

    /// 对应的位深度数值 (Int32)，方便直接传给底层 C 库
    var bit: Int32 {
        switch self {
        case .bit32:
            32
        case .bit16:
            16
        case .bit8:
            8
        }
    }
}
