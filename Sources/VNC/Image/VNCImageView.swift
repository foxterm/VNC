// FoxTerm | VNCImageView.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import SwiftUI
import VNC

public struct VNCImageView: NSViewRepresentable {
    @Environment(\.cgImage) var cgImage
    @Environment(\.isVNCActive) var isActive
    @Environment(\.sendPointerEvent) var sendPointerEvent
    @Environment(\.sendKeyEvent) var sendKeyEvent

    public init() {}

    public func makeNSView(context _: Context) -> VNCEventHandlingView {
        let view = VNCEventHandlingView(frame: .zero)
        view.sendPointerEvent = sendPointerEvent
        view.sendKeyEvent = sendKeyEvent
        return view
    }

    public func updateNSView(_ view: VNCEventHandlingView, context _: Context) {
        view.image = cgImage
        view.sendPointerEvent = sendPointerEvent
        view.sendKeyEvent = sendKeyEvent

        if isActive {
            #if os(macOS)
                DispatchQueue.main.async {
                    view.window?.makeFirstResponder(view)
                }
            #endif
            view.becomeFirstResponder()
            view.isHidden = false
        } else {
            view.resignFirstResponder()
            view.isHidden = true
        }
    }
}

public class VNCEventHandlingView: NSView {
    var sendPointerEvent: sendVNCPointerEvent?
    var sendKeyEvent: sendVNCKeyEvent?

    private var lastModifierFlags: NSEvent.ModifierFlags = []
    private var currentButtonMask: Int32 = 0

    var image: CGImage? {
        didSet {
            imageLayer.contents = image
        }
    }

    private lazy var imageLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .resize
        #if os(macOS)
            layer.drawsAsynchronously = true // 开启异步渲染以提升性能
        #endif
        return layer
    }()

    /// 将映射表设为 static 静态常量，避免频繁方法调用时的重复对象创建
    private static let macModifierMap: [UInt16: Int32] = [
        55: 0xFFEB, // left command -> Super_L
        54: 0xFFEC, // right command -> Super_R
        59: 0xFFE3, // left control -> Control_L
        62: 0xFFE4, // right control -> Control_R
        58: 0xFFE9, // left alt -> Alt_L
        61: 0xFFEA, // right alt -> Alt_R
        56: 0xFFE1, // left shift -> Shift_L
        60: 0xFFE2, // right shift -> Shift_R
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.addSublayer(imageLayer)
    }

    deinit {
        image = nil
    }
}

public extension VNCEventHandlingView {
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true) // 禁用调整大小时的隐式动画
        imageLayer.frame = bounds
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            window.acceptsMouseMovedEvents = true
        }
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }

        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeInKeyWindow,
            .enabledDuringMouseDrag,
        ]
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // MARK: - 鼠标与滚轮事件

    override func mouseMoved(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func mouseDown(with event: NSEvent) {
        sendMouseEvent(event, button: 1, pressed: true)
    }

    override func mouseUp(with event: NSEvent) {
        sendMouseEvent(event, button: 1, pressed: false)
    }

    override func rightMouseDown(with event: NSEvent) {
        sendMouseEvent(event, button: 2, pressed: true)
    }

    override func rightMouseUp(with event: NSEvent) {
        sendMouseEvent(event, button: 2, pressed: false)
    }

    override func otherMouseDown(with event: NSEvent) {
        let button = Int32(event.buttonNumber + 1)
        sendMouseEvent(event, button: button, pressed: true)
    }

    override func otherMouseUp(with event: NSEvent) {
        let button = Int32(event.buttonNumber + 1)
        sendMouseEvent(event, button: button, pressed: false)
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }

        let deltaY = event.scrollingDeltaY
        if abs(deltaY) > 0.1 {
            let wheelButton: Int32 = deltaY > 0 ? 8 : 16
            let (remoteX, remoteY) = convertToRemoteCoordinates(point)

            sendPointerEvent?(x: remoteX, y: remoteY, buttonMask: wheelButton)

            // 修复：使用 [weak self] 避免主队列延迟闭包导致内存泄漏
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self else { return }
                sendPointerEvent?(x: remoteX, y: remoteY, buttonMask: currentButtonMask)
            }
        }
    }

    private func processMouseEvent(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }

        let (remoteX, remoteY) = convertToRemoteCoordinates(point)
        sendPointerEvent?(x: remoteX, y: remoteY, buttonMask: currentButtonMask)
    }

    private func sendMouseEvent(_ event: NSEvent, button: Int32, pressed: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }

        let buttonValue: Int32 = switch button {
        case 1: 1 // 左键
        case 2: 4 // 右键
        case 3: 2 // 中键
        default: 0
        }

        if pressed {
            currentButtonMask |= buttonValue
        } else {
            currentButtonMask &= ~buttonValue
        }

        let (remoteX, remoteY) = convertToRemoteCoordinates(point)
        sendPointerEvent?(x: remoteX, y: remoteY, buttonMask: currentButtonMask)
    }

    private func convertToRemoteCoordinates(_ point: CGPoint) -> (Int32, Int32) {
        let fbWidth = CGFloat(image?.width ?? Int(bounds.width))
        let fbHeight = CGFloat(image?.height ?? Int(bounds.height))

        guard bounds.width > 0, bounds.height > 0 else { return (0, 0) }

        let scaleX = fbWidth / bounds.width
        let scaleY = fbHeight / bounds.height

        let x = Int32(point.x * scaleX)
        let y = Int32((bounds.height - point.y) * scaleY) // Flip Y 轴适应 macOS 坐标系

        return (x, y)
    }

    // MARK: - 键盘事件处理

    override func flagsChanged(with event: NSEvent) {
        if let keysym = Self.macModifierMap[event.keyCode] {
            let wasPressed = isModifierPressed(event.keyCode, flags: lastModifierFlags)
            let isPressed = isModifierPressed(event.keyCode, flags: event.modifierFlags)
            if wasPressed != isPressed {
                sendKeyEvent?(keysym: keysym, down: isPressed)
            }
        }
        lastModifierFlags = event.modifierFlags
    }

    private func isModifierPressed(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 55, 54: flags.contains(.command)
        case 59, 62: flags.contains(.control)
        case 58, 61: flags.contains(.option)
        case 56, 60: flags.contains(.shift)
        default: false
        }
    }

    override func keyDown(with event: NSEvent) {
        sendKeyEvent(event, pressed: true)
    }

    override func keyUp(with event: NSEvent) {
        sendKeyEvent(event, pressed: false)
    }

    private func sendKeyEvent(_ event: NSEvent, pressed: Bool) {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        let isShiftPressed = modifierFlags.contains(.shift)
        let isCapsLockOn = modifierFlags.contains(.capsLock)
        let useUppercase = (isShiftPressed && !isCapsLockOn) || (!isShiftPressed && isCapsLockOn)
        let keysym = VNC.convertKeysym(keyCode: keyCode, useUppercase: useUppercase)
        sendKeyEvent?(keysym: keysym, down: pressed)
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
