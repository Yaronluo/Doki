// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DokiDanmaku",
    platforms: [
        .tvOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "DokiDanmaku", targets: ["DokiDanmaku"])
    ],
    targets: [
        .target(
            name: "DokiDanmaku",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "DokiDanmakuTests",
            dependencies: ["DokiDanmaku"]
        )
    ]
)
