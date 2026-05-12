# Architecture Overview

Understand the modern, feature-based architecture that powers CodeEditorPlugin.

## Overview

CodeEditorPlugin uses a clean, modern architecture optimized for performance, maintainability, and extensibility. Built with Swift 6's actor system, it provides thread-safe operations while maintaining a responsive UI. Recent major refactoring (2025) includes enhanced platform abstractions using `#if canImport()` patterns, a unified wrapper system for cross-platform support, and comprehensive architectural improvements.

## Feature-Based Organization

The codebase is organized by feature rather than by type, providing several benefits:

- **Streamlined Organization**: 20 top-level directories in the main target for better discoverability
- **Self-Contained Features**: Each feature includes its own models, views, and logic
- **Faster Development**: No jumping between directories to understand a feature
- **Better Testability**: Feature isolation makes testing straightforward

### Directory Structure (Reorganized 2025)

```
Sources/CodeEditorPlugin/
├── Core/                    # Core functionality, APIs, business logic
├── Text/                    # TextKit2, layout, parsing, range store, processing
├── Layout/                  # UI components, view models (GutterView, MinimapView)
├── Configuration/           # Settings and validation system
├── SyntaxHighlighting/      # Language highlighting and tree-sitter adapters
├── Languages/               # Language-specific providers
├── Completion/              # Code completion with view model
├── Features/                # Optional features (folding, smart editing, search/replace)
├── SwiftUI/                 # SwiftUI integration (CodeEditor)
├── Platform/                # Cross-platform abstractions
├── Extensions/              # Type extensions (+Extensions naming)
├── Performance/             # Monitoring and optimization
├── LSP/                     # Language Server Protocol
├── Annotations/             # Code annotation system
├── Search/                  # Search result and support types
├── Workspace/               # Workspace indexing/search types
├── Models/                  # Data models
├── Utilities/               # Shared utilities
└── Resources/               # Bundled theme JSON
```

(Long-form prose docs live in the top-level [`docs/`](../README.md) folder, not inside `Sources/`.)

**Key Changes (January 2025)**:
- **Consolidated Text Handling**: TextKit, TextLayout, and TextProcessing merged into unified `Text/` directory (34 files)
  - Combines all text manipulation, layout fragments, and async processing
  - Improves code discoverability by grouping related functionality
- **Merged Small Directories**: 
  - API → Core (public API surface now in Core/CodeEditorAPI.swift)
  - UIComponents → Layout (UI components with their ViewModels)
  - BusinessLogic → Core (services like TextEditingService, LanguageDetectionService)
- **Distributed ViewModels**: Moved to their respective feature directories
  - GutterViewModel now in Layout/ alongside GutterView
  - MinimapViewModel now in Layout/ alongside MinimapView
  - CompletionViewModel remains in Completion/ directory
- **Flattened Nested Structures**: 
  - Removed DebuggerIntegration subdirectory
  - Debugger features now directly in Features/ directory
- **New Service Layer**: Introduced business logic services in Core/
  - TextEditingService: Centralized text manipulation logic
  - EditorLayoutService: Layout calculations and management
  - LanguageDetectionService: Auto-detection of file types
  - SyntaxHighlightingService: Coordination of highlighting

**Benefits of Reorganization**:
- **Better Discoverability**: Related code now lives together (e.g., all text handling in one place)
- **Reduced Navigation**: feature ownership is concentrated in 20 main-target directories
- **Clearer Ownership**: ViewModels next to their Views makes relationships obvious
- **Service-Oriented**: New service layer provides clear API boundaries
- **Simplified Imports**: Fewer directories means cleaner import statements

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
- Immutable `with(display:)`, `with(layout:)`, `with(behavior:)`, and `with(performance:)` updates
- Eight built-in presets for common scenarios and platforms
- Live configuration updates without view recreation

### SyntaxHighlightingCoordinator

Manages multi-language syntax highlighting:

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
- **CrossPlatformCoordinator**: Unified input handling across all platforms
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
- **115 `*Tests.swift` files** across 4 test targets covering the major editor, configuration, platform, and language paths
- **Zero SwiftLint violations** across 453 Swift files in the main target and 513 Swift files under `Sources/`
- **Enhanced cross-platform consistency**
- **Directory organization** across 20 top-level main-target directories for discoverability

## See Also

- [Platform-Abstraction](../Platform/platform-abstraction.md)
- [Swift6-Concurrency](../Concurrency/swift6.md)
- [Configuration-System](../Configuration/system.md)
