// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "apc-core",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "APCCore",
            targets: ["APCCore"]
        ),
        .executable(
            name: "apc-daemon",
            targets: ["apc-daemon"]
        ),
        .executable(
            name: "apc",
            targets: ["apc"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "APCCore",
            dependencies: [],
            path: "Sources/APCCore"
        ),
        .executableTarget(
            name: "apc-daemon",
            dependencies: ["APCCore"],
            path: "Sources/apc-daemon"
        ),
        .executableTarget(
            name: "apc",
            dependencies: ["APCCore"],
            path: "Sources/apc-cli"
        )
    ]
)
