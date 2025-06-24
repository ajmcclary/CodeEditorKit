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

### Code Quality
```bash
# Format code
swiftformat --swiftversion 6.0 .

# Lint code (with auto-fix)
swiftlint --fix

# Run linter
swiftlint

# Full quality check sequence
swiftformat --swiftversion 6.0 . && swiftlint --fix && swiftlint && swift build && swift test
```

## High-Level Architecture

### Directory Structure (Simplified)

```
Sources/CodeEditorPlugin/
├── Core/                   # Core text editing components
│   ├── STTextView.swift    # Main text view (TextKit2)
│   └── Delegates/          # STTextViewDelegate & protocol
├── SyntaxHighlighting/     # All highlighting logic unified
│   ├── Coordinator.swift   # Main highlighting system
│   ├── SwiftSyntax/        # Swift AST-based highlighting
│   └── Regex/              # Regex-based for other languages
├── TextProcessing/         # Actor-based text processing
├── RangeProcessing/        # Actor-based range validation
├── Layout/                 # Layout and view components
│   ├── STGutterView.swift  # Line numbers
│   └── Fragments/          # Text layout fragments
├── Plugins/                # Plugin system
│   ├── PluginCore/         # Core plugin infrastructure
│   └── Annotations/        # Annotation plugin
├── Extensions/             # All extensions (flattened)
├── Models/                 # Data models
├── Completion/             # Code completion
├── Platform/               # Platform-specific code
└── CodeEditorPlugin.swift  # Main module file
```

### Core Components

1. **STTextView** - The main text view component built on TextKit2
   - Located in `Sources/CodeEditorPlugin/Core/STTextView.swift`
   - Provides the core editing functionality with modern TextKit2 integration
   - Supports features like line numbers, syntax highlighting, and plugin system

2. **Plugin System** - Extensible architecture for adding functionality
   - Protocol: `STPlugin` in `Sources/CodeEditorPlugin/Plugins/PluginCore/STPlugin.swift`
   - Events flow through `STPluginEvents` for text changes and UI updates
   - Each plugin can have a coordinator for complex state management

3. **Syntax Highlighting** - Multi-language support with two strategies
   - `SyntaxHighlightingCoordinator` in `Sources/CodeEditorPlugin/SyntaxHighlighting/`
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

### Working with the Simplified Structure

**Finding Components:**
- Core text editing → `Core/`
- Syntax highlighting → `SyntaxHighlighting/`
- Text/range processing → `TextProcessing/` or `RangeProcessing/`
- UI components → `Layout/`
- Type extensions → `Extensions/` (all in one place with +Extensions naming)

**Extension Naming Convention:**
- Use `+Extensions` suffix for extension files
- Example: `NSColor+Extensions.swift`, `String+Extensions.swift`
- SwiftLint `file_name` rule disabled to allow this pattern

**Feature-Based Organization Benefits:**
- Related code is co-located (e.g., all syntax highlighting together)
- Easier to understand component boundaries
- Simpler imports and module structure
- Better for navigation and maintenance

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

**Directory Structure Simplification (Latest)**
- Reduced from 39 to 13 directories (67% reduction)
- Transitioned from type-based to feature-based organization
- Flattened Extensions directory structure
- Eliminated 19 single-file directories
- Adopted +Extensions naming convention for clarity

**TextKit2 Synchronization Fixes**
- Unified text update mechanism through `NSTextContentStorage`
- Proper synchronization between text storage and layout manager
- Ensures consistent rendering across all text changes
- See `STTextView_Fix_Summary.md` for details

**Code Quality Improvements**
- SwiftLint configuration with custom rules
- SwiftFormat integration for consistent styling
- Zero linting violations maintained
- Comprehensive test coverage (69 tests total)