# Plugin System Guide

Learn how to create and use plugins to extend CodeEditorPlugin functionality.

## Overview

The CodeEditorPlugin framework now includes a stable plugin architecture that allows third-party developers to extend the editor with new languages, features, and integrations. This guide covers the plugin system implementation and how to create your own plugins.

## Architecture

The plugin system consists of several key components:

- **Plugin Protocol**: Core contract that all plugins must implement
- **Plugin Manager**: Manages plugin lifecycle and registration
- **Plugin Context**: Provides controlled access to editor APIs
- **Plugin Loader**: Discovers and loads plugins from designated directories
- **Permission System**: Controls what APIs plugins can access

## Creating a Plugin

### Basic Plugin Structure

```swift
import CodeEditorPlugin

@available(macOS 13.0, iOS 16.0, *)
public final class MyAwesomePlugin: Plugin {
    public static let identifier = "com.example.myawesomeplugin"
    
    public var metadata: PluginMetadata {
        PluginMetadata(
            identifier: Self.identifier,
            name: "My Awesome Plugin",
            version: "1.0.0",
            author: "Your Name",
            description: "Adds awesome features to the code editor",
            capabilities: [.syntaxHighlighting, .codeCompletion],
            minimumHostVersion: "1.0.0",
            platforms: [.macOS, .iOS, .catalyst]
        )
    }
    
    public init() {}
    
    public func activate(context: PluginContext) async throws {
        // Register your providers and handlers
        logger.info("Plugin activated!")
    }
    
    public func deactivate(context: PluginContext) async throws {
        // Clean up resources
        logger.info("Plugin deactivated!")
    }
}
```

### Plugin Manifest

Each plugin bundle must include a `plugin.json` manifest:

```json
{
  "identifier": "com.example.myawesomeplugin",
  "name": "My Awesome Plugin",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Adds awesome features to the code editor",
  "mainClass": "MyAwesomePlugin",
  "capabilities": ["syntaxHighlighting", "codeCompletion"],
  "minimumHostVersion": "1.0.0",
  "platforms": ["macOS", "iOS", "catalyst"],
  "permissions": ["languages", "completion"],
  "dependencies": [
    {
      "identifier": "com.example.dependency",
      "minimumVersion": "1.0.0",
      "optional": false
    }
  ]
}
```

## Plugin Capabilities

Plugins can provide various capabilities:

### Syntax Highlighting

```swift
public func activate(context: PluginContext) async throws {
    let highlighter = MyLanguageHighlighter()
    try await context.languageRegistry.register(highlighter, for: .custom("mylang"))
}
```

### Code Completion

```swift
public func activate(context: PluginContext) async throws {
    let provider = MyCompletionProvider()
    await context.completionRegistry.register(provider, for: .custom("mylang"))
}
```

### Custom Commands

```swift
public func activate(context: PluginContext) async throws {
    let command = PluginCommand(
        identifier: "myplugin.format",
        title: "Format Code",
        keyboardShortcut: KeyboardShortcut(key: "f", modifiers: [.command, .shift])
    )
    
    try await context.registerCommand(command) {
        // Format the code
    }
}
```

## Plugin Permissions

Plugins must declare the permissions they need:

- **languages**: Access to language registry
- **completion**: Access to completion providers  
- **commands**: Register custom commands
- **themes**: Register custom themes
- **fileSystem**: Access sandboxed file system
- **network**: Network access (for language servers)
- **configuration**: Read editor configuration
- **diagnostics**: Provide error diagnostics

## Plugin Distribution

### Bundle Structure

```
MyPlugin.codeeditorplugin/
├── plugin.json          # Plugin manifest
├── Resources/           # Plugin resources
│   ├── icon.png
│   └── themes/
└── Code/               # Compiled plugin code
    └── MyPlugin.framework
```

### Installation Locations

Plugins are loaded from these directories in order:

1. User Plugins: `~/Library/Application Support/CodeEditorPlugin/Plugins/`
2. App Bundle: `YourApp.app/Contents/PlugIns/`
3. Framework Bundle: Built-in plugins

### Code Signing

Release builds require plugins to be properly code signed:

```bash
codesign --sign "Developer ID" --timestamp MyPlugin.codeeditorplugin
```

## Best Practices

### Performance

- Use async/await for long-running operations
- Implement proper cancellation support
- Cache expensive computations
- Clean up resources in `deactivate()`

### Error Handling

```swift
public func activate(context: PluginContext) async throws {
    do {
        try await performSetup()
    } catch {
        context.logger.error("Setup failed: \(error)")
        throw PluginError.activationFailed(reason: error.localizedDescription)
    }
}
```

### State Persistence

```swift
public func saveState() async -> [String: Any] {
    return [
        "userPreferences": preferences,
        "cache": cacheData
    ]
}

public func restoreState(_ state: [String: Any]) async {
    if let prefs = state["userPreferences"] as? [String: Any] {
        preferences = prefs
    }
}
```

## Security

The plugin system implements several security measures:

1. **Sandboxing**: Plugins run with limited file system access
2. **Permission System**: Plugins must declare required permissions
3. **Code Signing**: Release builds require signed plugins
4. **API Access Control**: Plugin context provides controlled API access

## Migration from Internal APIs

If you're migrating from internal registry patterns:

```swift
// Old approach (internal)
LanguageRegistry.shared.register(provider, for: .python)

// New approach (plugin)
public func activate(context: PluginContext) async throws {
    try await context.languageRegistry.register(provider, for: .python)
}
```

## Debugging Plugins

### Development Mode

During development, you can disable plugin signing:

```swift
// In your app's initialization
#if DEBUG
PluginLoader.requiresCodeSigning = false
#endif
```

### Logging

Use the provided logger for debugging:

```swift
context.logger.debug("Processing file: \(filename)")
context.logger.error("Failed to parse: \(error)")
```


## Example: Language Support Plugin

Here's a complete example of adding support for a new language:

```swift
import CodeEditorPlugin

@available(macOS 13.0, iOS 16.0, *)
public final class RustLanguagePlugin: Plugin {
    public static let identifier = "com.example.rust-language"
    
    public var metadata: PluginMetadata {
        PluginMetadata(
            identifier: Self.identifier,
            name: "Rust Language Support",
            version: "1.0.0",
            author: "Example Corp",
            description: "Adds Rust language support with syntax highlighting and completion",
            capabilities: [.syntaxHighlighting, .codeCompletion, .languageServer],
            minimumHostVersion: "1.0.0"
        )
    }
    
    private var lspClient: LSPClient?
    
    public init() {}
    
    public func activate(context: PluginContext) async throws {
        // Register syntax highlighter
        let highlighter = RustSyntaxHighlighter()
        try await context.languageRegistry.register(highlighter, for: .rust)
        
        // Register completion provider
        let completionProvider = RustCompletionProvider()
        await context.completionRegistry.register(completionProvider, for: .rust)
        
        // Start language server if permitted
        if context.hasPermission(.network) {
            lspClient = try await startLanguageServer(context)
        }
        
        context.logger.info("Rust language support activated")
    }
    
    public func deactivate(context: PluginContext) async throws {
        // Stop language server
        await lspClient?.shutdown()
        
        // Unregister providers
        await context.languageRegistry.unregister(for: .rust)
        await context.completionRegistry.unregister(for: .rust)
    }
    
    private func startLanguageServer(_ context: PluginContext) async throws -> LSPClient {
        let config = LocalLSPConfiguration(
            serverPath: "/usr/local/bin/rust-analyzer",
            arguments: [],
            environment: [:]
        )
        
        let client = LSPClient(configuration: config)
        try await client.start()
        return client
    }
}
```

## Future Enhancements

The plugin system is designed to be extensible. Planned enhancements include:

- **Plugin Marketplace**: Discover and install plugins
- **Hot Reload**: Reload plugins without restarting
- **Plugin Debugging**: Enhanced debugging tools
- **Cross-Plugin Communication**: Allow plugins to interact
- **Resource Limits**: CPU and memory limits for plugins

## See Also

- <doc:Plugin-Architecture>
- <doc:Creating-a-Plugin>
- <doc:Security>