# SwiftUI Integration

Integrate CodeEditorPlugin seamlessly into your SwiftUI applications.

## Overview

CodeEditorPlugin provides first-class SwiftUI support with a modern, declarative API that feels right at home in your SwiftUI apps. Configuration is handled through the environment, and all SwiftUI patterns work as expected.

## Basic Integration

The simplest way to add a code editor:

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "print(\"Hello, World!\")"
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
    }
}
```

## Configuration

### Using Direct Configuration

Create configurations by mutating the nested `EditorConfiguration` value:

```swift
struct MyEditor: View {
    @State private var code = ""
    @State private var configuration = {
        var config = EditorConfiguration()
        config.display.fontSize = 16
        config.display.isLineNumbersEnabled = true
        config.display.isSyntaxHighlightingEnabled = true
        return config
    }()
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .codeTheme(.dark)
            .environment(\.codeEditorConfiguration, configuration)
    }
}
```

### Using Presets

Start from intelligent presets:

```swift
// Minimal editor for simple use cases
var minimalConfig = EditorConfiguration.minimal
minimalConfig.display.fontSize = 14

// Read-only editor for code display
var readOnlyConfig = EditorConfiguration.readOnly

// Platform-optimized configuration
var platformConfig = EditorConfiguration.platformOptimized
platformConfig.behavior.isCodeCompletionEnabled = true
```

### Using Environment

Apply configuration through SwiftUI's environment:

```swift
struct MyEditor: View {
    @State private var code = ""
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .environment(\.codeEditorConfiguration, configuration)
            .onAppear {
                configuration.display.isLineNumbersEnabled = true
            }
    }
}
```

### Using Consolidated Environment (Recommended)

For better ergonomics, use the consolidated environment configuration:

```swift
struct MyEditor: View {
    @State private var code = ""
    
    var body: some View {
        CodeEditor(text: $code)
            .codeEditorEnvironment(
                language: .swift,
                theme: .dark,
                configuration: EditorConfiguration.default,
                becomeFirstResponder: .yes
            )
    }
}
```

Or create a complete environment configuration:

```swift
struct MyEditor: View {
    @State private var code = ""
    
    var body: some View {
        let configuration = {
            var config = EditorConfiguration.default
            config.display.fontSize = 16
            config.display.isLineNumbersEnabled = true
            return config
        }()

        let environment = CodeEditorEnvironment(
            language: .swift,
            theme: .dark,
            configuration: configuration,
            becomeFirstResponder: true,
            memoryMonitor: MemoryMonitor(),
            eventSystem: UnifiedEventSystem()
        )
        
        CodeEditor(text: $code)
            .codeEditorEnvironment(environment)
    }
}
```

### Configuration Interface

A settings view can bind directly into the nested configuration value:

```swift
final class EditorSettings: ObservableObject {
    @Published var configuration = EditorConfiguration.default
}

struct SearchableSettingsView: View {
    @EnvironmentObject var settings: EditorSettings
    @State private var searchText = ""
    
    var body: some View {
        ScrollView {
            VStack {
                // Search bar for filtering options
                TextField("Search settings...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Configuration sections
                ForEach(filteredSections, id: \.id) { section in
                    ConfigurationSection(title: section.title) {
                        section.content()
                    }
                }
            }
        }
    }
}

// Theme selection with preview
struct ThemeConfigurationSection: View {
    @State private var selectedTheme = Theme.lcarsDark
    private let themes = ThemeFamily.bundled("zed-trek")?.themes ?? [.lcarsDark]
    
    var body: some View {
        VStack {
            ForEach(themes, id: \.id) { theme in
                ThemeRow(theme: theme, isSelected: selectedTheme == theme) {
                    selectedTheme = theme
                }
            }
            
            // Live preview of theme
            ThemePreview(theme: selectedTheme)
                .frame(height: 120)
        }
    }
}
```

### Direct Binding Pattern (Recommended)

The recommended approach for configuration in SwiftUI is to use direct property binding, which provides better Swift 6 concurrency support:

```swift
struct ConfigurationView: View {
    @EnvironmentObject var settings: EditorSettings
    @Binding var selectedTheme: Theme
    
    var body: some View {
        Form {
            Toggle("Show Line Numbers",
                   isOn: $settings.configuration.display.isLineNumbersEnabled)
            
            Slider(value: $settings.configuration.display.fontSize,
                   in: 10...20,
                   step: 1) {
                Text("Font Size")
            }
            
            Picker("Theme", selection: $selectedTheme) {
                ForEach(ThemeFamily.bundled("zed-trek")?.themes ?? [.lcarsDark], id: \.id) { theme in
                    Text(theme.name).tag(theme)
                }
            }
        }
    }
}

// For batch updates
Button("Apply Preset") {
    var config = EditorConfiguration.default
    config.display.fontSize = 16
    config.layout.tabWidth = 4
    settings.configuration = config
}
```

**Benefits of Direct Binding:**
- **Zero Sendable warnings**: Works seamlessly with Swift 6 concurrency
- **Type safety**: Compiler-verified property access
- **Performance**: No additional binding overhead
- **Simplicity**: Clear, readable code
- **SwiftUI integration**: Natural SwiftUI patterns

## Modifiers

### Language Setting

Set the programming language for syntax highlighting:

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    // or
    .codeLanguage(.python)
    // or detect from filename
    .codeLanguage(Language(fileExtension: "rs") ?? .plainText)
```

### Frame and Layout

Standard SwiftUI modifiers work as expected:

```swift
CodeEditor(text: $code)
    .frame(minHeight: 400, maxHeight: .infinity)
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
```

## State Management

### Using ObservableObject

For complex state management:

```swift
final class DocumentEditorModel: ObservableObject {
    @Published var code = ""
    @Published var configuration = EditorConfiguration()
    @Published var language: Language = .swift
    
    func loadFile(from url: URL) {
        code = (try? String(contentsOf: url)) ?? ""
        language = Language(fileExtension: url.pathExtension) ?? .plainText
    }
}

struct EditorView: View {
    @StateObject private var state = DocumentEditorModel()
    
    var body: some View {
        CodeEditor(text: $state.code)
            .codeLanguage(state.language)
            .environment(\.codeEditorConfiguration, state.configuration)
    }
}
```

### Binding to External State

Connect to your app's data model:

```swift
struct DocumentEditor: View {
    @Binding var document: TextDocument
    
    var body: some View {
        CodeEditor(text: $document.content)
            .codeLanguage(document.language)
            .onChange(of: document.content) { _ in
                document.lastModified = Date()
                document.save()
            }
    }
}
```

## Platform-Specific Features

### iOS Keyboard Handling

The editor automatically handles keyboard appearance:

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    // Keyboard handling is automatic on iOS
```

### macOS Window Integration

Take advantage of macOS features:

```swift
#if canImport(AppKit)
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .focusable()  // Enable keyboard focus
#endif
```

## Environment Keys Reference

CodeEditorPlugin provides a consolidated environment value plus direct projections for common settings. Use the consolidated value when setting several defaults at once, and use direct keys or modifiers for targeted overrides.

### Available Environment Keys

#### `\.codeEditorEnvironment`
- **Type**: `CodeEditorEnvironment`
- **Default**: `CodeEditorEnvironment.default`
- **Usage**: Sets language, theme, configuration, focus, memory monitor, and event system together
```swift
CodeEditor(text: $code)
    .codeEditorEnvironment(
        language: .swift,
        theme: .dark,
        configuration: .minimal,
        becomeFirstResponder: .yes
    )
```

#### `\.codeEditorConfiguration`
- **Type**: `EditorConfiguration`
- **Default**: `EditorConfiguration()`
- **Usage**: Sets the editor configuration projection
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorConfiguration, .presentation)
```

#### `\.codeEditorLanguage`
- **Type**: `Language`
- **Default**: `.plainText`
- **Usage**: Sets the programming language for syntax highlighting
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorLanguage, .python)
```

#### `\.codeEditorTheme`
- **Type**: `Theme`
- **Default**: `.default`
- **Usage**: Sets the color theme
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorTheme, .dark)

// Prefer the convenience modifier for individual editors:
CodeEditor(text: $code)
    .codeTheme(.dark)
```

#### `\.codeEditorBecomeFirstResponder`
- **Type**: `Bool`
- **Default**: `false`
- **Usage**: Requests focus when set to true
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorBecomeFirstResponder, true)
// Or use the convenience modifier:
CodeEditor(text: $code)
    .becomeFirstResponder()
```

#### `\.codeEditorMemoryMonitor`
- **Type**: `MemoryMonitor?`
- **Default**: `nil`
- **Usage**: Shares a memory monitor across editors
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorMemoryMonitor, sharedMonitor)
```

#### `\.codeEditorEventSystem`
- **Type**: `UnifiedEventSystem?`
- **Default**: `nil`
- **Usage**: Shares an event system across editors
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorEventSystem, sharedEventSystem)
```

### Using Environment Keys

Environment keys can be set at any level in the view hierarchy and will propagate to all child views:

```swift
struct ContentView: View {
    @State private var code = ""
    
    var body: some View {
        VStack {
            // Configuration applies to all child CodeEditor views
            CodeEditor(text: $code)
            CodeEditor(text: $code)
        }
        .environment(\.codeEditorConfiguration, .minimal)
        .environment(\.codeEditorLanguage, .javascript)
    }
}
```

### Reading Environment Values

You can read environment values in your custom views:

```swift
struct CustomEditorWrapper: View {
    @Environment(\.codeEditorConfiguration) var config
    @Environment(\.codeEditorLanguage) var language
    @Environment(\.codeEditorTheme) var theme
    
    var body: some View {
        Text("Current language: \(language.rawValue)")
    }
}
```

## Best Practices

1. **Use @State Wisely**: Keep code text in @State for responsiveness
2. **Environment Configuration**: Always use environment for configuration
3. **Consistent Updates**: Centralize preset changes and validation in your own app model
4. **Search and Discovery**: Implement searchable configuration interfaces with keywords
5. **Input Validation**: Use bounds checking for numeric inputs (e.g., `.clamped(to: 1...8)`)
6. **Platform-Specific UI**: Adapt interface elements to each platform's conventions
7. **Lazy Loading**: For large files, load content asynchronously
8. **Memory Management**: Use weak references in closures
9. **Platform Testing**: Test on all target platforms

## Advanced Patterns

### Multiple Editors

Manage multiple editors with different configurations:

```swift
struct SplitEditor: View {
    @State private var leftCode = ""
    @State private var rightCode = ""
    @State private var leftConfig = EditorConfiguration.default
    @State private var rightConfig = EditorConfiguration.minimal
    
    var body: some View {
        HSplitView {
            CodeEditor(text: $leftCode)
                .environment(\.codeEditorConfiguration, leftConfig)
            
            CodeEditor(text: $rightCode)
                .environment(\.codeEditorConfiguration, rightConfig)
        }
    }
}
```

### Custom Environment Values

Extend the environment for your needs:

```swift
private struct CustomThemeKey: EnvironmentKey {
    static let defaultValue = Theme.lcarsDark
}

extension EnvironmentValues {
    var editorTheme: Theme {
        get { self[CustomThemeKey.self] }
        set { self[CustomThemeKey.self] = newValue }
    }
}
```

## See Also

- [Configuration system](../Configuration/system.md)
- [Theme system](../Features/theme-system.md)
- [UIKit and AppKit integration](../Platform/uikit-appkit.md)
