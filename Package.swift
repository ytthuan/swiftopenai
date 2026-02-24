// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftOpenAI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SwiftOpenAI",
            targets: ["SwiftOpenAI"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftOpenAI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftOpenAITests",
            dependencies: ["SwiftOpenAI"]
        ),
    ]
)
