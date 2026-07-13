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
            name: "CodeEditorAnnotations",
            targets: ["CodeEditorAnnotations"]
        ),
        .library(
            name: "CodeEditorCommon",
            targets: ["CodeEditorCommon"]
        ),
        .library(
            name: "CodeEditorCompletion",
            targets: ["CodeEditorCompletion"]
        ),
        .library(
            name: "CodeEditorConfiguration",
            targets: ["CodeEditorConfiguration"]
        ),
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorLSP",
            targets: ["CodeEditorLSP"]
        ),
        .library(
            name: "CodeEditorLanguages",
            targets: ["CodeEditorLanguages"]
        ),
        .library(
            name: "CodeEditorLayout",
            targets: ["CodeEditorLayout"]
        ),
        .library(
            name: "CodeEditorPlatform",
            targets: ["CodeEditorPlatform"]
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
            name: "CodeEditorSwiftUI",
            targets: ["CodeEditorSwiftUI"]
        ),
        .library(
            name: "CodeEditorTextModel",
            targets: ["CodeEditorTextModel"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
        .library(
            name: "CodeEditorView",
            targets: ["CodeEditorView"]
        ),
        .library(
            name: "CodeEditorWorkspace",
            targets: ["CodeEditorWorkspace"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ajmcclary/DesignKit.git", from: "1.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        // TEMP: using ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable
        // because upstream 1.19.x fails to build under Swift 6.3's Testing
        // Attachment APIs. Revert to upstream after pointfreeco/swift-snapshot-testing#1090
        // lands in a tagged release.
        .package(url: "https://github.com/ajmcclary/swift-snapshot-testing", branch: "fix-swift-6.3-attachable"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0")
    ],
    targets: [
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
            dependencies: ["CodeEditorCommon", "CodeEditorPlatform"],
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
            name: "CodeEditorLanguages",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
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
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorSyntaxHighlighting",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorAnnotations",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                .product(name: "DesignKitThemes", package: "DesignKit")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorCompletion",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
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
            name: "CodeEditorLSP",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLayout",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorPlatform",
                "CodeEditorSyntaxHighlighting",
                .product(name: "DesignKitThemes", package: "DesignKit")
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
            name: "CodeEditorView",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorWorkspace",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSmartEditing",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSwiftUI",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorLanguages",
                "CodeEditorSwiftUI",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView"
            ],
            exclude: [
                "Info.plist"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorUI",
            dependencies: [
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorLanguages",
                "CodeEditorSwiftUI",
                "CodeEditorSymbols",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorPlugin",
                "CodeEditorSwiftUI",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView",
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
            name: "CodeEditorCommonTests",
            dependencies: ["CodeEditorCommon", "CodeEditorDiagnostics"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorTextModelTests",
            dependencies: ["CodeEditorCommon", "CodeEditorTextModel"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorCompletionTests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorDiagnostics",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorLSPTests",
            dependencies: ["CodeEditorCommon", "CodeEditorDiagnostics", "CodeEditorLSP"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorViewTests",
            dependencies: [
                "CodeEditorAnnotations", "CodeEditorCommon", "CodeEditorCompletion",
                "CodeEditorConfiguration", .product(name: "DesignKitTokens", package: "DesignKit"), "CodeEditorDiagnostics",
                "CodeEditorFolding", "CodeEditorLSP", "CodeEditorLanguages", "CodeEditorLayout",
                "CodeEditorPlatform", "CodeEditorSearch", "CodeEditorSmartEditing",
                "CodeEditorSymbols", "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel", .product(name: "DesignKitThemes", package: "DesignKit"), "CodeEditorView",
                .product(name: "CustomDump", package: "swift-custom-dump")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorSwiftUITests",
            dependencies: [
                "CodeEditorAnnotations", "CodeEditorCommon", "CodeEditorCompletion",
                "CodeEditorConfiguration", "CodeEditorDiagnostics", "CodeEditorFolding",
                "CodeEditorLSP", "CodeEditorLanguages", "CodeEditorLayout", "CodeEditorPlatform",
                "CodeEditorSwiftUI", "CodeEditorSymbols", "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel", .product(name: "DesignKitThemes", package: "DesignKit"), "CodeEditorView",
                .product(name: "CustomDump", package: "swift-custom-dump")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorUITests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorLanguages",
                "CodeEditorPlugin",
                "CodeEditorSwiftUI",
                "CodeEditorSymbols",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorUI",
                "CodeEditorView",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "Snapshots/__Snapshots__"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorHygieneTests",
            swiftSettings: swiftSettings
        )
    ]
)
