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
        .package(url: "https://github.com/foxterm/libetos.git", from: "1.0.9"),
        .package(url: "https://github.com/foxterm/Sync.git", from: "1.0.9"),
        .package(url: "https://github.com/foxterm/Proxy.git", from: "1.0.9"),
        .package(url: "https://github.com/foxterm/Extension.git", from: "1.0.9"),
        .package(url: "https://github.com/foxterm/OpenSSL.git", from: "1.0.9"),
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
                .product(name: "libetos", package: "libetos"),
                .product(name: "Sync", package: "Sync"),
                .product(name: "Proxy", package: "Proxy"),
                .product(name: "Extension", package: "Extension"),
                .product(name: "OpenSSL", package: "OpenSSL"),
                "libvncclient",
                "vnc_renderer",
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                /// .linkedLibrary("sasl2", .when(platforms: [.macOS])),
                .linkedFramework("Security"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
    ]
)
