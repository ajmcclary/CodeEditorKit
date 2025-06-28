# GEMINI.md

This file provides guidance to Gemini Code (gemini.google.com/code) when working with code in this repository.

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

After successful refactoring completed today, the project now uses a feature-based organization (reduced from 39 to 10 directories):

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
│   ├── GutterView.swift             # Cross-platform line numbers (fixed rendering issues)
│   └── CodeEditorContainerView.swift # iOS container architecture (resolved clipping)
├── SwiftUI/                 # SwiftUI integration
│   ├── CodeEditorSwiftUIView.swift  # Main SwiftUI wrapper
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
   - Provides the core editing functionality with modern TextKit2 integration
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

3. **Syntax Highlighting** - Multi-language support with working implementation
   - `SyntaxHighlightingCoordinator` in `Sources/CodeEditorPlugin/SyntaxHighlighting/`
   - **SwiftSyntax integration** for Swift code with AST-based highlighting
   - **Regex-based highlighting** for 15+ other programming languages
   - **Performance optimized** with viewport-based rendering and background processing
   - **Fully functional** with comprehensive language support

4. **Annotation System** - Inline code comment detection and visualization
   - Detects TODO/FIXME/NOTE/WARNING/ERROR comments in code
   - Displays hover popups with annotation details and styled presentation
   - `AnnotationsDataSource` for data source pattern integration
   - Performance tested with large files and many annotations

5. **Cross-Platform Layout** - Fixed iOS and macOS support with proper text rendering
   - `GutterView.swift` for cross-platform line number display (no more clipping issues)
   - `CodeEditorContainerView.swift` for iOS container architecture (proper text alignment)
   - Successfully separates gutter from text view with correct scrolling behavior
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

### Working with the Simplified Structure

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

**Feature-Based Organization Benefits:**
- **74% Directory Reduction** - From 39 to 10 directories for simpler navigation
- **Related code co-location** - All syntax highlighting components together
- **Clear component boundaries** - Easy to understand dependencies
- **Simplified imports** - Flattened structure reduces module overhead
- **Better maintainability** - Logical grouping improves code organization

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

Tests are located in `Tests/CodeEditorPluginTests/` (106 tests) and `CodeEditorSample/Tests/CodeEditorSampleTests/` (66 tests) for a total of 172 comprehensive tests. The project uses Swift Package Manager's built-in testing support. Key test files include:

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

### Architecture Achievements and Lessons Learned

**Major Refactoring Completed Today**
- **Directory Structure Simplification**: Reduced from 39 to 10 directories (74% reduction)
- **Feature-Based Organization**: Transitioned from type-based to feature-based organization
- **Fixed Text Rendering Issues**: Resolved all line number clipping and text display problems
- **Working Cross-Platform Support**: Both iOS and macOS now render correctly without issues
- **Unified Configuration System**: Complete implementation of nested EditorConfiguration
- **Working Syntax Highlighting**: Fully functional multi-language support
- **Swift 6 Compliance**: Full actor-based concurrency throughout codebase

**Configuration System Evolution**
- **Nested Structure**: Organized into display, layout, behavior, and performance sections
- **Immutable Updates**: `.with()` methods for clean configuration changes
- **Preset System**: Built-in configurations for common use cases
- **SwiftUI Integration**: Environment-based configuration passing
- **Type Safety**: Full Codable and Sendable conformance

**Comprehensive Platform Abstraction System**
- **Runtime Capability Detection**: `PlatformCapabilities` for feature availability checking
- **Semantic Color System**: `PlatformColors` enum with adaptive light/dark mode support
- **Cross-Platform Font System**: `PlatformFonts` with consistent font creation across platforms
- **Input Handling Abstraction**: `CrossPlatformCoordinator` for mouse, touch, and pencil input
- **Performance Optimization**: Memory-aware configuration and hardware acceleration detection
- **Platform-Appropriate UI**: Context menus, keyboard shortcuts, and gesture handling

**Performance and Quality Achievements**
- **Zero SwiftLint Violations**: Maintained across all 102+ files
- **172 Comprehensive Tests**: 106 main package + 66 sample app tests
- **Actor-Based Concurrency**: Full Swift 6 compliance with thread safety
- **TextKit2 Integration**: Modern text handling with proper synchronization
- **Viewport Optimization**: Efficient rendering for large files

**Cross-Platform Success (Fixed Today)**
- **iOS Container Architecture**: Fixed line number display - no more clipping issues
- **Text Rendering**: Resolved all text alignment and display problems on both platforms
- **Keyboard Handling**: Content insets working correctly without frame resizing
- **SwiftUI Wrappers**: Native SwiftUI integration with environment configuration
- **macOS Optimization**: Smooth scrolling and proper gutter display
- **Zero Known Issues**: All rendering problems have been resolved

**Development Process Insights**
- **Feature-based organization** significantly improves maintainability
- **Nested configuration** provides better API organization than flat structures
- **Comprehensive testing** prevents regressions during major refactoring
- **Actor-based concurrency** requires careful design but provides excellent thread safety
- **SwiftLint configuration** with custom rules maintains code quality at scale
- **Iterative refinement** - Today's successful fixes show the value of focused problem-solving

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

**Supported Languages (15+):**
- Swift (SwiftSyntax AST-based)
- Python, JavaScript/TypeScript, Rust, C/C++
- HTML/CSS, JSON/YAML, Markdown
- Go, Java, Ruby, PHP, SQL, XML

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
        CodeEditorSwiftUIView(
            text: $code,
            language: .swift,
            showLineNumbers: true,
            highlightSelectedLine: true,
            isEditable: true
        )
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

## Platform Abstraction System

The CodeEditorPlugin includes a comprehensive platform abstraction system located in `Sources/CodeEditorPlugin/Platform/`. This system provides seamless cross-platform development while maintaining access to platform-specific optimizations.

### Core Components

**PlatformImports.swift** - Type aliases and semantic color system:
```swift
// Platform-agnostic types
PlatformColor, PlatformFont, PlatformView, PlatformViewController

// Semantic color system
PlatformColors.label                    // Adaptive text color
PlatformColors.systemBackground         // Adaptive background color
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

### Usage Examples

**Basic Platform Types:**
```swift
// Use semantic colors that adapt to light/dark mode
let textColor: PlatformColor = PlatformColors.label
let backgroundColor: PlatformColor = PlatformColors.systemBackground

// Create cross-platform fonts
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)

// Platform-aware view controllers
class MyEditorViewController: PlatformViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Your cross-platform code here
    }
}
```

**Runtime Capability Detection:**
```swift
// Check platform capabilities before using features
if PlatformCapabilities.shared.supportsHardwareAcceleration {
    textView.enableHardwareAcceleration()
}

// Use memory-aware configuration
let memoryConfig = PlatformCapabilities.shared.recommendedMemoryConfiguration
```

**Cross-Platform Input Handling:**
```swift
let coordinator = CrossPlatformCoordinator()

// Automatically configure appropriate input handling
coordinator.configureInputHandling(for: textView)

// Create platform-appropriate context menus
let contextMenu = coordinator.createContextMenu(for: selectedText)
```

For detailed documentation, see `Sources/CodeEditorPlugin/Platform/README.md`.

