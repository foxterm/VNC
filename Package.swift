// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "VNC",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
    ],
    products: [
        .library(name: "VNC", targets: ["VNC"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/krzyzanowskim/OpenSSL.git", from: "3.6.0001"
        ),
        .package(url: "https://github.com/foxterm/SSH.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "VNC",
            dependencies: [
                .target(name: "libvncclient"),
                .target(name: "vnc_renderer"),
                .product(name: "Extension", package: "SSH"),
                .product(name: "libetos", package: "SSH"),
                .product(name: "Sync", package: "SSH"),
                .product(name: "Proxy", package: "SSH"),
                .product(name: "OpenSSL", package: "OpenSSL"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("sasl2", .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "vnc_renderer",
            dependencies: [
            ]
        ),
        .binaryTarget(
            name: "libvncclient",
            path: "xcframework/libvncclient.xcframework"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
