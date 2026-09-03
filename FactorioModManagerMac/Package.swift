// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactorioModManagerMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FactorioModManagerMac",
            targets: ["FactorioModManagerMac"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0")
    ],
    targets: [
        .executableTarget(
            name: "FactorioModManagerMac",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/FactorioModManager"
        ),
        .testTarget(
            name: "FactorioModManagerTests",
            dependencies: ["FactorioModManagerMac"],
            path: "Tests/FactorioModManagerTests"
        ),
    ]
)
