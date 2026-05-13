// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

/// CodeEditorPlugin Package Configuration
///
/// This package provides a production-ready code editor component for Swift applications
/// with comprehensive syntax highlighting, code completion, and cross-platform support.
///
/// ## Requirements
///
/// - **Swift**: 6.3 or later
/// - **Platforms** (intentional — targets the current Apple OS family):
///   - macOS 26.3+
///   - iOS 26.3+
///
/// Mac Catalyst is **not supported.** The framework went pure SwiftUI +
/// native AppKit/UIKit in 0.2.0 — see `CHANGELOG.md` for the rationale.
///
/// Consumers on older OS releases should pin a future LTS tag rather than expect
/// the floor to be lowered. See `docs/README.md` § Platform Requirements.
///
/// ## Installation
///
/// Add to your `Package.swift`:
/// ```swift
/// dependencies: [
///     .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "0.1.0")
/// ]
/// ```
///
/// ## License
///
/// MIT — see `LICENSE` at the repo root.
///
/// ## Dependencies
///
/// - **SwiftSyntax**: For Swift language AST-based syntax highlighting
///
/// ## Build Configuration
///
/// - Strict concurrency checking enabled for Swift 6 compatibility
/// - Optimized for both debug and release builds

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    // Enable strict concurrency checking for Swift 6 compatibility
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "CodeEditorPlugin",
    platforms: [.macOS("26.3"), .iOS("26.3")],
    products: [
        .library(
            name: "CodeEditorDesignTokens",
            targets: ["CodeEditorDesignTokens"]
        ),
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
        .executable(
            name: "CodeEditorSample",
            targets: ["CodeEditorSample"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        // TEMP: using ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable
        // because upstream 1.19.x fails to build under Swift 6.3's Testing
        // Attachment APIs. Revert to upstream after pointfreeco/swift-snapshot-testing#1090
        // lands in a tagged release.
        .package(url: "https://github.com/ajmcclary/swift-snapshot-testing", branch: "fix-swift-6.3-attachable"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
        .target(
            name: "CodeEditorDesignTokens",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorDesignTokens",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("Resources/Themes")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorUI",
            dependencies: [
                "CodeEditorDesignTokens",
                "CodeEditorPlugin"
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "CodeEditorSample",
            dependencies: [
                "CodeEditorDesignTokens",
                "CodeEditorPlugin",
                "CodeEditorUI"
            ],
            resources: [
                .process("Resources/SampleSnippets")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorPlugin",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "__Snapshots__",
                "Theming/__Snapshots__"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorDesignTokensTests",
            dependencies: [
                "CodeEditorDesignTokens",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "__Snapshots__"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorUITests",
            dependencies: [
                "CodeEditorUI",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "Snapshots/__Snapshots__"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorSampleTests",
            dependencies: [
                "CodeEditorSample"
            ],
            swiftSettings: swiftSettings
        )
    ]
)
