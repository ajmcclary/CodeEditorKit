// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodeEditorSample",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CodeEditorSample",
            targets: ["CodeEditorSample"]
        )
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "CodeEditorSample",
            dependencies: [
                .product(name: "CodeEditorPlugin", package: "CodeEditorPlugin")
            ]
        ),
        .testTarget(
            name: "CodeEditorSampleTests",
            dependencies: [
                "CodeEditorSample",
                .product(name: "CodeEditorPlugin", package: "CodeEditorPlugin")
            ]
        ),
    ]
)