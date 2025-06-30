# Plugin System

The CodeEditorPlugin features a comprehensive plugin architecture for extending language support and editor capabilities.

## Current State

The plugin system is **fully functional** for built-in plugins. Dynamic plugin loading from external bundles is planned for a future release.

### Working Features

- ✅ **Plugin Registration**: Register built-in plugins via `PluginManager.shared.register()`
- ✅ **Language Detection**: Automatic language detection from file extensions
- ✅ **Feature Providers**: Support for completion, formatting, linting, and documentation
- ✅ **Indentation Providers**: Language-specific indentation rules
- ✅ **LSP Integration**: Language Server Protocol client support
- ✅ **Plugin Lifecycle**: Proper initialization and cleanup
- ✅ **Error Handling**: Comprehensive error reporting system

### Built-in Plugins

Currently, plugins must be compiled into the main project:

```swift
// Register a built-in plugin
let swiftPlugin = SwiftLanguagePlugin()
PluginManager.shared.register(swiftPlugin)

// Register TypeScript plugin with all features
let typeScriptPlugin = TypeScriptPlugin()
PluginManager.shared.register(typeScriptPlugin)
```

## Plugin Protocol

All language plugins must conform to the `LanguagePlugin` protocol:

```swift
public protocol LanguagePlugin: AnyObject, Sendable {
    var identifier: String { get }
    var displayName: String { get }
    var fileExtensions: [String] { get }
    var languageMode: String { get }
    
    // Feature provider factories
    func createHighlighter() -> (any SyntaxHighlighter)?
    func createCompletionProvider() -> (any CompletionProvider)?
    func createFormatter() -> (any CodeFormatter)?
    func createLinter() -> (any Linter)?
    func createIndentationProvider() -> (any IndentationProvider)?
    func createDocumentationProvider() -> (any DocumentationProvider)?
    func createSymbolProvider() -> (any SymbolProvider)?
    func createFoldingProvider() -> (any FoldingProvider)?
    func createLSPClient() -> (any LSPClientProtocol)?
}
```

## Feature Providers

### IndentationProvider

Handles language-specific indentation rules:

```swift
public protocol IndentationProvider: Sendable {
    func shouldIncreaseIndent(for line: String) -> Bool
    func shouldDecreaseIndent(for line: String) -> Bool
    func indentationLevel(for line: String, previous: String?) -> Int
}
```

### LSPClientProtocol

Integrates with Language Server Protocol servers:

```swift
public protocol LSPClientProtocol: AnyObject, Sendable {
    var serverPath: String { get }
    var serverArguments: [String] { get }
    
    func start() async throws
    func stop() async
    func sendRequest<T: Encodable>(_ method: String, params: T) async throws
    func sendNotification<T: Encodable>(_ method: String, params: T) async
}
```

## Future: Dynamic Plugin Loading

Dynamic plugin loading is planned for a future release. The implementation will support:

### Plugin Types

1. **Binary Plugins**
   - Compiled Swift frameworks
   - Loaded via Bundle APIs
   - Code signing verification required

2. **Script Plugins**
   - JavaScript via JavaScriptCore
   - Python via PythonKit
   - Sandboxed execution environment

3. **WebAssembly Plugins**
   - Cross-platform WASM modules
   - Runs in isolated sandbox
   - Language-agnostic plugin development

### Security Model

- **Code Signing**: Binary plugins must be signed
- **Sandboxing**: Script and WASM plugins run in isolated environments
- **Permissions**: Fine-grained API access control
- **Resource Limits**: CPU, memory, and I/O quotas

### Plugin Manifest

Plugins will include a `plugin.json` manifest:

```json
{
  "identifier": "com.example.rustplugin",
  "name": "Rust Language Support",
  "version": "1.0.0",
  "api_version": "1.0",
  "main": "RustPlugin.framework",
  "permissions": ["syntax", "completion", "lsp"],
  "file_extensions": ["rs", "toml"],
  "dependencies": {
    "rust-analyzer": "^1.0.0"
  }
}
```

## Example: TypeScript Plugin

See `TypeScriptPlugin.swift` for a complete example of a language plugin with:
- Syntax highlighting via regex patterns
- Custom indentation rules
- File extension associations
- Future LSP integration ready

## Plugin Development Guide

To create a new built-in plugin:

1. Create a class conforming to `LanguagePlugin`
2. Implement required properties
3. Provide feature providers as needed
4. Register with `PluginManager.shared.register()`

Example minimal plugin:

```swift
final class MyLanguagePlugin: LanguagePlugin {
    let identifier = "com.example.mylang"
    let displayName = "My Language"
    let fileExtensions = ["mylang", "ml"]
    let languageMode = "mylang"
    
    func createHighlighter() -> (any SyntaxHighlighter)? {
        return MyLanguageHighlighter()
    }
    
    // Return nil for features not supported
    func createCompletionProvider() -> (any CompletionProvider)? { nil }
    func createFormatter() -> (any CodeFormatter)? { nil }
    // ... other providers
}
```

## Testing Plugins

The plugin system includes comprehensive tests in `PluginManagerTests.swift`:
- Plugin registration and retrieval
- Feature provider management
- Error handling
- Thread safety
- Performance benchmarks

## Roadmap

### Phase 1 (Current)
- ✅ Built-in plugin system
- ✅ Core feature providers
- ✅ Plugin lifecycle management

### Phase 2 (Planned)
- 🔄 Dynamic binary plugin loading
- 🔄 Plugin marketplace integration
- 🔄 Hot reload support

### Phase 3 (Future)
- 📋 Script plugin support
- 📋 WebAssembly plugins
- 📋 Plugin development SDK