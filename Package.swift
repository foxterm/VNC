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
        .package(url: "https://github.com/krzyzanowskim/OpenSSL.git", .upToNextMinor(from: "3.6.5000")),
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
                .linkedLibrary("sasl2", .when(platforms: [.macOS])),
                .linkedFramework("Security"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
    ]
)
