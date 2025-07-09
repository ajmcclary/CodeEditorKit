# AGENTS.md

This guide helps AI code assistants understand the CodeEditorPlugin project structure and best practices.

## Project Overview

CodeEditorPlugin is a Swift 6-based code editor component for macOS, iOS, and Mac Catalyst:

- **Modern Architecture**: Swift 6 actors for thread-safe operations
- **Cross-Platform Excellence**: Sophisticated abstraction layer for native performance
- **17 Languages Supported**: SwiftSyntax for Swift, regex for others
- **319 Comprehensive Tests**: Production-quality coverage (284 core + 35 sample)
- **Zero Technical Debt**: No SwiftLint violations across 270 files, clean architecture
- **74% Directory Reduction**: Simplified from 39 to 10 directories

## Quick Reference Commands

### Essential Workflow
```bash
# Standard development cycle
swift build && swiftlint && swift test

# Run sample app
cd CodeEditorSample && swift run CodeEditorSample

# Fix linting issues
swiftlint --fix

# Clean rebuild
swift package clean && swift build
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
├── Platform/                # Enhanced cross-platform abstractions
├── TextProcessing/          # Actor-based processing
├── Extensions/              # Type extensions (+Extensions suffix)
├── LSP/                     # Language Server Protocol
└── Features/                # Additional features (folding, search, etc.)
```

### Key Components

**CodeEditorView** (`Core/CodeEditorView.swift`)
- Main TextKit2-based text view with cross-platform support

**EditorConfiguration** (`Configuration/EditorConfiguration.swift`)
- Nested structure: display, layout, behavior, performance
- Presets: default, minimal, readOnly, markdown, presentation
- Immutable updates with `.with()` methods

**Platform Abstraction** (`Platform/`)
- Unified types: PlatformColor, PlatformFont, PlatformView
- Enhanced with `#if canImport()` patterns (replaced all `#if os()`)
- Runtime capability detection via PlatformCapabilities
- CrossPlatformCoordinator for unified input handling
- Zero-compromise native experience

## Code Patterns & Best Practices

### Configuration Usage
```swift
// Create and modify
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

### Language Support
```swift
// Auto-detect language
textView.setLanguage(fileExtension: "swift")

// Direct assignment
textView.language = .python
```

## Development Guidelines

### Code Quality Standards
- **Swift 6 Concurrency**: Use actors for background work
- **Zero SwiftLint Violations**: Required across all files
- **Test Coverage**: Add tests for new features
- **Cross-Platform**: Test on macOS, iOS, and Mac Catalyst

### Directory Navigation
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

**Platform-Specific Features**
1. Use `#if canImport()` not `#if os()`
2. Add abstraction in `Platform/` if needed
3. Test on all platforms

## Testing Requirements

- **Main Package**: 390 tests in `Tests/CodeEditorPluginTests/`
- **Sample App**: 35 tests in `CodeEditorSample/Tests/`
- **Performance**: Include benchmarks for new features
- **Platforms**: Test macOS, iOS, and Mac Catalyst

## Recent Achievements

- **74% Directory Reduction**: Simplified architecture
- **Swift 6 Migration**: Full actor-based concurrency
- **Cross-Platform Fixed**: All rendering issues resolved
- **17 Languages**: Comprehensive syntax highlighting
- **Unified Wrapper Architecture**: Protocol-based sample app wrappers

### Recent Major Refactoring (2025)
- **Platform Abstraction Enhancement**: Replaced all `#if os()` with `#if canImport()`
- **Modern UI Controls**: Platform-appropriate toggle switches
- **Fixed Configuration**: Settings apply correctly across platforms
- **Resolved Double Line Numbers**: Fixed gutter duplication
- **Simplified Architecture**: Direct CodeEditor usage for iOS/Catalyst
- **41 Files**: Well-organized sample app maintaining zero violations

## Advanced Features

### Performance Monitoring
- Frame rate analysis (60fps target)
- Memory usage tracking
- Syntax highlighting metrics
- Large file optimization (500KB+)

### Plugin Architecture (Preview)
- Custom language plugins
- Tool integrations
- Theme extensions
- Domain-specific commands

### Language Server Protocol (Preview)
- Intelligent code completion
- Real-time diagnostics
- Go-to-definition
- Hover documentation

## Supported Languages & Requirements

**Languages**: Swift (AST), Python, JavaScript, TypeScript, Rust, C/C++, HTML, CSS, JSON, YAML, Markdown, Go, Java, Ruby, PHP, SQL, XML, Shell

**Requirements**:
- **macOS**: 12.0+ (optimized for 14+)
- **iOS**: 16.0+
- **Mac Catalyst**: 16.0+
- **Swift**: 6.0+
- **Xcode**: 16.0+

## Documentation System

Generate documentation:
```bash
swift package generate-documentation --target CodeEditorPlugin
```

Key files: `GettingStarted.md`, `Configuration-System.md`, `SwiftUI-Integration.md`

Remember: This is a **production-ready** component. Maintain high quality standards!