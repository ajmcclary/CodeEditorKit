# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building the Package
```bash
# Build the main package
swift build

# Build in release mode
swift build -c release

# Clean build artifacts
swift package clean

# Update dependencies
swift package update
```

### Running Tests
```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose
```

### Example Application
```bash
# Build and run the example application
cd CodeEditorSample
swift build
swift run
```

## High-Level Architecture

### Core Components

1. **STTextView** - The main text view component built on TextKit2
   - Located in `Sources/CodeEditorPlugin/Services/TextServices/STTextView.swift`
   - Provides the core editing functionality with modern TextKit2 integration
   - Supports features like line numbers, syntax highlighting, and plugin system

2. **Plugin System** - Extensible architecture for adding functionality
   - Protocol: `STPlugin` in `Sources/CodeEditorPlugin/Middleware/PluginSystem/Plugin.swift`
   - Events flow through `STPluginEvents` for text changes and UI updates
   - Each plugin can have a coordinator for complex state management

3. **Syntax Highlighting** - Multi-language support with two strategies
   - `SyntaxHighlightingCoordinator` manages the overall system
   - SwiftSyntax integration for Swift code (requires swift-syntax dependency)
   - Regex-based highlighting for other languages

4. **Annotation System** - Line-based annotations for inline documentation
   - `STLineAnnotation` protocol defines the interface
   - Data source pattern via `STAnnotationsDataSource`
   - Integrated through the plugin system

### Key Design Patterns

1. **Protocol-Oriented Design**
   - `STTextViewProtocol` defines the core text view interface
   - `STTextViewDelegate` for comprehensive event handling
   - `TextSystemInterface` provides abstract text system access

2. **Type Aliases for Public API**
   - `CodeEditorTextView` → `STTextView`
   - `CodeEditorDelegate` → `STTextViewDelegate`
   - `CodeEditorPluginProtocol` → `STPlugin`
   - Defined in `Sources/CodeEditorPlugin/CodeEditorPlugin.swift`

3. **Versioned Content System**
   - Tracks text changes with version numbers
   - Enables efficient range validation and updates
   - Critical for maintaining consistency in concurrent operations

4. **Actor-Based Concurrency**
   - Background processing with Swift 6 actors
   - `BackgroundProcessor` for async operations
   - Thread-safe range validation and processing

### Platform Support

- **macOS**: 12.0+
- **iOS**: 16.0+
- **Mac Catalyst**: 16.0+
- **Swift**: 6.0+ (uses experimental concurrency features)

### Dependencies

- **swift-syntax** (510.0.0+): Used for Swift language syntax highlighting

### Performance Considerations

- Hardware acceleration support for large files
- Viewport-based rendering for efficiency
- Background processing for syntax highlighting
- Read-only mode available for viewing without editing overhead

### Testing Approach

Tests are located in `Tests/CodeEditorPluginTests/`. The project uses Swift Package Manager's built-in testing support. Key test files include:
- `STTextViewTests.swift` - Core text view functionality
- `SyntaxHighlightingTests.swift` - Highlighting system tests
- `ConfigurationTests.swift` - Configuration system tests

### Recent Architecture Changes

The project recently addressed TextKit2 synchronization issues (see `STTextView_Fix_Summary.md`):
- Unified text update mechanism through `NSTextContentStorage`
- Proper synchronization between text storage and layout manager
- Ensures consistent rendering across all text changes