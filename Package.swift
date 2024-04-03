// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// The package manifest.
let package = Package(
    name: "SwiftUtils",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other
        // packages.
        .library(name: "SwiftUtils", targets: ["SwiftUtils"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "SwiftUtils"),
        .testTarget(name: "SwiftUtilsTests", dependencies: ["SwiftUtils"])
    ]
)
