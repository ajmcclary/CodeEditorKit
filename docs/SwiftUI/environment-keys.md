# SwiftUI Environment Keys

Learn about the custom environment keys provided by CodeEditorPlugin for advanced SwiftUI integration.

## Overview

CodeEditorPlugin provides several custom environment keys that allow you to configure code editors throughout your SwiftUI view hierarchy. These keys enable powerful composition patterns and make it easy to apply consistent settings across multiple editors.

## Available Environment Keys

### `codeEditorConfiguration`

The main configuration key that controls all aspects of the editor's behavior and appearance.

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
**Default**: `EditorConfiguration.default`

> **Related Modifier**: Use the `CodeEditor/environment(_:_:)` method directly on the view for convenience.

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

> **Related Modifier**: Use `CodeEditor/codeLanguage(_:)` for setting the language on individual editors.

### `codeEditorTheme`

Controls the visual theme of the editor, including syntax highlighting colors.

```swift
struct ThemedEditor: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        CodeEditor(text: .constant(""))
            .environment(\.codeEditorTheme, colorScheme == .dark ? .dark : .light)
    }
}
```

**Type**: `Theme`  
**Default**: `.default`

> **Related Modifier**: Use `CodeEditor/codeTheme(_:)` for setting the theme on individual editors.

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

> **Related Modifier**: Use `CodeEditor/memoryMonitor(_:)` for setting a custom memory monitor.

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

> **Related Modifier**: Use `CodeEditor/focused(_:)` for more advanced focus management with FocusState.

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
            eventSystem.subscribe(to: TextChangeEvent.self) { event in
                // Handle text change in one of the editors
            }
        }
    }
}
```

**Type**: `UnifiedEventSystem?`  
**Default**: `nil` (creates a new instance)

> **Related Modifier**: Use `CodeEditor/eventSystem(_:)` for setting a custom event system on individual editors.

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
            .environment(\.codeEditorTheme, .light)
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

- [Configuration-System](../Configuration/system.md)
- [SwiftUI-Integration](integration.md)