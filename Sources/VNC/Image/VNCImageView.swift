// FoxTerm | VNCImageView.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import libvncclient
import SwiftUI
#if os(macOS)
    import AppKit

    public typealias PlatformViewRepresentable = NSViewRepresentable
    public typealias PlatformView = NSView
#elseif os(iOS)
    import UIKit

    public typealias PlatformViewRepresentable = UIViewRepresentable
    public typealias PlatformView = UIView
#endif

// MARK: - iOS Touch Mode

#if os(iOS)
    /// VNC 触摸交互模式
    public enum VNCTouchMode {
        /// 直接触摸: 点击即单击，拖动即移动 (如同直接触摸远程屏幕)
        case direct
        /// 触控板模式: 手指移动光标，点击触发单击 (如同使用触控板)
        case trackpad
    }
#endif

/// VNC 远程桌面画面视图 (跨平台)
///
/// 基于 `NSViewRepresentable` (macOS) / `UIViewRepresentable` (iOS) 封装，
/// 将 `CGImage` 帧数据渲染到 `CALayer` 上，并捕获鼠标/键盘/触摸事件发送给远端。
/// 通过 SwiftUI `Environment` 注入图像数据与事件回调。
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
            view.sendPointerEvent = sendPointerEvent
            view.sendKeyEvent = sendKeyEvent

            if isActive {
                view.image = cgImage
                if view.isHidden {
                    view.isHidden = false
                    view.becomeFirstResponder()
                    #if os(macOS)
                        DispatchQueue.main.async {
                            view.window?.makeFirstResponder(view)
                        }
                    #endif
                }
            } else if !view.isHidden {
                view.resignFirstResponder()
                view.isHidden = true
                view.image = nil
            }
        }
    }
}

/// VNC 事件处理视图
///
/// 负责将 `CGImage` 渲染到 `CALayer` 并捕获所有输入事件 (鼠标、键盘、触摸手势)，
/// 通过 `sendPointerEvent` 和 `sendKeyEvent` 回调将事件传递给 VNC 客户端。
/// 使用 `CATransaction` 禁用隐式动画以消除渲染延迟。
public class VNCEventHandlingView: PlatformView {
    var sendPointerEvent: sendVNCPointerEvent?
    var sendKeyEvent: sendVNCKeyEvent?

    private var currentButtonMask: Int32 = 0

    #if os(iOS)
        var touchMode: VNCTouchMode {
            get { _touchMode }
            set { _touchMode = newValue }
        }

        private var _touchMode: VNCTouchMode = .direct
        private var isDragging = false
        private var lastScrollPoint: CGPoint = .zero

        private lazy var lightHaptic = UIImpactFeedbackGenerator(style: .light)
        private lazy var mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
        private lazy var heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    #endif

    var image: CGImage? {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.contents = image
            CATransaction.commit()
        }
    }

    /// 渲染层，禁用隐式动画以匹配 VNC 帧推送节奏
    private lazy var imageLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .resize
        layer.isOpaque = true
        layer.actions = [
            "contents": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
        ]
        return layer
    }()

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
            setupGestures()
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

        override public var canBecomeFirstResponder: Bool {
            true
        }

        // MARK: - Gesture Setup

        func setupGestures() {
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            doubleTap.delegate = self

            let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
            singleTap.numberOfTapsRequired = 1
            singleTap.require(toFail: doubleTap)
            singleTap.delegate = self

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.5
            longPress.delegate = self

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 1
            pan.maximumNumberOfTouches = 1
            pan.delegate = self

            let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            twoFingerPan.delegate = self

            let pinch = UIPinchGestureRecognizer(target: self, action: nil)
            pinch.delegate = self

            addGestureRecognizer(doubleTap)
            addGestureRecognizer(singleTap)
            addGestureRecognizer(longPress)
            addGestureRecognizer(pan)
            addGestureRecognizer(twoFingerPan)
            addGestureRecognizer(pinch)
        }

        // MARK: - Gesture Handlers

        @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: self)
            guard bounds.contains(point) else { return }

            if !isFirstResponder {
                becomeFirstResponder()
            }

            let (rx, ry) = convertToRemoteCoordinates(point)
            sendPointerEvent?(x: rx, y: ry, buttonMask: 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                sendPointerEvent?(x: rx, y: ry, buttonMask: 0)
            }
            lightHaptic.impactOccurred()
        }

        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: self)
            guard bounds.contains(point) else { return }

            let (rx, ry) = convertToRemoteCoordinates(point)

            sendPointerEvent?(x: rx, y: ry, buttonMask: 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                guard let self else { return }
                sendPointerEvent?(x: rx, y: ry, buttonMask: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                    guard let self else { return }
                    sendPointerEvent?(x: rx, y: ry, buttonMask: 1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                        guard let self else { return }
                        sendPointerEvent?(x: rx, y: ry, buttonMask: 0)
                    }
                }
            }
            mediumHaptic.impactOccurred()
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            let point = gesture.location(in: self)
            guard bounds.contains(point) else { return }

            switch gesture.state {
            case .began:
                if !isFirstResponder {
                    becomeFirstResponder()
                }
                let (rx, ry) = convertToRemoteCoordinates(point)
                sendPointerEvent?(x: rx, y: ry, buttonMask: 4)
                heavyHaptic.impactOccurred()
            case .ended, .cancelled:
                let (rx, ry) = convertToRemoteCoordinates(point)
                sendPointerEvent?(x: rx, y: ry, buttonMask: 0)
            default:
                break
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let point = gesture.location(in: self)
            guard bounds.contains(point) else { return }

            switch gesture.state {
            case .began:
                if !isFirstResponder {
                    becomeFirstResponder()
                }
                isDragging = true
                if _touchMode == .direct {
                    currentButtonMask = 1
                    sendPointerEvent(at: point, buttonMask: 1)
                }
            case .changed:
                if _touchMode == .direct, isDragging {
                    sendPointerEvent(at: point, buttonMask: 1)
                } else if _touchMode == .trackpad {
                    sendPointerEvent(at: point, buttonMask: currentButtonMask)
                }
            case .ended, .cancelled:
                if _touchMode == .direct {
                    sendPointerEvent(at: point, buttonMask: 0)
                }
                isDragging = false
            default:
                break
            }
        }

        @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            let point = gesture.location(in: self)

            switch gesture.state {
            case .began:
                lastScrollPoint = point
            case .changed:
                let translation = gesture.translation(in: self)
                let deltaY = translation.y

                if abs(deltaY) > 3 {
                    let wheelButton: Int32 = deltaY > 0 ? 16 : 8
                    let (rx, ry) = convertToRemoteCoordinates(point)
                    sendPointerEvent?(x: rx, y: ry, buttonMask: wheelButton)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                        guard let self else { return }
                        let (rx2, ry2) = convertToRemoteCoordinates(point)
                        sendPointerEvent?(x: rx2, y: ry2, buttonMask: 0)
                    }
                    gesture.setTranslation(.zero, in: self)
                }
            case .ended, .cancelled:
                lastScrollPoint = .zero
            default:
                break
            }
        }

        private func sendPointerEvent(at point: CGPoint, buttonMask: Int32) {
            guard bounds.contains(point) else { return }
            let (rx, ry) = convertToRemoteCoordinates(point)
            sendPointerEvent?(x: rx, y: ry, buttonMask: buttonMask)
        }
    }

    extension VNCEventHandlingView: UIGestureRecognizerDelegate {
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer, otherGestureRecognizer is UIPinchGestureRecognizer {
                return true
            }
            if gestureRecognizer is UIPinchGestureRecognizer, otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }

        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive _: UITouch) -> Bool {
            if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
                if panGesture.minimumNumberOfTouches == 2 {
                    return true
                }
            }
            return true
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

        /// 捕获 Control / Shift / Option / Command 等修饰键变化
        override func flagsChanged(with event: NSEvent) {
            let keyCode = event.keyCode
            let keysym = VNC.convertKeysym(keyCode: keyCode, useUppercase: false)

            guard keysym != XK_VoidSymbol else { return }

            // 根据按键状态判断是按下还是释放
            let isPressed: Bool
            switch keyCode {
            case 56, 59, 60: isPressed = event.modifierFlags.contains(.shift)
            case 55, 54: isPressed = event.modifierFlags.contains(.command)
            case 58, 61: isPressed = event.modifierFlags.contains(.option)
            case 62, 63: isPressed = event.modifierFlags.contains(.control)
            case 57: isPressed = event.modifierFlags.contains(.capsLock)
            default: return
            }

            sendKeyEvent?(keysym: keysym, down: isPressed)
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

// MARK: - 坐标转换

extension VNCEventHandlingView {
    /// 将视图本地坐标转换为远程桌面像素坐标
    ///
    /// 根据帧缓冲区尺寸与视图尺寸的比例进行缩放；macOS 需翻转 Y 轴 (原点在左下角)，
    /// iOS 与 VNC 协议原点一致 (左上角)，无需翻转。
    /// - Parameter point: 视图本地坐标点
    /// - Returns: 远程桌面的 (x, y) 像素坐标
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
