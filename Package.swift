// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TestingExtensions",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "TestingExtensions", targets: ["TestingExtensions"]),
        .library(name: "TestingExtensionsDynamic", type: .dynamic, targets: ["TestingExtensions"])
    ],
    dependencies: [
        .package(name: "swift-snapshot-testing", url: "https://github.com/pointfreeco/swift-snapshot-testing.git", .upToNextMajor(from: "1.10.0")),
        .package(name: "SwiftRex", url: "https://github.com/SwiftRex/SwiftRex.git", .upToNextMajor(from: "0.8.12"))
    ],
    targets: [
        .target(
            name: "TestingExtensions",
            dependencies: [
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "CombineRexDynamic", package: "SwiftRex")
            ]
        )
    ]
)
