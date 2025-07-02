# GEMINI.md

This guide helps Gemini and other AI code assistants effectively work with the CodeEditorPlugin project.

## Project Overview

CodeEditorPlugin is a **production-ready**, **Swift 6-based** code editor component for macOS, iOS, and Mac Catalyst.

### Key Differentiators
- **Swift 6 Actor System**: Full concurrency safety with modern actors
- **True Cross-Platform**: Not a port - built from the ground up for all platforms
- **17 Languages**: SwiftSyntax for Swift, optimized regex for others
- **172 Tests**: Comprehensive test coverage ensuring reliability (106 core + 66 sample)
- **Zero Technical Debt**: Clean architecture, no linting violations
- **Advanced Features**: Plugin architecture, LSP integration, performance monitoring
- **74% Simpler**: Directory structure reduced from 39 to 10 directories

## Essential Commands

### Development Workflow
```bash
# Build the main package
swift build

# Run the sample application
cd CodeEditorSample && swift run CodeEditorSample

# Run all tests (172 total)
swift test

# Quality check (build + lint + test)
swift build && swiftlint && swift test
```

### Code Quality
```bash
# Auto-fix linting issues
swiftlint --fix

# Check for violations (should be 0)
swiftlint

# Clean rebuild
swift package clean && swift build
```

## Architecture & Structure

### Feature-Based Organization
The codebase is organized by feature for clarity and maintainability:

```
Sources/CodeEditorPlugin/
├── Core/                    # Text editing engine (CodeEditorView)
├── Configuration/           # Unified config system
├── SyntaxHighlighting/      # Language highlighting
├── Layout/                  # UI components (GutterView)
├── SwiftUI/                 # SwiftUI integration
├── Platform/                # Cross-platform abstractions
├── TextProcessing/          # Actor-based processing
├── Completion/              # Code completion
├── LSP/                     # Language Server Protocol
├── Plugin/                  # Plugin architecture
└── Extensions/              # Type extensions (+Extensions)
```

### Core Components Explained

**1. CodeEditorView** (`Core/CodeEditorView.swift`)
- The heart of the editor - TextKit2-based text view
- Handles text editing, selection, and input
- Platform-aware with proper iOS/macOS support

**2. EditorConfiguration** (`Configuration/EditorConfiguration.swift`)
- Nested configuration: display, layout, behavior, performance
- Presets: default, minimal, readOnly, markdown, presentation
- Immutable updates with `.with()` pattern

**3. SyntaxHighlightingCoordinator** (`SyntaxHighlighting/`)
- Manages language detection and highlighting
- SwiftSyntax for accurate Swift AST analysis
- Regex patterns for 16+ other languages
- Viewport-optimized for performance

**4. Platform Abstraction** (`Platform/`)
- Unified types: PlatformColor, PlatformFont, PlatformView
- Capability detection: hardware acceleration, TextKit2
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
- Maintain 172+ test count

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
swift package clean
rm -rf .build
swift build

# Performance issues
# Use Instruments with the sample app
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
- **Test Count**: 172 (106 main + 66 sample)
- **SwiftLint**: Zero violations required
- **Platforms**: Must work on all three
- **Performance**: <16ms frame time (60fps target)

### Supported Languages
Swift (AST-based), Python, JavaScript, TypeScript, Rust, C, C++, HTML, CSS, JSON, YAML, Markdown, Go, Java, Ruby, PHP, SQL, XML, Shell

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

### Advanced Editing Capabilities
- Smart context-aware indentation
- Code folding with persistence
- Symbol navigation and breadcrumbs
- Incremental parsing for performance
- Intelligent bracket matching
- Powerful search & replace with regex

## Key Achievements
- **Architecture**: 74% directory reduction through reorganization
- **Swift 6**: Full migration to actor-based concurrency
- **Cross-Platform**: All rendering issues resolved
- **Performance**: Viewport optimization implemented
- **Quality**: Zero linting violations maintained
- **Advanced Features**: Plugin system and LSP integration added

### Recent CodeEditorSample Improvements
- **Modern UI**: Replaced old checkboxes with platform-appropriate toggles
- **Configuration Fix**: Settings now apply correctly on all platforms
- **Double Line Numbers**: Resolved gutter duplication on macOS Native
- **Simplified Architecture**: Direct CodeEditor usage for iOS/Catalyst
- **State Management**: Proper SwiftUI updates with objectWillChange
- **File Count**: Increased to 40 files while maintaining zero violations

## Remember
This is a **production-ready** component used in real applications. Every change should maintain or improve the quality standards. When in doubt, add tests and check performance!