
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WiPeerKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "WiPeerKit",
            targets: ["WiPeerKit"]
        ),
        .executable(
            name: "WiPeerKitCLI",
            targets: ["WiPeerKitCLI"]
        ),
    ],
    dependencies: [
        // No external dependencies - using only Apple frameworks
    ],
    targets: [
        .target(
            name: "WiPeerKit",
            dependencies: [],
            path: "Sources/WiPeerKit"
        ),
        .executableTarget(
            name: "WiPeerKitCLI",
            dependencies: ["WiPeerKit"],
            path: "Tools/WiPeerKitCLI"
        ),
        .testTarget(
            name: "WiPeerKitTests",
            dependencies: ["WiPeerKit"],
            path: "Tests/WiPeerKitTests"
        ),
    ]
)
