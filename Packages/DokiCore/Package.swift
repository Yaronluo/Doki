// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DokiCore",
    platforms: [
        .tvOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "DokiCore", targets: ["DokiCore"])
    ],
    targets: [
        .target(
            name: "DokiCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "DokiCoreTests",
            dependencies: ["DokiCore"]
        )
    ]
)
