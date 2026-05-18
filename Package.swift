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
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
        .library(
            name: "CodeEditorSearch",
            targets: ["CodeEditorSearch"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
        .library(
            name: "CodeEditorWorkspace",
            targets: ["CodeEditorWorkspace"]
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
            name: "CodeEditorCommon",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorTextModel",
            dependencies: ["CodeEditorCommon"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorPlatform",
            dependencies: ["CodeEditorCommon"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorConfiguration",
            dependencies: ["CodeEditorCommon", "CodeEditorPlatform", "CodeEditorTextModel"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorTheming",
            dependencies: ["CodeEditorCommon", "CodeEditorDesignTokens"],
            resources: [
                .process("Resources/Themes")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLanguages",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            path: "Sources/CodeEditorPlugin/Languages",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorDiagnostics",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            path: "Sources/CodeEditorDiagnostics",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSyntaxHighlighting",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorSyntaxHighlighting",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorFolding",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSearch",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSymbols",
            dependencies: [
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorWorkspace",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            exclude: [
                "Info.plist",
                "Languages"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorUI",
            dependencies: [
                "CodeEditorDesignTokens",
                "CodeEditorLanguages",
                "CodeEditorPlugin",
                "CodeEditorTheming"
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "CodeEditorSample",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSearch",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                "CodeEditorUI",
                "CodeEditorWorkspace"
            ],
            exclude: [
                "README.md"
            ],
            resources: [
                .process("Resources/SampleSnippets")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSearch",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "__Snapshots__",
                "Theming/__Snapshots__",
                "Layout/__Snapshots__"
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
                "CodeEditorConfiguration",
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
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSample",
                "CodeEditorSearch",
                "CodeEditorWorkspace",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "__Snapshots__"
            ],
            swiftSettings: swiftSettings
        )
    ]
)
