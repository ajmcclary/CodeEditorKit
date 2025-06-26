# CodeEditorPlugin

A powerful, production-ready code editor component for macOS and iOS applications. Built with modern Swift 6 Actor-Based Concurrency, CodeEditorPlugin provides comprehensive syntax highlighting, professional line numbers, themes, smooth scrolling, and extensive customization for building world-class code editing experiences.

## ✨ Features

- 🎨 **Advanced Syntax Highlighting** - Support for 15+ programming languages with SwiftSyntax integration for Swift and regex-based highlighting for other languages
- 🎯 **Professional Line Numbers** - Cross-platform gutter implementation with proper iOS container architecture
- 🌈 **Rich Theme System** - 6+ built-in themes with comprehensive color customization
- 📜 **Smooth Scrolling** - Proper NSScrollView integration with responsive performance for large files
- 📐 **TextKit2 Foundation** - Built on modern TextKit2 for reliability and future compatibility
- ⚡ **Performance Optimized** - Actor-based background processing with viewport-based rendering
- 🔧 **Unified Configuration** - Structured configuration system with nested settings and builder pattern
- ✏️ **Full Editing Support** - Complete text editing with undo/redo and comprehensive delegate support
- 🎯 **Line Highlighting** - Current line highlighting with customizable colors
- 👻 **Invisible Characters** - Configurable whitespace visualization
- 📏 **Smart Indentation** - Tab width configuration with spaces/tabs support
- 📝 **Inline Annotations** - TODO/FIXME/NOTE/WARNING/ERROR detection with hover popups
- 📱 **Cross-Platform** - macOS 12.0+, iOS 16.0+, and Mac Catalyst support
- 🎨 **SwiftUI Integration** - Native SwiftUI wrapper with environment-based configuration
- 🏗️ **Swift 6 Concurrency** - Full actor-based architecture with thread-safe validation

## 📋 Requirements

- **Swift**: 6.0+ (with full actor-based concurrency support)
- **Platforms**: 
  - **macOS**: 12.0+ (optimized for macOS 14+)
  - **iOS**: 16.0+ (with proper container architecture)
  - **Mac Catalyst**: 16.0+
- **Xcode**: 16.0+
- **Dependencies**: swift-syntax 510.0.0+ (for Swift language support)

## 📦 Installation

### Swift Package Manager

Add CodeEditorPlugin to your project:

1. In Xcode: File → Add Package Dependencies...
2. Enter: `https://github.com/ajmcclary/CodeEditorPlugin.git`
3. Select your preferred version

Or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
]
```

## 🚀 Quick Start

### SwiftUI Integration (Recommended)

The modern SwiftUI API provides the cleanest integration:

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
        func greetWorld() {
            print("Hello, CodeEditorPlugin!")
            // TODO: Add more features
        }
        """
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        VStack {
            CodeEditorSwiftUIView(
                text: $code,
                language: .swift,
                showLineNumbers: true,
                highlightSelectedLine: true,
                isEditable: true
            )
            .environment(\.codeEditorConfiguration, configuration)
            .frame(minHeight: 400)
        }
        .padding()
    }
}
```

### AppKit Integration

For direct AppKit usage:

```swift
import CodeEditorPlugin
import AppKit

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create text view
        let textView = CodeEditorView()
        textView.text = "// Your Swift code here\nprint(\"Hello, World!\")"
        
        // Apply configuration
        let config = EditorConfiguration()
        config.apply(to: textView)
        
        // Set language for syntax highlighting
        textView.setLanguage(fileExtension: "swift")
        
        // Configure for scrolling
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        
        view.addSubview(scrollView)
        // Setup constraints...
    }
}
```

## ⚙️ Configuration System

CodeEditorPlugin uses a modern, structured configuration system with nested settings for better organization.

### EditorConfiguration Structure

```swift
var config = EditorConfiguration()

// Display Settings
config.display.showLineNumbers = true
config.display.highlightSelectedLine = true  
config.display.showInvisibleCharacters = false
config.display.fontSize = 14.0
config.display.enableSyntaxHighlighting = true
config.display.enableAnnotations = true

// Layout Settings  
config.layout.wrapLines = false
config.layout.tabWidth = 4
config.layout.insertSpacesForTabs = true
config.layout.lineSpacing = 1.2

// Behavior Settings
config.behavior.isEditable = true
config.behavior.autoIndent = true
config.behavior.enableCodeCompletion = true
config.behavior.isContinuousSpellCheckingEnabled = false

// Performance Settings
config.performance.useHardwareAcceleration = true
config.performance.smoothScrolling = true
config.performance.maxSyntaxHighlightingLength = 500_000
```

### Configuration Builder Pattern

For fluid configuration creation:

```swift
let config = EditorConfigurationBuilder()
    .showLineNumbers(true)
    .fontSize(16)
    .wrapLines(false)
    .annotations(true)
    .hardwareAcceleration(true)
    .build()
```

### Configuration Presets

Use predefined configurations for common scenarios:

```swift
// Built-in presets
let defaultConfig = EditorConfiguration.default
let minimalConfig = EditorConfiguration.minimal  
let readOnlyConfig = EditorConfiguration.readOnly
let markdownConfig = EditorConfiguration.markdown
let presentationConfig = EditorConfiguration.presentation

// Apply to text view
config.apply(to: textView)
```

## 🎨 Syntax Highlighting

### Supported Languages

- **Swift** - Native SwiftSyntax integration with AST-based highlighting
- **Python** - Advanced syntax highlighting with decorators and f-strings
- **JavaScript/TypeScript** - ES6+ features and JSX support
- **Rust** - Ownership syntax, macros, and attributes
- **C/C++** - Modern C++20 features
- **HTML/CSS** - HTML5 and CSS3 support
- **JSON/YAML** - Structured data formats
- **Markdown** - GitHub Flavored Markdown
- **Go, Java, Ruby, PHP, SQL, XML** - Comprehensive language support

### Language Detection

```swift
// Automatic detection from file extension
textView.setLanguage(fileExtension: "swift")
textView.setLanguage(fileExtension: "py") 
textView.setLanguage(fileExtension: "js")

// Direct language setting
textView.language = .swift
textView.language = .python
textView.language = .javascript
```

## 🏗️ Architecture

CodeEditorPlugin features a clean, modern architecture optimized for Swift 6:

### Simplified Directory Structure

After major refactoring, the project now uses a feature-based organization:

```
Sources/CodeEditorPlugin/
├── Core/                    # Core text editing components
│   ├── CodeEditorView.swift     # Main text view with TextKit2
│   └── AnnotationsDataSource.swift # Annotation system
├── Configuration/           # Unified configuration system
│   └── EditorConfiguration.swift   # Nested configuration structure
├── SyntaxHighlighting/      # All highlighting logic
│   ├── SyntaxHighlightingCoordinator.swift # Main coordinator
│   ├── SwiftSyntaxHighlighter.swift        # Swift AST highlighting
│   └── RegexSyntaxHighlighter.swift        # Regex-based highlighting
├── Layout/                  # Layout and view components
│   ├── GutterView.swift             # Cross-platform line numbers
│   └── CodeEditorContainerView.swift # iOS container architecture
├── SwiftUI/                 # SwiftUI integration
│   ├── CodeEditorSwiftUIView.swift  # Main SwiftUI wrapper
│   └── CodeEditor.swift             # Modern SwiftUI view
├── Extensions/              # All extensions (flattened)
├── Models/                  # Data models and annotations
├── TextProcessing/          # Actor-based text processing
├── RangeProcessing/         # Actor-based range validation
├── Completion/              # Code completion system
└── Platform/                # Platform-specific code
```

### Key Benefits

- **74% Directory Reduction** - From 39 to 10 directories for simpler navigation
- **Feature-Based Organization** - Related components grouped together
- **Unified Configuration** - Single EditorConfiguration with nested structure
- **Swift 6 Compliance** - Full actor-based concurrency throughout
- **Cross-Platform Design** - Proper iOS container architecture for line numbers

### Actor-Based Concurrency

- **Thread-Safe Validation** - All text processing uses Swift 6 actors
- **Background Processing** - Syntax highlighting and validation run on background actors
- **Sendable Conformance** - Complete thread-safety in all operations
- **Isolation Parameters** - Advanced actor communication patterns

## 📱 Example Application

The comprehensive sample app in `CodeEditorSample/` demonstrates all features:

- ✅ **Full-featured editor** with working syntax highlighting
- ✅ **6 built-in themes** with real-time switching
- ✅ **Configuration presets** (minimal, read-only, markdown, presentation)
- ✅ **Inline annotations** with TODO/FIXME/NOTE/WARNING/ERROR detection
- ✅ **Cross-platform support** with iOS and macOS implementations
- ✅ **Interactive feature tour** and comprehensive documentation
- ✅ **Performance testing** with large files and annotation systems

### Running the Example

```bash
cd CodeEditorSample
swift run CodeEditorSample
```

## 🧪 Testing & Quality

### Comprehensive Test Suite

- **172 total tests** across both projects
- **106 main package tests** - Core functionality, syntax highlighting, configuration
- **66 sample app tests** - Integration testing, UI components, annotation system
- **Performance benchmarks** - Large file handling and annotation performance

### Code Quality Standards

```bash
# All commands should show zero violations/errors
swiftlint --fix && swiftlint    # ✅ 0 violations across all files
swift build                     # ✅ Clean builds
swift test                      # ✅ 172/172 tests passing
```

### Quality Metrics

- **Zero SwiftLint violations** across entire codebase
- **Swift 6 compliant** with full concurrency safety
- **Comprehensive documentation** with inline code examples
- **Cross-platform tested** on macOS, iOS, and Mac Catalyst

## 🔧 Development

### Project Structure Benefits

Our simplified architecture provides:

- **Easier navigation** - Feature-based organization groups related code
- **Better maintainability** - Clear component boundaries and dependencies  
- **Reduced complexity** - 74% fewer directories with logical grouping
- **Improved build times** - Flattened structure reduces module overhead

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run quality checks: `swiftlint --fix && swift test`
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📄 License

CodeEditorPlugin is available under the MIT license. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **STTextView** by Marcin Krzyzanowski - Inspiration for TextKit2 integration
- **Apple's TextKit2** - Foundation framework providing modern text handling
- **SwiftSyntax** - Enabling native Swift AST-based syntax highlighting
- **Swift 6 Concurrency** - Actor-based architecture patterns from Apple's documentation

---

**Ready to build amazing code editors?** Check out the [sample application](CodeEditorSample/) to see CodeEditorPlugin in action! 🚀