# CodeEditorPlugin

A powerful, customizable code editor component for macOS and iOS applications, built on Apple's TextKit2 framework. CodeEditorPlugin provides syntax highlighting, line numbers, themes, and an extensible plugin system for building modern code editing experiences in Swift applications.

## Features

- 🎨 **Syntax Highlighting** - Support for 11+ programming languages including Swift, Python, JavaScript, and more
- 🎯 **Line Numbers** - Configurable line number display with custom styling
- 🌈 **Theme Support** - Multiple built-in themes (Xcode, VS Code Dark, GitHub Light, etc.)
- 🔌 **Plugin System** - Extensible architecture for adding custom functionality
- 📐 **TextKit2 Based** - Modern text rendering with hardware acceleration support
- 📱 **Cross-Platform** - Works on macOS 12+, iOS 16+, and Mac Catalyst 16+
- ⚡ **Performance Optimized** - Efficient rendering for large files with viewport-based updates
- 🔧 **Highly Configurable** - Pre-built configurations for different use cases

## Requirements

- Swift 6.0 or later
- macOS 12.0+ / iOS 16.0+ / Mac Catalyst 16.0+
- Xcode 16.0 or later

## Installation

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

## Quick Start

### Basic Usage

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "print(\"Hello, World!\")"
    
    var body: some View {
        CodeEditorTextView(text: $code)
            .showsLineNumbers(true)
            .font(.monospacedSystemFont(ofSize: 14, weight: .regular))
    }
}
```

### Using STTextView Directly

```swift
import CodeEditorPlugin
import AppKit

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let textView = STTextView()
        textView.string = "// Your code here"
        textView.showsLineNumbers = true
        textView.highlightSelectedLine = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        
        // Add syntax highlighting
        let highlighter = SyntaxHighlightingCoordinator()
        textView.addPlugin(highlighter.createPlugin())
        
        view.addSubview(textView)
    }
}
```

## Pre-Built Configurations

CodeEditorPlugin includes several pre-built configurations for common use cases:

```swift
// Full-featured editor with all capabilities
let config = EditorConfiguration.fullFeatured

// Minimal editor for simple text editing
let config = EditorConfiguration.minimal

// Read-only viewer
let config = EditorConfiguration.readOnly

// Markdown editing optimized
let config = EditorConfiguration.markdown

// Presentation mode with larger fonts
let config = EditorConfiguration.presentation
```

## Syntax Highlighting

### Supported Languages

- Swift
- Python
- JavaScript/TypeScript
- Rust
- C/C++
- HTML/CSS
- JSON
- Markdown
- Ruby
- Shell
- And more...

### Custom Language Support

```swift
// Auto-detect language from file extension
let language = highlighter.detectLanguage(from: "example.swift")

// Or specify directly
let tokens = highlighter.highlight(source: code, language: .swift)
```

## Theme System

### Built-in Themes

- Xcode (Light/Dark)
- VS Code Dark
- GitHub (Light/Dark)
- Atom One Dark
- Tomorrow Night

### Creating Custom Themes

```swift
let customTheme = Theme(
    name: "My Theme",
    settings: ThemeSettings(
        background: .init(hex: "#1e1e1e"),
        foreground: .init(hex: "#d4d4d4"),
        currentLine: .init(hex: "#2a2a2a"),
        selection: .init(hex: "#264f78"),
        cursor: .init(hex: "#aeafad")
    ),
    tokenColors: [
        TokenColor(scope: "keyword", color: .init(hex: "#569cd6")),
        TokenColor(scope: "string", color: .init(hex: "#ce9178")),
        TokenColor(scope: "comment", color: .init(hex: "#6a9955"))
    ]
)
```

## Plugin Development

Create custom plugins to extend functionality:

```swift
class MyCustomPlugin: STPlugin {
    func setUp(context: PluginContext) {
        // Initialize your plugin
    }
    
    func makeCoordinator(context: CoordinatorContext) -> MyCoordinator {
        return MyCoordinator()
    }
    
    func tearDown() {
        // Clean up resources
    }
}

// Use the plugin
textView.addPlugin(MyCustomPlugin())
```

## Annotations

Add line-based annotations for warnings, errors, or other information:

```swift
class ErrorAnnotation: STLineAnnotation {
    let message: String
    let line: Int
    
    var view: NSView {
        // Return your custom annotation view
    }
}

// Add annotations
textView.addAnnotation(ErrorAnnotation(message: "Syntax error", line: 42))
```

## Performance Tips

- Enable hardware acceleration for large files: `textView.enableHardwareAcceleration = true`
- Use read-only mode when editing is not required: `textView.isEditable = false`
- Disable features you don't need (line numbers, plugins) for better performance
- Consider using viewport-based rendering for very large documents

## Example Application

Check out the example application in `Example/CodeEditorSample/` for a comprehensive demonstration of all features:

```bash
cd Example/CodeEditorSample
swift run
```

## Architecture

CodeEditorPlugin is built with a modular, protocol-oriented architecture:

- **Core**: STTextView built on TextKit2
- **Plugins**: Extensible plugin system for adding features
- **Themes**: Flexible theming system with TextMate grammar support
- **Highlighting**: Modular syntax highlighting with language-specific implementations
- **Annotations**: Line-based annotation system for inline feedback

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

CodeEditorPlugin is available under the MIT license. See the LICENSE file for more info.

## Acknowledgments

This project builds upon Apple's STTextView and integrates swift-syntax for Swift language support.