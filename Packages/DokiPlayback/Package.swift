// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DokiPlayback",
    platforms: [
        .tvOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "DokiPlayback", targets: ["DokiPlayback"])
    ],
    dependencies: [
        .package(path: "../DokiCore")
    ],
    targets: [
        .target(
            name: "DokiPlayback",
            dependencies: ["DokiCore"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "DokiPlaybackTests",
            dependencies: ["DokiPlayback", "DokiCore"]
        )
    ]
)
