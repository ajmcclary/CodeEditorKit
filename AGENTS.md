# AGENTS.md

This guide helps AI code assistants understand the CodeEditorPlugin project structure, conventions, and best practices.

## Project Overview

CodeEditorPlugin is a **production-ready**, **Swift 6-based** code editor component for macOS, iOS, and Mac Catalyst. Key highlights:

- **Modern Architecture**: Built with Swift 6 actors for thread-safe, performant operations
- **Cross-Platform Excellence**: Sophisticated abstraction layer for true native performance
- **17 Languages Supported**: SwiftSyntax for Swift, regex for other languages
- **172 Comprehensive Tests**: Production-quality test coverage
- **Zero Technical Debt**: No SwiftLint violations, clean architecture

## Quick Reference Commands

### Building & Running
```bash
# Build main package
swift build

# Run sample app
cd CodeEditorSample && swift run CodeEditorSample

# Clean and rebuild
swift package clean && swift build
```

### Quality Assurance
```bash
# Fix and check linting
swiftlint --fix && swiftlint

# Run all tests
swift test

# Full quality check
swift build && swiftlint && swift test
```

## Architecture Overview

### Feature-Based Organization
```
Sources/CodeEditorPlugin/
├── Core/                    # Text editing engine
├── Configuration/           # Unified config system
├── SyntaxHighlighting/      # Language support
├── Layout/                  # UI components
├── SwiftUI/                 # SwiftUI integration
├── Platform/                # Cross-platform layer
├── TextProcessing/          # Actor-based processing
├── Plugin/                  # Plugin architecture
├── LSP/                     # Language Server Protocol
└── Extensions/              # Type extensions (+Extensions suffix)
```

### Key Components

**CodeEditorView** (`Core/CodeEditorView.swift`)
- Main TextKit2-based text view
- Cross-platform with proper iOS container support
- Supports line numbers, highlighting, annotations

**EditorConfiguration** (`Configuration/EditorConfiguration.swift`)
- Nested structure: display, layout, behavior, performance
- Presets: default, minimal, readOnly, markdown, presentation
- Immutable updates with `.with()` methods

**SyntaxHighlightingCoordinator** (`SyntaxHighlighting/`)
- SwiftSyntax for Swift AST analysis
- Regex-based for 16+ other languages
- Viewport-optimized rendering

**Platform Abstraction** (`Platform/`)
- Unified types: PlatformColor, PlatformFont, PlatformView
- Runtime capability detection
- Zero-compromise native experience

## Code Patterns & Best Practices

### Configuration Usage
```swift
// Create and modify configuration
var config = EditorConfiguration()
config.display.showLineNumbers = true
config.layout.tabWidth = 4

// Use presets
let config = EditorConfiguration.minimal

// Immutable updates
let newConfig = config.with(display: modifiedDisplay)
```

### SwiftUI Integration
```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .environment(\.codeEditorConfiguration, config)
```

### Platform Abstraction
```swift
// Always use platform abstractions
let color = PlatformColors.label
let font = PlatformFonts.monospacedSystemFont(ofSize: 14)

// Check capabilities
if PlatformCapabilities.shared.supportsTextKit2 {
    // Use TextKit2 features
}
```

### Syntax Highlighting
```swift
// Auto-detect language
textView.setLanguage(fileExtension: "swift")

// Direct assignment
textView.language = .python
```

## Important Guidelines

### Code Quality Standards
- **Swift 6 Concurrency**: Use actors for all background work
- **Zero Violations**: Maintain SwiftLint compliance
- **Test Coverage**: Add tests for new features
- **Cross-Platform**: Test on macOS, iOS, and Mac Catalyst

### Performance Optimization
- Enable hardware acceleration for large files
- Use viewport-based rendering
- Leverage background actors for heavy processing
- Test with files >500KB

### Directory Navigation Tips
- Core editing → `Core/`
- Configuration → `Configuration/`
- Syntax highlighting → `SyntaxHighlighting/`
- UI components → `Layout/`
- SwiftUI → `SwiftUI/`
- Extensions → `Extensions/` (+Extensions naming)

### Common Tasks

**Adding a New Language**
1. Add language case to `Language` enum
2. Create regex patterns in `RegexSyntaxHighlighter`
3. Add file extension mapping
4. Add tests

**Creating Configuration Options**
1. Add property to appropriate config section
2. Update presets if needed
3. Add SwiftUI modifier if applicable
4. Document the option

**Platform-Specific Features**
1. Use `#if canImport()` not `#if os()`
2. Add abstraction in `Platform/` if needed
3. Test on all platforms
4. Update capability detection

## Testing Requirements

- **Main Package**: 106 tests in `Tests/CodeEditorPluginTests/`
- **Sample App**: 66 tests in `CodeEditorSample/Tests/`
- **Performance**: Include benchmarks for new features
- **Platforms**: Test macOS, iOS, and Mac Catalyst

## Recent Achievements

- **74% Directory Reduction**: Simplified from 39 to 10 directories
- **Swift 6 Migration**: Full actor-based concurrency
- **Cross-Platform Fixed**: Resolved all rendering issues
- **17 Languages**: Comprehensive syntax highlighting
- **Zero Debt**: No linting violations, all tests passing

## Supported Languages

Swift (AST), Python, JavaScript, TypeScript, Rust, C, C++, HTML, CSS, JSON, YAML, Markdown, Go, Java, Ruby, PHP, SQL, XML, Shell

## Platform Requirements

- **macOS**: 12.0+ (optimized for 14+)
- **iOS**: 16.0+
- **Mac Catalyst**: 16.0+
- **Swift**: 6.0+
- **Xcode**: 16.0+

## Quick Debugging

```bash
# Check for issues
swiftlint
swift test --filter failing_test_name

# Clean rebuild
swift package clean
rm -rf .build
swift build

# View test output
swift test --verbose
```

Remember: This is a **production-ready** component. Maintain the high quality standards!