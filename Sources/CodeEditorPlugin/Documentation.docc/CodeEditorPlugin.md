# CodeEditorPlugin

A powerful, production-ready code editor component for macOS, iOS, and Mac Catalyst with modern Swift 6 architecture.

@Metadata {
    @TechnologyRoot
}

## Overview

CodeEditorPlugin provides world-class performance, extensive customization, and a feature set designed for professional development tools. Built from the ground up with true cross-platform support in mind, it delivers advanced syntax highlighting, a robust theme system, and seamless native performance on **macOS, iOS, and Mac Catalyst**.

### Key Features

- 🚀 **Modern Swift 6 Concurrency** - Actor-based architecture for thread safety and performance
- 💻 **True Cross-Platform** - Sophisticated abstraction layer for native performance everywhere
- 🎨 **20 Programming Languages** - SwiftSyntax for Swift, optimized regex for other languages
- ✅ **Production-Grade Quality** - 70 test files with zero linting violations
- 🔧 **Extensible Architecture** - LSP integration and internal plugin infrastructure
- 📁 **Organized Source Tree** - 18 top-level source directories for discoverability

### Quick Start

Get started in seconds with SwiftUI:

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

See <doc:QuickStart> for more examples and advanced usage.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Installation>
- <doc:QuickStart>

### Architecture

- <doc:Architecture-Overview>
- <doc:Platform-Abstraction>
- <doc:Swift6-Concurrency>

### Configuration

- <doc:Configuration-System>
- <doc:Configuration-Presets>
- <doc:Theme-System>

### Features

- <doc:Syntax-Highlighting>
- <doc:Annotation-System>
- <doc:Performance-Monitoring>
- <doc:Performance-Optimization-Integration>
- <doc:MemoryMonitor-Injection>
- <doc:Unified-Event-System>
- <doc:Code-Folding-API>
- <doc:Production-Reliability>
- <doc:LSP-Integration>

### Integration

- <doc:SwiftUI-Integration>
- <doc:UIKit-AppKit-Integration>
- <doc:Advanced-Patterns>

### Swift 6 & Modern APIs

- <doc:Sendable-Callbacks>
- <doc:Duration-API-Migration>

### Documentation

- <doc:DocC-Documentation-Guide>
- <doc:Troubleshooting>

### API Reference

- ``CodeEditorView``
- ``EditorConfiguration``
- ``CodeEditor``
- ``SyntaxHighlightingCoordinator``
- ``Theme``
- ``UnifiedEventSystem``

## See Also

- <doc:GettingStarted>
- <doc:QuickStart>
- <doc:Installation>
