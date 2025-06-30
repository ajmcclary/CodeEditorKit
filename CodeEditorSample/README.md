# CodeEditorSample

[![Tests](https://img.shields.io/badge/tests-46%20passing-brightgreen)](#testing--quality)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#quality-metrics)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Files](https://img.shields.io/badge/files-36-blue)](#quality-metrics)

**The definitive showcase and reference implementation for CodeEditorPlugin.**

This application is the primary way to evaluate the full capabilities of the **CodeEditorPlugin**. More than just a demo, it serves as a comprehensive reference implementation showcasing production-ready patterns, advanced features, and best practices for integrating the plugin into professional applications.

## 🎯 What This Demonstrates

Experience firsthand how CodeEditorPlugin transforms text editing in your applications:

### Architecture & Performance
- ✅ **Modern Architecture in Practice**: See Swift 6 actors and the feature-based structure implemented in a real application. Observe how background processing keeps the UI responsive even with large files.
- ✅ **Production Performance**: Monitor real-time performance metrics, memory usage, and rendering efficiency. Learn optimization strategies for your specific use cases.

### Advanced Capabilities
- ✅ **Advanced Features Showcase**: An interactive playground exploring performance monitoring, the preview plugin architecture, and Language Server Protocol (LSP) integration concepts.
- ✅ **Rich Syntax Highlighting**: Experience all **17 supported languages** with accurate, performant highlighting. See how SwiftSyntax provides AST-based analysis for Swift code.

### Cross-Platform Excellence
- ✅ **Robust Cross-Platform Support**: A single codebase that adapts perfectly to macOS, iOS, and Mac Catalyst. Witness how the platform abstraction layer provides truly native experiences on each platform.
- ✅ **Platform-Specific Optimizations**: See how the editor leverages platform capabilities while maintaining a consistent API.

### Configuration & Customization
- ✅ **Comprehensive Configuration**: A live, interactive UI to manipulate all 40+ configuration options in real-time. Instantly see how each setting affects the editor's behavior and appearance.
- ✅ **Theme System**: Switch between multiple professional themes (Xcode, VS Code Dark, GitHub, Solarized) and learn how to create custom themes.

### Integration Patterns
- ✅ **Production-Ready Patterns**: Best practices for SwiftUI integration, configuration management, theme handling, and annotation systems. Copy these patterns directly into your applications.
- ✅ **Real-World Implementation**: See how to handle edge cases, manage state, and integrate with existing application architectures.

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

- ✅ **Perfect Test Suite**: All **46 tests passing** with comprehensive coverage
- ✅ **Zero Code Quality Issues**: **0 SwiftLint violations** across all 36 files
- ✅ **Swift 6 Ready**: Full actor-based concurrency and strict compliance
- ✅ **Production Performance**: Optimized builds and fast test execution
- ✅ **Cross-Platform Excellence**: Verified on macOS, iOS, and Mac Catalyst

## ✨ How to Integrate the Plugin

This sample app demonstrates battle-tested patterns for integrating CodeEditorPlugin. Below are key integration patterns you can adapt directly for your projects.

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
- **46 Automated Tests**: Comprehensive coverage of UI, configuration, integration, and performance (100% passing)
- **Test Categories**:
  - BasicFunctionalityTests (4 tests)
  - ConfigurationUITests (12 tests)
  - PluginConfigurationTests (11 tests)  
  - QuickIsFlippedTest (1 test)
  - SampleCodeTests (12 tests)
  - SimplifiedIntegrationTests (6 tests)
  
### Quality Metrics
- **SwiftLint Compliance**: Zero violations across 36 files (part of overall 0 violations across 204 project files)
- **Swift 6 Concurrency**: Full actor isolation and Sendable compliance
- **Memory Safety**: Verified with Instruments and comprehensive memory leak detection
- **Test Pass Rate**: 100% - All tests passing in final validation

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