// FoxTerm | KeyEvent.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Extension
import Foundation
import libvncclient
import SwiftUI

public extension VNC {
    /// 发送鼠标指针移动与按钮状态事件
    /// - Parameters:
    ///   - x: 光标 X 坐标 (远程桌面像素坐标)
    ///   - y: 光标 Y 坐标 (远程桌面像素坐标)
    ///   - buttonMask: 按钮掩码 (1=左键, 2=中键, 4=右键, 8=滚轮上, 16=滚轮下)
    func sendPointerEvent(x: Int32, y: Int32, buttonMask: Int32) {
        guard isCursor, let rawClient else { return }
        SendPointerEvent(rawClient, x, y, buttonMask)
    }

    /// 发送鼠标按键事件 (按下或释放)
    ///
    /// 将逻辑按钮编号 (1=左键, 2=中键, 3=右键) 转换为 VNC 协议按钮掩码后发送。
    /// - Parameters:
    ///   - x: 光标 X 坐标 (远程桌面像素坐标)
    ///   - y: 光标 Y 坐标 (远程桌面像素坐标)
    ///   - button: 按钮类型 (1=左键, 2=中键, 3=右键)
    ///   - pressed: `true` 表示按下，`false` 表示释放
    func sendMouseButtonEvent(x: Int32, y: Int32, button: Int32, pressed: Bool) {
        guard isCursor, let rawClient else { return }

        let buttonMask: Int32 = pressed ? (1 << (button - 1)) : 0
        SendPointerEvent(rawClient, x, y, buttonMask)
    }

    /// 发送鼠标滚轮事件
    ///
    /// VNC 协议使用按钮 4 (掩码 8) 表示向上滚动，按钮 5 (掩码 16) 表示向下滚动。
    /// 发送滚轮按下事件后，延迟 50ms 自动发送释放事件以完成一次完整滚动。
    /// - Parameters:
    ///   - x: 光标 X 坐标 (远程桌面像素坐标)
    ///   - y: 光标 Y 坐标 (远程桌面像素坐标)
    ///   - wheelDelta: 滚轮增量 (正数向上滚动，负数向下滚动)
    func sendMouseWheelEvent(x: Int32, y: Int32, wheelDelta: Int32) {
        guard isCursor, let rawClient else { return }

        let buttonMask: Int32 = wheelDelta > 0 ? 8 : 16
        SendPointerEvent(rawClient, x, y, buttonMask)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let rawClient = self.rawClient else { return }
            SendPointerEvent(rawClient, x, y, 0)
        }
    }

    // MARK: - 键盘事件

    /// 发送键盘按键事件
    /// - Parameters:
    ///   - keysym: X11 键值符号 (如 XK_a, XK_Return)
    ///   - down: `true` 表示按下，`false` 表示释放
    func sendKeyEvent(keysym: Int32, down: Bool) {
        guard isCursor, let rawClient else { return }
        SendKeyEvent(rawClient, keysym.uint32, down ? 1 : 0)
    }

    /// 将 macOS 虚拟键码 (keyCode) 映射为 X11 keysym
    ///
    /// 使用静态字典进行 O(1) 查找，覆盖字母、数字、符号、功能键、导航键和小键盘。
    /// - Parameters:
    ///   - keyCode: macOS NSEvent 中的虚拟键码
    ///   - useUppercase: 是否输出大写字母 (由 Shift/CapsLock 状态决定)
    /// - Returns: 对应的 X11 keysym，未映射时返回 `XK_VoidSymbol`
    static func convertKeysym(keyCode: UInt16, useUppercase: Bool) -> Int32 {
        if let entry = keyCodeMap[keyCode] {
            return useUppercase ? entry.upper : entry.lower
        }
        return XK_VoidSymbol
    }

    /// 键码映射表：keyCode → (小写 keysym, 大写 keysym)
    private static let keyCodeMap: [UInt16: (lower: Int32, upper: Int32)] = {
        var map: [UInt16: (Int32, Int32)] = [
            // 字母键 (主键盘区)
            0: (XK_a, XK_A), 1: (XK_s, XK_S), 2: (XK_d, XK_D), 3: (XK_f, XK_F),
            4: (XK_h, XK_H), 5: (XK_g, XK_G), 6: (XK_z, XK_Z), 7: (XK_x, XK_X),
            8: (XK_c, XK_C), 9: (XK_v, XK_V), 11: (XK_b, XK_B), 12: (XK_q, XK_Q),
            13: (XK_w, XK_W), 14: (XK_e, XK_E), 15: (XK_r, XK_R), 16: (XK_y, XK_Y),
            17: (XK_t, XK_T), 31: (XK_o, XK_O), 32: (XK_u, XK_U), 34: (XK_i, XK_I),
            35: (XK_p, XK_P), 37: (XK_l, XK_L), 38: (XK_j, XK_J), 40: (XK_k, XK_K),
            45: (XK_n, XK_N), 46: (XK_m, XK_M),
            // 数字键与符号键
            18: (XK_1, XK_exclam), 19: (XK_2, XK_at), 20: (XK_3, XK_numbersign),
            21: (XK_4, XK_dollar), 23: (XK_5, XK_percent), 22: (XK_6, XK_asciicircum),
            26: (XK_7, XK_ampersand), 28: (XK_8, XK_asterisk), 25: (XK_9, XK_parenleft),
            29: (XK_0, XK_parenright),
            // 方括号与反斜杠
            33: (XK_bracketleft, XK_braceleft), 30: (XK_bracketright, XK_braceright),
            42: (XK_backslash, XK_bar),
            // 分号、引号
            41: (XK_semicolon, XK_colon), 39: (XK_quoteright, XK_quotedbl),
            50: (XK_grave, XK_asciitilde),
            // 逗号、句号、斜杠
            43: (XK_comma, XK_less), 47: (XK_period, XK_greater),
            44: (XK_slash, XK_question),
            // 连字符、等号
            27: (XK_minus, XK_underscore), 24: (XK_equal, XK_plus),
            // 控制键
            49: (XK_space, XK_space), 53: (XK_Escape, XK_Escape),
            48: (XK_Tab, XK_Tab), 51: (XK_BackSpace, XK_BackSpace),
            117: (XK_Delete, XK_Delete), 36: (XK_Return, XK_Return),
            76: (XK_KP_Enter, XK_KP_Enter), 57: (XK_Caps_Lock, XK_Caps_Lock),
            // 修饰键
            54: (XK_Meta_R, XK_Meta_R), 55: (XK_Meta_L, XK_Meta_L),
            56: (XK_Shift_L, XK_Shift_L), 59: (XK_Shift_L, XK_Shift_L),
            60: (XK_Shift_R, XK_Shift_R), 58: (XK_Alt_L, XK_Alt_L),
            61: (XK_Alt_R, XK_Alt_R), 63: (XK_Control_L, XK_Control_L),
            62: (XK_Control_R, XK_Control_R),
            // 功能键
            122: (XK_F1, XK_F1), 120: (XK_F2, XK_F2), 99: (XK_F3, XK_F3),
            118: (XK_F4, XK_F4), 96: (XK_F5, XK_F5), 97: (XK_F6, XK_F6),
            98: (XK_F7, XK_F7), 100: (XK_F8, XK_F8), 101: (XK_F9, XK_F9),
            109: (XK_F10, XK_F10), 103: (XK_F11, XK_F11), 111: (XK_F12, XK_F12),
            105: (XK_F13, XK_F13), 107: (XK_F14, XK_F14), 113: (XK_F15, XK_F15),
            106: (XK_F16, XK_F16), 64: (XK_F17, XK_F17), 79: (XK_F18, XK_F18),
            80: (XK_F19, XK_F19), 90: (XK_F20, XK_F20),
            // 导航键
            115: (XK_Home, XK_Home), 119: (XK_End, XK_End),
            116: (XK_Page_Up, XK_Page_Up), 121: (XK_Page_Down, XK_Page_Down),
            123: (XK_Left, XK_Left), 124: (XK_Right, XK_Right),
            125: (XK_Down, XK_Down), 126: (XK_Up, XK_Up),
            // 小键盘区
            83: (XK_KP_1, XK_KP_1), 84: (XK_KP_2, XK_KP_2),
            85: (XK_KP_3, XK_KP_3), 86: (XK_KP_4, XK_KP_4),
            87: (XK_KP_5, XK_KP_5), 88: (XK_KP_6, XK_KP_6),
            89: (XK_KP_7, XK_KP_7), 91: (XK_KP_8, XK_KP_8),
            92: (XK_KP_9, XK_KP_9), 82: (XK_KP_0, XK_KP_0),
            67: (XK_KP_Multiply, XK_KP_Multiply), 75: (XK_KP_Divide, XK_KP_Divide),
            69: (XK_KP_Add, XK_KP_Add), 78: (XK_KP_Subtract, XK_KP_Subtract),
            81: (XK_KP_Equal, XK_KP_Equal), 65: (XK_KP_Decimal, XK_KP_Decimal),
            71: (XK_Clear, XK_Clear),
            // 其他
            10: (XK_section, XK_section),
        ]
        return map
    }()

    /// 发送字符输入事件
    ///
    /// 将 Unicode 字符转换为 X11 keysym 后发送按键事件。
    /// - Parameters:
    ///   - character: 待发送的字符
    ///   - pressed: `true` 表示按下，`false` 表示释放
    func sendCharacterEvent(character: Character, pressed: Bool) {
        guard isCursor, let rawClient else { return }

        let keysym = getX11KeySym(for: character)
        SendKeyEvent(rawClient, keysym, pressed ? 1 : 0)
    }

    // MARK: - 键盘映射辅助函数

    /// 将单个 Unicode 字符映射为 X11 keysym
    ///
    /// ASCII 字符 (U+0000 ~ U+007F) 直接返回其码值；非 ASCII 字符使用 Unicode keysym 编码格式 `0x01000000 | codepoint`。
    /// - Parameter character: 待转换的字符
    /// - Returns: 对应的 X11 keysym 值
    func getX11KeySym(for character: Character) -> UInt32 {
        guard let unicodeScalar = character.unicodeScalars.first else {
            return 0
        }

        let value = unicodeScalar.value
        if value < 0x80 {
            return UInt32(value)
        } else {
            return 0x0100_0000 | UInt32(value)
        }
    }

    /// 发送内容到远程剪贴板
    func sendToRemoteClipboard(_ text: String) {
        guard let rawClient else { return }
        guard SendClientCutTextUTF8(rawClient, text.bytes, text.count.int32) != 0 else {
            SendClientCutText(rawClient, text.bytes, text.count.int32)
            return
        }
    }
}
