// swift-tools-version: 6.0

import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "CodeEditorPlugin",
    platforms: [.macOS(.v12), .iOS(.v16), .macCatalyst(.v16)],
    products: [
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    ],
    targets: [
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            swiftSettings: settings
        ),
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: ["CodeEditorPlugin"],
            swiftSettings: settings
        ),
    ]
)
