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
            url: "https://github.com/krzyzanowskim/OpenSSL.git", .upToNextMajor(from: "3.6.0001")
        ),
        .package(url: "https://github.com/foxterm/SSH.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "VNC",
            dependencies: [
                .target(name: "libvncclient"),
                .product(name: "Extension", package: "SSH"),
                .product(name: "libetos", package: "SSH"),
                .product(name: "Sync", package: "SSH"),
                .product(name: "OpenSSL", package: "OpenSSL"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .binaryTarget(
            name: "libvncclient",
            path: "xcframework/libvncclient.xcframework"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
