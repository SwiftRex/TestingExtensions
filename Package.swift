// swift-tools-version:5.2
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
        .package(name: "SnapshotTesting", url: "https://github.com/pointfreeco/swift-snapshot-testing.git", .branch("master")),
        .package(name: "SwiftRex", url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.7.1")
    ],
    targets: [
        .target(name: "TestingExtensions", dependencies: ["SnapshotTesting", .product(name: "CombineRexDynamic", package: "SwiftRex")])
    ]
)