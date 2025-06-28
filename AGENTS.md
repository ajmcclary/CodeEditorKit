# AGENTS.md

This guide helps the Gemini code assistant understand the project structure, conventions, and commands to provide effective support.

## Build and Development Commands

**Building the Package:**
- `swift build`: Build the main package.
- `swift build -c release`: Build in release mode.
- `swift package clean`: Clean build artifacts.
- `swift package update`: Update dependencies.

**Code Quality and Linting:**
- `swiftlint --fix`: Fix lint violations automatically.
- `swiftlint`: Run linting (should show 0 violations).
- `swift build && swiftlint && swift test`: Combined build, lint, and test.

**Running Tests:**
- `swift test`: Run all tests for the main package.
- `cd CodeEditorSample && swift test`: Run sample app tests.

**Example Application:**
- `cd CodeEditorSample && swift run CodeEditorSample`: Build and run the example app.

## High-Level Architecture

The project follows a feature-based organization.

**Key Components:**
- **`CodeEditorView`**: The core TextKit2-based text view (`Sources/CodeEditorPlugin/Core/CodeEditorView.swift`).
- **`EditorConfiguration`**: A nested configuration system for the editor (`Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`).
- **`SyntaxHighlightingCoordinator`**: Manages syntax highlighting for multiple languages (`Sources/CodeEditorPlugin/SyntaxHighlighting/`).
- **`AnnotationsDataSource`**: Handles inline `TODO`/`FIXME` comment detection (`Sources/CodeEditorPlugin/Core/AnnotationsDataSource.swift`).
- **`GutterView`**: Renders line numbers and is cross-platform compatible (`Sources/CodeEditorPlugin/Layout/GutterView.swift`).

**Key Design Patterns:**
- **Protocol-Oriented Design**: Core functionality is defined by protocols like `CodeEditorViewProtocol` and `CodeEditorViewDelegate`.
- **Actor-Based Concurrency**: Swift 6 actors are used for background processing and thread safety.
- **Platform Abstraction**: A system in `Sources/CodeEditorPlugin/Platform/` provides cross-platform types and capabilities.

## Directory Structure

The `Sources/CodeEditorPlugin/` directory is organized by feature:

- `Core/`: Core text editing components.
- `Configuration/`: Editor configuration system.
- `SyntaxHighlighting/`: Syntax highlighting logic.
- `Layout/`: View components like the gutter and line numbers.
- `SwiftUI/`: SwiftUI integration and wrappers.
- `Extensions/`: All Swift extensions, named with a `+Extensions` suffix.
- `Models/`: Data models used throughout the plugin.
- `Platform/`: Cross-platform abstraction layer.

## Platform and Dependencies

- **Platforms**: macOS 12.0+, iOS 16.0+, Mac Catalyst 16.0+
- **Swift Version**: 6.0+
- **Dependencies**: `swift-syntax` for Swift syntax highlighting.

## Testing

- **Main Package Tests**: Located in `Tests/CodeEditorPluginTests/`.
- **Sample App Tests**: Located in `CodeEditorSample/Tests/CodeEditorSampleTests/`.
- Run tests using the `swift test` command as described above.