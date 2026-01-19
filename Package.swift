// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

/// CodeEditorPlugin Package Configuration
///
/// This package provides a production-ready code editor component for Swift applications
/// with comprehensive syntax highlighting, code completion, and cross-platform support.
///
/// ## Requirements
///
/// - **Swift**: 6.0 or later
/// - **Platforms**:
///   - macOS 14.0+
///   - iOS 16.0+
///   - Mac Catalyst 16.0+
///
/// ## Installation
///
/// Add to your `Package.swift`:
/// ```swift
/// dependencies: [
///     .package(url: "https://github.com/yourusername/CodeEditorPlugin.git", from: "1.0.0")
/// ]
/// ```
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

let ksettings: [SwiftSetting] = [
    // Enable strict concurrency checking for Swift 6 compatibility
    .enableExperimentalFeature("StrictConcurrency")
]

let kpackage = Package(
    name: "CodeEditorPlugin",
    platforms: [.macOS(.v14), .iOS(.v16), .macCatalyst(.v16)],
    products: [
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/daikimat/depermaid.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            exclude: [
                "Info.plist"
            ],
            swiftSettings: ksettings
        ),
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: ["CodeEditorPlugin"],
            swiftSettings: ksettings
        )
    ]
)
