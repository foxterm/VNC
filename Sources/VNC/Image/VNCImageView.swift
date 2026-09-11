// FoxTerm | VNCImageView.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import SwiftUI
import VNC

#if os(macOS)
    import AppKit

    public typealias PlatformViewRepresentable = NSViewRepresentable
    public typealias PlatformView = NSView
#elseif os(iOS)
    import UIKit

    public typealias PlatformViewRepresentable = UIViewRepresentable
    public typealias PlatformView = UIView
#endif

public struct VNCImageView: PlatformViewRepresentable {
    @Environment(\.cgImage) var cgImage
    @Environment(\.isVNCActive) var isActive
    @Environment(\.sendPointerEvent) var sendPointerEvent
    @Environment(\.sendKeyEvent) var sendKeyEvent

    public init() {}

    #if os(macOS)
        public func makeNSView(context _: Context) -> VNCEventHandlingView {
            let view = VNCEventHandlingView(frame: .zero)
            setupView(view)
            return view
        }

        public func updateNSView(_ view: VNCEventHandlingView, context _: Context) {
            updateView(view)
        }
    #elseif os(iOS)
        public func makeUIView(context _: Context) -> VNCEventHandlingView {
            let view = VNCEventHandlingView(frame: .zero)
            setupView(view)
            return view
        }

        public func updateUIView(_ view: VNCEventHandlingView, context _: Context) {
            updateView(view)
        }
    #endif

    private func setupView(_ view: VNCEventHandlingView) {
        view.sendPointerEvent = sendPointerEvent
        view.sendKeyEvent = sendKeyEvent
    }

    private func updateView(_ view: VNCEventHandlingView) {
        autoreleasepool {
            view.image = cgImage
            view.sendPointerEvent = sendPointerEvent
            view.sendKeyEvent = sendKeyEvent

            if isActive {
                if view.isHidden {
                    view.isHidden = false
                    #if os(macOS)
                        DispatchQueue.main.async {
                            view.window?.makeFirstResponder(view)
                        }
                    #endif
                    view.becomeFirstResponder()
                }
            } else {
                if !view.isHidden {
                    view.resignFirstResponder()
                    view.isHidden = true
                    // 隐藏时释放显存，避免后台驻留 GPU 内存
                    view.image = nil
                }
            }
        }
    }
}

public class VNCEventHandlingView: PlatformView {
    var sendPointerEvent: sendVNCPointerEvent?
    var sendKeyEvent: sendVNCKeyEvent?

    private var currentButtonMask: Int32 = 0

    #if os(macOS)
        private var lastModifierFlags: NSEvent.ModifierFlags = []
    #endif

    var image: CGImage? {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if image == nil {
                imageLayer.contents = nil
            } else {
                imageLayer.contents = image
            }
            CATransaction.commit()
        }
    }

    private lazy var imageLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .resize
        layer.isOpaque = true
        layer.actions = [
            "contents": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
        ]
//        #if os(macOS)
//            layer.drawsAsynchronously = true
//        #endif
        return layer
    }()

    #if os(macOS)
        private static let macModifierMap: [UInt16: Int32] = [
            55: 0xFFEB, 54: 0xFFEC,
            59: 0xFFE3, 62: 0xFFE4,
            58: 0xFFE9, 61: 0xFFEA,
            56: 0xFFE1, 60: 0xFFE2,
        ]
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        #if os(macOS)
            wantsLayer = true
            layerContentsRedrawPolicy = .never

            layer?.isOpaque = true
            layer?.addSublayer(imageLayer)
        #elseif os(iOS)
            isMultipleTouchEnabled = true
            layer.isOpaque = true
            layer.addSublayer(imageLayer)
        #endif
    }

    #if os(macOS)
        override public func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.frame = bounds
            CATransaction.commit()
        }
    #elseif os(iOS)
        override public func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.frame = bounds
            CATransaction.commit()
        }
    #endif

    deinit {
        image = nil
        #if DEBUG
            print("♻️♻️♻️♻️", "VNCEventHandlingView")
        #endif
    }
}

// MARK: - iOS Touch & Keyboard Event Handling

#if os(iOS)
    extension VNCEventHandlingView: UIKeyInput {
        public var hasText: Bool {
            true
        }

        public func insertText(_ text: String) {
            for scalar in text.unicodeScalars {
                let keysym = Int32(scalar.value)
                sendKeyEvent?(keysym: keysym, down: true)
                sendKeyEvent?(keysym: keysym, down: false)
            }
        }

        public func deleteBackward() {
            let backspaceKeysym: Int32 = 0xFF08
            sendKeyEvent?(keysym: backspaceKeysym, down: true)
            sendKeyEvent?(keysym: backspaceKeysym, down: false)
        }

        override public func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
            guard let touch = touches.first else { return }
            let point = touch.location(in: self)

            if !isFirstResponder {
                becomeFirstResponder()
            }

            currentButtonMask = 1
            sendPointerEvent(at: point, buttonMask: currentButtonMask)
        }

        override public func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
            guard let touch = touches.first else { return }
            let point = touch.location(in: self)
            sendPointerEvent(at: point, buttonMask: currentButtonMask)
        }

        override public func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
            guard let touch = touches.first else { return }
            let point = touch.location(in: self)
            currentButtonMask = 0
            sendPointerEvent(at: point, buttonMask: currentButtonMask)
        }

        override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            touchesEnded(touches, with: event)
        }

        private func sendPointerEvent(at point: CGPoint, buttonMask: Int32) {
            guard bounds.contains(point) else { return }
            let (remoteX, remoteY) = convertToRemoteCoordinates(point)
            sendPointerEvent?(x: remoteX, y: remoteY, buttonMask: buttonMask)
        }

        override public var canBecomeFirstResponder: Bool {
            true
        }
    }
#endif

// MARK: - macOS Event Handling

#if os(macOS)
    public extension VNCEventHandlingView {
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
            case 1: 1
            case 2: 4
            case 3: 2
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
#endif

// MARK: - Shared Helpers

extension VNCEventHandlingView {
    private func convertToRemoteCoordinates(_ point: CGPoint) -> (Int32, Int32) {
        let fbWidth = CGFloat(image?.width ?? Int(bounds.width))
        let fbHeight = CGFloat(image?.height ?? Int(bounds.height))

        guard bounds.width > 0, bounds.height > 0 else { return (0, 0) }

        let scaleX = fbWidth / bounds.width
        let scaleY = fbHeight / bounds.height

        let x = Int32(point.x * scaleX)

        #if os(macOS)
            // macOS 原点在左下角，需要翻转 Y 轴
            let y = Int32((bounds.height - point.y) * scaleY)
        #else
            // iOS 原点在左上角，与 VNC 协议一致，无需翻转 Y 轴
            let y = Int32(point.y * scaleY)
        #endif

        return (x, y)
    }
}
