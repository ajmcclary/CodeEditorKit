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
        ),
        .executable(
            name: "IsFlippedTest",
            targets: ["IsFlippedTest"]
        ),
        .executable(
            name: "EditableTest",
            targets: ["EditableTest"]
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
        .executableTarget(
            name: "IsFlippedTest",
            dependencies: [
                .product(name: "CodeEditorPlugin", package: "CodeEditorPlugin")
            ]
        ),
        .executableTarget(
            name: "EditableTest",
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