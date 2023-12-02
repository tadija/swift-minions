// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "swift-minions",

    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],

    products: [
        .library(name: "Minions", targets: ["Minions"]),
    ],

    dependencies: [],

    targets: [
        .target(name: "Minions", dependencies: []),
        .testTarget(name: "MinionsTests", dependencies: ["Minions"]),
    ]
)
