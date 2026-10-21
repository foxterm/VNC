# VNC

[English](README.md) | [中文文档](README_CN.md)

A dedicated VNC client library for the FoxTerm APP. Built as a Swift wrapper around libvncclient, it supports remote desktop connections, frame rendering, keyboard/mouse input, and clipboard synchronization.

> This library is a dedicated core component for the [FoxTerm](https://foxterm.app/) APP. Download it here: [https://foxterm.app/](https://foxterm.app/)

## Features

- **VNC Protocol** — Full RFB client implementation based on libvncclient
- **Multiple Authentication** — VNC password authentication, VeNCrypt, X509 certificates, username/password credentials
- **Frame Rendering** — Frame buffer to CGImage real-time conversion, supporting 32/16/8-bit color depth
- **Keyboard & Mouse Input** — Full mouse events (move/click/scroll wheel) and keyboard events (macOS keyCode to X11 keysym mapping)
- **Cross-Platform View** — `VNCImageView` wrapper (macOS NSViewRepresentable / iOS UIViewRepresentable)
- **iOS Touch Gestures** — Single tap, double tap, long press (right-click), drag, two-finger scroll, supporting both direct touch and trackpad modes
- **Clipboard Sync** — Remote clipboard reception (UTF-8) and local clipboard sending
- **Port Forwarding** — SOCKS5 / HTTP proxy connection support
- **JPEG Compression** — Configurable JPEG quality and data compression levels
- **Desktop Size Changes** — Dynamic detection of remote resolution changes
- **Real-Time FPS** — Frame rate statistics and callbacks
- **Bell Notification** — Remote Bell events trigger local sound/haptic feedback

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 17.0           |
| macOS    | 14.0           |
| Swift    | 5.10           |

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/foxterm/VNC.git", branch: "main"),
```

```swift
.product(name: "VNC", package: "VNC"),
```

### CocoaPods

```ruby
pod 'VNC', :git => 'https://github.com/foxterm/VNC.git'
```

### Dependencies

- [libetos](https://github.com/foxterm/libetos) — Low-level socket
- [Sync](https://github.com/foxterm/Sync) — Concurrency synchronization primitives
- [Proxy](https://github.com/foxterm/Proxy) — Network proxy
- [Extension](https://github.com/foxterm/Extension) — Foundation extensions
- [OpenSSL-Universal](https://github.com/krzyzanowskim/OpenSSL) — OpenSSL cryptographic toolkit
- [LibVNC](https://github.com/LibVNC/libvncserver.git) — VNC protocol implementation (upstream, includes libvncclient)

## Usage

### Establishing a Connection

```swift
let vnc = VNC(host: "192.168.1.100", port: 5900, password: "password")

// Register delegate
vnc.vncDelegate = self

// 1. TCP Socket connection
guard await vnc.connect() else { return }

// Or connect via proxy
// guard await vnc.connect(proxy: proxyConfig) else { return }

// 2. VNC handshake
guard await vnc.handshake() else { return }
```

### Configuration Options

```swift
vnc.preferredColorDepth = .bit32    // Color depth: .bit32 / .bit16 / .bit8
vnc.enableJPEG = true               // JPEG compression
vnc.qualityLevel = 9                // JPEG quality (1-9)
vnc.compressLevel = 6               // Data compression (1-9)
vnc.isCursor = true                 // Show remote cursor
```

### X509 TLS Authentication

```swift
vnc.caCertPath = "/path/to/ca.pem"
vnc.caCrlPath = "/path/to/ca-crl.pem"      // Optional
vnc.clientCertPath = "/path/to/client.pem"  // Optional
vnc.clientKeyPath = "/path/to/client.key"   // Optional
```

### Keyboard & Mouse Input

```swift
// Mouse move + click
vnc.sendPointerEvent(x: 100, y: 200, buttonMask: 1)  // Left button pressed
vnc.sendPointerEvent(x: 100, y: 200, buttonMask: 0)  // Released

// Mouse button
vnc.sendMouseButtonEvent(x: 100, y: 200, button: 1, pressed: true)  // Left button
vnc.sendMouseButtonEvent(x: 100, y: 200, button: 3, pressed: true)  // Right button

// Scroll wheel
vnc.sendMouseWheelEvent(x: 100, y: 200, wheelDelta: 3)

// Keyboard
vnc.sendKeyEvent(keysym: XK_a, down: true)
vnc.sendKeyEvent(keysym: XK_a, down: false)

// Character input
vnc.sendCharacterEvent(character: "A", pressed: true)

// macOS keyCode to X11 keysym
let keysym = VNC.convertKeysym(keyCode: event.keyCode, useUppercase: false)
```

### Clipboard

```swift
// Send local text to remote clipboard
vnc.sendToRemoteClipboard("Copied text")

// Receive remote clipboard (via cutText property)
let remoteText = vnc.cutText
```

### SwiftUI View

```swift
struct RemoteDesktopView: View {
    @State var cgImage: CGImage?
    @State var isActive = false

    var body: some View {
        VNCImageView()
            .environment(\.cgImage, cgImage)
            .environment(\.isVNCActive, isActive)
            .sendPointerEvent { x, y, buttonMask in
                vnc.sendPointerEvent(x: x, y: y, buttonMask: buttonMask)
            }
            .sendKeyEvent { keysym, down in
                vnc.sendKeyEvent(keysym: keysym, down: down)
            }
    }
}
```

### Delegate Callbacks

```swift
extension ViewController: VNCDelegate {
    func disconnect() {
        // Connection disconnected
    }

    func buffer(vnc: VNC, image: CGImage?) {
        // New frame received, update UI
        cgImage = image
    }

    func handleDesktopSizeChange(width: Int, height: Int) {
        // Remote resolution changed
    }

    func handleFPSChange(eps: Double) {
        // Frame rate updated
    }
}
```

## Project Structure

```
Sources/
├── VNC/
│   ├── VNC.swift           # Core client class
│   ├── Client.swift        # Handshake, event loop, disconnect
│   ├── Socket.swift        # TCP connection, proxy, event polling
│   ├── Auth.swift          # Authentication (password, credentials, X509)
│   ├── Callbacks.swift     # libvncclient C callback registration & event handling
│   ├── FrameBuffer.swift   # Frame buffer to CGImage extraction
│   ├── KeyEvent.swift      # Keyboard/mouse input, keyCode mapping
│   ├── Protocol.swift      # VNCDelegate protocol
│   ├── Type.swift          # ColorDepth enum
│   └── Image/
│       ├── VNCImageView.swift  # Cross-platform rendering view + event handling
│       └── Environment.swift   # SwiftUI Environment injection
└── vnc_renderer/
    ├── vnc_renderer.c          # C-level pixel format conversion
    └── include/vnc_renderer.h
libvncclient.xcframework/       # Precompiled libvncclient (iOS + macOS)
```

## License

MIT
