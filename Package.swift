
// swift-tools-version: 6.1
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
            targets: ["WiPeerKit"]),
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
        .testTarget(
            name: "WiPeerKitTests",
            dependencies: ["WiPeerKit"],
            path: "Tests/WiPeerKitTests"
        ),
    ]
)
