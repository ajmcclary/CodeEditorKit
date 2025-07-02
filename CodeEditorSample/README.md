# CodeEditorSample

[![Tests](https://img.shields.io/badge/tests-66%20passing-brightgreen)](#testing--quality)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#quality-metrics)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Files](https://img.shields.io/badge/files-40-blue)](#quality-metrics)

**The definitive showcase and comprehensive reference implementation for CodeEditorPlugin.**

This sample application is the primary way to evaluate the full capabilities of CodeEditorPlugin — showcasing its most advanced features, production-ready patterns, and modern Swift 6 architecture in action. More than just a demo, it serves as a living documentation of best practices and a testbed for exploring the plugin's sophisticated capabilities.

## 🎯 What This Demonstrates

Experience firsthand how CodeEditorPlugin transforms text editing in your applications:

### Modern Architecture in Practice
- ✅ **Swift 6 Actor System**: See how background actors handle intensive operations while keeping the UI buttery smooth. Watch real-time performance metrics as syntax highlighting processes in the background.
- ✅ **Feature-Based Organization**: Explore the clean, modular architecture that reduced directory count by 74%. Each feature is self-contained and easy to understand.
- ✅ **Thread Safety by Design**: Observe how Swift 6's strict concurrency prevents data races at compile time, not runtime.

### Advanced Features Showcase
- ✅ **Interactive Feature Explorer**: An interactive view where you can toggle advanced features in real-time:
  - Performance monitoring with frame rate and memory analysis
  - Plugin architecture preview - see how extensibility works
  - Language Server Protocol integration concepts
  - Code folding, smart indentation, and symbol navigation
- ✅ **17 Programming Languages**: Experience accurate syntax highlighting across all supported languages, from SwiftSyntax-powered Swift to optimized regex patterns for Python, JavaScript, Rust, and more.

### Production-Ready Patterns
- ✅ **SwiftUI Best Practices**: Modern, environment-based configuration patterns you can copy directly into your apps
- ✅ **Configuration Management**: See how the nested EditorConfiguration system works in practice with live updates
- ✅ **Theme System Implementation**: Professional themes (Xcode, VS Code Dark, GitHub, Solarized) with full dark mode support
- ✅ **Annotation System**: Interactive TODO/FIXME/NOTE badges with hover popups

### True Cross-Platform Excellence
- ✅ **Platform Abstraction in Action**: Watch how the same code adapts perfectly to macOS, iOS, and Mac Catalyst without compromises
- ✅ **Native Platform Features**: 
  - macOS: Full keyboard shortcuts, native menus, hover effects, modern toggle switches
  - iOS: Touch-optimized selection, proper keyboard handling, SwiftUI-native integration
  - Mac Catalyst: Best of both worlds with adaptive UI and proper configuration flow
- ✅ **Zero-Compromise Performance**: Platform-specific optimizations ensure native performance on each platform
- ✅ **Unified Configuration System**: Settings changes apply instantly across all platforms with proper state management

### Recent Refactoring Improvements

The CodeEditorSample has undergone significant improvements to ensure full compliance with CodeEditorPlugin across all platforms:

#### Configuration System Overhaul
- **Fixed Toggle Controls**: Replaced old-style checkboxes with modern `DefaultToggleStyle()` on macOS Native
- **Proper State Management**: Added `objectWillChange.send()` calls to force SwiftUI updates
- **Environment-Based Configuration**: iOS and Mac Catalyst now use CodeEditor directly with SwiftUI environment

#### Architecture Simplification
- **Removed Wrapper Layers**: Eliminated intermediate `CodeEditorViewWrapper` for iOS/Catalyst
- **Direct Component Usage**: Now uses `CodeEditor` from CodeEditorPlugin directly
- **Unified Update Flow**: Configuration changes propagate correctly through the coordinator pattern

#### Platform-Specific Fixes
- **macOS Native**: Resolved double line numbers by properly managing gutter views in container
- **Mac Catalyst**: Fixed configuration application with proper SwiftUI patterns
- **iOS/iPadOS**: Simplified to use native SwiftUI CodeEditor component

#### Code Quality Improvements
- **Zero SwiftLint Violations**: Maintained across all 40 files
- **Removed Debug Logging**: Cleaned up all console output for production readiness
- **Better Separation of Concerns**: Clear platform-specific code paths with `#if` directives

## 🚀 Quick Start

### Running the Application

```bash
# Navigate to the sample directory
cd CodeEditorSample

# Run the sample app (opens a native macOS window)
swift run CodeEditorSample

# Run the comprehensive test suite
swift test

# Run with performance monitoring
swift run CodeEditorSample --enable-performance-monitoring
```

The app launches a complete code editing environment demonstrating all features of the CodeEditorPlugin. Use the toolbar and configuration panel to explore different capabilities.

### 🎊 Recent Achievements

- ✅ **Perfect Test Suite**: All **66 tests passing** with comprehensive coverage
- ✅ **Zero Code Quality Issues**: **0 SwiftLint violations** across all 40 files
- ✅ **Swift 6 Ready**: Full actor-based concurrency and strict compliance
- ✅ **Production Performance**: Optimized builds and fast test execution
- ✅ **Cross-Platform Excellence**: Verified on macOS, iOS, and Mac Catalyst
- ✅ **Modern UI Controls**: Replaced old-style checkboxes with platform-appropriate toggle switches
- ✅ **Fixed Configuration Flow**: All settings now apply correctly across all platforms
- ✅ **Resolved Double Line Numbers**: Fixed gutter view duplication on macOS Native
- ✅ **Simplified Architecture**: Direct CodeEditor usage for iOS/Catalyst platforms

## ✨ How to Integrate the Plugin

This sample app provides battle-tested patterns for integrating CodeEditorPlugin into your applications. Below are clear, copy-paste-friendly examples for the most common integration tasks.

### 1. SwiftUI Integration

The recommended approach using modern, environment-based configuration for the cleanest integration.

```swift
// See Views/SwiftUIDemoView.swift for complete implementation
import CodeEditorPlugin
import SwiftUI

struct EditorView: View {
    @State private var code: String
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(detectLanguage(from: fileExtension))
            .environment(\.codeEditorConfiguration, configuration)
            .onAppear {
                // Configure editor on appearance
                configuration.display.showLineNumbers = true
                configuration.display.enableAnnotations = true
            }
    }
}
```

### 2. Configuration Management

Learn how to use the structured `EditorConfiguration` system for fine-grained control.

```swift
// See Models/EditorConfiguration.swift for all options
var config = EditorConfiguration()

// Display settings
config.display.showLineNumbers = true
config.display.fontSize = 14
config.display.enableAnnotations = true

// Layout settings
config.layout.tabWidth = 4
config.layout.wrapLines = false
config.layout.lineSpacing = 1.2

// Behavior settings
config.behavior.autoIndent = true
config.behavior.enableCodeCompletion = true

// Performance settings
config.performance.useHardwareAcceleration = true
config.performance.maxSyntaxHighlightingLength = 500_000

// Apply to an existing editor
config.apply(to: textView)
```

### 3. Leveraging Configuration Presets

Use pre-built configurations optimized for common scenarios.

```swift
// See how presets are implemented in Models/EditorConfiguration.swift
enum ConfigurationPreset {
    case fullFeatured    // All features enabled
    case minimal         // Lightweight, fast editing
    case readOnly        // Viewing without editing
    case markdown        // Optimized for Markdown
    case presentation    // Large fonts for demos
}

// Apply a preset
let config = ConfigurationPreset.fullFeatured.configuration
```

### 4. Custom Theme Implementation

Create beautiful, accessible themes that adapt to light and dark modes.

```swift
// See Themes/ThemeProvider.swift for complete implementation
enum ColorTheme: String, CaseIterable {
    case xcode, vsDark, github, solarizedDark
    
    var backgroundColor: PlatformColor {
        switch self {
        case .xcode: return PlatformColor(hex: "#FFFFFF", dark: "#1F1F24")
        case .vsDark: return PlatformColor(hex: "#1E1E1E")
        // ... more themes
        }
    }
    
    // Define all theme colors...
}

// Apply a theme
configuration.display.backgroundColor = theme.backgroundColor
configuration.display.textColor = theme.textColor
```

### 5. Annotation System Integration

See how to detect and display inline code annotations.

```swift
// Annotations are automatically detected in comments
// TODO: This appears as an inline badge
// FIXME: This shows as a warning badge
// NOTE: Informational annotation

// Configure annotation behavior
config.display.enableAnnotations = true
config.display.annotationRenderingMode = .inline
```

## 🧪 Testing & Quality

The sample app maintains the same high quality standards as the core plugin:

### Test Coverage
- **66 Automated Tests**: Comprehensive coverage of UI, configuration, integration, and performance (100% passing)
- **Test Categories**:
  - `AnnotationSystemTests`: Comprehensive annotation testing with performance benchmarks (20 tests)
  - `ConfigurationUITests`: UI-level configuration tests (12 tests)
  - `SampleCodeTests`: Language sample validation (12 tests)
  - `PluginConfigurationTests`: Plugin system tests (11 tests)
  - `SimplifiedIntegrationTests`: End-to-end integration testing (6 tests)
  - `BasicFunctionalityTests`: Core functionality verification (4 tests)
  - `QuickIsFlippedTest`: View hierarchy tests (1 test)
  
### Quality Metrics
- **SwiftLint Compliance**: Zero violations across 40 files
- **Swift 6 Concurrency**: Full actor isolation and Sendable compliance
- **Memory Safety**: Verified with Instruments and comprehensive memory leak detection
- **Test Pass Rate**: 100% - All tests passing in final validation
- **Performance Testing**: Automated benchmarks ensure consistent performance
- **Configuration System**: Fully functional with proper state management across all platforms

### Running Tests

```bash
# Run all sample app tests
swift test

# Run specific test suites
swift test --filter ConfigurationUITests
swift test --filter PluginConfigurationTests

# Run with verbose output
swift test --verbose

# Run performance tests only
swift test --filter Performance
```

## 📋 Requirements

- **Swift**: 6.0+
- **Platforms**:
  - **macOS**: 12.0+ (optimized for macOS 14+)
  - **iOS**: 16.0+
  - **Mac Catalyst**: 16.0+
- **Xcode**: 16.0+
- **Dependencies**: Inherits all dependencies from `CodeEditorPlugin`

## 🤝 Contributing

We welcome contributions to make this sample app even better! Whether you're adding new integration examples, improving documentation, or showcasing additional features:

1. Fork the repository
2. Create a feature branch
3. Add your enhancements with appropriate tests
4. Ensure all tests pass (`swift test`)
5. Submit a pull request with a clear description

## 📚 Learning Resources

- **Integration Patterns**: Study the `Views/` directory for SwiftUI best practices
- **Configuration Examples**: See `Models/EditorConfiguration.swift` for all options
- **Theme Creation**: Learn from `Themes/ThemeProvider.swift`
- **Performance Optimization**: Check `Services/ConfigurationCoordinator.swift`

--- 

**🎉 Ready to build something amazing?** This sample app provides everything you need to integrate CodeEditorPlugin into your applications. Study the patterns, run the tests, and create powerful code editing experiences for your users!