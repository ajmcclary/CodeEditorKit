# CodeEditorPlugin

[![Tests](https://img.shields.io/badge/test%20files-125-brightgreen)](#testing)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#testing)
[![Swift](https://img.shields.io/badge/Swift-6.3%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Mac%20Catalyst-lightgrey)](#requirements)
[![Files](https://img.shields.io/badge/source%20files-481-blue)](#architecture)

A powerful, production-ready code editor component for macOS, iOS, and Mac Catalyst. Built with Swift 6.3 and featuring syntax highlighting for 20 languages, comprehensive theming, and a modern architecture designed for performance and extensibility.

## ✨ Key Features

- **20 Languages**: Syntax highlighting with SwiftSyntax for Swift, optimized regex for others
- **Cross-Platform**: Native performance on macOS, iOS, and Mac Catalyst 
- **Swift 6 Concurrency**: Actor-based architecture for thread safety and performance
- **Rich Editing**: Line numbers, code folding, annotations, smart indentation
- **Themeable**: Bundled LCARS Dark theme plus Zed-compatible JSON theme loading
- **SwiftUI Native**: First-class SwiftUI integration with environment-based configuration
- **Extensible**: Language Server Protocol support with local server management on macOS and remote WebSocket clients on all supported platforms

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

- **Swift**: 6.3+
- **Platforms**:
  - macOS 26.3+
  - iOS 26.3+
  - Mac Catalyst 26.3+
- **Xcode**: 26.3+

## 📊 Platform Feature Availability

| Feature | macOS | iOS | Mac Catalyst |
|---------|:-----:|:---:|:------------:|
| Core Editor | ✅ | ✅ | ✅ |
| Syntax Highlighting | ✅ | ✅ | ✅ |
| Code Folding | ✅ | ✅ | ✅ |
| Line Numbers | ✅ | ✅ | ✅ |
| Themes | ✅ | ✅ | ✅ |
| Annotations | ✅ | ✅ | ✅ |
| Code Completion | ✅ | ✅ | ✅ |
| Language Server Protocol (Local) | ✅ | ❌ | ❌ |
| Language Server Protocol (Remote) | ✅ | ✅ | ✅ |
| Memory Monitoring | ✅ | ✅ | ✅ |
| Large File Support (10MB+) | ✅ | ⚠️ | ⚠️ |

### Platform Notes

- **Local LSP**: Only available on macOS due to Process API requirements. iOS and Catalyst apps must use remote LSP servers via WebSocket.
- **Large Files**: iOS and Catalyst have memory constraints. Files over 10MB may experience reduced performance. Consider:
  - Enabling viewport-based rendering
  - Disabling real-time syntax highlighting for very large files
  - Using the performance monitoring APIs to track memory usage

## 🏗️ Architecture

### Directory Structure

```
Sources/CodeEditorPlugin/
├── Core/              # Core functionality, APIs, business logic (40+ files)
├── Text/              # Unified text handling (34 files)
├── Layout/            # UI components and view models (20+ files)
├── Configuration/     # Settings and validation (29 files)
├── SyntaxHighlighting/# Language highlighting (15 files)
├── Languages/         # Language providers (37 files)
├── Completion/        # Code completion (18 files)
├── Features/          # Optional features (11 files)
├── SwiftUI/           # SwiftUI integration (10 files)
├── Platform/          # Cross-platform abstractions (32 files)
├── PluginSystem/      # Internal plugin infrastructure
├── Extensions/        # Type extensions (20 files)
├── Performance/       # Monitoring (7 files)
├── LSP/              # Language Server Protocol (7 files)
├── Annotations/       # Code annotations (8 files)
├── Models/           # Data models (7 files)
├── Utilities/        # Shared utilities (12 files)
└── Documentation.docc/# DocC documentation
```

18 top-level source directories, 437 Swift source files.

### Core Components

- **CodeEditorView**: TextKit2-based editor with platform adaptations
- **EditorConfiguration**: Structured settings with presets
- **Platform Abstraction**: Unified API for cross-platform development
- **Text Processing**: Consolidated text handling in unified `Text/` directory

## 🎨 Configuration

### Basic Setup

```swift
var config = EditorConfiguration()
config.display.isLineNumbersEnabled = true
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

The bundled default theme is LCARS Dark. Additional Zed-compatible theme JSON can be decoded through the theme loader APIs.

```swift
CodeEditor(text: $code)
    .codeTheme(.dark)       // .default and .dark resolve to LCARS Dark
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
    
// Important: Always stop monitoring when done
// (e.g., in onDisappear or deinit)
monitor.stopMonitoring()
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

### Language Server Protocol (LSP)

Local LSP server management is macOS-only. Remote WebSocket LSP clients are available on every supported platform.

```swift
let client = await LSPClient.createAndSetup()
let server = LSPServerConfiguration.remote(
    RemoteLSPConfiguration(
        serverURL: URL(string: "wss://lsp.example.com/swift")!,
        authentication: .bearerToken("your-token")
    )
)

try await client.connect(configuration: server, language: .swift)
```

## 🧪 Testing

The package includes 70 test files covering the major editor, configuration, platform, and language paths:

```bash
# Run tests in parallel (faster)
swift test --parallel

# Full workflow with linting
swift build && swiftlint && swift test --parallel

# Run specific test
swift test --filter TestName
```

## 📚 Documentation

DocC documentation lives in `Sources/CodeEditorPlugin/Documentation.docc`.
Build it from Xcode's documentation workflow, or add the Swift-DocC plugin locally
if you need CLI archive generation.

Key documentation files:
- `GettingStarted.md` - Quick setup guide
- `Configuration-System.md` - Configuration details
- `SwiftUI-Integration.md` - SwiftUI best practices
- `Platform-Abstraction.md` - Cross-platform development

## 🎯 Recent Improvements (2025)

- **Directory Reorganization**: Streamlined from 22 to 18 directories for better discoverability
- **Unified Text Handling**: Consolidated TextKit, TextLayout, and TextProcessing into single `Text/` directory
- **Business Logic Services**: Introduced service layer for better separation of concerns
- **Swift 6 Concurrency**: Full actor isolation with zero concurrency warnings
- **Performance**: Parallel test execution, optimized syntax highlighting with caching
- **API Refinement**: Cleaner public API surface with internal implementation details hidden

## 📄 License

CodeEditorPlugin is proprietary software. All rights reserved. Unauthorized use, copying, distribution, or modification is prohibited without written permission.

Created by AJ McClary © 2025.
