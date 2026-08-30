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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FactorioModManagerMac",
            dependencies: [],
            path: "Sources/FactorioModManager"
        ),
        .testTarget(
            name: "FactorioModManagerTests",
            dependencies: ["FactorioModManagerMac"],
            path: "Tests/FactorioModManagerTests"
        ),
    ]
)
