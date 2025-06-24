# CodeEditorPlugin

A powerful, customizable code editor component for macOS applications built with Swift. CodeEditorPlugin provides syntax highlighting, line numbers, themes, and extensive customization options for building modern code editing experiences in Swift applications.

## Features

- 🎨 **Syntax Highlighting** - Support for 15+ programming languages including Swift, Python, JavaScript, and more
- 🎯 **Line Numbers** - Configurable line number display with custom styling
- 🌈 **Theme Support** - Multiple built-in themes (Xcode, VS Code Dark, GitHub Light, Solarized, etc.)
- 📐 **NSTextView Based** - Built on macOS native text system for reliability and performance
- ⚡ **Performance Optimized** - Efficient rendering for large files
- 🔧 **Highly Configurable** - Extensive customization options for appearance and behavior
- ✏️ **Full Editing Support** - Complete text editing capabilities with undo/redo
- 🎯 **Line Highlighting** - Highlight current line with customizable colors
- 👻 **Invisible Characters** - Show spaces, tabs, and line breaks
- 📏 **Tab & Indentation** - Configurable tab width and space/tab preferences

## Requirements

- Swift 6.0 or later
- macOS 14.0 or later
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

### SwiftUI Usage

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var text = "print(\"Hello, World!\")"
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        CodeEditorView(
            configuration: configuration,
            text: $text,
            language: "swift"
        )
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
        textView.text = "// Your code here"
        textView.showsLineNumbers = true
        textView.highlightSelectedLine = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        
        // Enable syntax highlighting
        textView.language = .swift
        textView.isSyntaxHighlightingEnabled = true
        
        view.addSubview(textView)
    }
}
```

## Configuration

### EditorConfiguration

The `EditorConfiguration` struct provides extensive customization options:

```swift
var config = EditorConfiguration()
config.showLineNumbers = true
config.highlightSelectedLine = true
config.fontSize = 14
config.theme = .vsDark
config.tabWidth = 4
config.insertSpacesForTabs = true
```

### Available Themes

- `.xcode` - Xcode default light theme
- `.vsDark` - VS Code dark theme  
- `.github` - GitHub light theme
- `.solarizedDark` - Solarized dark theme
- `.minimal` - Minimal light theme
- `.presentation` - High contrast presentation theme

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

### Setting Language

```swift
// Auto-detect language from file extension
textView.setLanguage(fileExtension: "swift")

// Or set directly
textView.language = .swift
```

## Example Application

Check out the comprehensive example application in `Example/CodeEditorSample/` that demonstrates:

- Full-featured code editor with syntax highlighting
- Multiple themes and real-time theme switching
- Configuration import/export
- Line numbers, invisible characters, and line highlighting
- Multiple editor instances
- Preset configurations (minimal, read-only, markdown, presentation)
- Interactive feature tour

To run the example:

```bash
cd Example/CodeEditorSample
swift run CodeEditorSample
```

## Architecture

CodeEditorPlugin is built with a clean, modular architecture:

- **Core**: `STTextView` - NSTextView subclass with enhanced functionality
- **Syntax Highlighting**: Token-based highlighting system with per-language support
- **Themes**: Comprehensive theming system with built-in color schemes
- **Configuration**: Flexible configuration system for easy customization
- **SwiftUI Integration**: Native SwiftUI wrapper for seamless integration

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

CodeEditorPlugin is available under the MIT license. See the LICENSE file for more info.

## Acknowledgments

This project was inspired by STTextView by Marcin Krzyzanowski and includes syntax highlighting patterns from various open-source projects.