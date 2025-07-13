# CLAUDE.md

This file provides guidance to Claude and other AI assistants when working with the CodeEditorPlugin repository.

## Quick Reference

### Essential Commands
```bash
# Standard workflow - build, lint, and test
swift build && swiftlint && swift test --parallel

# Fix linting issues automatically
swiftlint --fix

# Run sample app
swift run

# Generate documentation
swift package generate-documentation --target CodeEditorPlugin

# Run tests in parallel (faster)
swift test --parallel
```

### Project Statistics
- **333 Source Files** in main plugin
- **53 Test Files** with comprehensive coverage
- **18 Feature Directories** (streamlined from 22)
- **17+ Languages Supported** with syntax highlighting
- **Zero SwiftLint Violations** maintained across codebase

## Architecture Overview

### Directory Structure (Reorganized 2025)
```
Sources/CodeEditorPlugin/
├── Core/                    # Core functionality + APIs + Business Logic
│   ├── CodeEditorView.swift             # Main text view
│   ├── CodeEditorAPI.swift              # Public API surface
│   ├── TextEditingService.swift         # Text manipulation logic
│   └── EditorLayoutService.swift        # Layout calculations
├── Text/                    # All text handling (consolidated)
│   ├── TextKit helpers                  # NSTextView extensions
│   ├── Text layout                      # Layout fragments
│   └── Text processing                  # Async processing
├── Layout/                  # UI layout + Components + ViewModels
│   ├── GutterView.swift                 # Line numbers
│   ├── MinimapView.swift                # Code minimap
│   ├── GutterViewModel.swift            # Gutter state
│   └── MinimapViewModel.swift           # Minimap state
├── Configuration/           # Settings & validation
├── SyntaxHighlighting/      # Language highlighting
├── Languages/               # Language-specific providers
├── Completion/              # Code completion + ViewModel
├── Features/                # Optional features (flat structure)
├── SwiftUI/                 # SwiftUI integration
├── Platform/                # Cross-platform abstractions
├── Extensions/              # Type extensions
├── Performance/             # Monitoring & optimization
├── LSP/                     # Language Server Protocol
├── Annotations/             # Code annotations
├── Models/                  # Data models
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

### Key Files by Directory

**Core/** (40+ files)
- `CodeEditorView.swift` - Main text editor view
- `CodeEditorAPI.swift` - Public API interface
- `TextEditingService.swift` - Text manipulation logic
- `LanguageDetectionService.swift` - Auto-detect file types
- `SyntaxHighlightingService.swift` - Highlighting coordination
- `UnifiedEventSystem.swift` - Cross-platform event handling

**Text/** (34 files)
- `TextKitBridge.swift` - TextKit1/2 compatibility
- `TextLayoutManager.swift` - Custom layout management
- `AsyncTextProcessor.swift` - Background text processing
- `TextProcessingPipeline.swift` - Processing coordination
- `RangeValidator.swift` - Text range validation

**Layout/** (20+ files)
- `GutterView.swift` - Line number display
- `MinimapView.swift` - Code overview widget
- `CodeEditorContainerView.swift` - iOS container
- `GutterViewModel.swift` - Gutter state management
- `BaseUIComponents.swift` - Shared UI components

**Configuration/** (29 files)
- `EditorConfiguration.swift` - Main config structure
- `EditorConfigurationBuilder.swift` - Fluent builder API
- `ConfigurationValidator.swift` - Config validation
- `PresetConfiguration.swift` - Built-in presets
- `ConfigurationMigrator.swift` - Version migration

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

### Directory Reorganization (January 2025)
- **Reduced from 22 to 18 directories** for better discoverability
- **Consolidated text handling**: Created unified `Text/` directory combining TextKit, TextLayout, and TextProcessing
- **Merged small directories**: API → Core, UIComponents → Layout, BusinessLogic → Core
- **Distributed ViewModels**: Moved to their respective feature directories
- **Flattened nested structures**: Removed DebuggerIntegration subdirectory
- **Improved code organization**: Related functionality now grouped together

### Architecture & Performance
- **Unified Event System**: Consistent event handling across platforms
- **AsyncSyntaxHighlighter Cache**: LRU cache with memory limits
- **SwiftSyntaxHighlighter+Shared**: Refactored shared highlighting logic
- **Dependency Injection**: Replaced singletons (e.g., MemoryMonitor)
- **Swift 6 Concurrency**: Full actor isolation, eliminated Task anti-patterns
- **Business Logic Services**: Introduced service layer for language detection, syntax highlighting, and text editing

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