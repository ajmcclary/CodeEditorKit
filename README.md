# CodeEditorPlugin

[![Tests](https://img.shields.io/badge/tests-53%20passing-brightgreen)](#testing)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#testing)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Mac%20Catalyst-lightgrey)](#requirements)

A powerful, production-ready code editor component for macOS, iOS, and Mac Catalyst. Built with Swift 6 and featuring syntax highlighting for 17+ languages, comprehensive theming, and a modern architecture designed for performance and extensibility.

## ✨ Key Features

- **17+ Languages**: Syntax highlighting with SwiftSyntax for Swift, optimized regex for others
- **Cross-Platform**: Native performance on macOS, iOS, and Mac Catalyst 
- **Swift 6 Concurrency**: Actor-based architecture for thread safety and performance
- **Rich Editing**: Line numbers, code folding, annotations, smart indentation
- **Themeable**: Built-in themes (Xcode, VS Code Dark, GitHub, Solarized)
- **SwiftUI Native**: First-class SwiftUI integration with environment-based configuration
- **Extensible**: Plugin architecture and Language Server Protocol support

## 🚀 Quick Start

### SwiftUI

```swift
import SwiftUI
import CodeEditorPlugin

struct ContentView: View {
    @State private var code = "print(\"Hello, World!\")"
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .codeTheme(.dark)
            .frame(minHeight: 300)
    }
}
```

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## 📋 Requirements

- **Swift**: 6.0+
- **Platforms**:
  - macOS 12.0+ (optimized for 14+)
  - iOS 16.0+
  - Mac Catalyst 16.0+
- **Xcode**: 16.0+

## 🏗️ Architecture

### Directory Structure

```
Sources/CodeEditorPlugin/
├── Core/              # Text editing engine
├── Configuration/     # Settings management  
├── SyntaxHighlighting/# Language support
├── SwiftUI/          # SwiftUI components
├── Platform/         # Cross-platform abstractions
└── Languages/        # Language-specific providers
```

### Core Components

- **CodeEditorView**: TextKit2-based editor with platform adaptations
- **EditorConfiguration**: Structured settings with presets
- **Platform Abstraction**: Unified API for cross-platform development

## 🎨 Configuration

### Basic Setup

```swift
var config = EditorConfiguration()
config.display.showLineNumbers = true
config.display.fontSize = 14
config.layout.tabWidth = 4
config.behavior.autoIndent = true

// Use presets
let config = EditorConfiguration.minimal  // or .readOnly, .markdown, etc.
```

### SwiftUI Modifiers

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .lineNumbers(true)
    .highlightSelectedLine(true)
    .tabWidth(4)
    .enableCodeFolding(true)
    .environment(\.codeEditorConfiguration, config)
```

### Themes

Built-in themes adapt to light/dark mode:

```swift
CodeEditor(text: $code)
    .codeTheme(.xcode)      // or .vsDark, .github, .solarized
```

## 🔧 Advanced Usage

### Code Folding

```swift
config.display.enableCodeFolding = true
config.display.showFoldingControls = true

// Programmatic control
if editor.toggleFold(at: lineNumber) {
    print("Toggled fold")
}
```

### Annotations

Automatically detects TODO, FIXME, NOTE, WARNING, and ERROR comments:

```swift
config.display.enableAnnotations = true
// TODO: This appears as an inline badge
// FIXME: Shows as a warning badge
```

### Memory Monitoring

```swift
let monitor = MemoryMonitor()
monitor.startMonitoring()

CodeEditor(text: $code)
    .memoryMonitor(monitor)
```

### Language Support

```swift
// Auto-detect from file extension
textView.setLanguage(fileExtension: "py")

// Or set directly
textView.language = .python

// Supported languages:
// Swift, Python, JavaScript, TypeScript, Rust, C/C++, Go, Java, Ruby,
// PHP, HTML, CSS, JSON, YAML, XML, SQL, Shell, Markdown
```

## 🧪 Testing

The plugin includes 53 comprehensive tests covering all major functionality:

```bash
# Run tests
swift test

# With linting
swift build && swiftlint && swift test
```

## 📚 Documentation

Build the DocC documentation:

```bash
swift package generate-documentation --target CodeEditorPlugin
```

Key documentation files:
- `GettingStarted.md` - Quick setup guide
- `Configuration-System.md` - Configuration details
- `SwiftUI-Integration.md` - SwiftUI best practices
- `Platform-Abstraction.md` - Cross-platform development

## 🎮 Sample Application

Explore all features with the included sample app:

```bash
cd CodeEditorSample
swift run
```

The sample demonstrates:
- All configuration options
- Theme switching
- Language highlighting
- Performance monitoring
- Cross-platform behavior

## 📄 License

CodeEditorPlugin is proprietary software. All rights reserved. Unauthorized use, copying, distribution, or modification is prohibited without written permission.

Created by AJ McClary © 2025.