// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PixelCatPop",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "PixelCatPop", targets: ["PixelCatPop"])
    ],
    targets: [
        .executableTarget(
            name: "PixelCatPop",
            path: "Sources/PixelCatPop",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PixelCatPopTests",
            dependencies: ["PixelCatPop"],
            path: "Tests/PixelCatPopTests"
        )
    ]
)
