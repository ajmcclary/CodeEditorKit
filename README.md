# CodeEditorPlugin

[![Tests](https://img.shields.io/badge/tests-66%20passing-brightgreen)](#testing)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#testing)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Mac%20Catalyst-lightgrey)](#requirements)
[![Files](https://img.shields.io/badge/files-401%20source-blue)](#architecture)

A powerful, production-ready code editor component for macOS, iOS, and Mac Catalyst. Built with Swift 6 and featuring syntax highlighting for 20 languages, comprehensive theming, and a modern architecture designed for performance and extensibility.

## ✨ Key Features

- **20 Languages**: Syntax highlighting with SwiftSyntax for Swift, optimized regex for others
- **Cross-Platform**: Native performance on macOS, iOS, and Mac Catalyst 
- **Swift 6 Concurrency**: Actor-based architecture for thread safety and performance
- **Rich Editing**: Line numbers, code folding, annotations, smart indentation
- **Themeable**: Built-in themes (Xcode, VS Code Dark, GitHub, Solarized)
- **SwiftUI Native**: First-class SwiftUI integration with environment-based configuration
- **Extensible**: Plugin architecture (Preview) and Language Server Protocol support (macOS only)

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
  - macOS 14.0+
  - iOS 16.0+
  - Mac Catalyst 16.0+
- **Xcode**: 16.0+

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
| Plugin Architecture | ✅ | ✅ | ✅ |
| Memory Monitoring | ✅ | ✅ | ✅ |
| Large File Support (10MB+) | ✅ | ⚠️ | ⚠️ |

### Platform Notes

- **Local LSP**: Only available on macOS due to Process API requirements. iOS and Catalyst apps must use remote LSP servers via WebSocket.
- **Large Files**: iOS and Catalyst have memory constraints. Files over 10MB may experience reduced performance. Consider:
  - Enabling viewport-based rendering
  - Disabling real-time syntax highlighting for very large files
  - Using the performance monitoring APIs to track memory usage

## 🔌 Plugin Architecture (Preview)

The CodeEditorPlugin supports extensibility through a plugin system that allows adding new languages, themes, and features. This system is currently in preview and the API may change.

```swift
// Example: Adding a custom language
let customLanguage = LanguageConfiguration(
    id: "custom",
    displayName: "Custom Language",
    fileExtensions: ["cst", "custom"],
    syntaxPatterns: customPatterns
)
LanguageRegistry.register(customLanguage)
```

For detailed plugin development guidance, see `Documentation.docc/Plugin-Architecture.md`.

## 🏗️ Architecture

### Directory Structure (Streamlined 2025)

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
├── Extensions/        # Type extensions (20 files)
├── Performance/       # Monitoring (7 files)
├── LSP/              # Language Server Protocol (7 files)
├── Annotations/       # Code annotations (8 files)
├── Models/           # Data models (7 files)
├── Utilities/        # Shared utilities (12 files)
└── Documentation.docc/# DocC documentation
```

18 directories (down from 22), 333 source files total.

### Core Components

- **CodeEditorView**: TextKit2-based editor with platform adaptations
- **EditorConfiguration**: Structured settings with presets
- **Platform Abstraction**: Unified API for cross-platform development
- **Text Processing**: Consolidated text handling in unified `Text/` directory

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

The plugin now supports LSP on all platforms through remote WebSocket connections:

```swift
// Local LSP (macOS only)
config.lsp.servers["swift"] = LSPServerConfiguration.local(
    LocalLSPConfiguration(
        executablePath: "/usr/bin/sourcekit-lsp"
    )
)

// Remote LSP (all platforms)
config.lsp.servers["swift"] = LSPServerConfiguration.remote(
    RemoteLSPConfiguration(
        serverURL: URL(string: "wss://lsp.example.com/swift")!,
        authentication: .bearerToken("your-token")
    )
)
```

## 🧪 Testing

The plugin includes 53 comprehensive tests covering all major functionality:

```bash
# Run tests in parallel (faster)
swift test --parallel

# Full workflow with linting
swift build && swiftlint && swift test --parallel

# Run specific test
swift test --filter TestName
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