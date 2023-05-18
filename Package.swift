// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "swift-minions",

    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .macOS(.v12)
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
