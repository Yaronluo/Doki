// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DokiUI",
    platforms: [
        .tvOS(.v26)
    ],
    products: [
        .library(name: "DokiUI", targets: ["DokiUI"])
    ],
    dependencies: [
        .package(path: "../DokiCore"),
        .package(path: "../DokiDanmaku")
    ],
    targets: [
        .target(
            name: "DokiUI",
            dependencies: ["DokiCore", "DokiDanmaku"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        )
    ]
)
