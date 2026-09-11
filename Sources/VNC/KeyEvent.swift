// FoxTerm | KeyEvent.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Extension
import Foundation
import libvncclient
import SwiftUI

public extension VNC {
    /// 发送鼠标移动事件
    /// - Parameters:
    ///   - x: X坐标
    ///   - y: Y坐标
    ///   - buttonMask: 按钮掩码 (1=左键, 2=中键, 4=右键)
    func sendPointerEvent(x: Int32, y: Int32, buttonMask: Int32) {
        guard isCursor else {
            return
        }
        guard let rawClient else { return }
        SendPointerEvent(rawClient, x, y, buttonMask)
    }

    /// 发送鼠标点击事件
    /// - Parameters:
    ///   - x: X坐标
    ///   - y: Y坐标
    ///   - button: 按钮类型 (1=左键, 2=中键, 3=右键)
    ///   - pressed: 是否按下
    func sendMouseButtonEvent(x: Int32, y: Int32, button: Int32, pressed: Bool) {
        guard isCursor else {
            return
        }
        guard let rawClient else { return }

        var buttonMask: Int32 = 0
        switch button {
        case 1: // 左键
            buttonMask = pressed ? 1 : 0
        case 2: // 中键
            buttonMask = pressed ? 2 : 0
        case 3: // 右键
            buttonMask = pressed ? 4 : 0
        default:
            break
        }

        SendPointerEvent(rawClient, x, y, buttonMask)
    }

    /// 发送鼠标滚轮事件
    /// - Parameters:
    ///   - x: X坐标
    ///   - y: Y坐标
    ///   - wheelDelta: 滚轮增量 (正数向上滚动，负数向下滚动)
    func sendMouseWheelEvent(x: Int32, y: Int32, wheelDelta: Int32) {
        guard isCursor else {
            return
        }
        guard let rawClient else { return }

        // VNC通常使用按钮4(向上)和按钮5(向下)来表示滚轮
        let buttonMask: Int32 = wheelDelta > 0 ? 8 : 16 // 8=向上, 16=向下
        SendPointerEvent(rawClient, x, y, buttonMask)

        // 发送按钮释放事件
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            SendPointerEvent(rawClient, x, y, 0)
        }
    }

    // MARK: - 键盘事件

    func sendKeyEvent(keysym: Int32, down: Bool) {
        guard isCursor else {
            return
        }
        guard let rawClient else { return }
        SendKeyEvent(rawClient, keysym.uint32, down ? 1 : 0)
    }

    /// 将NSEvent转换为X11 keysym
    static func convertKeysym(keyCode: UInt16, useUppercase: Bool) -> Int32 {
        #if DEBUG
            print(keyCode, useUppercase)
        #endif
        switch keyCode {
        // 字母键 (主键盘区)
        case 0: return useUppercase ? XK_A : XK_a
        case 1: return useUppercase ? XK_S : XK_s
        case 2: return useUppercase ? XK_D : XK_d
        case 3: return useUppercase ? XK_F : XK_f
        case 4: return useUppercase ? XK_H : XK_h
        case 5: return useUppercase ? XK_G : XK_g
        case 6: return useUppercase ? XK_Z : XK_z
        case 7: return useUppercase ? XK_X : XK_x
        case 8: return useUppercase ? XK_C : XK_c
        case 9: return useUppercase ? XK_V : XK_v
        case 11: return useUppercase ? XK_B : XK_b
        case 12: return useUppercase ? XK_Q : XK_q
        case 13: return useUppercase ? XK_W : XK_w
        case 14: return useUppercase ? XK_E : XK_e
        case 15: return useUppercase ? XK_R : XK_r
        case 16: return useUppercase ? XK_Y : XK_y
        case 17: return useUppercase ? XK_T : XK_t
        case 31: return useUppercase ? XK_O : XK_o
        case 32: return useUppercase ? XK_U : XK_u
        case 34: return useUppercase ? XK_I : XK_i
        case 35: return useUppercase ? XK_P : XK_p
        case 37: return useUppercase ? XK_L : XK_l
        case 38: return useUppercase ? XK_J : XK_j
        case 40: return useUppercase ? XK_K : XK_k
        case 45: return useUppercase ? XK_N : XK_n
        case 46: return useUppercase ? XK_M : XK_m
        // 数字键和符号键 (主键盘区)
        case 18: return useUppercase ? XK_1 : XK_exclam // 1!
        case 19: return useUppercase ? XK_2 : XK_at // 2@
        case 20: return useUppercase ? XK_3 : XK_numbersign // 3#
        case 21: return useUppercase ? XK_4 : XK_dollar // 4$
        case 23: return useUppercase ? XK_5 : XK_percent // 5%
        case 22: return useUppercase ? XK_6 : XK_asciicircum // 6^
        case 26: return useUppercase ? XK_7 : XK_ampersand // 7&
        case 28: return useUppercase ? XK_8 : XK_asterisk // 8*
        case 25: return useUppercase ? XK_9 : XK_parenleft // 9(
        case 29: return useUppercase ? XK_0 : XK_parenright // 0)
        // 方括号和反斜杠
        case 33: return useUppercase ? XK_bracketleft : XK_braceleft // [{
        case 30: return useUppercase ? XK_bracketright : XK_braceright // ]}
        case 42: return useUppercase ? XK_backslash : XK_bar // \|
        // 分号区域
        case 41: return useUppercase ? XK_semicolon : XK_colon // ;:
        case 39: return useUppercase ? XK_quoteright : XK_quotedbl // '"
        case 50: return useUppercase ? XK_asciitilde : XK_grave // `~
        // 逗号、句号和斜杠
        case 43: return useUppercase ? XK_less : XK_comma // ,<
        case 47: return useUppercase ? XK_period : XK_greater // .>
        case 44: return useUppercase ? XK_slash : XK_question // /?
        // 连字符和等号
        case 27: return useUppercase ? XK_minus : XK_underscore // -_
        case 24: return useUppercase ? XK_equal : XK_plus // =+
        // 控制键
        case 49: return XK_space
        case 53: return XK_Escape
        case 48: return XK_Tab
        case 51: return XK_BackSpace
        case 117: return XK_Delete
        case 36: return XK_Return
        case 76: return XK_KP_Enter // 另一个回车键(小键盘)
        case 57: return XK_Caps_Lock
        // 修饰键
        case 54: return XK_Meta_R // Right Command
        case 55: return XK_Meta_L // Left Command
        case 56: return XK_Shift_L // Left Shift (注意: 您的信息中列出两次)
        case 59: return XK_Shift_L // Left Shift
        case 60: return XK_Shift_R // Right Shift
        case 58: return XK_Alt_L // Left Option
        case 61: return XK_Alt_R // Right Option
        case 63: return XK_Control_L // Left Control (注意: 您的信息中左右控制键keyCode似乎颠倒了)
        case 62: return XK_Control_R // Right Control
        // 功能键
        case 122: return XK_F1
        case 120: return XK_F2
        case 99: return XK_F3
        case 118: return XK_F4
        case 96: return XK_F5
        case 97: return XK_F6
        case 98: return XK_F7
        case 100: return XK_F8
        case 101: return XK_F9
        case 109: return XK_F10
        case 103: return XK_F11
        case 111: return XK_F12
        case 105: return XK_F13
        case 107: return XK_F14
        case 113: return XK_F15
        case 106: return XK_F16
        case 64: return XK_F17
        case 79: return XK_F18
        case 80: return XK_F19
        case 90: return XK_F20
        // 导航键
        case 115: return XK_Home
        case 119: return XK_End
        case 116: return XK_Page_Up
        case 121: return XK_Page_Down
        case 123: return XK_Left
        case 124: return XK_Right
        case 125: return XK_Down
        case 126: return XK_Up
        // 小键盘区
        case 83: return XK_KP_1
        case 84: return XK_KP_2
        case 85: return XK_KP_3
        case 86: return XK_KP_4
        case 87: return XK_KP_5
        case 88: return XK_KP_6
        case 89: return XK_KP_7
        case 91: return XK_KP_8
        case 92: return XK_KP_9
        case 82: return XK_KP_0
        case 67: return XK_KP_Multiply
        case 75: return XK_KP_Divide
        case 69: return XK_KP_Add
        case 78: return XK_KP_Subtract
        case 81: return XK_KP_Equal
        case 65: return XK_KP_Decimal
        case 71: return XK_Clear // Num Lock 或 Clear
        // 其他特殊键
        case 10: return XK_section // §± (取决于键盘布局)
        default:
            return XK_VoidSymbol
        }
    }

    /// 发送字符事件
    /// - Parameters:
    ///   - character: 字符
    ///   - pressed: 是否按下
    func sendCharacterEvent(character: Character, pressed: Bool) {
        guard isCursor else {
            return
        }
        guard let rawClient else { return }

        // 将字符转换为X11 keysym
        let keysym = getX11KeySym(for: character)
        SendKeyEvent(rawClient, keysym, pressed ? 1 : 0)
    }

    /// 发送特殊键事件
    /// - Parameters:
    ///   - specialKey: 特殊键类型
    ///   - pressed: 是否按下
    func sendSpecialKeyEvent(_ specialKey: SpecialKey, pressed: Bool) {
        guard isCursor else {
            return
        }
        guard let rawClient else { return }
        SendKeyEvent(rawClient, specialKey.keysym.uint32, pressed ? 1 : 0)
    }

    // MARK: - 键盘映射辅助函数

    func getX11KeySym(for character: Character) -> UInt32 {
        // 简单的字符到X11 keysym映射
        guard let unicodeScalar = character.unicodeScalars.first else {
            return 0
        }

        let value = unicodeScalar.value
        if value < 0x80 {
            // ASCII字符
            return UInt32(value)
        } else {
            // 非ASCII字符，使用Unicode keysym格式
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
