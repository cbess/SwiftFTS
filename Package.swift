// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftFTS",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .macCatalyst(.v16),
        .tvOS(.v16),
        .visionOS(.v2)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftFTS",
            targets: ["SwiftFTS"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftFTS",
            cSettings: [
                 .define("SQLITE_ENABLE_FTS5", to: "1")
            ]
        ),
        .testTarget(
            name: "SwiftFTSTests",
            dependencies: ["SwiftFTS"]
        ),
    ]
)
