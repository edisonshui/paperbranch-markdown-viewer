// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PaperbranchEditorProofHost",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PaperbranchBridgeCore"),
        .executableTarget(
            name: "PaperbranchEditorProofHost",
            dependencies: ["PaperbranchBridgeCore"]
        ),
        .testTarget(
            name: "PaperbranchBridgeCoreTests",
            dependencies: ["PaperbranchBridgeCore"]
        ),
    ]
)
