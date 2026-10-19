// FoxTerm | Environment.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import SwiftUI

public extension EnvironmentValues {
    @Entry var cgImage: CGImage?

    @Entry var sendPointerEvent: sendVNCPointerEvent? = nil
    @Entry var sendKeyEvent: sendVNCKeyEvent? = nil

    @Entry var isVNCActive: Bool = false
}

public extension View {
    func sendPointerEvent(_ action: @escaping sendVNCPointerEvent.Action) -> some View {
        environment(\.sendPointerEvent, sendVNCPointerEvent(action: action))
    }

    func sendKeyEvent(_ action: @escaping sendVNCKeyEvent.Action) -> some View {
        environment(\.sendKeyEvent, sendVNCKeyEvent(action: action))
    }
}

/// 鼠标事件
public struct sendVNCPointerEvent {
    public typealias Action = (Int32, Int32, Int32) -> Void
    public let action: Action
    public func callAsFunction(x: Int32, y: Int32, buttonMask: Int32) {
        action(x, y, buttonMask)
    }
}

/// 键盘事件
public struct sendVNCKeyEvent {
    public typealias Action = (Int32, Bool) -> Void
    public let action: Action
    public func callAsFunction(keysym: Int32, down: Bool) {
        action(keysym, down)
    }
}
