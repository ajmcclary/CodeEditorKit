# Plugin Architecture

@Metadata {
    @PageColor(purple)
}

Extend CodeEditorPlugin with custom functionality through the plugin system.

## Overview

The plugin architecture enables you to extend CodeEditorPlugin without modifying its core code. Add new languages, tools, commands, and themes through a secure, sandboxed plugin system.

> Note: The plugin system is currently in preview. Full support coming in v2.0.

## Plugin Types

### Language Plugins

Add support for new programming languages:

```swift
class MyLanguagePlugin: LanguagePlugin {
    var identifier: String { "com.example.mylang" }
    var displayName: String { "My Language" }
    var fileExtensions: [String] { ["ml", "myl"] }
    
    func tokenize(_ text: String) -> [Token] {
        // Implement tokenization
    }
    
    func getSyntaxPatterns() -> [SyntaxPattern] {
        [
            .keyword(["func", "var", "let", "if", "else"]),
            .string(delimiter: "\"", escape: "\\"),
            .comment(single: "//", multi: ("/*", "*/")),
            .number(pattern: #/\d+(\.\d+)?/#)
        ]
    }
}
```

### Tool Plugins

Integrate external tools:

```swift
class LinterPlugin: ToolPlugin {
    var identifier: String { "com.example.linter" }
    var displayName: String { "My Linter" }
    
    func analyze(_ content: String) async -> [Diagnostic] {
        // Run linter and return diagnostics
    }
    
    var supportedCommands: [PluginCommand] {
        [
            PluginCommand(
                id: "lint",
                title: "Run Linter",
                keyboardShortcut: "⌘⇧L"
            )
        ]
    }
}
```

### Theme Plugins

Add custom themes:

```swift
class CustomThemePlugin: ThemePlugin {
    var identifier: String { "com.example.themes" }
    
    var themes: [Theme] {
        [
            Theme(
                id: "neon",
                name: "Neon Dreams",
                colors: NeonColorScheme()
            ),
            Theme(
                id: "forest",
                name: "Forest",
                colors: ForestColorScheme()
            )
        ]
    }
}
```

### Command Plugins

Add custom editor commands:

```swift
class RefactoringPlugin: CommandPlugin {
    var commands: [EditorCommand] {
        [
            EditorCommand(
                id: "extract-function",
                title: "Extract Function",
                handler: extractFunction
            ),
            EditorCommand(
                id: "rename-symbol",
                title: "Rename Symbol",
                handler: renameSymbol
            )
        ]
    }
    
    func extractFunction(in editor: EditorContext) async {
        // Implement refactoring
    }
}
```

## Plugin Development

### Plugin Structure

```
MyPlugin/
├── Info.plist
├── Sources/
│   └── MyPlugin.swift
├── Resources/
│   ├── icon.png
│   └── configuration.json
└── Tests/
    └── MyPluginTests.swift
```

### Plugin Manifest

Info.plist configuration:

```xml
<key>PluginIdentifier</key>
<string>com.example.myplugin</string>
<key>PluginVersion</key>
<string>1.0.0</string>
<key>MinimumEditorVersion</key>
<string>1.0.0</string>
<key>PluginCapabilities</key>
<array>
    <string>language</string>
    <string>theme</string>
</array>
```

### Plugin Lifecycle

```swift
class MyPlugin: Plugin {
    // Called when plugin loads
    func activate(context: PluginContext) async throws {
        // Register capabilities
        context.register(languageProvider)
        context.register(themeProvider)
    }
    
    // Called when plugin unloads
    func deactivate() async {
        // Cleanup resources
    }
    
    // Handle configuration changes
    func configure(_ config: PluginConfiguration) {
        // Apply settings
    }
}
```

## Plugin API

### Editor Context

Access editor functionality:

```swift
class EditorContext {
    // Current text
    var text: String { get }
    
    // Selection
    var selectedRange: NSRange { get set }
    
    // Language
    var language: Language? { get }
    
    // Modify text
    func insertText(_ text: String, at position: Int)
    func replaceText(in range: NSRange, with text: String)
    
    // UI
    func showCompletions(_ items: [CompletionItem])
    func showDiagnostic(_ diagnostic: Diagnostic)
}
```

### Storage API

Persist plugin data:

```swift
class PluginStorage {
    // Key-value storage
    func set<T: Codable>(_ value: T, forKey key: String)
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    
    // File storage
    var documentsDirectory: URL { get }
    var cacheDirectory: URL { get }
}
```

### Networking

Make network requests:

```swift
class PluginNetworking {
    // Restricted to approved domains
    func fetch(from url: URL) async throws -> Data
    
    // WebSocket support
    func connectWebSocket(to url: URL) -> WebSocketConnection
}
```

## Security

### Sandboxing

Plugins run in a secure sandbox:
- No file system access outside designated folders
- Network access restricted to approved domains
- No process spawning
- Limited memory and CPU usage

### Permissions

Plugins must declare required permissions:

```swift
enum PluginPermission {
    case network(domains: [String])
    case fileAccess(directories: [FileDirectory])
    case notifications
    case backgroundProcessing
}
```

### Code Signing

Plugins must be signed for distribution:

```bash
codesign --sign "Developer ID" MyPlugin.bundle
```

## Plugin Installation

### Manual Installation

```swift
// Drop plugin into plugins directory
~/Library/Application Support/CodeEditorPlugin/Plugins/
```

### Programmatic Installation

```swift
let manager = PluginManager.shared
try await manager.install(from: pluginURL)
```

### Plugin Marketplace

Coming in v2.0:

```swift
let marketplace = PluginMarketplace()
let plugins = await marketplace.search("language")
try await marketplace.install(plugin)
```

## Best Practices

1. **Minimal Impact**: Plugins should be lightweight
2. **Async Operations**: Use async/await for long operations
3. **Error Handling**: Gracefully handle all errors
4. **Documentation**: Provide clear documentation
5. **Testing**: Include comprehensive tests

## Example: Simple Language Plugin

```swift
import CodeEditorPlugin

@main
class JSONLanguagePlugin: LanguagePlugin {
    var identifier: String { "com.example.json-enhanced" }
    var displayName: String { "JSON Enhanced" }
    var fileExtensions: [String] { ["json", "jsonc"] }
    
    func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        
        // Simple JSON tokenizer
        let patterns: [(regex: Regex, type: TokenType)] = [
            (#/"[^"]*":\s*/#, .property),
            (#/:\s*"[^"]*"/#, .string),
            (#/:\s*\d+(\.\d+)?/#, .number),
            (#/:\s*(true|false)/#, .keyword),
            (#/[{}\[\],]/#, .operator)
        ]
        
        for (regex, type) in patterns {
            let matches = text.matches(of: regex)
            for match in matches {
                tokens.append(Token(
                    range: match.range,
                    type: type
                ))
            }
        }
        
        return tokens.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}
```

## See Also

- <doc:LSP-Integration>
- <doc:Architecture-Overview>
- <doc:Advanced-Patterns>