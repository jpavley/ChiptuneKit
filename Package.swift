// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChiptuneKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ChiptuneKit",
            targets: ["ChiptuneKit"]
        ),
    ],
    targets: [
        .target(
            name: "ChiptuneKit"
        ),
        .testTarget(
            name: "ChiptuneKitTests",
            dependencies: ["ChiptuneKit"]
        ),
    ]
)
