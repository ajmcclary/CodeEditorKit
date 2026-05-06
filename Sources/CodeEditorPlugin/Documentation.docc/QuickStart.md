# Quick Start

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

Get a code editor running in your app with these ready-to-use snippets.

## Overview

This guide provides copy-paste code snippets for common use cases. Each example is self-contained and production-ready.

## Basic Setup

### SwiftUI - Minimal Editor

```swift
import SwiftUI
import CodeEditorPlugin

struct ContentView: View {
    @State private var code = "// Type your code here"
    
    var body: some View {
        CodeEditor(text: $code)
            .frame(minHeight: 300)
    }
}
```

### SwiftUI - With Language and Theme

```swift
struct ContentView: View {
    @State private var code = "def hello():\n    print('Hello, World!')"
    
    var body: some View {
        CodeEditor(text: $code, language: .python, theme: .dark)
            .frame(minHeight: 300)
    }
}
```

### UIKit - Basic Setup

```swift
import UIKit
import CodeEditorPlugin

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editor = CodeEditorView()
        editor.text = "// Your code here"
        editor.language = .swift
        
        view.addSubview(editor)
        editor.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            editor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
```

## Common Use Cases

### Read-Only Code Viewer

```swift
struct CodeViewerView: View {
    let sourceCode: String
    
    var body: some View {
        CodeEditor(text: .constant(sourceCode))
            .editable(false)
            .lineNumbers(true)
            .environment(\.codeEditorConfiguration, .readOnly)
    }
}
```

### Dark Theme Editor

```swift
CodeEditor(text: $code)
    .codeTheme(.dark)
    .lineNumbers(true)
    .isSelectedLineHighlighted(true)
    .isMinimapVisible(true)
```

### Platform-Optimized Editor

```swift
CodeEditor(text: $code)
    .environment(\.codeEditorConfiguration, .platformOptimized)
```

## Advanced Features

### With Code Completion

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .codeCompletion { context in
        // Return completion items based on context
        if context.text.hasSuffix(".") {
            return [
                SwiftUICompletionItem(
                    label: "append",
                    kind: .method,
                    insertText: "append(<#value#>)"
                )
            ]
        }
        return []
    }
```

### With Text Change Handler

```swift
CodeEditor(text: $code, debounceInterval: .milliseconds(500))
    .onTextChange { newText in
        // Handle text changes (debounced)
        validateSyntax(newText)
    }
    .onSelectionChange { range in
        // Handle selection changes
        updateCursorInfo(range)
    }
```

## Configuration Examples

### Using Direct Configuration

```swift
var config = EditorConfiguration()
config.display.fontSize = 16
config.layout.tabWidth = 2
config.display.isLineNumbersEnabled = true
config.display.isCodeFoldingEnabled = true

CodeEditor(text: $code)
    .codeLanguage(.javascript)
    .environment(\.codeEditorConfiguration, config)
```

### Quick Presets

```swift
// For iOS devices
.environment(\.codeEditorConfiguration, .iOS)

// For Mac Catalyst
.environment(\.codeEditorConfiguration, .catalyst)

// For Markdown editing
.environment(\.codeEditorConfiguration, .markdown)

// For presentations
.environment(\.codeEditorConfiguration, .presentation)
```

## Next Steps

- <doc:GettingStarted> - Comprehensive setup guide
- <doc:Configuration-System> - All configuration options
- <doc:SwiftUI-Integration> - Advanced SwiftUI features
- <doc:Syntax-Highlighting> - Language support details

## See Also

- <doc:Platform-Abstraction>
- <doc:Theme-System>
- <doc:Performance-Monitoring>
