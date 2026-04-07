// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Genie",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Genie",
            path: "Sources/Genie",
            resources: [
                .process("../../Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
