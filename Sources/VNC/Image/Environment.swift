// FoxTerm | Environment.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry var cgImage: CGImage?

    @Entry var sendPointerEvent: sendPointerEvent? = nil
    @Entry var sendKeyEvent: sendKeyEvent? = nil
}

extension View {
    func sendPointerEvent(_ action: @escaping sendPointerEvent.Action) -> some View {
        environment(\.sendPointerEvent, WorkspaceVNC.sendPointerEvent(action: action))
    }

    func sendKeyEvent(_ action: @escaping sendKeyEvent.Action) -> some View {
        environment(\.sendKeyEvent, WorkspaceVNC.sendKeyEvent(action: action))
    }
}

/// 鼠标事件
struct sendPointerEvent {
    typealias Action = (Int32, Int32, Int32) -> Void
    let action: Action
    func callAsFunction(x: Int32, y: Int32, buttonMask: Int32) {
        action(x, y, buttonMask)
    }
}

/// 键盘事件
struct sendKeyEvent {
    typealias Action = (Int32, Bool) -> Void
    let action: Action
    func callAsFunction(keysym: Int32, down: Bool) {
        action(keysym, down)
    }
}
