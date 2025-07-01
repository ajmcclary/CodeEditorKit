# Quick Start Guide

## CodeEditorPlugin - Production-Ready Code Editor for Swift

A modern, cross-platform code editor component for macOS, iOS, and Mac Catalyst applications. Features syntax highlighting for 17+ languages, code completion, annotations, and comprehensive SwiftUI integration.

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/CodeEditorPlugin.git", from: "1.0.0")
]
```

Or add via Xcode: **File → Add Packages → Enter repository URL**

## Basic Usage

### 1. SwiftUI Integration (Recommended)

```swift
import SwiftUI
import CodeEditorPlugin

struct ContentView: View {
    @State private var code = """
        import Foundation
        
        func greetWorld() {
            print("Hello, World!")
        }
        """
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .showsLineNumbers(true)
            .enablesSyntaxHighlighting(true)
            .frame(minHeight: 400)
    }
}
```

### 2. AppKit Integration (macOS)

```swift
import AppKit
import CodeEditorPlugin

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editor = CodeEditorView()
        editor.language = .swift
        editor.showsLineNumbers = true
        editor.text = "print(\"Hello, World!\")"
        
        view.addSubview(editor)
        // Add Auto Layout constraints...
    }
}
```

### 3. UIKit Integration (iOS)

```swift
import UIKit
import CodeEditorPlugin

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editor = CodeEditorView()
        editor.language = .swift
        editor.showsLineNumbers = true
        editor.text = "print(\"Hello, iOS!\")"
        
        view.addSubview(editor)
        // Add Auto Layout constraints...
    }
}
```

## Configuration Made Easy

### Using the Builder Pattern (Recommended)

```swift
// Quick configurations for common scenarios
let swiftConfig = EditorConfigurationBuilder.swift()
let webConfig = EditorConfigurationBuilder.web()
let readOnlyConfig = EditorConfigurationBuilder.readOnly()

// Custom configuration
let customConfig = EditorConfigurationBuilder()
    .fontSize(16)
    .theme(.dark)
    .language(.python)
    .tabWidth(4)
    .enableCodeCompletion(true)
    .wrapLines(false)
    .build()

// Apply to editor
editor.configuration = customConfig
```

### Traditional Configuration

```swift
var config = EditorConfiguration()
config.display.fontSize = 16
config.display.showLineNumbers = true
config.display.enableSyntaxHighlighting = true
config.layout.tabWidth = 4
config.behavior.enableCodeCompletion = true

editor.configuration = config
```

## Supported Languages

- **Swift** (Full AST-based highlighting)
- **Python** 
- **JavaScript/TypeScript**
- **HTML/CSS**
- **JSON/YAML**
- **Markdown**
- **Rust**
- **Go**
- **Java**
- **C/C++**
- **Ruby**
- **PHP**
- **SQL**
- **XML**
- **Shell scripts**
- **Plain text**

## Key Features

### ✨ Syntax Highlighting
```swift
editor.language = .swift
editor.isSyntaxHighlightingEnabled = true
```

### 📝 Code Completion
```swift
editor.enablesCodeCompletion = true

// Or programmatically
let completions = try await editor.requestCompletionSafe(at: cursorPosition)
```

### 🔍 Annotations (TODO, FIXME, etc.)
```swift
editor.enablesAnnotations = true

// Automatically detects:
// TODO: Implement this feature
// FIXME: Bug in calculation
// NOTE: Important information
```

### 📏 Line Numbers
```swift
editor.showsLineNumbers = true
```

### ⚡ Performance Optimized
```swift
// Automatic optimization for large files
editor.optimizeForLargeFiles()

// Hardware acceleration (when available)
var performance = config.performance
performance.useHardwareAcceleration = true
```

## Error Handling

The editor provides comprehensive error handling:

```swift
do {
    // Safe operations that validate input
    try editor.setText(largeText)
    try editor.setLanguage(.python)
    try editor.replaceTextSafe(in: range, with: "new text")
    
    // Async operations with error handling
    let hover = try await editor.requestHoverSafe(at: position)
    let completions = try await editor.requestCompletionSafe(at: position)
} catch let error as CodeEditorError {
    print("Editor error: \(error.localizedDescription)")
    
    // Attempt automatic recovery
    if editor.attemptErrorRecovery(from: error) {
        print("Successfully recovered from error")
    }
}
```

## Themes and Customization

### Built-in Themes
```swift
let config = EditorConfigurationBuilder()
    .theme(.dark)    // or .light, .minimal
    .build()
```

### Custom Colors
```swift
editor.backgroundColor = PlatformColor.codeBackground
editor.selectedLineHighlightColor = PlatformColor.selectedLineHighlight
```

## Advanced Features

### Language Server Protocol (LSP)
```swift
// Configure LSP for enhanced features
try await editor.languageServerManager.configureLanguageServer(
    for: .swift,
    serverPath: "/usr/bin/sourcekit-lsp"
)

// Get hover information
let hover = try await editor.requestHoverSafe(at: cursorPosition)
```

### Real-time Performance Monitoring
```swift
// Enable performance monitoring
let stats = editor.performanceStatistics
print("Rendering time: \(stats.averageRenderTime)ms")
```

### Plugin System
```swift
// Extend functionality with plugins
let pluginManager = PluginManager()
pluginManager.registerPlugin(MyCustomPlugin())
```

## Common Patterns

### Read-Only Code Viewer
```swift
let config = EditorConfigurationBuilder()
    .codeReviewMode()
    .fontSize(14)
    .build()

editor.configuration = config
```

### Markdown Editor
```swift
let config = EditorConfigurationBuilder()
    .language(.markdown)
    .wrapLines(true)
    .enableSpellCheck(true)
    .showLineNumbers(false)
    .build()
```

### Presentation Mode
```swift
let config = EditorConfigurationBuilder()
    .presentationMode()  // Large font, minimal UI
    .build()
```

## Platform-Specific Notes

### macOS
- Full TextKit 2 support
- Native scroll bars and text handling
- Optimized for macOS 14+ (works on 12.0+)

### iOS
- Keyboard-aware layout
- Touch-optimized interactions
- Container view architecture for proper text handling

### Mac Catalyst
- Hybrid touch/mouse support
- Adaptive UI elements
- Consistent behavior across input methods

## Performance Tips

1. **Large Files**: Enable hardware acceleration and adjust highlighting limits
2. **Real-time Editing**: Use `.enableRealTimeEditingMode()` for optimal performance
3. **Read-only Display**: Use `.enableReadOnlyViewingMode()` for viewing scenarios
4. **Memory Management**: The editor automatically manages memory with built-in cleanup

## Migration from Other Editors

### From NSTextView/UITextView
```swift
// Old way
let textView = NSTextView()
textView.string = code
textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

// New way
let editor = CodeEditorView()
editor.text = code
editor.configuration = EditorConfigurationBuilder()
    .fontSize(14)
    .language(.swift)
    .build()
```

## Troubleshooting

### Common Issues

**Build Errors**: Ensure you're using Swift 6.0+ and Xcode 15+

**Performance Issues**: Check file size limits and enable hardware acceleration

**Layout Issues**: Use the container view architecture for iOS/complex layouts

**Memory Issues**: The editor includes automatic cleanup - check for retain cycles in delegates

### Getting Help

- Check the comprehensive documentation in `CLAUDE.md`
- Review the sample application in `CodeEditorSample/`
- File issues on GitHub with detailed reproduction steps

## Next Steps

- Explore the sample application for advanced usage patterns
- Read the full documentation for comprehensive API reference
- Check out the plugin system for extending functionality
- Join the community for tips and best practices

---

**Ready to build amazing code editing experiences!** 🚀