// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FCPXMLMaker",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "FCPXMLMaker",
            dependencies: [
                .product(name: "SwiftWhisper", package: "SwiftWhisper")
            ],
            path: "Sources/FCPXMLMaker"
        )
    ]
)
