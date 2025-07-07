# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CodeEditorPlugin is a Swift 6-based code editor component for macOS, iOS, and Mac Catalyst:
- **Swift 6 concurrency** with actor-based architecture
- **Enhanced cross-platform abstraction** using `#if canImport()` patterns
- **17+ programming languages** with syntax highlighting
- **319 comprehensive tests** (284 main + 35 sample app) - All passing
- **Zero SwiftLint violations** across all 242 files
- **Production-grade reliability** with comprehensive error handling
- **Feature-based architecture** (74% directory reduction)

## Essential Commands

### Build and Test
```bash
# Standard workflow
swift build && swiftlint && swift test

# Fix linting issues
swiftlint --fix

# Run sample app
cd CodeEditorSample && swift run CodeEditorSample
```

### Development Quality
```bash
# Full quality check
swift build && swiftlint && swift test

# Clean rebuild
swift package clean && swift build
```

## Architecture Overview

### Directory Structure
```
Sources/CodeEditorPlugin/
├── Core/                    # Text editing (CodeEditorView)
├── Configuration/           # EditorConfiguration system
├── SyntaxHighlighting/      # Language support
├── Layout/                  # UI components (GutterView)
├── SwiftUI/                 # SwiftUI integration (CodeEditor)
├── Platform/                # Cross-platform abstractions
├── Extensions/              # Type extensions (+Extensions naming)
├── TextProcessing/          # Actor-based processing
├── LSP/                     # Language Server Protocol
└── Documentation.docc/      # DocC documentation
```

### Core Components

**CodeEditorView** (`Core/CodeEditorView.swift`)
- Main TextKit2-based text view
- Cross-platform with iOS container support

**EditorConfiguration** (`Configuration/EditorConfiguration.swift`)
- Nested structure: `display`, `layout`, `behavior`, `performance`
- Presets: `default`, `minimal`, `readOnly`, `markdown`, `presentation`
- Immutable updates with `.with()` methods

**Platform Abstraction** (`Platform/`)
- Unified types: `PlatformColor`, `PlatformFont`, `PlatformView`
- Capability detection: `PlatformCapabilities.shared`
- Cross-platform coordinator for input handling

## Key Patterns

### Configuration Usage
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

## Development Guidelines

### Code Quality Standards
- **Swift 6 Concurrency**: Use actors for background work
- **Zero SwiftLint Violations**: Required across all files
- **Cross-Platform**: Test on macOS, iOS, and Mac Catalyst
- **Extension Naming**: Use `+Extensions` suffix

### Finding Components
- Core editing → `Core/`
- Configuration → `Configuration/`
- Syntax highlighting → `SyntaxHighlighting/`
- UI components → `Layout/`
- SwiftUI integration → `SwiftUI/`
- Platform code → `Platform/`
- Extensions → `Extensions/`

### Common Tasks

**Adding Configuration Options**
1. Add property to appropriate config section
2. Update presets if needed
3. Add SwiftUI modifier if applicable

**Platform-Specific Features**
1. Use `#if canImport()` not `#if os()`
2. Add abstraction in `Platform/` if needed
3. Test on all platforms

## Recent Major Refactoring (2025)

### Enhanced Platform Abstraction
- **Replaced all `#if os()` with `#if canImport()`** for proper Catalyst support
- **Unified type system**: `PlatformColor`, `PlatformFont`, `PlatformView` throughout
- **Runtime capability detection**: `PlatformCapabilities.shared` for feature availability
- **Cross-platform coordinator**: Manages input handling across all platforms

### CodeEditorSample Improvements
- **Unified wrapper protocol**: `CodeEditorViewWrapperProtocol` with platform implementations
- **Direct SwiftUI integration**: iOS/Catalyst now use `CodeEditor` component directly
- **Fixed configuration flow**: All settings apply correctly across platforms
- **Resolved double line numbers**: Proper gutter view management on macOS

### Architecture Achievements
- **74% directory reduction**: From 39 to 10 core feature directories
- **253 total Swift files**: 216 plugin + 37 sample app (well organized)
- **319 comprehensive tests**: 284 plugin + 35 sample app (100% passing)
- **Zero SwiftLint violations**: Maintained across entire codebase
- **Swift 6 concurrency compliance**: Full actor isolation and `@preconcurrency` usage

## Important Reminders

- **Production-Ready**: Maintain high quality standards
- **Swift 6 First**: Use modern concurrency patterns
- **Test Coverage**: Currently 319 tests - maintain this standard
- **Documentation**: Reference DocC docs in `Documentation.docc/`
- **Cross-Platform**: Always test on all platforms

## Documentation System

Generate documentation:
```bash
swift package generate-documentation --target CodeEditorPlugin
```

Key docs: `GettingStarted.md`, `Configuration-System.md`, `SwiftUI-Integration.md`, `Platform-Abstraction.md`