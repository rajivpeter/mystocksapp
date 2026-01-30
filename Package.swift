// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MyStocksApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MyStocksApp",
            targets: ["MyStocksApp"]
        ),
    ],
    dependencies: [
        // Add external dependencies here
        // .package(url: "https://github.com/example/package", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MyStocksApp",
            dependencies: [],
            path: "MyStocksApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
