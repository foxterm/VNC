# VNC

[English](README.md) | [中文文档](README_CN.md)

FoxTerm APP 专用 VNC 客户端库，基于 libvncclient 的 Swift 封装，支持远程桌面连接、帧渲染、键鼠输入及剪贴板同步。

> 本库为 [FoxTerm](https://foxterm.app/) APP 专用核心组件，欢迎下载使用：[https://foxterm.app/](https://foxterm.app/)

## 功能

- **VNC 协议** — 完整的 RFB 客户端实现，基于 libvncclient
- **多种认证** — VNC 密码认证、VeNCrypt、X509 证书、用户名/密码凭据
- **帧渲染** — 帧缓冲区 → CGImage 实时转换，支持 32/16/8 位色深
- **键鼠输入** — 完整的鼠标事件（移动/点击/滚轮）和键盘事件（macOS keyCode → X11 keysym 映射）
- **跨平台视图** — `VNCImageView` 封装（macOS NSViewRepresentable / iOS UIViewRepresentable）
- **iOS 触摸手势** — 单击、双击、长按（右键）、拖动、双指滚动，支持直接触摸和触控板两种模式
- **剪贴板同步** — 远端剪贴板接收（UTF-8）与本地剪贴板发送
- **端口转发** — 支持 SOCKS5 / HTTP 代理连接
- **JPEG 压缩** — 可配置 JPEG 质量和数据压缩级别
- **桌面尺寸变化** — 动态检测远端分辨率变更
- **实时 FPS** — 帧率统计与回调
- **蜂鸣提示** — 远端 Bell 事件触发本地声音/触觉反馈

## 环境要求

| 平台 | 最低版本 |
|------|---------|
| iOS  | 17.0    |
| macOS | 14.0   |
| Swift | 5.10   |

## 安装

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

### 依赖

- [libetos](https://github.com/foxterm/libetos) — 底层 Socket
- [Sync](https://github.com/foxterm/Sync) — 并发同步原语
- [Proxy](https://github.com/foxterm/Proxy) — 网络代理
- [Extension](https://github.com/foxterm/Extension) — Foundation 扩展
- [OpenSSL-Universal](https://github.com/krzyzanowskim/OpenSSL) — OpenSSL 加密工具库
- [LibVNC](https://github.com/LibVNC/libvncserver.git) — VNC 协议实现（上游，含 libvncclient）

## 使用

### 建立连接

```swift
let vnc = VNC(host: "192.168.1.100", port: 5900, password: "password")

// 注册代理
vnc.vncDelegate = self

// 1. TCP Socket 连接
guard await vnc.connect() else { return }

// 或通过代理连接
// guard await vnc.connect(proxy: proxyConfig) else { return }

// 2. VNC 握手
guard await vnc.handshake() else { return }
```

### 配置选项

```swift
vnc.preferredColorDepth = .bit32    // 色深：.bit32 / .bit16 / .bit8
vnc.enableJPEG = true               // JPEG 压缩
vnc.qualityLevel = 9                // JPEG 质量 (1-9)
vnc.compressLevel = 6               // 数据压缩 (1-9)
vnc.isCursor = true                 // 显示远程光标
```

### X509 TLS 认证

```swift
vnc.caCertPath = "/path/to/ca.pem"
vnc.caCrlPath = "/path/to/ca-crl.pem"      // 可选
vnc.clientCertPath = "/path/to/client.pem"  // 可选
vnc.clientKeyPath = "/path/to/client.key"   // 可选
```

### 键鼠输入

```swift
// 鼠标移动 + 点击
vnc.sendPointerEvent(x: 100, y: 200, buttonMask: 1)  // 左键按下
vnc.sendPointerEvent(x: 100, y: 200, buttonMask: 0)  // 释放

// 鼠标按键
vnc.sendMouseButtonEvent(x: 100, y: 200, button: 1, pressed: true)  // 左键
vnc.sendMouseButtonEvent(x: 100, y: 200, button: 3, pressed: true)  // 右键

// 滚轮
vnc.sendMouseWheelEvent(x: 100, y: 200, wheelDelta: 3)

// 键盘
vnc.sendKeyEvent(keysym: XK_a, down: true)
vnc.sendKeyEvent(keysym: XK_a, down: false)

// 字符输入
vnc.sendCharacterEvent(character: "A", pressed: true)

// macOS keyCode → X11 keysym
let keysym = VNC.convertKeysym(keyCode: event.keyCode, useUppercase: false)
```

### 剪贴板

```swift
// 发送本地文本到远端剪贴板
vnc.sendToRemoteClipboard("复制的文本")

// 接收远端剪贴板（通过 cutText 属性）
let remoteText = vnc.cutText
```

### SwiftUI 视图

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

### 代理回调

```swift
extension ViewController: VNCDelegate {
    func disconnect() {
        // 连接断开
    }

    func buffer(vnc: VNC, image: CGImage?) {
        // 收到新帧，更新 UI
        cgImage = image
    }

    func handleDesktopSizeChange(width: Int, height: Int) {
        // 远端分辨率变化
    }

    func handleFPSChange(eps: Double) {
        // 帧率更新
    }
}
```

## 项目结构

```
Sources/
├── VNC/
│   ├── VNC.swift           # 核心客户端类
│   ├── Client.swift        # 握手、事件循环、断开
│   ├── Socket.swift        # TCP 连接、代理、事件轮询
│   ├── Auth.swift          # 认证（密码、凭据、X509）
│   ├── Callbacks.swift     # libvncclient C 回调注册与事件响应
│   ├── FrameBuffer.swift   # 帧缓冲区 → CGImage 提取
│   ├── KeyEvent.swift      # 键鼠输入、keyCode 映射
│   ├── Protocol.swift      # VNCDelegate 协议
│   ├── Type.swift          # ColorDepth 枚举
│   └── Image/
│       ├── VNCImageView.swift  # 跨平台渲染视图 + 事件处理
│       └── Environment.swift   # SwiftUI Environment 注入
└── vnc_renderer/
    ├── vnc_renderer.c          # C 层像素格式转换
    └── include/vnc_renderer.h
libvncclient.xcframework/       # 预编译 libvncclient（iOS + macOS）
```

## 许可证

MIT
