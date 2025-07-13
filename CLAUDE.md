# CLAUDE.md

This file provides guidance to Claude and other AI assistants when working with the CodeEditorPlugin repository.

## Quick Reference

### Essential Commands
```bash
# Standard workflow - build, lint, and test
swift build && swiftlint && swift test

# Fix linting issues automatically
swiftlint --fix

# Run sample app
swift run

# Generate documentation
swift package generate-documentation --target CodeEditorPlugin
```

### Project Statistics
- **252 Source Files** in main plugin
- **53 Test Files** with comprehensive coverage
- **22 Feature Directories** (well-organized architecture)
- **17+ Languages Supported** with syntax highlighting
- **Zero SwiftLint Violations** maintained across codebase

## Architecture Overview

### Directory Structure
```
Sources/CodeEditorPlugin/
├── Core/                    # Text editing engine (CodeEditorView)
├── Configuration/           # EditorConfiguration system
├── SyntaxHighlighting/      # Language highlighting support
├── Layout/                  # UI components (GutterView, MinimapView)
├── SwiftUI/                 # SwiftUI integration (CodeEditor)
├── Platform/                # Cross-platform abstractions
├── Extensions/              # Type extensions (+Extensions naming)
├── TextProcessing/          # Actor-based text processing
├── Performance/             # Memory/performance monitoring
├── Completion/              # Code completion system
├── Features/                # Additional features (folding, search)
├── Languages/               # Language-specific providers
├── LSP/                     # Language Server Protocol
├── TextKit/                 # TextKit helpers
├── Utilities/               # Shared utilities
└── Documentation.docc/      # DocC documentation
```

### Core Components

**CodeEditorView** (`Core/CodeEditorView.swift`)
- Main TextKit2-based text view
- Cross-platform with iOS container support
- Unified event system for consistent behavior

**EditorConfiguration** (`Configuration/EditorConfiguration.swift`)
- Nested structure: `display`, `layout`, `behavior`, `performance`
- Presets: `default`, `minimal`, `readOnly`, `markdown`, `presentation`
- Immutable updates with `.with()` methods

**Platform Abstraction** (`Platform/`)
- Unified types: `PlatformColor`, `PlatformFont`, `PlatformView`
- Uses `#if canImport()` patterns (NOT `#if os()`)
- Runtime capability detection via `PlatformCapabilities.shared`
- `CrossPlatformCoordinator` for unified input handling

## Key Usage Patterns

### Configuration
```swift
// Basic configuration
var config = EditorConfiguration()
config.display.showLineNumbers = true
config.layout.tabWidth = 4
config.behavior.isEditable = true

// Use presets
let config = EditorConfiguration.minimal

// Apply to view
config.apply(to: textView)
```

### SwiftUI Integration
```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "// Your code"
    @State private var config = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .environment(\.codeEditorConfiguration, config)
    }
}
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

// Use #if canImport() not #if os()
#if canImport(AppKit)
import AppKit
#endif
```

### Language Support
```swift
// Auto-detect language
textView.setLanguage(fileExtension: "swift")

// Direct assignment
textView.language = .python

// Supported: Swift (AST), Python, JavaScript, TypeScript, Rust, C/C++, 
// HTML, CSS, JSON, YAML, Markdown, Go, Java, Ruby, PHP, SQL, XML, Shell
```

### SwiftUI Configuration Binding Patterns

```swift
// ✅ RECOMMENDED: Direct binding pattern (Thread-safe, no Sendable warnings)
Toggle("Show Line Numbers", 
       isOn: $appState.currentConfiguration.display.isLineNumbersEnabled)

Slider(value: $appState.currentConfiguration.display.fontSize, 
       in: 10...20)

Picker("Theme", selection: $appState.currentConfiguration.display.theme) {
    ForEach(themes, id: \.self) { theme in
        Text(theme.name).tag(theme)
    }
}

// ✅ RECOMMENDED: Batch updates for multiple properties
appState.updateConfiguration { config in
    config.display.showLineNumbers = true
    config.display.fontSize = 16
    config.behavior.isEditable = true
}

// ❌ AVOID: Complex binding builders (causes Sendable warnings)
// ConfigurationBindingBuilder patterns have been deprecated
```

**Key Benefits of Direct Binding:**
- **Zero Sendable warnings**: Works seamlessly with Swift 6 concurrency
- **Type safety**: Compiler-verified property access
- **Performance**: No additional binding overhead
- **Simplicity**: Clear, readable code
- **SwiftUI integration**: Natural SwiftUI patterns

**Configuration Update Patterns:**
```swift
// Single property update
appState.currentConfiguration.display.showLineNumbers = true

// Multiple property update (preferred for batches)
appState.updateConfiguration { config in
    config.display.showLineNumbers = true
    config.layout.tabWidth = 4
}

// Preset application
appState.applyPreset(.minimal)
```

## Development Guidelines

### Code Quality Standards
- **Swift 6 Concurrency**: Use actors for background work
- **Zero SwiftLint Violations**: Run `swiftlint --fix` before committing
- **Cross-Platform Testing**: Test on macOS, iOS, and Mac Catalyst
- **Extension Naming**: Use `+Extensions` suffix for extension files
- **Logging**: Use `CrossPlatformLogger.logger()` not `print()`

### Common Tasks

**Adding Configuration Options**
1. Add property to appropriate config section
2. Update presets if needed
3. Add SwiftUI modifier if applicable
4. Update documentation

**Adding Platform-Specific Features**
1. Use `#if canImport()` not `#if os()`
2. Add abstraction in `Platform/` directory
3. Update `PlatformCapabilities` if needed
4. Test on all platforms

**Debugging & Testing**
```bash
# Run specific test
swift test --filter TestName

# Test with verbose output
swift test --verbose

# Platform-specific testing
xcodebuild -scheme CodeEditorPlugin -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Recent Improvements (2024-2025)

### Architecture & Performance
- **Unified Event System**: Consistent event handling across platforms
- **AsyncSyntaxHighlighter Cache**: LRU cache with memory limits
- **SwiftSyntaxHighlighter+Shared**: Refactored shared highlighting logic
- **Dependency Injection**: Replaced singletons (e.g., MemoryMonitor)
- **Swift 6 Concurrency**: Full actor isolation, eliminated Task anti-patterns

### Platform Enhancements
- **Enhanced Abstraction**: All `#if os()` replaced with `#if canImport()`
- **Cross-Platform Coordinator**: Unified input handling system
- **Runtime Capabilities**: Dynamic feature detection
- **Native Performance**: Zero-compromise on each platform

### Quality Improvements
- **Force Unwrap Removal**: All unsafe unwraps eliminated
- **Proper Cleanup**: Resources cleaned up in `removeFromSuperview`
- **API Refinement**: Internal implementation details hidden
- **Code Duplication**: Shared configurations in builders
- **Modern Patterns**: `Task.sleep` instead of `DispatchQueue.asyncAfter`
- **Sendable Compliance**: AppState made Sendable, removed unused ConfigurationBindingBuilder
- **Direct Bindings**: Standardized on SwiftUI-native binding patterns without warnings

## Advanced Features

### Performance Monitoring
- Frame rate analysis (60fps target)
- Memory usage tracking with configurable limits
- Syntax highlighting performance metrics
- Large file optimization (500KB+ files)

### Language Server Protocol (Preview)
- Intelligent code completion
- Real-time diagnostics
- Go-to-definition support
- Hover documentation

## Important Reminders

- **Production Quality**: This is used in real applications - maintain standards
- **Swift 6 First**: Use modern concurrency patterns throughout
- **Test Everything**: Add tests for new features and bug fixes
- **Cross-Platform**: Always test on macOS, iOS, and Mac Catalyst
- **Documentation**: Update DocC documentation for API changes

## Documentation

Key documentation files in `Documentation.docc/`:
- `CodeEditorPlugin.md` - Main documentation hub
- `GettingStarted.md` - Quick setup guide
- `Configuration-System.md` - Configuration details
- `SwiftUI-Integration.md` - SwiftUI usage guide
- `Platform-Abstraction.md` - Cross-platform development
- `Unified-Event-System.md` - Event handling system
- `Deprecation-Timeline.md` - API deprecation schedule