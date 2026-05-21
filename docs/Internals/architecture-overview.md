# Architecture Overview

Understand the modern, feature-based architecture that powers CodeEditorPlugin.

## Overview

CodeEditorPlugin uses a modular architecture optimized for performance, maintainability, and extensibility. Built with Swift 6's actor system, it provides thread-safe operations while maintaining a responsive UI. The current architecture includes platform abstractions based on `#if canImport()` patterns, native AppKit / UIKit TextKit2 surfaces, and an umbrella product over focused SwiftPM targets.

## Feature-Based Organization

The codebase is organized by feature and product boundary rather than by type. The pre-0.2.0 single large source tree was extracted into sibling SwiftPM targets so cross-module ownership is explicit and consumers can depend on narrower products where useful.

### Directory Structure

```
Sources/
├── CodeEditorPlugin/             # Umbrella target: re-export hub only
├── CodeEditorView/               # TextKit2 editor surface and view-coupled services
├── CodeEditorSwiftUI/            # SwiftUI `CodeEditor` wrapper and environment
├── CodeEditorUI/                 # Optional SwiftUI chrome/components
├── CodeEditorConfiguration/      # Settings, presets, validation
├── CodeEditorTheming/            # Theme model, loader, bundled theme JSON
├── CodeEditorSyntaxHighlighting/ # SwiftSyntax/regex highlighters and range-query helpers
├── CodeEditorLanguages/          # Language catalog, detection, folding/symbol interfaces
├── CodeEditorCompletion/         # Completion manager, ranking, providers, UI adapters
├── CodeEditorLSP/                # LSP clients, manager, transports, wire types
├── CodeEditorDiagnostics/        # Performance/memory monitoring and diagnostics UI
├── CodeEditorTextModel/          # RangeStore, line geometry, TextKit2 primitives
├── CodeEditorPlatform/           # Platform aliases, capabilities, constants, helpers
├── CodeEditorCommon/             # Shared errors, models, utilities, extensions
├── CodeEditorAnnotations/        # Annotation model and view chrome
├── CodeEditorFolding/            # Fold-storage primitives and provider registry
├── CodeEditorSymbols/            # Symbol-navigation data surfaces
├── CodeEditorLayout/             # Layout primitives and reusable chrome internals
├── CodeEditorSmartEditing/       # Auto-bracket, multi-cursor, indentation, selection engines
├── CodeEditorSearch/             # Opt-in project-wide search protocols/adapters
├── CodeEditorWorkspace/          # Opt-in workspace file-tree protocols/adapters
└── CodeEditorSample/             # Executable demo app
```

(Long-form prose docs live in the top-level [`docs/`](../README.md) folder, not inside `Sources/`.)

**Key boundaries**:
- **Umbrella vs. direct products**: `CodeEditorPlugin` re-exports the common host-facing modules, while products such as `CodeEditorLSP`, `CodeEditorSearch`, `CodeEditorWorkspace`, `CodeEditorDiagnostics`, and `CodeEditorUI` can be imported directly.
- **View-coupled code stays in `CodeEditorView`**: `CodeEditorView`, `CodeEditorAPI`, `EditorDocuments`, in-document `SearchReplaceEngine`, view-coupled LSP adapters, folding presentation, minimap/gutter views, and TextKit2 setup live together.
- **Portable models moved out**: shared data structures, language descriptors, folding storage, symbol storage, configuration, theming, platform helpers, and text-model primitives live in separate targets.
- **Optional project surfaces stay opt-in**: project-wide search and workspace file-tree protocols are products, but the umbrella does not depend on them.

**Benefits of the extraction**:
- **Clear ownership**: module names now describe runtime boundaries, not just folders.
- **Narrower imports**: tests and clients can import `CodeEditorView`, `CodeEditorSwiftUI`, `CodeEditorDiagnostics`, or other focused modules directly.
- **Smaller public entry point**: the umbrella target has one Swift file plus resources and exists to preserve the simple `import CodeEditorPlugin` path.
- **Better test reach**: internal symbols are tested through the modules that own them instead of through an overgrown umbrella target.

## Core Components

### CodeEditorView

The heart of the editor, built on TextKit2 and owned by the `CodeEditorView` target:

- Modern text editing with TextKit2
- Cross-platform support with proper iOS container architecture
- Comprehensive delegate system for customization
- Support for annotations, line numbers, and syntax highlighting

### EditorConfiguration

A sophisticated configuration system with:

- Nested structure: display, layout, behavior, performance
- Immutable `with(display:)`, `with(layout:)`, `with(behavior:)`, and `with(performance:)` updates
- Eight built-in presets for common scenarios and platforms
- Live configuration updates without view recreation

### SyntaxHighlightingCoordinator

Manages multi-language syntax highlighting across `CodeEditorSyntaxHighlighting`, `CodeEditorLanguages`, and the view-coupled controller in `CodeEditorView`:

- SwiftSyntax integration for accurate Swift highlighting
- Strategy-based highlighting for the remaining supported languages
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

The enhanced platform abstraction layer enables true cross-platform support:

- **Unified Types**: `PlatformColor`, `PlatformFont`, `PlatformView`
- **Enhanced Patterns**: All `#if os()` replaced with `#if canImport()` for cleaner two-platform conditionals (macOS / iOS)
- **Capability Detection**: Runtime feature availability checking via `PlatformCapabilities`
- **CrossPlatformCoordinator**: Unified input handling for `CodeEditorView`
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

### Configuration

Configuration uses direct nested values:

```swift
var config = EditorConfiguration()
config.display.isLineNumbersEnabled = true
config.display.isSyntaxHighlightingEnabled = true
config.layout.tabWidth = 4
```

## Performance Optimizations

- **Viewport Rendering**: Only visible content is processed
- **Incremental Parsing**: Only changed sections are re-parsed
- **Background Processing**: Syntax highlighting happens off the main thread
- **Memory Efficiency**: Large files are handled with streaming

## Recent Architecture Improvements

### SwiftUI Representable Bridge
- Uses platform-specific SwiftUI representables for AppKit and UIKit text views
- Shares coordinator setup where possible while preserving native platform behavior
- Applies configuration through `EditorConfiguration` and the consolidated `CodeEditorEnvironment`

### Platform Abstraction Enhancements
- Replaced all `#if os()` with `#if canImport()` patterns throughout codebase
- Replaced direct UIColor/NSColor with `PlatformColors`
- Enhanced concurrency safety with proper actor isolation
- Fixed platform-specific build issues
- Added CrossPlatformCoordinator for unified input handling

### Quality Achievements
- **221 `*Tests.swift` files** across 4 test targets covering editor, configuration, platform, language, UI, sample, and performance paths
- **589 Swift files under `Sources/`**, with the umbrella `Sources/CodeEditorPlugin/` reduced to a single re-export file
- **Enhanced cross-platform consistency**
- **Module organization** aligned with SwiftPM target boundaries for discoverability

## See Also

- [Platform-Abstraction](../Platform/platform-abstraction.md)
- [Swift6-Concurrency](../Concurrency/swift6.md)
- [Configuration-System](../Configuration/system.md)
