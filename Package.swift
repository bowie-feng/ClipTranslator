// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipTranslator",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "ClipTranslator",
            path: "Sources",
            resources: []
        )
    ]
)
