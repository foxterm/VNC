// FoxTerm | SpecialKey.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import libvncclient

public enum SpecialKey {
    // TTY Functions
    case backspace
    case tab
    case linefeed
    case clear
    case `return`
    case pause
    case scrollLock
    case sysReq
    case escape
    case delete

    // Cursor control & motion
    case home
    case left
    case up
    case right
    case down
    case prior
    case pageUp
    case next
    case pageDown
    case end
    case begin

    // Misc Functions
    case select
    case print
    case execute
    case insert
    case undo
    case redo
    case menu
    case find
    case cancel
    case help
    case breakKey
    case modeSwitch
    case numLock

    // Keypad Functions
    case kpSpace
    case kpTab
    case kpEnter
    case kpF1
    case kpF2
    case kpF3
    case kpF4
    case kpHome
    case kpLeft
    case kpUp
    case kpRight
    case kpDown
    case kpPrior
    case kpPageUp
    case kpNext
    case kpPageDown
    case kpEnd
    case kpBegin
    case kpInsert
    case kpDelete
    case kpEqual
    case kpMultiply
    case kpAdd
    case kpSeparator
    case kpSubtract
    case kpDecimal
    case kpDivide
    case kp0
    case kp1
    case kp2
    case kp3
    case kp4
    case kp5
    case kp6
    case kp7
    case kp8
    case kp9

    // Function keys
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12
    case f13
    case f14
    case f15
    case f16
    case f17
    case f18
    case f19
    case f20
    case f21
    case f22
    case f23
    case f24
    case f25
    case f26
    case f27
    case f28
    case f29
    case f30
    case f31
    case f32
    case f33
    case f34
    case f35

    // Modifier keys
    case shiftL
    case shiftR
    case controlL
    case controlR
    case capsLock
    case shiftLock
    case metaL
    case metaR
    case altL
    case altR
    case superL
    case superR
    case hyperL
    case hyperR

    var keysym: Int32 {
        switch self {
        // TTY Functions
        case .backspace: XK_BackSpace
        case .tab: XK_Tab
        case .linefeed: XK_Linefeed
        case .clear: XK_Clear
        case .return: XK_Return
        case .pause: XK_Pause
        case .scrollLock: XK_Scroll_Lock
        case .sysReq: XK_Sys_Req
        case .escape: XK_Escape
        case .delete: XK_Delete
        // Cursor control & motion
        case .home: XK_Home
        case .left: XK_Left
        case .up: XK_Up
        case .right: XK_Right
        case .down: XK_Down
        case .prior: XK_Prior
        case .pageUp: XK_Page_Up
        case .next: XK_Next
        case .pageDown: XK_Page_Down
        case .end: XK_End
        case .begin: XK_Begin
        // Misc Functions
        case .select: XK_Select
        case .print: XK_Print
        case .execute: XK_Execute
        case .insert: XK_Insert
        case .undo: XK_Undo
        case .redo: XK_Redo
        case .menu: XK_Menu
        case .find: XK_Find
        case .cancel: XK_Cancel
        case .help: XK_Help
        case .breakKey: XK_Break
        case .modeSwitch: XK_Mode_switch
        case .numLock: XK_Num_Lock
        // Keypad Functions
        case .kpSpace: XK_KP_Space
        case .kpTab: XK_KP_Tab
        case .kpEnter: XK_KP_Enter
        case .kpF1: XK_KP_F1
        case .kpF2: XK_KP_F2
        case .kpF3: XK_KP_F3
        case .kpF4: XK_KP_F4
        case .kpHome: XK_KP_Home
        case .kpLeft: XK_KP_Left
        case .kpUp: XK_KP_Up
        case .kpRight: XK_KP_Right
        case .kpDown: XK_KP_Down
        case .kpPrior: XK_KP_Prior
        case .kpPageUp: XK_KP_Page_Up
        case .kpNext: XK_KP_Next
        case .kpPageDown: XK_KP_Page_Down
        case .kpEnd: XK_KP_End
        case .kpBegin: XK_KP_Begin
        case .kpInsert: XK_KP_Insert
        case .kpDelete: XK_KP_Delete
        case .kpEqual: XK_KP_Equal
        case .kpMultiply: XK_KP_Multiply
        case .kpAdd: XK_KP_Add
        case .kpSeparator: XK_KP_Separator
        case .kpSubtract: XK_KP_Subtract
        case .kpDecimal: XK_KP_Decimal
        case .kpDivide: XK_KP_Divide
        case .kp0: XK_KP_0
        case .kp1: XK_KP_1
        case .kp2: XK_KP_2
        case .kp3: XK_KP_3
        case .kp4: XK_KP_4
        case .kp5: XK_KP_5
        case .kp6: XK_KP_6
        case .kp7: XK_KP_7
        case .kp8: XK_KP_8
        case .kp9: XK_KP_9
        // Function keys
        case .f1: XK_F1
        case .f2: XK_F2
        case .f3: XK_F3
        case .f4: XK_F4
        case .f5: XK_F5
        case .f6: XK_F6
        case .f7: XK_F7
        case .f8: XK_F8
        case .f9: XK_F9
        case .f10: XK_F10
        case .f11: XK_F11
        case .f12: XK_F12
        case .f13: XK_F13
        case .f14: XK_F14
        case .f15: XK_F15
        case .f16: XK_F16
        case .f17: XK_F17
        case .f18: XK_F18
        case .f19: XK_F19
        case .f20: XK_F20
        case .f21: XK_F21
        case .f22: XK_F22
        case .f23: XK_F23
        case .f24: XK_F24
        case .f25: XK_F25
        case .f26: XK_F26
        case .f27: XK_F27
        case .f28: XK_F28
        case .f29: XK_F29
        case .f30: XK_F30
        case .f31: XK_F31
        case .f32: XK_F32
        case .f33: XK_F33
        case .f34: XK_F34
        case .f35: XK_F35
        // Modifier keys
        case .shiftL: XK_Shift_L
        case .shiftR: XK_Shift_R
        case .controlL: XK_Control_L
        case .controlR: XK_Control_R
        case .capsLock: XK_Caps_Lock
        case .shiftLock: XK_Shift_Lock
        case .metaL: XK_Meta_L
        case .metaR: XK_Meta_R
        case .altL: XK_Alt_L
        case .altR: XK_Alt_R
        case .superL: XK_Super_L
        case .superR: XK_Super_R
        case .hyperL: XK_Hyper_L
        case .hyperR: XK_Hyper_R
        }
    }
}
