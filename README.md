# CodeEditorPlugin

A powerful, modern code editor component for macOS and iOS applications built with Swift 6. CodeEditorPlugin provides syntax highlighting, line numbers, themes, scrolling, and extensive customization options for building modern code editing experiences in Swift applications.

## ✨ Features

- 🎨 **Advanced Syntax Highlighting** - Support for 15+ programming languages including Swift, Python, JavaScript, TypeScript, Rust, C/C++, and more
- 🎯 **Professional Line Numbers** - Configurable line number display with custom styling and highlighting
- 🌈 **Rich Theme System** - 6+ built-in themes (Xcode, VS Code Dark, GitHub Light, Solarized, etc.) with custom theme support
- 📜 **Smooth Scrolling** - Proper NSScrollView integration with responsive scrolling for large files
- 📐 **TextKit2 Foundation** - Built on modern TextKit2 for reliability, performance, and future compatibility
- ⚡ **Performance Optimized** - Efficient rendering for large files with background processing
- 🔧 **Highly Configurable** - Extensive customization options for appearance and behavior
- ✏️ **Full Editing Support** - Complete text editing capabilities with undo/redo and find/replace
- 🎯 **Line Highlighting** - Highlight current line with customizable colors and styles
- 👻 **Invisible Characters** - Show spaces, tabs, and line breaks with configurable visibility
- 📏 **Smart Indentation** - Configurable tab width, space/tab preferences, and auto-indentation
- 🔌 **Plugin Architecture** - Extensible plugin system for custom functionality
- 📱 **Cross-Platform** - macOS, iOS, and Mac Catalyst support

## 📋 Requirements

- **Swift**: 6.0 or later (with experimental concurrency features)
- **macOS**: 12.0+ / **iOS**: 16.0+ / **Mac Catalyst**: 16.0+
- **Xcode**: 16.0 or later
- **Dependencies**: swift-syntax 510.0.0+ (for Swift language support)

## 📦 Installation

### Swift Package Manager

Add CodeEditorPlugin to your project using Swift Package Manager:

1. In Xcode, select "File" → "Add Package Dependencies..."
2. Enter the repository URL: `https://github.com/ajmcclary/CodeEditorPlugin.git`
3. Select the version you want to use

Or add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
]
```

## 🚀 Quick Start

### SwiftUI Usage (Recommended)

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var text = """
        func greetWorld() {
            print("Hello, World!")
            print("Welcome to CodeEditorPlugin!")
        }
        """
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        VStack {
            CodeEditorView(
                configuration: configuration,
                text: $text,
                language: "swift"
            )
            .frame(minHeight: 400)
        }
        .padding()
    }
}
```

### AppKit Usage

```swift
import CodeEditorPlugin
import AppKit

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create scroll view (required for proper scrolling)
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        
        // Create text view
        let textView = STTextView()
        textView.text = "// Your code here\nprint(\"Hello, World!\")"
        textView.showsLineNumbers = true
        textView.highlightSelectedLine = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        
        // Configure for scrolling
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Enable syntax highlighting
        textView.language = .swift
        textView.isSyntaxHighlightingEnabled = true
        
        // Embed in scroll view
        scrollView.documentView = textView
        view.addSubview(scrollView)
        
        // Setup constraints...
    }
}
```

## ⚙️ Configuration

### EditorConfiguration

The `EditorConfiguration` struct provides extensive customization options:

```swift
var config = EditorConfiguration()

// Appearance
config.showLineNumbers = true
config.highlightSelectedLine = true
config.showInvisibleCharacters = false
config.fontSize = 14
config.theme = .vsDark

// Behavior
config.isEditable = true
config.wrapLines = false
config.tabWidth = 4
config.insertSpacesForTabs = true

// Advanced
config.enableCustomPlugin = true
config.hardwareAcceleration = true
```

### Available Themes

- `.xcode` - Xcode default light theme
- `.vsDark` - VS Code dark theme  
- `.github` - GitHub light theme
- `.solarizedDark` - Solarized dark theme
- `.minimal` - Minimal light theme
- `.presentation` - High contrast presentation theme

### Custom Themes

```swift
let customTheme = ColorTheme(
    backgroundColor: NSColor.black,
    textColor: NSColor.white,
    selectedLineColor: NSColor.darkGray,
    // ... customize all colors
)
config.theme = customTheme
```

## 🎨 Syntax Highlighting

### Supported Languages

- **Swift** (with SwiftSyntax integration)
- **Python** 
- **JavaScript/TypeScript**
- **Rust**
- **C/C++**
- **HTML/CSS**
- **JSON**
- **Markdown**
- **Ruby**
- **Shell/Bash**
- **Go**
- **Java**
- **PHP**
- **SQL**
- **XML**

### Language Detection

```swift
// Auto-detect from file extension
textView.setLanguage(fileExtension: "swift")
textView.setLanguage(fileExtension: "py")
textView.setLanguage(fileExtension: "js")

// Or set directly
textView.language = .swift
textView.language = .python
textView.language = .javascript
```

## 📱 Example Application

Check out the comprehensive example application in `Example/CodeEditorSample/` that demonstrates:

- ✅ **Full-featured code editor** with syntax highlighting and scrolling
- ✅ **Multiple themes** with real-time theme switching
- ✅ **Configuration management** with import/export
- ✅ **All editor features** (line numbers, invisible characters, line highlighting)
- ✅ **Multiple editor instances** and layouts
- ✅ **Preset configurations** (minimal, read-only, markdown, presentation)
- ✅ **Interactive feature tour** and documentation
- ✅ **Performance testing** with large files

### Running the Example

```bash
cd Example/CodeEditorSample
swift run CodeEditorSample
```

## 🏗️ Architecture

CodeEditorPlugin is built with a clean, modular architecture optimized for Swift 6:

### Core Components

- **STTextView** - Enhanced NSTextView subclass with modern TextKit2 integration
- **Syntax Highlighting** - Multi-strategy highlighting system (SwiftSyntax + Regex-based)
- **Theme System** - Comprehensive theming with color management
- **Plugin Architecture** - Extensible system for custom functionality
- **SwiftUI Integration** - Native SwiftUI wrappers with proper scroll view embedding
- **Performance Layer** - Background processing and viewport optimization

### Key Design Patterns

- **Protocol-Oriented Design** - STTextViewProtocol, STTextViewDelegate
- **Actor-Based Concurrency** - Swift 6 actors for background processing  
- **Type Aliases** - Clean public API (CodeEditorTextView, CodeEditorDelegate)
- **Versioned Content System** - Efficient change tracking and validation

### Recent Improvements

- ✅ **Swift 6 Compliance** - Full concurrency safety and modern Swift features
- ✅ **Proper Scrolling** - NSScrollView integration for smooth scrolling
- ✅ **Protocol Conformance** - Complete STTextViewDelegate implementation
- ✅ **Code Quality** - SwiftLint/SwiftFormat integration with 0 violations
- ✅ **Test Coverage** - Comprehensive test suite with 69 passing tests
- ✅ **Performance** - Optimized for large files and responsive editing

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Main project tests
swift test

# Example project tests  
cd Example/CodeEditorSample
swift test
```

**Test Results**: 69 tests passing across both projects with performance benchmarks.

## 🔧 Development

### Code Quality

The project maintains high code quality standards:

```bash
# Format code
swiftformat --swiftversion 6.0 .

# Lint code  
swiftlint --fix && swiftlint

# Build and test
swift build && swift test
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Ensure all tests pass and code is properly formatted
4. Submit a pull request

## 📄 License

CodeEditorPlugin is available under the MIT license. See the LICENSE file for more info.

## 🙏 Acknowledgments

- Inspired by STTextView by Marcin Krzyzanowski
- Built on Apple's TextKit2 framework
- Syntax highlighting patterns from various open-source projects
- Swift 6 concurrency patterns from Apple's documentation