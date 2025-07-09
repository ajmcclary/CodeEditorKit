# GEMINI.md

This guide helps Gemini and other AI code assistants effectively work with the CodeEditorPlugin project.

## Project Overview

CodeEditorPlugin is a Swift 6-based code editor component for macOS, iOS, and Mac Catalyst.

### Key Differentiators
- **Swift 6 Actor System**: Full concurrency safety with modern actors
- **True Cross-Platform**: Built from the ground up for all platforms
- **17 Languages**: SwiftSyntax for Swift, optimized regex for others
- **425 Tests**: Comprehensive test coverage ensuring reliability (390 core + 35 sample)
- **Zero Technical Debt**: Clean architecture, no linting violations across 270 files
- **74% Simpler**: Directory structure reduced from 39 to 10 directories

## Essential Commands

### Development Workflow
```bash
# Build, lint, and test (standard workflow)
swift build && swiftlint && swift test

# Run the sample application
cd CodeEditorSample && swift run CodeEditorSample

# Auto-fix linting issues
swiftlint --fix

# Clean rebuild
swift package clean && swift build
```

## Architecture & Structure

### Feature-Based Organization
```
Sources/CodeEditorPlugin/
├── Core/                    # Text editing engine (CodeEditorView)
├── Configuration/           # Unified config system
├── SyntaxHighlighting/      # Language highlighting
├── Layout/                  # UI components (GutterView)
├── SwiftUI/                 # SwiftUI integration
├── Platform/                # Enhanced cross-platform abstractions
├── TextProcessing/          # Actor-based processing
├── Completion/              # Code completion
├── LSP/                     # Language Server Protocol
└── Extensions/              # Type extensions (+Extensions)
```

### Core Components

**CodeEditorView** (`Core/CodeEditorView.swift`)
- Main TextKit2-based text view with platform-aware support

**EditorConfiguration** (`Configuration/EditorConfiguration.swift`)
- Nested configuration: display, layout, behavior, performance
- Presets: default, minimal, readOnly, markdown, presentation
- Immutable updates with `.with()` pattern

**Platform Abstraction** (`Platform/`)
- Unified types: PlatformColor, PlatformFont, PlatformView
- Enhanced with `#if canImport()` patterns replacing `#if os()`
- Runtime capability detection: hardware acceleration, TextKit2
- CrossPlatformCoordinator for unified input handling
- Ensures native feel on each platform

## Code Examples

### Basic Integration
```swift
// Create editor with configuration
let editor = CodeEditorView()
var config = EditorConfiguration()
config.display.showLineNumbers = true
config.layout.tabWidth = 4
config.apply(to: editor)

// Set language
editor.setLanguage(fileExtension: "swift")
```

### SwiftUI Usage
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

### Platform Abstractions
```swift
// Always use abstractions for cross-platform code
let textColor = PlatformColors.label
let bgColor = PlatformColors.systemBackground
let font = PlatformFonts.monospacedSystemFont(ofSize: 14)

// Check capabilities
if PlatformCapabilities.shared.supportsHardwareAcceleration {
    config.performance.useHardwareAcceleration = true
}
```

## Working Guidelines

### Code Style
- **Swift 6 Actors**: Use actors for all background work
- **Platform Checks**: Use `#if canImport()` not `#if os()`
- **Extensions**: Name with `+Extensions` suffix
- **SwiftLint**: Maintain zero violations

### Performance Best Practices
- Enable hardware acceleration for large files
- Use viewport-based rendering
- Test with files >500KB
- Profile with Instruments

### Testing Requirements
- Add tests for new features
- Run on all platforms (macOS, iOS, Mac Catalyst)
- Include performance benchmarks
- Maintain 319+ test count

## Common Development Tasks

### Adding a Language
1. Add case to `Language` enum in `Models/`
2. Add regex patterns in `RegexSyntaxHighlighter`
3. Map file extensions in `SyntaxHighlightingCoordinator`
4. Add test cases

### Adding Configuration Options
1. Add property to appropriate section (display/layout/behavior/performance)
2. Update configuration presets if needed
3. Add SwiftUI modifier if applicable
4. Document in inline comments

### Platform-Specific Features
1. Add abstraction in `Platform/` directory
2. Implement for each platform with `#if canImport()`
3. Update `PlatformCapabilities` if needed
4. Test on all platforms

## Debugging Tips

### Common Issues
```bash
# SwiftLint violations
swiftlint --fix

# Test failures
swift test --filter TestName --verbose

# Build issues
swift package clean && swift build

# Performance issues - use Instruments with sample app
```

### Platform-Specific Testing
```bash
# macOS
swift run CodeEditorSample

# iOS Simulator
xcodebuild -scheme CodeEditorSample -destination 'platform=iOS Simulator,name=iPhone 15'

# Mac Catalyst
xcodebuild -scheme CodeEditorSample -destination 'platform=macOS,variant=Mac Catalyst'
```

## Project Standards

### Quality Metrics
- **Test Count**: 319 (284 main + 35 sample)
- **SwiftLint**: Zero violations across 270 files (229 plugin + 41 sample)
- **Platforms**: Must work on all three
- **Performance**: <16ms frame time (60fps target)

### Supported Languages
Swift (AST-based), Python, JavaScript, TypeScript, Rust, C/C++, HTML, CSS, JSON, YAML, Markdown, Go, Java, Ruby, PHP, SQL, XML, Shell

### Platform Requirements
- **macOS**: 12.0+ (optimized for 14+)
- **iOS**: 16.0+
- **Mac Catalyst**: 16.0+
- **Swift**: 6.0+ (required for actors)
- **Xcode**: 16.0+

## Advanced Features

### Performance Monitoring
- Real-time frame rate analysis (60fps target)
- Memory usage tracking and profiling
- Syntax highlighting performance metrics
- Large file optimization (500KB+)

### Plugin Architecture (Preview)
- Custom language plugin support
- External tool integrations
- Theme marketplace ready
- Domain-specific command extensions

### Language Server Protocol (Preview)
- Intelligent code completion
- Real-time error diagnostics
- Go-to-definition navigation
- Hover documentation tooltips
- Automated refactoring support

## Key Achievements
- **Architecture**: 74% directory reduction through reorganization
- **Swift 6**: Full migration to actor-based concurrency
- **Cross-Platform**: All rendering issues resolved
- **Performance**: Viewport optimization implemented
- **Quality**: Zero linting violations maintained

### Recent Major Refactoring (2025)
- **Platform Abstraction Enhancement**: Replaced all `#if os()` with `#if canImport()` patterns
- **Modern UI**: Replaced old checkboxes with platform-appropriate toggles
- **Configuration Fix**: Settings now apply correctly on all platforms
- **Unified Wrapper Architecture**: Protocol-based wrapper system with platform implementations
- **Simplified Architecture**: Direct CodeEditor usage for iOS/Catalyst
- **File Organization**: 270 total Swift files (229 plugin + 41 sample app)

## Documentation System

CodeEditorPlugin includes comprehensive DocC documentation in `Sources/CodeEditorPlugin/Documentation.docc/`:

### Key Documentation
- **Main Hub**: `CodeEditorPlugin.md` - Central documentation entry point
- **Getting Started**: `GettingStarted.md` - Quick setup and basic usage
- **Configuration Guide**: `Configuration-System.md` - Complete config documentation
- **Integration Guides**: `SwiftUI-Integration.md`, `Platform-Abstraction.md`

### Viewing Documentation
```bash
# Generate documentation
swift package generate-documentation --target CodeEditorPlugin

# View in browser
swift package --allow-writing-to-directory docs generate-documentation --target CodeEditorPlugin --output-path docs --transform-for-static-hosting
open docs/documentation/codeeditorplugin/index.html
```

## Remember
This is a **production-ready** component used in real applications. Every change should maintain or improve the quality standards. When in doubt, add tests and check performance!