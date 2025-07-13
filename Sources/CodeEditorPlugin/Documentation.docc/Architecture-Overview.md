# Architecture Overview

@Metadata {
    @PageColor(orange)
}

Understand the modern, feature-based architecture that powers CodeEditorPlugin.

## Overview

CodeEditorPlugin uses a clean, modern architecture optimized for performance, maintainability, and extensibility. Built with Swift 6's actor system, it provides thread-safe operations while maintaining a responsive UI. Recent major refactoring (2025) includes enhanced platform abstractions using `#if canImport()` patterns, a unified wrapper system for cross-platform support, and comprehensive architectural improvements.

## Feature-Based Organization

The codebase is organized by feature rather than by type, providing several benefits:

- **Streamlined Organization**: 18 directories (down from 22) for better discoverability
- **Self-Contained Features**: Each feature includes its own models, views, and logic
- **Faster Development**: No jumping between directories to understand a feature
- **Better Testability**: Feature isolation makes testing straightforward

### Directory Structure (Reorganized 2025)

```
Sources/CodeEditorPlugin/
├── Core/                    # Core functionality, APIs, business logic (40+ files)
├── Text/                    # Unified text handling (TextKit, layout, processing)
├── Layout/                  # UI components, view models (GutterView, MinimapView)
├── Configuration/           # Settings and validation system
├── SyntaxHighlighting/      # Language highlighting (17+ languages)
├── Languages/               # Language-specific providers
├── Completion/              # Code completion with view model
├── Features/                # Optional features (flat structure)
├── SwiftUI/                 # SwiftUI integration (CodeEditor)
├── Platform/                # Cross-platform abstractions
├── Extensions/              # Type extensions (+Extensions naming)
├── Performance/             # Monitoring and optimization
├── LSP/                     # Language Server Protocol
├── Annotations/             # Code annotation system
├── Models/                  # Data models
├── Utilities/               # Shared utilities
└── Documentation.docc/      # DocC documentation
```

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
- **Reduced Navigation**: 18 directories instead of 22 means less hunting for files
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

The enhanced platform abstraction layer enables true cross-platform support:

- **Unified Types**: `PlatformColor`, `PlatformFont`, `PlatformView`
- **Enhanced Patterns**: All `#if os()` replaced with `#if canImport()` for better Catalyst support
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
- Replaced all `#if os()` with `#if canImport()` patterns throughout codebase
- Replaced direct UIColor/NSColor with `PlatformColors`
- Enhanced concurrency safety with proper actor isolation
- Fixed platform-specific build issues
- Added CrossPlatformCoordinator for unified input handling

### Quality Achievements
- **53 comprehensive tests** with 100% pass rate
- **Zero SwiftLint violations** across 333 source files
- **Enhanced cross-platform consistency**
- **Directory streamlining** from 22 to 18 directories for better discoverability

## See Also

- <doc:Platform-Abstraction>
- <doc:Swift6-Concurrency>
- <doc:Configuration-System>