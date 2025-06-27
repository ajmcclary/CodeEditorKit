# CodeEditorSample

A comprehensive demonstration application showcasing the full capabilities of the **CodeEditorPlugin**. This sample app serves as both a functional code editor and a reference implementation for developers learning to integrate CodeEditorPlugin into their own applications.

> **🎉 Recently Enhanced:** Cross-platform compatibility improvements with Mac Catalyst fixes, iOS ConfigurationExporter implementation, enhanced platform abstractions, and 66 comprehensive tests. Demonstrates the complete refactored architecture with modular platform-specific components.

## 🎯 What This Demonstrates

This sample application provides a complete example of:

- ✅ **Cross-Platform Compatibility** - Complete Mac Catalyst support with proper platform detection patterns
- ✅ **iOS Feature Parity** - Native iOS ConfigurationExporter using UIDocumentPickerViewController
- ✅ **Modular Architecture** - Platform-specific file organization with clean separation of concerns
- ✅ **Enhanced Platform Abstractions** - Semantic color system with 8 new system colors
- ✅ **Unified Configuration Integration** - How to use the plugin's EditorConfiguration system
- ✅ **Working Syntax Highlighting** - **17 programming languages** with SwiftUI and AppKit
- ✅ **Professional UI Components** - Line numbers, themes, status bars, and toolbars
- ✅ **Configuration Presets** - Pre-built editor configurations for different use cases
- ✅ **Real-Time Configuration** - Live updates without restart using nested configuration structure
- ✅ **Inline Annotations** - TODO/FIXME/NOTE/WARNING/ERROR detection with hover popups
- ✅ **Modern Architecture** - Swift 6 actor-based concurrency with full thread safety
- ✅ **Comprehensive Testing** - **66 tests** covering all major functionality including cross-platform features
- ✅ **Advanced Features Showcase** - Interactive demo with performance monitoring and feature exploration
- ✅ **Plugin System Preview** - Architecture demonstration with marketplace integration
- ✅ **Language Server Protocol** - LSP integration showcase for future language features

## 🚀 Quick Start

### Running the Application

```bash
# Navigate to the sample directory
cd CodeEditorSample

# Run the sample app (opens macOS window)
swift run CodeEditorSample

# Run tests to verify everything works
swift test
```

The app launches as a native macOS application with a complete code editing interface, demonstrating all features of CodeEditorPlugin.

## ✨ Key Features Demonstrated

### 1. 📋 Configuration System Integration

The sample shows how to properly integrate with CodeEditorPlugin's unified configuration:

```swift
// Sample uses the plugin's EditorConfiguration directly
import CodeEditorPlugin

// Configuration with nested structure
var config = EditorConfiguration()
config.display.showLineNumbers = true
config.display.fontSize = 14
config.layout.wrapLines = false
config.behavior.isEditable = true
config.performance.useHardwareAcceleration = true

// Apply to editor
config.apply(to: textView)
```

### 2. 🔧 Configuration Presets

Pre-built configurations for common scenarios using EditorConfigurationBuilder:

- **Full Featured** - All features enabled for development
- **Minimal** - Clean interface for focused writing  
- **Read Only** - Syntax-highlighted viewer mode
- **Markdown** - Optimized for Markdown editing with spell check
- **Presentation** - Large fonts and high contrast for demos

```swift
// Using presets (defined in Models/EditorConfiguration.swift)
let config = ConfigurationPreset.fullFeatured.configuration
let minimal = ConfigurationPreset.minimal.configuration
```

### 3. 🎨 SwiftUI Integration

Demonstrates modern SwiftUI integration patterns:

```swift
// Basic SwiftUI integration
CodeEditorSwiftUIView(
    text: $code,
    language: .swift,
    showLineNumbers: true,
    highlightSelectedLine: true,
    isEditable: true
)
.environment(\.codeEditorConfiguration, configuration)

// Cross-platform wrapper (see Views/CodeEditorViewWrapper.swift)
SampleCodeEditorView(
    configuration: configuration,
    text: $text,
    language: "swift"
)
```

### 4. 🌈 Multi-Language Syntax Highlighting (17 Languages)

Working syntax highlighting for:

- **Swift** - Native SwiftSyntax integration with AST-based highlighting
- **Python, JavaScript, TypeScript** - Advanced regex-based highlighting with modern features
- **Rust, Go, C/C++, Java** - Modern language features and syntax
- **HTML/CSS** - Web languages with advanced selectors and CSS3 features
- **JSON, YAML, XML** - Structured data formats with validation
- **Markdown** - GitHub Flavored Markdown with extension support
- **Ruby, PHP, SQL** - Dynamic languages and database queries

### 5. 🎨 Theme System

Professional themes with real-time switching:

```swift
// Theme management (see Themes/ThemeProvider.swift)
enum ColorTheme: String, CaseIterable {
    case xcode, vsDark, github, solarizedDark, minimal, presentation
    
    var backgroundColor: NSColor { /* theme colors */ }
    var textColor: NSColor { /* theme colors */ }
    // ... complete theme definitions
}
```

### 6. 📝 Annotation System

Complete inline annotation system:

```swift
// Annotation detection (see Services/AnnotationManager.swift)
let manager = AnnotationManager(textView: textView)
manager.scanForAnnotations() // Finds TODO, FIXME, NOTE, WARNING, ERROR
```

## 🏗️ Project Architecture

### Sample App Structure (Cross-Platform Enhanced)

```
CodeEditorSample/
├── Sources/CodeEditorSample/
│   ├── CodeEditorSampleApp.swift          # Main app with menu system
│   ├── Models/
│   │   ├── EditorConfiguration.swift      # Configuration presets
│   │   ├── AppState.swift                 # Global state with import/export
│   │   ├── SampleCodeProvider.swift       # 17-language sample content
│   │   └── *Samples.swift                 # Sample code by language category
│   ├── Views/
│   │   ├── ContentView.swift              # Main entry point
│   │   ├── UnifiedContentView.swift       # Cross-platform main UI
│   │   ├── UnifiedConfigurationView.swift # Complete configuration UI with LSP/Plugin sections
│   │   ├── AdvancedFeaturesShowcaseView.swift # Interactive advanced features demo
│   │   ├── SampleCodeEditorView.swift     # Editor with live preview
│   │   ├── CodeEditorViewWrapper.swift    # Platform wrapper
│   │   ├── SwiftUIDemoView.swift          # SwiftUI integration demo
│   │   └── StatusBarView.swift            # Status information
│   ├── Services/
│   │   ├── AnnotationManager.swift        # Annotation detection with performance testing
│   │   └── ConfigurationExporter.swift    # Cross-platform settings import/export (macOS+iOS)
│   ├── Themes/
│   │   └── ThemeProvider.swift            # Color theme definitions with Mac Catalyst fixes
│   └── Platform/
│       └── PlatformTypes.swift            # Platform abstractions
└── Tests/CodeEditorSampleTests/            # 66 comprehensive tests
    ├── AnnotationSystemTests.swift        # Comprehensive annotation testing (20 tests)
    ├── BasicFunctionalityTests.swift       # Core functionality (4 tests)
    ├── ConfigurationUITests.swift          # UI configuration (12 tests)
    ├── PluginConfigurationTests.swift      # Plugin integration (11 tests)
    ├── SampleCodeTests.swift              # 17-language samples testing (12 tests)
    ├── SimplifiedIntegrationTests.swift    # End-to-end testing (6 tests)
    └── QuickIsFlippedTest.swift           # View hierarchy testing (1 test)
```

### Key Integration Patterns

**1. Plugin Configuration Integration:**
```swift
// Sample uses plugin's EditorConfiguration via typealias
typealias EditorConfiguration = CodeEditorPlugin.EditorConfiguration

// Configuration presets use EditorConfigurationBuilder
return EditorConfigurationBuilder()
    .showLineNumbers(true)
    .fontSize(14)
    .annotations(true)
    .build()
```

**2. Cross-Platform SwiftUI Wrapper:**
```swift
// Unified wrapper handling macOS and iOS differences
struct SampleCodeEditorView: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    
    var body: some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            CodeEditor(text: $text)
                .codeLanguage(detectLanguage(from: language))
                .environment(\.codeEditorConfiguration, configuration)
        } else {
            CodeEditorViewWrapper(/* AppKit integration */)
        }
        #else
        CodeEditorSwiftUIView(/* iOS implementation */)
        #endif
    }
}
```

**3. Real-Time Configuration Updates:**
```swift
// Live configuration updates (see Views/ContentView.swift)
@Published var currentConfiguration = EditorConfiguration() {
    didSet {
        // Configuration automatically applied through SwiftUI binding
    }
}
```

## 🧪 Testing & Quality

### Test Coverage (66 Tests)

- **20 Annotation Tests** - Comprehensive annotation system with performance benchmarks
- **12 Configuration Tests** - UI and integration testing
- **12 Sample Code Tests** - 17-language sample validation with comprehensive syntax testing
- **11 Plugin Tests** - Plugin system verification and architecture testing
- **6 Integration Tests** - End-to-end functionality
- **4 Basic Tests** - Core functionality verification
- **1 UI Test** - View hierarchy testing

### Running Tests

```bash
# Run all sample app tests
swift test

# Verbose output
swift test --verbose

# Specific test suite
swift test --filter ConfigurationUITests
```

### Code Quality

```bash
# Lint and format code
swiftlint --fix && swiftlint  # ✅ Only 1 minor file length warning
swift build                   # ✅ Clean build
swift test                    # ✅ 66/66 tests passing
```

## 🛠️ Customization Examples

### Adding New Language Support

```swift
// 1. Add to SampleCode enum
enum SampleCode: String, CaseIterable {
    case swift, javascript, typescript, python, go, rust, cpp, java,
         html, css, json, markdown, yaml, xml, sql, ruby, php, newLanguage
}

// 2. Add sample code (in Models/SampleCodeProvider.swift)
case .newLanguage:
    return """
    // Your language sample here with comments
    // TODO: Add comprehensive language features
    print("Hello from new language!")
    """

// 2. Language detection works automatically via file extensions
textView.setLanguage(fileExtension: "newlang")
```

### Creating Custom Themes

```swift
// Add to Themes/ThemeProvider.swift
static let customTheme = ColorTheme(
    backgroundColor: NSColor.black,
    textColor: NSColor.white,
    selectedLineColor: NSColor.darkGray,
    keywordColor: NSColor.systemBlue,
    stringColor: NSColor.systemGreen,
    commentColor: NSColor.systemGray
)
```

### Custom Configuration Presets

```swift
// Add to Models/EditorConfiguration.swift
case .custom:
    return EditorConfigurationBuilder()
        .showLineNumbers(true)
        .fontSize(16)
        .wrapLines(true)
        .annotations(false)
        .hardwareAcceleration(true)
        .build()
```

## 📋 Requirements

- **Swift**: 6.0+ (full actor-based concurrency)
- **Platforms**:
  - **macOS**: 12.0+ (optimized for macOS 14+)
  - **iOS**: 16.0+ (with container architecture)
  - **Mac Catalyst**: 16.0+
- **Xcode**: 16.0+
- **Dependencies**: Inherits from CodeEditorPlugin (swift-syntax 510.0.0+)

## 🔧 Configuration Reference

### Nested Configuration Structure

```swift
var config = EditorConfiguration()

// Display settings
config.display.showLineNumbers = true
config.display.highlightSelectedLine = true
config.display.showInvisibleCharacters = false
config.display.fontSize = 14.0
config.display.enableSyntaxHighlighting = true
config.display.enableAnnotations = true

// Layout settings
config.layout.wrapLines = false
config.layout.tabWidth = 4
config.layout.insertSpacesForTabs = true
config.layout.lineSpacing = 1.2

// Behavior settings
config.behavior.isEditable = true
config.behavior.autoIndent = true
config.behavior.enableCodeCompletion = true

// Performance settings
config.performance.useHardwareAcceleration = true
config.performance.smoothScrolling = true
```

### Builder Pattern Usage

```swift
let config = EditorConfigurationBuilder()
    .showLineNumbers(true)
    .fontSize(16)
    .wrapLines(false)
    .annotations(true)
    .hardwareAcceleration(true)
    .build()
```

## 🐛 Troubleshooting

### Common Issues & Solutions

**Configuration not applying:**
```swift
// Ensure proper configuration application
config.apply(to: textView)
// Or use SwiftUI environment
.environment(\.codeEditorConfiguration, config)
```

**Performance with large files:**
```swift
// Optimize settings
config.performance.useHardwareAcceleration = true
config.display.showLineNumbers = false
config.performance.maxSyntaxHighlightingLength = 100_000
```

**Syntax highlighting not working:**
```swift
// Verify language setting
textView.setLanguage(fileExtension: "swift")
// And ensure highlighting is enabled
config.display.enableSyntaxHighlighting = true
```

## 📚 Learning Resources

1. **📖 Sample App Code** - Complete working implementation
2. **🧪 Test Suite** - Reference implementation patterns
3. **⚙️ Configuration Presets** - Example configurations for different use cases
4. **📝 Language Samples** - Multi-language code examples
5. **🎨 Theme Gallery** - Color scheme implementations

## 🤝 Contributing

This sample app welcomes improvements:

1. Fork the repository
2. Add features or improvements to the sample
3. Ensure all tests pass: `swift test`
4. Update documentation if needed
5. Submit a pull request

Focus areas for contributions:
- Additional language samples (targeting 20+ languages)
- Advanced feature implementations (multi-cursor, search/replace)
- New configuration presets and themes
- UI enhancements and accessibility
- Performance optimizations and benchmarks
- Cross-platform improvements (iOS/iPadOS)
- Plugin system development
- LSP integration features

## 📄 License

This sample application is part of the CodeEditorPlugin package and follows the same MIT license terms.

---

**🎉 Ready to build your own code editor?** This sample app provides everything you need to get started with CodeEditorPlugin! Study the code, run the tests, and adapt the patterns for your own applications.