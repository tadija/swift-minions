// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "AEKit",

    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .macOS(.v12)
    ],

    products: [
        .library(
            name: "AEKit",
            targets: ["AEKit"]
        ),
    ],

    dependencies: [],

    targets: [
        .target(
            name: "AEKit",
            dependencies: []
        ),
        .testTarget(
            name: "AEKitTests",
            dependencies: ["AEKit"]
        ),
    ]
)
