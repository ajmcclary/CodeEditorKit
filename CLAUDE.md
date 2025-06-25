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

### Code Quality and Linting
```bash
# Fix lint violations automatically
swiftlint --fix

# Run linting (should show 0 violations)
swiftlint

# Combined build, lint, and test
swift build && swiftlint && swift test
```

### Running Tests
```bash
# Run all tests (71 tests in main package)
swift test

# Run tests with verbose output
swift test --verbose

# Run sample app tests (43 tests)
cd CodeEditorSample
swift test
```

### Example Application
```bash
# Build and run the example application
cd CodeEditorSample
swift build
swift run CodeEditorSample
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
├── Models/                 # Data models (including annotations)
├── Extensions/             # All extensions (flattened)
├── Completion/             # Code completion
├── Platform/               # Platform-specific code
└── CodeEditorPlugin.swift  # Main module file
```

### Core Components

1. **STTextView** - The main text view component built on TextKit2
   - Located in `Sources/CodeEditorPlugin/Core/STTextView.swift`
   - Provides the core editing functionality with modern TextKit2 integration
   - Supports features like line numbers, syntax highlighting, and annotations

2. **Annotation System** - Inline code comment detection and visualization
   - Detects TODO/FIXME/NOTE/WARNING/ERROR comments in code
   - Displays hover popups with annotation details
   - `AnnotationManager` handles detection and positioning
   - Data source pattern via `STAnnotationsDataSource`
   - Integrated through the plugin system with visual badges

3. **Syntax Highlighting** - Multi-language support with two strategies
   - `SyntaxHighlightingCoordinator` in `Sources/CodeEditorPlugin/SyntaxHighlighting/`
   - SwiftSyntax integration for Swift code (requires swift-syntax dependency)
   - Regex-based highlighting for other languages


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

Tests are located in `Tests/CodeEditorPluginTests/` (71 tests) and `CodeEditorSample/Tests/CodeEditorSampleTests/` (43 tests) for a total of 114 comprehensive tests. The project uses Swift Package Manager's built-in testing support. Key test files include:

**Main Package Tests (71 tests):**
- `STTextViewTests.swift` - Core text view functionality
- `SyntaxHighlightingTests.swift` - Highlighting system tests
- `ConfigurationTests.swift` - Configuration system tests
- `AnnotationTests.swift` - Annotation system functionality

**Sample App Tests (43 tests):**
- `AnnotationSystemTests.swift` - Comprehensive annotation testing with performance benchmarks
- `BasicFunctionalityTests.swift` - Core functionality verification
- `SampleCodeTests.swift` - Language sample validation
- `SimplifiedIntegrationTests.swift` - End-to-end integration testing

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
- Zero linting violations maintained across 102 files
- Swift 6 concurrency compliance with all actor isolation issues resolved
- Comprehensive test coverage (114 tests total: 71 main + 43 sample)

**Annotation System Implementation**
- Complete inline annotation system with TODO/FIXME/NOTE/WARNING/ERROR detection
- Hover popups for annotation details with styled presentation
- TextKit1-compatible annotation positioning for broad platform support
- Performance testing with large files and many annotations