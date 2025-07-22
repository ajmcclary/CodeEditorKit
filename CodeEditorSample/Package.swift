// swift-tools-version: 6.0

/// CodeEditorSample Package Configuration
///
/// This package provides a comprehensive demonstration application for the CodeEditorPlugin,
/// showcasing its capabilities across macOS, iOS, and Mac Catalyst platforms.
///
/// ## Overview
///
/// The CodeEditor Sample app demonstrates:
/// - **Syntax Highlighting**: Live demos for 17+ programming languages
/// - **Interactive Configuration**: Real-time editor customization
/// - **Cross-Platform Support**: Optimized for macOS, iOS, and Mac Catalyst
/// - **Advanced Features**: Annotations, performance monitoring, and themes
/// - **Sample Code Library**: Real-world code examples for each language
///
/// ## Requirements
///
/// - **Swift**: 6.0 or later
/// - **Platforms**:
///   - macOS 14.0+
///   - iOS 16.0+
///   - Mac Catalyst 16.0+
///
/// ## Building and Running
///
/// ```bash
/// # Build the sample app
/// swift build
///
/// # Run the sample app
/// swift run CodeEditorSample
///
/// # Run tests
/// swift test
/// ```
///
/// ## Project Structure
///
/// The sample app is organized into feature-based modules:
/// - **Models**: Data structures and state management
/// - **Views**: SwiftUI interface components
/// - **Services**: Business logic and coordination
/// - **Themes**: Theme management and customization
///
/// ## Key Features
///
/// - **Unified Interface**: Single codebase supporting all platforms
/// - **Responsive Design**: Adapts to different screen sizes and orientations
/// - **Configuration Export**: Save and share editor configurations
/// - **Language Detection**: Automatic language identification
/// - **Performance Monitoring**: Real-time metrics and optimization
///
/// ## Dependencies
///
/// - **CodeEditorPlugin**: The main code editor component library
///
/// ## Development
///
/// This sample serves as both a demonstration and a testing ground for
/// CodeEditorPlugin features. It's designed to showcase best practices
/// for integrating the editor into real applications.
///
/// - Note: The sample app uses the local CodeEditorPlugin via relative path dependency
///
/// - SeeAlso: The main CodeEditorPlugin package for core functionality

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
        .package(path: ".."),
        .package(url: "https://github.com/daikimat/depermaid.git", from: "1.1.0")
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
        )
    ]
)
