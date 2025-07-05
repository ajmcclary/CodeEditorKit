# Architecture Overview

@Metadata {
    @PageColor(orange)
}

Understand the modern, feature-based architecture that powers CodeEditorPlugin.

## Overview

CodeEditorPlugin uses a clean, modern architecture optimized for performance, maintainability, and extensibility. Built with Swift 6's actor system, it provides thread-safe operations while maintaining a responsive UI. Recent enhancements include a unified wrapper system for cross-platform support and comprehensive platform abstractions.

## Feature-Based Organization

The codebase is organized by feature rather than by type, providing several benefits:

- **74% Directory Reduction**: Simplified from 39 to 10 directories
- **Self-Contained Features**: Each feature includes its own models, views, and logic
- **Faster Development**: No jumping between directories to understand a feature
- **Better Testability**: Feature isolation makes testing straightforward

### Directory Structure

```
Sources/CodeEditorPlugin/
├── Core/                    # Text editing engine (CodeEditorView)
├── Configuration/           # EditorConfiguration system
├── SyntaxHighlighting/      # Language support (17 languages)
├── Layout/                  # UI components (GutterView)
├── SwiftUI/                 # SwiftUI integration (CodeEditor)
├── Platform/                # Cross-platform abstractions
├── Extensions/              # Type extensions (+Extensions naming)
├── TextProcessing/          # Actor-based processing
├── LSP/                     # Language Server Protocol
└── Documentation.docc/      # DocC documentation
```

## Core Components

### CodeEditorView

The heart of the editor, built on TextKit2:

- Modern text editing with TextKit2
- Cross-platform support with proper iOS container architecture
- Comprehensive delegate system for customization
- Support for annotations, line numbers, and syntax highlighting

### EditorConfiguration

A sophisticated configuration system with:

- Nested structure: display, layout, behavior, performance
- Builder pattern with immutable updates
- Five built-in presets for common use cases
- Live configuration updates without view recreation

### SyntaxHighlightingCoordinator

Manages multi-language syntax highlighting:

- SwiftSyntax integration for accurate Swift highlighting
- Regex-based highlighting for 16+ other languages
- Viewport-based rendering for optimal performance
- Background processing to maintain UI responsiveness

## Actor-Based Concurrency

All intensive operations use Swift 6's actor system:

```swift
actor BackgroundProcessor {
    func processLargeFile(_ content: String) async -> ProcessedResult {
        // Heavy processing happens here, UI stays responsive
    }
}
```

Benefits:
- **Thread Safety**: Data races are impossible, not just unlikely
- **UI Responsiveness**: Heavy operations never block the main thread
- **Scalability**: Automatic work distribution across cores
- **Future-Proof**: Built on Apple's latest concurrency model

## Platform Abstraction

The platform abstraction layer enables true cross-platform support:

- **Unified Types**: `PlatformColor`, `PlatformFont`, `PlatformView`
- **Capability Detection**: Runtime feature availability checking
- **Native Performance**: No abstraction penalties
- **50% Less Platform Code**: Write once, deploy everywhere

## Design Patterns

### Protocol-Oriented Design

```swift
protocol CodeEditorViewProtocol {
    var text: String { get set }
    var language: Language? { get set }
    func applyConfiguration(_ config: EditorConfiguration)
}
```

### Versioned Content System

Tracks changes with version numbers for:
- Efficient range validation
- Consistent concurrent operations
- Optimized update cycles

### Builder Pattern

Configuration uses builders for flexibility:

```swift
let config = EditorConfigurationBuilder()
    .showLineNumbers(true)
    .enableSyntaxHighlighting(true)
    .tabWidth(4)
    .build()
```

## Performance Optimizations

- **Viewport Rendering**: Only visible content is processed
- **Incremental Parsing**: Only changed sections are re-parsed
- **Background Processing**: Syntax highlighting happens off the main thread
- **Memory Efficiency**: Large files are handled with streaming

## Recent Architecture Improvements

### Unified Wrapper System
- Implemented `CodeEditorViewWrapperProtocol` for sample app
- Platform-specific implementations: `MacOSCodeEditorViewWrapper`, `IOSCodeEditorViewWrapper`
- Eliminated code duplication through protocol-based architecture

### Platform Abstraction Enhancements
- Replaced direct UIColor/NSColor with `PlatformColors`
- Enhanced concurrency safety with proper actor isolation
- Fixed platform-specific build issues

### Quality Achievements
- **319 comprehensive tests** with 100% pass rate
- **Zero build errors** and SwiftLint violations
- **Enhanced cross-platform consistency**

## See Also

- <doc:Platform-Abstraction>
- <doc:Swift6-Concurrency>
- <doc:Configuration-System>