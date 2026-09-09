// FoxTerm | Type.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation

public enum ColorDepth: String, CaseIterable {
    case bit32, bit16, bit8

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
