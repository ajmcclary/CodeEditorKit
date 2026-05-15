# SwiftUI Environment Keys

Learn about the custom environment keys provided by CodeEditorPlugin for advanced SwiftUI integration.

## Overview

CodeEditorPlugin provides a consolidated `CodeEditorEnvironment` value plus direct environment projections for common settings. The direct keys remain supported for compatibility and convenience; internally they read and write the consolidated environment value.

## Available Environment Keys

### `codeEditorEnvironment`

The consolidated environment value for editor language, theme, configuration, focus, memory monitoring, and event-system injection.

```swift
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .codeEditorEnvironment(
                    language: .swift,
                    theme: .dark,
                    configuration: .minimal,
                    becomeFirstResponder: .yes
                )
        }
    }
}
```

**Type**: `CodeEditorEnvironment`<br>
**Default**: `CodeEditorEnvironment.default`

> **Related Modifier**: Use `.codeEditorEnvironment(...)` when configuring several editor defaults together.

### `codeEditorConfiguration`

The configuration projection that controls all aspects of the editor's behavior and appearance.

```swift
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.codeEditorConfiguration, .minimal)
        }
    }
}
```

**Type**: `EditorConfiguration`  
**Default**: `EditorConfiguration()`

> **Related Modifier**: Use SwiftUI's `.environment(\.codeEditorConfiguration, ...)` directly, or the consolidated `.codeEditorEnvironment(...)` helper.

### `codeEditorLanguage`

Sets the programming language for syntax highlighting and code completion.

```swift
struct CodeView: View {
    var body: some View {
        VStack {
            CodeEditor(text: .constant(""))
            CodeEditor(text: .constant(""))
        }
        .environment(\.codeEditorLanguage, .swift)
    }
}
```

**Type**: `Language`  
**Default**: `.plainText`

> **Related Modifier**: Use `.codeLanguage(_:)` for setting the language on individual editors.

### `codeEditorTheme`

Controls the visual theme of the editor, including syntax highlighting colors.

```swift
struct ThemedEditor: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        CodeEditor(text: .constant(""))
            .environment(
                \.codeEditorTheme,
                colorScheme == .dark
                    ? Theme.bundled(family: "zed-trek", variant: "LCARS Dark") ?? .dark
                    : Theme.bundled(family: "zed-trek", variant: "LCARS Light") ?? .default
            )
    }
}
```

> The built-in `Theme.default`, `Theme.dark`, and `Theme.lcarsDark` all resolve to the bundled `"LCARS Dark"` variant of the `Zed Trek` family. For a light/dark split, load specific variants via `Theme.bundled(family:variant:)` as shown above, or define your own helpers.

**Type**: `Theme`  
**Default**: `.default` (resolves to `Theme.lcarsDark` → `"LCARS Dark"`)

> **Related Modifier**: Use `.codeTheme(_:)` for setting the theme on individual editors.

### `codeEditorMemoryMonitor`

Provides a custom memory monitor for resource management across multiple editors.

```swift
struct MultiEditorView: View {
    let sharedMonitor = MemoryMonitor()
    
    var body: some View {
        VStack {
            CodeEditor(text: .constant(""))
            CodeEditor(text: .constant(""))
        }
        .environment(\.codeEditorMemoryMonitor, sharedMonitor)
    }
}
```

**Type**: `MemoryMonitor?`  
**Default**: `nil` (each editor creates its own monitor)

> **Related Modifier**: Use `.memoryMonitor(_:)` for setting a custom memory monitor.

### `codeEditorBecomeFirstResponder`

Controls whether the editor should automatically become the first responder when it appears.

```swift
struct FocusedEditor: View {
    var body: some View {
        CodeEditor(text: .constant(""))
            .environment(\.codeEditorBecomeFirstResponder, true)
    }
}
```

**Type**: `Bool`  
**Default**: `false`

> **Related Modifier**: Use `.becomeFirstResponder()` or `.becomeFirstResponder(_:)` on the editor view.

### `codeEditorEventSystem`

Provides a custom event system for publishing and subscribing to editor events. Use this key to inject a custom instance for better testability and isolation.

```swift
struct MultiEditorView: View {
    let eventSystem = UnifiedEventSystem()
    
    var body: some View {
        VStack {
            CodeEditor(text: .constant(""))
            CodeEditor(text: .constant(""))
        }
        .environment(\.codeEditorEventSystem, eventSystem)
        .onAppear {
            // Subscribe to events from both editors
            eventSystem.subscribe(to: TextDidChangeEvent.self) { event in
                // Handle text change in one of the editors
            }
        }
    }
}
```

**Type**: `UnifiedEventSystem?`  
**Default**: `nil` (no shared system is injected unless you provide one)

> **Related Modifier**: Use `.eventSystem(_:)` for setting a custom event system on individual editors.

## Usage Patterns

### Hierarchical Configuration

Environment values cascade through the view hierarchy, allowing you to set defaults at a high level and override them for specific views:

```swift
struct ContentView: View {
    @State private var swiftCode = "print(\"Swift\")"
    @State private var pythonCode = "print(\"Python\")"
    
    var body: some View {
        VStack {
            // This editor inherits the Swift language from the environment
            CodeEditor(text: $swiftCode)
            
            // This editor overrides with Python
            CodeEditor(text: $pythonCode)
                .environment(\.codeEditorLanguage, .python)
        }
        .environment(\.codeEditorLanguage, .swift)
        .environment(\.codeEditorTheme, .dark)
    }
}
```

### Configuration Composition

Combine environment values with view modifiers for maximum flexibility:

```swift
struct EditorView: View {
    @State private var code = ""
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.javascript)  // View modifier takes precedence
            .environment(\.codeEditorTheme, .dark)  // Theme from environment
            .environment(\.codeEditorConfiguration, .minimal)  // Base configuration
    }
}
```

### Custom Environment Extensions

You can create your own view extensions that use these environment keys:

```swift
extension View {
    func applyEditorDefaults() -> some View {
        self
            .environment(\.codeEditorConfiguration, .default)
            .environment(\.codeEditorTheme, .default)
            .environment(\.codeEditorLanguage, .swift)
    }
}

// Usage
CodeEditor(text: $code)
    .applyEditorDefaults()
```

## Performance Considerations

- Environment values are efficiently propagated through the SwiftUI view tree
- Shared `MemoryMonitor` instances can reduce memory overhead when using multiple editors
- Configuration objects are value types and only trigger updates when actually changed

## See Also

- [Configuration system](../Configuration/system.md)
- [SwiftUI integration](integration.md)
