# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CodeEditorPlugin is a **production-ready**, **Swift 6-based** code editor component for macOS, iOS, and Mac Catalyst. It features:
- **Modern Swift 6 actor-based concurrency** throughout the codebase
- **Sophisticated cross-platform abstraction layer** for true native performance
- **17 programming languages** supported with syntax highlighting
- **172 comprehensive tests** (106 main + 66 sample app)
- **Zero SwiftLint violations** across all files
- **Feature-based architecture** for maintainability (74% directory reduction)
- **Plugin architecture and LSP integration** for extensibility
- **Advanced features** including performance monitoring, code folding, and smart indentation

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
# Run all tests (106 tests in main package)
swift test

# Run tests with verbose output
swift test --verbose

# Run sample app tests (66 tests)
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

### Current Directory Structure (Feature-Based Organization)

The project uses a **feature-based organization** (simplified from 39 to 10 directories):

```
Sources/CodeEditorPlugin/
├── Core/                    # Core text editing components
│   ├── CodeEditorView.swift     # Main text view with TextKit2
│   ├── AnnotationsDataSource.swift # Annotation system integration
│   └── CodeEditorViewDelegate.swift # Comprehensive delegate system
├── Configuration/           # Unified configuration system
│   └── EditorConfiguration.swift   # Nested configuration structure
├── SyntaxHighlighting/      # All highlighting logic
│   ├── SyntaxHighlightingCoordinator.swift # Main coordinator
│   ├── SwiftSyntaxHighlighter.swift        # Swift AST highlighting
│   └── RegexSyntaxHighlighter.swift        # Regex-based highlighting
├── Layout/                  # Layout and view components
│   ├── GutterView.swift             # Cross-platform line numbers
│   └── CodeEditorContainerView.swift # iOS container architecture
├── SwiftUI/                 # SwiftUI integration
│   ├── CodeEditorSwiftUIView.swift  # Main SwiftUI wrapper (deprecated)
│   └── CodeEditor.swift             # Modern SwiftUI view
├── Extensions/              # All extensions (flattened with +Extensions naming)
├── Models/                  # Data models and annotations
├── TextProcessing/          # Actor-based text processing
├── RangeProcessing/         # Actor-based range validation
├── Completion/              # Code completion system
├── LSP/                     # Language Server Protocol support
├── Plugin/                  # Plugin architecture system
├── Events/                  # Event handling system
└── Platform/                # Platform-specific code
```

### Core Components

1. **CodeEditorView** - The main text view component built on TextKit2
   - Located in `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
   - Provides core editing functionality with modern TextKit2 integration
   - Supports features like line numbers, syntax highlighting, and annotations
   - Cross-platform support with proper iOS container architecture

2. **EditorConfiguration** - Unified configuration system with nested structure
   - Located in `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`
   - **Nested Configuration Structure:**
     - `display` - Visual settings (line numbers, highlighting, fonts, annotations)
     - `layout` - Layout settings (tab width, line spacing, wrapping, gutter)
     - `behavior` - Editing behavior (auto-indent, completion, spell check)
     - `performance` - Performance settings (hardware acceleration, file limits)
   - **Configuration Presets:** default, minimal, readOnly, markdown, presentation
   - **Fluid API:** Supports `.with()` methods for immutable updates

3. **Syntax Highlighting** - Multi-language support with production-ready implementation
   - `SyntaxHighlightingCoordinator` in `Sources/CodeEditorPlugin/SyntaxHighlighting/`
   - **SwiftSyntax integration** for Swift code with AST-based highlighting
   - **Regex-based highlighting** for 16+ other programming languages
   - **Performance optimized** with viewport-based rendering and background processing
   - **Fully functional** with comprehensive language support

4. **Annotation System** - Inline code comment detection and visualization
   - Detects TODO/FIXME/NOTE/WARNING/ERROR comments in code
   - Displays hover popups with annotation details and styled presentation
   - `AnnotationsDataSource` for data source pattern integration
   - Performance tested with large files and many annotations

5. **Cross-Platform Layout** - Production-ready iOS and macOS support
   - `GutterView.swift` for cross-platform line number display
   - `CodeEditorContainerView.swift` for iOS container architecture
   - Successfully separates gutter from text view with correct scrolling
   - Handles keyboard appearance with proper content insets
   - All text rendering issues resolved on both platforms

### Key Design Patterns

1. **Protocol-Oriented Design**
   - `CodeEditorViewProtocol` defines the core text view interface
   - `CodeEditorViewDelegate` for comprehensive event handling
   - `TextSystemInterface` provides abstract text system access

2. **Type Aliases for Public API**
   - `CodeEditorTextView` → `CodeEditorView`
   - `CodeEditorDelegate` → `CodeEditorViewDelegate`
   - Defined in `Sources/CodeEditorPlugin/CodeEditorPlugin.swift`

3. **Versioned Content System**
   - Tracks text changes with version numbers
   - Enables efficient range validation and updates
   - Critical for maintaining consistency in concurrent operations

4. **Actor-Based Concurrency**
   - Background processing with Swift 6 actors
   - `BackgroundProcessor` for async operations
   - Thread-safe range validation and processing

### Platform Abstraction System

The plugin features a **sophisticated platform abstraction layer** that enables true cross-platform support:

**PlatformImports.swift** - Type aliases and semantic color system:
```swift
// Platform-agnostic types
PlatformColor, PlatformFont, PlatformView, PlatformViewController

// Semantic color system
PlatformColors.label                    // Adaptive text color
PlatformColors.systemBackground         // Adaptive background
PlatformColors.controlBackground        // Adaptive control background
```

**PlatformCapabilities.swift** - Runtime feature detection:
```swift
let capabilities = PlatformCapabilities.shared

// Check feature availability
if capabilities.supportsTextKit2 {
    // Use TextKit2 features
}

// Get optimal configuration
let config = capabilities.recommendedPerformanceConfiguration
```

**CrossPlatformCoordinator.swift** - UI pattern abstraction:
```swift
let coordinator = CrossPlatformCoordinator()

// Handle platform-specific input
coordinator.configureInputHandling(for: textView)
coordinator.handleTouchInput(event: touchEvent)    // iOS
coordinator.handleMouseInput(event: mouseEvent)    // macOS
```

### Working with the Project

**Finding Components:**
- Core text editing → `Core/`
- Configuration system → `Configuration/`
- Syntax highlighting → `SyntaxHighlighting/`
- Text/range processing → `TextProcessing/` or `RangeProcessing/`
- UI components → `Layout/`
- SwiftUI integration → `SwiftUI/`
- Type extensions → `Extensions/` (all in one place with +Extensions naming)
- Plugin system → `Plugin/`
- Language Server Protocol → `LSP/`

**Extension Naming Convention:**
- Use `+Extensions` suffix for extension files
- Example: `PlatformColor+Extensions.swift`, `String+Extensions.swift`
- SwiftLint `file_name` rule disabled to allow this pattern

**Configuration Usage Patterns:**
```swift
// Nested structure access
var config = EditorConfiguration()
config.display.showLineNumbers = true
config.layout.tabWidth = 4
config.behavior.isEditable = true
config.performance.useHardwareAcceleration = true

// Immutable updates with .with() methods
let newConfig = config.with(display: modifiedDisplay)

// Preset configurations
let readOnlyConfig = EditorConfiguration.readOnly
let minimalConfig = EditorConfiguration.minimal
```

### Platform Support

- **macOS**: 12.0+ (optimized for macOS 14+)
- **iOS**: 16.0+ (with proper container architecture)
- **Mac Catalyst**: 16.0+
- **Swift**: 6.0+ (uses modern concurrency features)

### Dependencies

- **swift-syntax** (510.0.0+): Used for Swift language syntax highlighting

### Performance Considerations

- Hardware acceleration support for large files
- Viewport-based rendering for efficiency
- Background processing for syntax highlighting
- Read-only mode available for viewing without editing overhead
- Actor-based concurrency ensures UI responsiveness

### Testing Approach

Tests are located in `Tests/CodeEditorPluginTests/` (106 tests) and `CodeEditorSample/Tests/CodeEditorSampleTests/` (66 tests) for a total of **172 comprehensive tests** with **100% pass rate**. 

**Main Package Tests (106 tests):**
- `CodeEditorViewTests.swift` - Core text view functionality (33 tests)
- `SyntaxHighlightingTests.swift` - Highlighting system tests (13 tests)
- `ConfigurationTests.swift` - Configuration system tests (6 tests)
- `AnnotationTests.swift` - Annotation system functionality (19 tests)
- `ConfigurationIntegrationTests.swift` - Comprehensive configuration testing (24 tests)
- `PerformanceConfigurationTests.swift` - Performance benchmarks (11 tests)

**Sample App Tests (66 tests):**
- `AnnotationSystemTests.swift` - Comprehensive annotation testing with performance benchmarks (20 tests)
- `BasicFunctionalityTests.swift` - Core functionality verification (4 tests)
- `SampleCodeTests.swift` - Language sample validation (12 tests)
- `SimplifiedIntegrationTests.swift` - End-to-end integration testing (6 tests)
- `ConfigurationUITests.swift` - UI-level configuration tests (12 tests)
- `PluginConfigurationTests.swift` - Plugin system tests (11 tests)
- `QuickIsFlippedTest.swift` - View hierarchy tests (1 test)

### Recent Achievements

**Architecture Improvements:**
- **Directory Structure Simplification**: Reduced from 39 to 10 directories (74% reduction)
- **Feature-Based Organization**: Transitioned from type-based to feature-based organization
- **Fixed Text Rendering Issues**: Resolved all line number clipping and text display problems
- **Working Cross-Platform Support**: Both iOS and macOS now render correctly without issues
- **Unified Configuration System**: Complete implementation of nested EditorConfiguration
- **Working Syntax Highlighting**: Fully functional multi-language support
- **Swift 6 Compliance**: Full actor-based concurrency throughout codebase

**Quality Achievements:**
- **Zero SwiftLint Violations**: Maintained across all files in both main plugin and sample app
- **172 Comprehensive Tests**: Full test coverage with **100% pass rate** (all tests passing)
- **Actor-Based Concurrency**: Full Swift 6 compliance with thread safety
- **TextKit2 Integration**: Modern text handling with proper synchronization
- **Viewport Optimization**: Efficient rendering for large files
- **Memory Management**: Proper TextKit2 memory handling with graceful test validation
- **Code Quality Standards**: Systematic lint violation fixes and test failure resolution

**CodeEditorSample Refactoring:**
- **Modern UI Controls**: Replaced old-style checkboxes with platform-appropriate toggle switches
- **Fixed Configuration Flow**: All settings now apply correctly across macOS Native, Mac Catalyst, and iOS
- **Resolved Double Line Numbers**: Fixed gutter view duplication on macOS Native
- **Simplified Architecture**: Direct use of CodeEditor component for iOS/Catalyst platforms
- **Enhanced State Management**: Proper SwiftUI update propagation with objectWillChange
- **Container View Management**: Proper separation of gutter management between container and text view

## Current Working Systems

### Syntax Highlighting System
The syntax highlighting system is **fully functional** and production-ready:

```swift
// Automatic language detection
textView.setLanguage(fileExtension: "swift")
textView.setLanguage(fileExtension: "py") 
textView.setLanguage(fileExtension: "js")

// Direct language assignment
textView.language = .swift
textView.language = .python
textView.language = .javascript
```

**Supported Languages (17):**
- Swift (SwiftSyntax AST-based)
- Python, JavaScript/TypeScript, Rust, C/C++
- HTML/CSS, JSON/YAML, Markdown
- Go, Java, Ruby, PHP, SQL, XML, Shell

### EditorConfiguration Usage

**Basic Configuration:**
```swift
var config = EditorConfiguration()

// Display settings
config.display.showLineNumbers = true
config.display.highlightSelectedLine = true
config.display.fontSize = 16.0
config.display.enableAnnotations = true

// Layout settings
config.layout.tabWidth = 4
config.layout.insertSpacesForTabs = true
config.layout.wrapLines = false

// Behavior settings
config.behavior.isEditable = true
config.behavior.autoIndent = true
config.behavior.enableCodeCompletion = true

// Performance settings
config.performance.useHardwareAcceleration = true
config.performance.smoothScrolling = true
```

**Configuration Presets:**
```swift
// Use built-in presets for common scenarios
let defaultConfig = EditorConfiguration.default
let minimalConfig = EditorConfiguration.minimal  
let readOnlyConfig = EditorConfiguration.readOnly
let markdownConfig = EditorConfiguration.markdown
let presentationConfig = EditorConfiguration.presentation

// Apply configuration
config.apply(to: textView)
```

### SwiftUI Integration

**Modern SwiftUI API:**
```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "// Your Swift code here"
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .environment(\.codeEditorConfiguration, configuration)
            .frame(minHeight: 400)
    }
}
```

### Annotation System

The annotation system detects and displays TODO/FIXME/NOTE/WARNING/ERROR comments:

```swift
// These comments will be detected and displayed with badges
// TODO: Implement this feature
// FIXME: Bug in the calculation
// NOTE: Important information
// WARNING: Deprecated method
// ERROR: Critical issue
```

**Features:**
- Hover popups with annotation details
- Performance tested with large files
- Styled presentation with different badge colors
- Cross-platform support

### Advanced Features

**Performance Monitoring:**
- Real-time frame rate analysis
- Memory usage tracking
- Syntax highlighting performance metrics
- Large file optimization (500KB+)

**Plugin Architecture (Preview):**
- Language plugin support
- Custom tool integrations
- Theme extensions
- Domain-specific commands

**Language Server Protocol (Preview):**
- Intelligent code completion
- Real-time diagnostics
- Go-to-definition
- Hover documentation
- Refactoring support

**Advanced Editing:**
- Smart indentation
- Code folding
- Symbol navigation
- Incremental parsing
- Bracket matching
- Search & replace with regex

## Best Practices for Development

### Code Organization
- **Follow feature-based structure** - Keep related components together
- **Use +Extensions naming** - All extension files should use this pattern
- **Leverage nested configuration** - Use the structured EditorConfiguration system
- **Apply actor isolation** - Ensure thread safety with Swift 6 actors

### Configuration Management
- **Start with presets** - Use built-in configurations as base
- **Use immutable updates** - Leverage `.with()` methods for changes
- **Test configurations** - Verify settings work across platforms
- **Document custom configs** - Explain specialized configuration choices

### Performance Considerations
- **Enable hardware acceleration** - Use `config.performance.useHardwareAcceleration = true`
- **Set appropriate limits** - Configure `maxSyntaxHighlightingLength` for large files
- **Use viewport rendering** - Leverage the built-in viewport optimization
- **Test with large files** - Verify performance with realistic content sizes

### Platform Abstraction Usage
- **Always use platform abstractions** - Use `PlatformColors.label` instead of `NSColor.labelColor`/`UIColor.label`
- **Check capabilities before using features** - Use `PlatformCapabilities.shared.supportsTextKit2`
- **Leverage semantic colors** - Use adaptive colors that respond to light/dark mode
- **Use cross-platform coordinator** - Let `CrossPlatformCoordinator` handle input differences
- **Prefer `#if canImport()` over `#if os()`** - Better compatibility with Mac Catalyst

## Important Reminders

- **Production-Ready**: This is not a prototype - the plugin is ready for production use
- **Swift 6 First**: All new code should use modern concurrency patterns
- **Test Coverage**: Maintain the high test coverage standard (currently 172 tests)
- **Zero Violations**: Keep SwiftLint violations at zero
- **Cross-Platform**: Always test changes on macOS, iOS, and Mac Catalyst