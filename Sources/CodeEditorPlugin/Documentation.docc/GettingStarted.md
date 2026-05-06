# Getting Started

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

Learn how to quickly integrate CodeEditorPlugin into your application.

## Overview

CodeEditorPlugin is a modern, cross-platform code editor component for macOS, iOS, and Mac Catalyst applications. Built with Swift 6 concurrency and production-grade reliability, it features syntax highlighting for 20 programming languages, code completion, annotations, and comprehensive SwiftUI integration. With 66 comprehensive test files and zero linting violations, this guide will help you get up and running in minutes.

## Installation

### Swift Package Manager

Add CodeEditorPlugin to your project using Xcode's package manager:

1. In Xcode, select **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/ajmcclary/CodeEditorPlugin.git`
3. Select your version requirements
4. Click **Add Package**

Alternatively, add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
]
```

## Basic Usage

### SwiftUI Integration (Recommended)

The simplest way to add a code editor to your SwiftUI app:

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
            .lineNumbers(true)
            .isSyntaxHighlightingEnabled(true)
            .frame(minHeight: 400)
    }
}
```

### AppKit Integration (macOS)

```swift
import AppKit
import CodeEditorPlugin

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editor = CodeEditorView()
        editor.language = .swift
        editor.isLineNumbersEnabled = true
        editor.text = "print(\"Hello, World!\")"
        
        view.addSubview(editor)
        // Add Auto Layout constraints...
    }
}
```

### UIKit Integration (iOS)

```swift
import UIKit
import CodeEditorPlugin

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editor = CodeEditorView()
        editor.language = .swift
        editor.isLineNumbersEnabled = true
        editor.text = "print(\"Hello, iOS!\")"
        
        view.addSubview(editor)
        // Add Auto Layout constraints...
    }
}
```

## Quick Configuration

Use configuration presets for common scenarios:

```swift
// Start with built-in presets
var config = EditorConfiguration.default
config.display.isLineNumbersEnabled = true

// Or use specialized presets
let readOnlyConfig = EditorConfiguration.readOnly
let minimalConfig = EditorConfiguration.minimal
let presentationConfig = EditorConfiguration.presentation

// Apply configuration changes
config.display.fontSize = 16
config.layout.tabWidth = 4
config.behavior.isCodeCompletionEnabled = true
config.layout.wrapLines = false

// Apply to editor
config.apply(to: editor)
```

## Key Features

### Syntax Highlighting
```swift
editor.language = .swift
editor.isSyntaxHighlightingEnabled = true
```

### Code Completion
```swift
editor.isCodeCompletionEnabled = true
```

### Annotations (TODO, FIXME, etc.)
```swift
editor.enablesAnnotations = true
// Automatically detects TODO, FIXME, NOTE, WARNING, ERROR comments
```

### Line Numbers
```swift
editor.isLineNumbersEnabled = true
```

## Supported Languages

- **Swift** (Full AST-based highlighting with SwiftSyntax)
- **Python**, **JavaScript/TypeScript**, **Rust**, **Go** 
- **HTML/CSS**, **JSON/YAML**, **Markdown**
- **Java**, **C/C++**, **Ruby**, **PHP**
- **SQL**, **XML**, **Shell scripts**
- **Plain text**

## Next Steps

- Explore <doc:Configuration-System> for detailed customization
- Learn about <doc:Syntax-Highlighting> for language support
- Review <doc:Production-Reliability> for robust error handling and concurrency safety
- See <doc:Advanced-Patterns> for sophisticated use cases
- Check out <doc:Performance-Monitoring> for optimization insights
- Review <doc:Troubleshooting> for common issues

## Platform Requirements

- **Swift**: 6.0+
- **macOS**: 12.0+ (optimized for macOS 14+)
- **iOS**: 16.0+
- **Mac Catalyst**: 16.0+