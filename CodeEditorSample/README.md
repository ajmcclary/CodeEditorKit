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
- ✅ **Comprehensive testing** with 23 passing tests and performance benchmarks

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

### 5. 🔧 Advanced Features

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
│   ├── CodeEditorView.swift          # SwiftUI ↔ STTextView bridge
│   ├── CodeEditorViewWrapper.swift   # Enhanced wrapper with callbacks
│   ├── EditorConfigurationView.swift # Settings sidebar
│   ├── StatusBarView.swift           # Status information
│   ├── EditorToolbar.swift           # Action toolbar
│   └── FeatureTourView.swift         # Interactive tour
├── 📊 Models
│   ├── EditorConfiguration.swift     # Configuration + presets
│   ├── SampleCodeProvider.swift      # Language samples
│   └── *Samples.swift               # Sample code by category
├── 🛠️ Services
│   └── ConfigurationExporter.swift   # Thread-safe config management
├── 🎨 Themes
│   └── ThemeProvider.swift           # Color theme definitions
├── 🔌 Plugins
│   └── CustomAnnotationPlugin.swift  # Example plugin
└── 🧪 Tests (23 tests)
    ├── BasicFunctionalityTests.swift
    ├── SampleCodeTests.swift
    ├── SimplifiedIntegrationTests.swift
    └── QuickIsFlippedTest.swift
```

### Key Integration Patterns

**1. SwiftUI + AppKit Integration:**
```swift
struct CodeEditorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = STTextView()
        
        // Configure scroll view for proper scrolling
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        
        return scrollView
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
class Coordinator: NSObject, @preconcurrency STTextViewDelegate {
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

**23 tests** covering critical functionality:
- ✅ Basic editor functionality
- ✅ Configuration management  
- ✅ Sample code validation
- ✅ Theme system
- ✅ Language detection
- ✅ Performance benchmarks
- ✅ Integration scenarios

### Code Quality Standards

```bash
# All quality checks pass
swiftformat --swiftversion 6.0 .  # ✅ 25 files formatted
swiftlint --fix && swiftlint       # ✅ 0 violations
swift build                       # ✅ Build complete
swift test                        # ✅ 23/23 tests passing
```

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
- **macOS**: 12.0+ (optimized for macOS 14+)
- **Xcode**: 16.0+
- **Dependencies**: swift-syntax 510.0.0+
- **Concurrency**: Full Swift 6 Actor-Based Concurrency with Sendable conformance

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