# SwiftUI Integration

@Metadata {
    @PageColor(blue)
}

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
                configuration.display.showLineNumbers = true
                configuration.display.theme = .xcodeDark
            }
    }
}
```

### Configuration Interface

The sample app provides a comprehensive configuration interface:

```swift
struct UnifiedConfigurationView: View {
    @EnvironmentObject var appState: AppState
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
    @EnvironmentObject var appState: AppState
    @State private var selectedTheme: ColorTheme = .xcode
    
    var body: some View {
        VStack {
            ForEach(ColorTheme.allCases, id: \.self) { theme in
                ThemeRow(theme: theme, isSelected: selectedTheme == theme) {
                    selectedTheme = theme
                    applyTheme(theme)
                }
            }
            
            // Live preview of theme
            ThemePreview(theme: selectedTheme)
                .frame(height: 120)
        }
    }
}
```

## Modifiers

### Language Setting

Set the programming language for syntax highlighting:

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    // or
    .codeLanguage(.python)
    // or detect from filename
    .codeLanguage(from: "main.rs")  // Detects Rust
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
class EditorState: ObservableObject {
    @Published var code = ""
    @Published var configuration = EditorConfiguration()
    @Published var language: Language = .swift
    
    func loadFile(from url: URL) {
        code = try String(contentsOf: url)
        language = Language.detect(from: url.pathExtension)
    }
}

struct EditorView: View {
    @StateObject private var state = EditorState()
    
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
#if os(macOS)
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .focusable()  // Enable keyboard focus
    .onCommand(#selector(NSText.selectAll(_:))) {
        // Handle Select All
    }
#endif
```

## Environment Keys Reference

CodeEditorPlugin provides several environment keys for configuration and state management:

### Available Environment Keys

#### `\.codeEditorConfiguration`
- **Type**: `EditorConfiguration`
- **Default**: `EditorConfiguration()`
- **Usage**: Sets the complete editor configuration
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorConfiguration, .presentation)
```

#### `\.codeEditorLanguage`
- **Type**: `Language`
- **Default**: `.swift`
- **Usage**: Sets the programming language for syntax highlighting
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorLanguage, .python)
```

#### `\.codeEditorTheme`
- **Type**: `CodeEditorSwiftUITheme`
- **Default**: `.default`
- **Usage**: Sets the color theme
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorTheme, .dark)
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
3. **Consistent Updates**: Use helper methods like `appState.updateConfiguration()` for consistent state management
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
private struct EditorThemeKey: EnvironmentKey {
    static let defaultValue = Theme.xcode
}

extension EnvironmentValues {
    var editorTheme: Theme {
        get { self[EditorThemeKey.self] }
        set { self[EditorThemeKey.self] = newValue }
    }
}
```

## See Also

- <doc:Configuration-System>
- <doc:Theme-System>
- <doc:UIKit-AppKit-Integration>