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

### Configuration Toolbar

Create a toolbar to control editor settings:

```swift
struct EditorWithToolbar: View {
    @State private var code = ""
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        VStack {
            // Toolbar
            HStack {
                Toggle("Line Numbers", isOn: $configuration.display.showLineNumbers)
                Toggle("Minimap", isOn: $configuration.display.showMinimap)
                
                Picker("Theme", selection: $configuration.display.theme) {
                    Text("Xcode").tag(Theme.xcode)
                    Text("VS Dark").tag(Theme.vsDark)
                    Text("GitHub").tag(Theme.github)
                }
            }
            .padding()
            
            // Editor
            CodeEditor(text: $code)
                .codeLanguage(.swift)
                .environment(\.codeEditorConfiguration, configuration)
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

## Best Practices

1. **Use @State Wisely**: Keep code text in @State for responsiveness
2. **Environment Configuration**: Always use environment for configuration
3. **Lazy Loading**: For large files, load content asynchronously
4. **Memory Management**: Use weak references in closures
5. **Platform Testing**: Test on all target platforms

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