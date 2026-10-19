// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "VNC",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "VNC", targets: ["VNC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/foxterm/libetos.git", branch: "main"),
        .package(url: "https://github.com/foxterm/Sync.git", branch: "main"),
        .package(url: "https://github.com/foxterm/Proxy.git", branch: "main"),
        .package(url: "https://github.com/foxterm/Extension.git", branch: "main"),
        .package(
            url: "https://github.com/krzyzanowskim/OpenSSL.git",
            from: "3.6.0001"
        ),
    ],
    targets: [
        .binaryTarget(
            name: "libvncclient",
            path: "libvncclient.xcframework"
        ),
        .target(
            name: "vnc_renderer"
        ),
        .target(
            name: "VNC",
            dependencies: [
                "libetos",
                "Sync",
                "Proxy",
                "Extension",
                "libvncclient",
                "vnc_renderer",
                .product(name: "OpenSSL", package: "OpenSSL"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedFramework("Security"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
    ]
)
