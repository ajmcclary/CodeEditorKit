// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodeEditorSample",
    platforms: [
        .macOS(.v14), .iOS(.v16), .macCatalyst(.v16)
    ],
    products: [
        .executable(
            name: "CodeEditorSample",
            targets: ["CodeEditorSample"]
        )
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "CodeEditorSample",
            dependencies: [
                .product(name: "CodeEditorPlugin", package: "CodeEditorPlugin")
            ],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "CodeEditorSampleTests",
            dependencies: [
                "CodeEditorSample",
                .product(name: "CodeEditorPlugin", package: "CodeEditorPlugin")
            ]
        )
    ]
)
