// swift-tools-version: 5.9
import PackageDescription

let kPackage = Package(
    name: "MyApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    dependencies: [
        // Add CodeEditorPlugin as a dependency
        .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                // Add to your target dependencies
                .product(name: "CodeEditorPlugin", package: "CodeEditorPlugin")
            ]
        )
    ]
)
