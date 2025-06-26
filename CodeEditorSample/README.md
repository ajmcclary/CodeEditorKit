# CodeEditor Sample App

A comprehensive, feature-rich macOS application demonstrating the full capabilities of the CodeEditorPlugin package. This sample app provides a professional code editing experience with modern Swift 6 Actor-Based Concurrency architecture, smooth scrolling, advanced syntax highlighting, and extensive customization options.

## 🎯 Overview

This sample app is a complete demonstration of CodeEditorPlugin's capabilities:

- ✅ **Full-featured code editor** with syntax highlighting for 15+ programming languages
- ✅ **6 built-in color themes** with real-time switching and custom theme support
- ✅ **Smooth scrolling** with proper NSScrollView integration
- ✅ **Professional UI** with line numbers, invisible characters, and line highlighting
- ✅ **Configuration management** with import/export functionality and presets
- ✅ **Multiple editor instances** with different configurations and layouts
- ✅ **Interactive feature tour** and comprehensive documentation
- ✅ **Swift 6 Actor-Based Concurrency** with thread-safe validation and processing
- ✅ **Full Swift 6 compliance** with complete Sendable conformance
- ✅ **Comprehensive testing** with 66 passing tests including annotation system testing and performance benchmarks
- ✅ **Inline Annotations** with hover popups for TODO/FIXME/NOTE/WARNING/ERROR comments
- ✅ **SwiftUI Integration** with cross-platform support for macOS, iOS, and iPadOS
- ✅ **Modern SwiftUI API** with environment theming and reactive bindings

## 🚀 Quick Start

### Running the Application

1. **Navigate to the sample directory:**
   ```bash
   cd CodeEditorSample
   ```

2. **Run the app:**
   ```bash
   swift run CodeEditorSample
   ```

3. **Or run tests:**
   ```bash
   swift test
   ```

The app launches as a native macOS application with its own window, menu bar, and full feature set.

## ✨ Key Features

### 1. 📋 Configuration Presets

The app includes professionally crafted editor configurations:

- **🔧 Full Featured**: All features enabled for professional development
- **🎨 Minimal**: Clean, distraction-free interface for focused writing
- **👁️ Read Only**: Syntax-highlighted code viewer with presentation mode
- **📝 Markdown**: Optimized for Markdown editing with line wrapping
- **🎤 Presentation**: Large fonts and high contrast for demos and teaching
- **⚡ Performance**: Optimized settings for large files

### 2. 🌈 Language Support & Syntax Highlighting

Advanced syntax highlighting with dual-strategy approach:

**Swift** (SwiftSyntax integration):
- Native AST-based highlighting
- Semantic analysis
- Advanced token recognition

**Other Languages** (Regex-based):
- JavaScript/TypeScript - ES6+ features, JSX support
- Python - Python 3.x syntax, decorators, f-strings
- Rust - Ownership syntax, macros, attributes
- Go - Goroutines, channels, interfaces
- C/C++ - Modern C++20 features
- Java - Generics, annotations, lambdas
- HTML/CSS - HTML5, CSS3, preprocessors
- JSON/YAML - Structured data formats
- Ruby - Rails conventions, blocks, symbols
- Shell/Bash - Advanced scripting features
- PHP - Modern PHP 8+ syntax
- SQL - Multiple dialect support
- XML - Namespaces, schemas
- Markdown - GFM extensions

### 3. 🎨 Professional Themes

Carefully designed color schemes for different preferences:

- **☀️ Xcode Default** - Apple's familiar light theme
- **🌙 VS Code Dark** - Popular dark theme with blue accents
- **📖 GitHub Light** - Clean, documentation-friendly theme
- **🌅 Solarized Dark** - Low-contrast, eye-friendly dark theme
- **✨ Minimal** - Ultra-clean monochrome design
- **🎯 Presentation** - High contrast for demos and accessibility

### 4. ⚙️ Real-time Editor Configuration

All settings update instantly without restart:

**Visual Features:**
- **📊 Line Numbers** - Professional gutter with highlighting
- **👻 Invisible Characters** - Configurable space/tab/newline indicators
- **📏 Line Wrapping** - Soft wrap vs horizontal scrolling
- **🎯 Current Line Highlighting** - Subtle line emphasis
- **🔤 Font Configuration** - Size (10-24pt), family selection
- **📐 Tab Settings** - Width (2/4/8), spaces vs tabs
- **📏 Line Spacing** - Vertical rhythm adjustment

**Editing Behavior:**
- **✏️ Editable/Read-only** - Toggle editing capabilities
- **🔄 Auto-indentation** - Smart code formatting
- **🎪 Hardware Acceleration** - Performance optimization

### 5. 📱 SwiftUI Integration

**Cross-Platform Support:**
- **🖥️ macOS** - Native NSViewRepresentable integration
- **📱 iOS** - UIViewRepresentable with touch optimizations  
- **📱 iPadOS** - Full tablet experience with split-screen support
- **💻 Mac Catalyst** - iPad apps running on macOS

**SwiftUI API:**
```swift
CodeEditorSwiftUIView(
    text: $code,
    language: .swift,
    theme: .default,
    showLineNumbers: true,
    highlightSelectedLine: true,
    isEditable: true
)
.onTextChange { newText in
    // Handle text changes
}
.onSelectionChange { range in
    // Handle selection changes
}
```

**Theme Environment:**
```swift
VStack {
    CodeEditorSwiftUIView(text: $code, language: .swift)
}
.codeEditorTheme(.dark)  // Apply theme to hierarchy
```

**Language Support:**
- Built-in language detection for Swift, Python, JavaScript, JSON
- Automatic syntax highlighting with proper highlighting rules
- Seamless integration with the underlying CodeEditorView

### 6. 🔧 Advanced Features

**📱 Modern Architecture:**
- SwiftUI + AppKit integration
- Swift 6 Actor-Based Concurrency throughout
- Thread-safe validation with RangeValidator actors
- Protocol-oriented design with Sendable conformance
- Advanced actor isolation patterns
- Comprehensive error handling

**💾 Configuration Management:**
- JSON import/export
- Configuration validation
- Preset management
- Settings persistence

**📊 Status & Information:**
- Real-time cursor position
- Selection range display
- Document statistics
- Performance metrics

**⌨️ Keyboard Shortcuts:**
- `⌘⇧L` - Toggle line numbers
- `⌘⇧I` - Toggle invisible characters  
- `⌘+` - Increase font size
- `⌘-` - Decrease font size
- `⌘0` - Reset font size
- `⌘T` - Cycle themes
- `⌘R` - Reload configuration

## 🏗️ Architecture

### Core Components

```
CodeEditorSample/
├── 📱 App Layer
│   ├── CodeEditorSampleApp.swift     # Main app + menu system
│   ├── ContentView.swift             # Primary layout with @Sendable closures
│   └── AppState.swift                # Global state management
├── 🎨 Views  
│   ├── SampleCodeEditorView.swift    # SwiftUI ↔ CodeEditorView bridge
│   ├── CodeEditorViewWrapper.swift   # Enhanced wrapper with callbacks
│   ├── SwiftUIDemoView.swift         # SwiftUI integration demo
│   ├── iOSContentView.swift          # iOS/iPadOS optimized interface
│   ├── EditorConfigurationView.swift # Settings sidebar
│   ├── StatusBarView.swift           # Status information
│   ├── EditorToolbar.swift           # Action toolbar
│   └── FeatureTourView.swift         # Interactive tour
├── 📊 Models
│   ├── EditorConfiguration.swift     # Configuration + presets
│   ├── SampleCodeProvider.swift      # Language samples
│   └── *Samples.swift               # Sample code by category
├── 🛠️ Services
│   ├── AnnotationManager.swift        # Code annotation detection & display
│   └── ConfigurationExporter.swift   # Thread-safe config management
├── 🎨 Themes
│   └── ThemeProvider.swift           # Color theme definitions
├── 🔌 Plugins
│   └── CustomAnnotationPlugin.swift  # Example plugin
└── 🧪 Tests (66 tests)
    ├── AnnotationSystemTests.swift      # Comprehensive annotation testing (20 tests)
    ├── BasicFunctionalityTests.swift    # Core functionality (4 tests)
    ├── ConfigurationUITests.swift       # UI configuration tests (12 tests)
    ├── PluginConfigurationTests.swift   # Plugin system tests (11 tests)
    ├── QuickIsFlippedTest.swift         # View hierarchy tests (1 test)
    ├── SampleCodeTests.swift           # Language sample validation (12 tests)
    └── SimplifiedIntegrationTests.swift # End-to-end testing (6 tests)
```

### Library Architecture (Simplified)

The CodeEditorPlugin library now features a streamlined, feature-based directory structure:

```
CodeEditorPlugin/
├── Core/                   # Core text editing (CodeEditorView, delegates)
├── SyntaxHighlighting/     # All highlighting logic unified
├── TextProcessing/         # Actor-based text processing & validation
├── RangeProcessing/        # Actor-based range validation
├── Layout/                 # Layout and view components
│   ├── GutterView.swift    # Line numbers (cross-platform)
│   ├── CodeEditorContainerView.swift # iOS container architecture
│   └── Fragments/          # Text layout fragments
├── Models/                 # Data models (including annotations)
├── Extensions/             # All extensions (flattened, +Extensions naming)
├── SwiftUI/                # SwiftUI integration components
├── Completion/             # Code completion
└── Platform/               # Platform-specific code
```

**Benefits of the simplified structure:**
- ✅ **74% reduction** in directory count (39 → 10 directories)
- ✅ **Feature-based organization** - Related code stays together
- ✅ **Easier navigation** - Less nesting, clearer structure
- ✅ **Better maintainability** - Components that work together are in the same directory

### Key Integration Patterns

**1. SwiftUI Cross-Platform Integration:**
```swift
// macOS Implementation
struct CodeEditorSwiftUIView: NSViewRepresentable {
    @Binding var text: String
    let language: Language
    
    func makeNSView(context: Context) -> CodeEditorView {
        let editorView = CodeEditorView()
        editorView.language = language
        editorView.string = text
        return editorView
    }
}

// iOS Implementation  
struct CodeEditorSwiftUIView: UIViewRepresentable {
    @Binding var text: String
    let language: Language
    
    func makeUIView(context: Context) -> CodeEditorContainerView {
        let containerView = CodeEditorContainerView()
        let editorView = containerView.textView
        editorView.language = language
        editorView.text = text
        return containerView
    }
}
```

**2. Real-time Configuration:**
```swift
// All changes update immediately
@Published var configuration = EditorConfiguration() {
    didSet { updateEditor() }
}
```

**3. Swift 6 Actor-Based Delegate Pattern:**
```swift
class Coordinator: NSObject, @preconcurrency CodeEditorViewDelegate {
    // Full protocol conformance with concurrency safety
    // @Sendable closures for thread-safe callbacks
}
```

**4. Actor-Based Validation:**
```swift
// Thread-safe validation with actors
actor SinglePhaseRangeValidator<Content: VersionedContent> {
    // Actor-isolated validation methods
    func validate(_ target: RangeTarget) async -> Action
}
```

## 🧪 Testing & Quality

### Test Coverage

**66 tests** covering critical functionality:
- ✅ Basic editor functionality
- ✅ Configuration management  
- ✅ Sample code validation
- ✅ Theme system
- ✅ Language detection
- ✅ Annotation system (TODO/FIXME/NOTE/WARNING/ERROR detection)
- ✅ Annotation positioning and layout
- ✅ Performance benchmarks
- ✅ Integration scenarios

### Code Quality Standards

```bash
# All quality checks pass
swiftformat --swiftversion 6.0 .  # ✅ 25 files formatted
swiftlint --fix && swiftlint       # ✅ 0 violations
swift build                       # ✅ Build complete
swift test                        # ✅ 66/66 tests passing
```

### Recent Improvements

- ✅ **Simplified Directory Structure** - Library reorganized from 39 to 10 directories
- ✅ **Feature-Based Organization** - Related components now grouped together
- ✅ **iOS Container Architecture** - Fixed line number display beyond line 88 with proper container separation
- ✅ **SwiftLint Compliance** - Zero violations across 25 files with custom configuration
- ✅ **Extension Naming Convention** - Adopted +Extensions pattern for clarity
- ✅ **Improved Build Performance** - Flattened structure reduces module complexity
- ✅ **Annotation System** - Complete inline code annotation system with hover popups
- ✅ **Swift 6 Concurrency** - Fixed all concurrency issues for full compliance
- ✅ **Keyboard Handling** - Proper content insets prevent line number compression on iOS

## 🛠️ Customization Guide

### Adding New Languages

1. **Define sample code:**
```swift
// In SampleCodeProvider.swift
case .newLanguage:
    return """
    // Your language sample here
    """
```

2. **Language auto-detection works automatically** via file extensions

### Creating Custom Themes

```swift
// In ThemeProvider.swift
static let customTheme = ColorTheme(
    backgroundColor: NSColor.black,
    textColor: NSColor.white,
    keywordColor: NSColor.systemBlue,
    stringColor: NSColor.systemGreen,
    commentColor: NSColor.systemGray,
    // ... define all colors
)
```

### Performance Optimization

For large files (>10MB):
```swift
config.hardwareAcceleration = true
config.showLineNumbers = false  // Reduces overhead
config.enableSyntaxHighlighting = false  // For very large files
```

## 📋 Requirements & Compatibility

- **Swift**: 6.0+ (with experimental concurrency and full actor-based architecture)
- **Platforms**: 
  - **macOS**: 12.0+ (optimized for macOS 14+)
  - **iOS**: 16.0+ (SwiftUI integration)
  - **iPadOS**: 16.0+ (Full tablet support)
  - **Mac Catalyst**: 16.0+ (iPad apps on macOS)
- **Xcode**: 16.0+
- **Dependencies**: swift-syntax 510.0.0+
- **Concurrency**: Full Swift 6 Actor-Based Concurrency with Sendable conformance

## 🐛 Known Issues

### Syntax Highlighting Not Working
**Status**: Under Investigation
**Impact**: Code appears without syntax highlighting despite configuration

**Details**: After the recent refactoring to integrate the unified EditorConfiguration system, syntax highlighting is not being applied in the sample application. The issue appears to be related to:
- Configuration application flow between SwiftUI and AppKit layers
- Language detection and setting mechanism in CodeEditorViewWrapper
- Potential timing issues with syntax highlighting coordinator initialization

**Workaround**: None currently available. All other editor features (line numbers, themes, editing) work correctly.

**Investigation Progress**:
- ✅ Confirmed configuration is being applied correctly
- ✅ Verified `setLanguage(fileExtension:)` is being called  
- ⏳ Investigating SyntaxHighlightingCoordinator initialization timing
- ⏳ Checking syntax highlighting application vs. text setting order

## 🐛 Troubleshooting

### Common Solutions

**❌ Text not visible:**
```swift
// Ensure proper theme contrast
config.theme = .vsDark  // Try different theme
```

**❌ Performance with large files:**
```swift
// Optimize for large content
config.hardwareAcceleration = true
config.showLineNumbers = false
```

**❌ Scrolling issues:**
- ✅ **Fixed!** Proper NSScrollView integration implemented

**❌ Build errors:**
```bash
swift package clean && swift build
```

## 📚 Learning Resources

1. **📖 Interactive Tour** - Built-in feature walkthrough
2. **⚙️ Configuration Presets** - Learn from example setups  
3. **🎨 Theme Gallery** - Explore visual customization
4. **🧪 Test Suite** - Reference implementation patterns
5. **📝 Code Samples** - Multi-language examples

## 🤝 Contributing

The sample app welcomes contributions:

1. Fork the repository
2. Add features or improvements
3. Ensure tests pass: `swift test`
4. Submit pull request

## 📄 License

This sample application is part of the CodeEditorPlugin package and follows the same MIT license terms.

---

**🎉 Ready to explore?** Run `swift run CodeEditorSample` and discover the full power of CodeEditorPlugin!