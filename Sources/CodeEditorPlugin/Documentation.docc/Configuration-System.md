# Configuration System

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

Master CodeEditorPlugin's powerful and flexible configuration system.

## Overview

The EditorConfiguration system provides fine-grained control over every aspect of the editor through a clean, nested structure. Configuration changes apply instantly without recreating views.

## Configuration Structure

EditorConfiguration is organized into four logical groups:

### Display Settings

Controls visual appearance:

```swift
config.display.showLineNumbers = true
config.display.highlightSelectedLine = true
config.display.fontSize = 14.0
config.display.fontName = "SF Mono"
config.display.enableAnnotations = true
config.display.showMinimap = false
config.display.showInvisibleCharacters = false
```

### Layout Settings

Controls spacing and dimensions:

```swift
config.layout.tabWidth = 4
config.layout.insertSpacesForTabs = true
config.layout.lineSpacing = 1.2
config.layout.wrapLines = false
config.layout.gutterWidth = 50
config.layout.editorInsets = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
```

### Behavior Settings

Controls editing behavior:

```swift
config.behavior.isEditable = true
config.behavior.autoIndent = true
config.behavior.enableCodeCompletion = true
config.behavior.enableBraceMatching = true
config.behavior.autoCloseBrackets = true
config.behavior.enableSpellChecking = false
```

### Performance Settings

Controls optimization features:

```swift
config.performance.useHardwareAcceleration = true
config.performance.maxSyntaxHighlightingLength = 500_000
config.performance.enableViewportRendering = true
config.performance.smoothScrolling = true
config.performance.debounceDelay = 100 // milliseconds
```

## Using Configuration

### SwiftUI Integration

Apply configuration through the environment:

```swift
struct MyEditor: View {
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration, configuration)
            .onAppear {
                configuration.display.showLineNumbers = true
                configuration.display.theme = .xcodeDark
            }
    }
}
```

### UIKit/AppKit Integration

Apply configuration directly:

```swift
let editor = CodeEditorView()
let config = EditorConfiguration()

config.display.showLineNumbers = true
config.layout.tabWidth = 2
config.apply(to: editor)
```

## Builder Pattern

The EditorConfigurationBuilder provides a fluent API for configuration:

```swift
// Language-specific presets
let swiftConfig = EditorConfigurationBuilder.swift()
let webConfig = EditorConfigurationBuilder.web()
let markdownConfig = EditorConfigurationBuilder.markdown()

// Custom configuration with chaining
let customConfig = EditorConfigurationBuilder()
    .fontSize(16)
    .theme(.dark)
    .language(.python)
    .tabWidth(4)
    .enableCodeCompletion(true)
    .wrapLines(false)
    .showLineNumbers(true)
    .enableAnnotations(true)
    .build()
```

### Builder Methods

```swift
// Display settings
.fontSize(_ size: CGFloat)
.fontName(_ name: String)
.theme(_ theme: Theme)
.showLineNumbers(_ show: Bool)
.highlightSelectedLine(_ highlight: Bool)
.enableAnnotations(_ enable: Bool)

// Layout settings  
.tabWidth(_ width: Int)
.insertSpacesForTabs(_ insert: Bool)
.wrapLines(_ wrap: Bool)
.lineSpacing(_ spacing: CGFloat)

// Behavior settings
.language(_ language: Language)
.enableCodeCompletion(_ enable: Bool)
.autoIndent(_ enable: Bool)
.editable(_ editable: Bool)

// Performance settings
.enableHardwareAcceleration(_ enable: Bool)
.maxFileSize(_ size: Int)
```

## Configuration Presets

Use built-in presets for common scenarios:

```swift
// Full-featured development
let devConfig = EditorConfiguration.default

// Minimal, distraction-free
let minimalConfig = EditorConfiguration.minimal

// Read-only viewing
let viewerConfig = EditorConfiguration.readOnly

// Markdown editing
let markdownConfig = EditorConfiguration.markdown

// Large font for presentations
let demoConfig = EditorConfiguration.presentation
```

## Builder Pattern

Create configurations using the builder pattern:

```swift
let config = EditorConfigurationBuilder()
    .preset(.default)  // Start from a preset
    .showLineNumbers(true)
    .fontSize(16)
    .tabWidth(2)
    .theme(.githubLight)
    .build()
```

## Immutable Updates

Use the `.with()` method for immutable updates:

```swift
let newConfig = existingConfig.with { config in
    config.display.fontSize = 18
    config.layout.tabWidth = 2
}
```

## Live Configuration Updates

Changes apply immediately without view recreation:

```swift
// This updates the editor instantly
configuration.display.theme = .vsDark
configuration.display.showLineNumbers.toggle()
```

## Custom Configuration

Create your own configuration presets:

```swift
extension EditorConfiguration {
    static var myCustomPreset: EditorConfiguration {
        var config = EditorConfiguration()
        config.display.fontSize = 13
        config.display.fontName = "JetBrains Mono"
        config.layout.tabWidth = 3
        config.behavior.autoIndent = true
        return config
    }
}
```

## Import/Export

Save and load configurations:

```swift
// Export to JSON
let jsonData = try configuration.toJSON()

// Import from JSON
let imported = try EditorConfiguration.from(json: jsonData)
```

## Best Practices

1. **Start with Presets**: Use built-in presets as a starting point
2. **Group Related Changes**: Update related settings together
3. **Use Environment**: Leverage SwiftUI's environment for clean propagation
4. **Test Configurations**: Verify settings work across all platforms
5. **Document Custom Configs**: Explain specialized configurations

## See Also

- <doc:Configuration-Presets>
- <doc:Theme-System>
- <doc:SwiftUI-Integration>