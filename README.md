# CodeEditorKit

[![Tests](https://img.shields.io/badge/test%20files-221-brightgreen)](#testing)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#testing)
[![Swift](https://img.shields.io/badge/Swift-6.3%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS-lightgrey)](#requirements)
[![Files](https://img.shields.io/badge/source%20files-589-blue)](#architecture)

A powerful, production-ready code editor component for native macOS and iOS / iPadOS. Built with Swift 6.3, TextKit2, and Swift 6 strict concurrency, featuring syntax highlighting for 25 concrete languages plus plain text, comprehensive theming, and a modern architecture designed for performance and extensibility.

## ✨ Key Features

- **25 Languages**: Syntax highlighting with SwiftSyntax for Swift and optimized highlighters for other supported languages
- **Cross-Platform**: Native performance on macOS and iOS / iPadOS
- **Swift 6 Concurrency**: Actor-based architecture for thread safety and performance
- **Rich Editing**: Line numbers, code folding, annotations, smart indentation
- **Themeable**: Bundled Zed Trek theme family (22 Star-Trek-inspired variants, default `LCARS Dark`) plus Zed-compatible JSON theme loading
- **SwiftUI Native**: First-class SwiftUI integration with environment-based configuration
- **Extensible**: Language Server Protocol support with local server management on macOS and remote WebSocket clients on all supported platforms

## 🚀 Quick Start

### SwiftUI

```swift
import SwiftUI
import CodeEditorKit

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
    // 0.1.0-beta.4 is a prerelease identifier — SwiftPM only resolves
    // prerelease tags when the lower bound itself names one.
    .package(url: "https://github.com/ajmcclary/CodeEditorKit.git", .upToNextMinor(from: "0.1.0-beta.4"))
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## 📋 Requirements

- **Swift**: 6.3+
- **Platforms**:
  - macOS 27.0+
  - iOS: not declared. The manifest carried `.iOS("26.0")` until the macOS 27
    migration; the declaration was removed, not raised, because the
    `CodeEditorWorkspace` product re-exports `WorkspaceKit`, which is macOS-only
    (unguarded FSEvents use). Every other product was verified to build for
    iOS 27 — see the `platforms:` comment in `Package.swift` for the evidence
    and for what restoring an iOS floor would require.
- **Xcode**: 26.3+

## 📊 Platform Feature Availability

| Feature | macOS | iOS / iPadOS |
|---------|:-----:|:---:|
| Core Editor | ✅ | ✅ |
| Syntax Highlighting | ✅ | ✅ |
| Code Folding | ✅ | ✅ |
| Line Numbers | ✅ | ✅ |
| Themes | ✅ | ✅ |
| Annotations | ✅ | ✅ |
| Code Completion | ✅ | ✅ |
| Language Server Protocol (Local) | ✅ | ❌ |
| Language Server Protocol (Remote) | ✅ | ✅ |
| Memory Monitoring | ✅ | ✅ |
| Large File Support (10MB+) | ✅ | ⚠️ |

### Platform Notes

- **Mac Catalyst**: Not supported as of 0.2.0. Use the native macOS path for Mac apps and the iOS path for iPad apps.
- **Local LSP**: Only available on macOS due to Process API requirements. iOS apps must use remote LSP servers via WebSocket.
- **Large Files**: iOS has tighter memory constraints. Files over 10MB may experience reduced performance. Consider:
  - Enabling viewport-based rendering
  - Disabling real-time syntax highlighting for very large files
  - Using the performance monitoring APIs to track memory usage

## 🏗️ Architecture

### SPM Targets

The package is split into focused SPM targets. `CodeEditorKit` is the umbrella that
`@_exported`-imports the most common surface; opt-in subsystems (LSP, Search, Workspace,
Diagnostics) are separate libraries you import by name when you need them.

```
Sources/
├── CodeEditorKit/             # Umbrella: re-exports the common surface (1 .swift file)
├── CodeEditorView/            # Editor surface: CodeEditorView class + services
├── CodeEditorSwiftUI/         # SwiftUI host wrapper, EditorController, modifiers
├── CodeEditorUI/              # Optional SwiftUI chrome/components
├── CodeEditorCommon/          # Shared utilities, models, error/recovery infrastructure
├── CodeEditorConfiguration/   # Settings, presets, validation
├── CodeEditorTheming/         # Theme system + bundled Zed Trek theme JSON
├── CodeEditorDesignTokens/    # Colors, spacing, typography tokens
├── CodeEditorPlatform/        # Cross-platform color/font/view abstractions
├── CodeEditorTextModel/       # TextKit2 primitives, RangeStore, geometry
├── CodeEditorLanguages/       # Language descriptors (25 languages + plain text)
├── CodeEditorSyntaxHighlighting/  # Highlighting engine (regex + SwiftSyntax)
├── CodeEditorLayout/          # Layout caches/coordinators, fold chevrons, popovers
├── CodeEditorAnnotations/     # Annotation data model + view chrome
├── CodeEditorFolding/         # Fold-storage primitives + provider registry
├── CodeEditorSymbols/         # Breadcrumb + symbol-navigation surface
├── CodeEditorCompletion/      # CompletionManager, ranking, providers, UI bridge
├── CodeEditorSmartEditing/    # Auto-bracket, multi-cursor, smart indent/selection
├── CodeEditorLSP/             # Language Server Protocol (process + WebSocket)
├── CodeEditorSearch/          # Project-wide file-search protocols + adapter
├── CodeEditorWorkspace/       # Workspace file-tree protocols + macOS adapter
├── CodeEditorDiagnostics/     # Performance instrumentation, memory monitoring
└── CodeEditorTreeSitterLanguages/  # Tree-sitter staging sources (not an SPM target yet)
```

The demo app now lives at `apps/CodeEditorDemo` in the superproject workspace, not in this package.

Long-form prose docs live in [`docs/`](docs/README.md), organized by topic.

21 source roots under `Sources/`, 515 Swift files total. The `CodeEditorKit` umbrella
target itself ships a single `CodeEditorKit.swift` entry stub plus `Resources/Info.plist`
— all subsystems live in sibling targets.

### Core Components

- **CodeEditorView**: TextKit2-based editor with platform adaptations
- **EditorConfiguration**: Structured settings with presets
- **Platform Abstraction**: Unified API for cross-platform development
- **CodeEditorTextModel**: TextKit2 primitives + RangeStore shared across targets

## 🎨 Configuration

### Basic Setup

```swift
var config = EditorConfiguration()
config.display.isLineNumbersEnabled = true
config.display.fontSize = 14
config.layout.tabWidth = 4
config.behavior.isAutoIndentEnabled = true

// Use presets
let config = EditorConfiguration.minimal  // or .readOnly, .markdown, etc.
```

### SwiftUI Modifiers

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .lineNumbers(true)
    .isSelectedLineHighlighted(true)
    .tabWidth(4)
    .isCodeFoldingEnabled(true)
    .environment(\.codeEditorConfiguration, config)
```

### Themes

The bundled default theme is `LCARS Dark`, drawn from the `Zed Trek` family (20 Star-Trek-inspired dark/light variants shipped in `Sources/CodeEditorTheming/Resources/Themes/zed-trek.json`). `Theme.default`, `Theme.dark`, and `Theme.lcarsDark` all resolve to the same variant. Additional Zed-compatible theme JSON can be decoded through `ThemeFamily.bundled(_:)`, `ThemeFamily(jsonData:)`, `ThemeFamily(contentsOf:)`, and `Theme.bundled(family:variant:)`.

```swift
CodeEditor(text: $code)
    .codeTheme(.dark)       // .default and .dark resolve to LCARS Dark
```

## 🔧 Advanced Usage

### Code Folding

```swift
config.display.isCodeFoldingEnabled = true
config.display.areFoldingControlsVisible = true

// Programmatic control
if editor.toggleFold(at: lineNumber) {
    CrossPlatformLogger.logger().info("Toggled fold")
}
```

### Annotations

Annotations are data-source driven. Host apps can scan for TODO/FIXME comments, diagnostics, or review notes and provide them to the editor:

```swift
config.display.areAnnotationsEnabled = true
editor.annotationsDataSource = dataSource
editor.reloadAnnotations()
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
// Swift, Python, JavaScript, TypeScript, Java, Go, Rust, C, C++, PHP,
// Ruby, JSON, YAML, XML, Markdown, CSS, HTML, SQL, Shell, Dockerfile,
// TOML, Lua, C#, Kotlin, Dart, plus plain text
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

### External syntax-highlighting providers

`CodeEditorHighlightingCore` defines a view-free, `Sendable` value contract,
`HighlightRangeProviding`, that lets an external engine drive syntax
highlighting without depending on the editor surface. Inject one through any of
three seams:

```swift
// 1. View level
codeEditorView.setExternalHighlightProvider(myProvider)

// 2. EditorController (SwiftUI host)
controller.setExternalHighlightProvider(myProvider)

// 3. SwiftUI modifier
CodeEditor(text: $code)
    .codeEditorHighlightProvider(myProvider)
```

**Semantics:** the injected provider *replaces* the built-in regex / SwiftSyntax
highlighter as the editor's **primary** highlight source — the built-in
highlighter no longer runs while a provider is installed. (This differs from the
LSP integration, which layers semantic tokens on top as a higher-priority
*supplemental* provider while the built-in highlighter still runs.) Pass `nil`
to restore the built-in highlighter. The provider only paints once the
range-store pipeline is enabled:

```swift
config.performance.usesRangeBasedHighlighting = true
config.display.useRangeStoreHighlighting = true
```

The separate [`CodeEditorTreeSitter`](../CodeEditorTreeSitter) package ships a
ready-made tree-sitter conformer, `TreeSitterHighlightProvider.standard(languageID:)`.

## 🧪 Testing

The package includes 4 test targets and 221 `*Tests.swift` files covering the major editor, configuration, platform, and language paths:

```bash
# Run tests in parallel (faster)
swift test --parallel

# Full workflow with linting
swift build && swiftlint --fix && swiftlint && swift test --parallel

# Run specific test
swift test --filter TestName
```

## 📚 Documentation

Documentation lives in [`docs/`](docs/README.md) as plain Markdown — no
DocC toolchain needed. Start with:

- [Getting Started](docs/GettingStarted.md) — install + first editor
- [Configuration system](docs/Configuration/system.md)
- [SwiftUI integration](docs/SwiftUI/integration.md)
- [Platform abstraction](docs/Platform/platform-abstraction.md)
- [Architecture decisions](docs/Architecture/README.md) and [diagrams](docs/Diagrams/README.md)

## 📄 License

CodeEditorKit is MIT licensed. See [`LICENSE`](LICENSE).

Created by AJ McClary © 2026.
