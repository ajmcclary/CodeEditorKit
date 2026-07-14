# Getting Started

A modern, cross-platform code editor for macOS and iOS / iPadOS. Built on TextKit2 with Swift 6 strict concurrency, SwiftSyntax for Swift highlighting, and a feature-based source tree designed for extension. (Mac Catalyst was retired in 0.2.0.)

## Platform Requirements

- **Swift**: 6.3 or later
- **Xcode**: 26.3 or later
- **Deployment targets**: macOS 26.0+, iOS 26.0+

## Installation

### Xcode

1. **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/ajmcclary/CodeEditorPlugin.git`
3. Until release tags are published, choose the `main` branch. After tags exist, switch to an up-to-next-major version rule.

### Package.swift

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", branch: "main")
    ],
    targets: [
        .target(name: "MyApp", dependencies: ["CodeEditorPlugin"])
    ]
)
```

CodeEditorPlugin pulls in `swift-syntax`, `swift-dependencies`, and `xctest-dynamic-overlay` (for `IssueReporting`). These are managed automatically by SwiftPM.

## A Minimal Editor

```swift
import SwiftUI
import CodeEditorPlugin

struct ContentView: View {
    @State private var code = "// Type your code here"

    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .frame(minHeight: 300)
    }
}
```

That's it — syntax highlighting, line numbers, and theming are on by sensible defaults.

## Common Snippets

### SwiftUI with language + theme

```swift
CodeEditor(text: $code, language: .python, theme: .dark)
    .lineNumbers(true)
    .isSelectedLineHighlighted(true)
    .frame(minHeight: 300)
```

### Read-only code viewer

```swift
struct CodeViewer: View {
    let source: String

    var body: some View {
        CodeEditor(text: .constant(source))
            .editable(false)
            .lineNumbers(true)
            .environment(\.codeEditorConfiguration, .readOnly)
    }
}
```

### Code completion

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .codeCompletion { context in
        guard context.text.hasSuffix(".") else { return [] }
        return [
            SwiftUICompletionItem(label: "append", kind: .method, insertText: "append(<#value#>)")
        ]
    }
```

### Reacting to text + selection changes (debounced)

```swift
CodeEditor(text: $code, debounceInterval: .milliseconds(500))
    .onTextChange { newText in validateSyntax(newText) }
    .onSelectionChange { range in updateCursorInfo(range) }
```

### AppKit (`NSViewController`)

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
        // Add Auto Layout constraints…
    }
}
```

### UIKit (`UIViewController`)

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
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
```

## Configuration

Configuration is plain-old-Swift values: build one up, mutate it, apply it.

```swift
var config = EditorConfiguration()
config.display.fontSize = 16
config.display.isLineNumbersEnabled = true
config.display.isCodeFoldingEnabled = true
config.layout.tabWidth = 2
config.behavior.isCodeCompletionEnabled = true

CodeEditor(text: $code)
    .codeLanguage(.javascript)
    .environment(\.codeEditorConfiguration, config)
```

Or start from a built-in preset:

```swift
.environment(\.codeEditorConfiguration, .readOnly)        // viewer-style
.environment(\.codeEditorConfiguration, .minimal)         // chrome-free
.environment(\.codeEditorConfiguration, .presentation)    // big fonts, no chrome
.environment(\.codeEditorConfiguration, .markdown)        // markdown-tuned
.environment(\.codeEditorConfiguration, .iOS)             // iOS defaults
.environment(\.codeEditorConfiguration, .platformOptimized)
```

See [Configuration system](Configuration/system.md) for the full schema and [Presets](Configuration/presets.md) for what each preset turns on.

## Supported Languages

Full AST-based highlighting via SwiftSyntax for **Swift**. The full catalog is **25 concrete languages plus plain text**: Swift, Python, JavaScript, TypeScript, Java, Go, Rust, C, C++, PHP, Ruby, JSON, YAML, XML, Markdown, CSS, HTML, SQL, Shell, Dockerfile, TOML, Lua, C#, Kotlin, Dart, and Plain Text.

Details: [Syntax highlighting](Features/syntax-highlighting.md).

## Where to Go Next

- **Customize the look**: [Theme system](Features/theme-system.md)
- **Platform-specific guidance**: [iOS](Platform/ios.md), [macOS](Platform/macos.md), [UIKit ↔ AppKit](Platform/uikit-appkit.md)
- **SwiftUI integration**: [SwiftUI integration](SwiftUI/integration.md), [environment keys](SwiftUI/environment-keys.md)
- **Performance**: [Monitoring](Performance/monitoring.md), [Optimizations](Performance/optimizations.md), [Production reliability](Performance/reliability.md)
- **Concurrency model**: [Swift 6 concurrency](Concurrency/swift6.md), [Sendable callbacks](Concurrency/sendable-callbacks.md)
- **Architecture deep-dives**: [Architecture overview](Internals/architecture-overview.md), [Advanced patterns](Internals/advanced-patterns.md)
- **Stuck?** [Troubleshooting](Reference/troubleshooting.md)

## Installation Troubleshooting

If package resolution fails:

1. **Product → Clean Build Folder** (⇧⌘K)
2. **File → Packages → Reset Package Caches**
3. Confirm Xcode 26.3+ is installed

If `swift-syntax` fails to resolve, pin its version explicitly in your `Package.swift`. Other recurring issues are documented in [Troubleshooting](Reference/troubleshooting.md).
