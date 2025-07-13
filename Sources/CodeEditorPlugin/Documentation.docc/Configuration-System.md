# Configuration System

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

Master CodeEditorPlugin's powerful and flexible configuration system.

## Overview

The EditorConfiguration system provides fine-grained control over every aspect of the editor through a clean, nested structure. Configuration changes apply instantly without recreating views.

## Quick Start with Builder Pattern

Use the fluent `EditorConfigurationBuilder` for easy configuration:

```swift
// Basic configuration
let config = EditorConfigurationBuilder()
    .fontSize(16)
    .showLineNumbers(true)
    .tabWidth(4)
    .theme(.dark)
    .language(.swift)
    .build()

// Start from presets
let config = EditorConfigurationBuilder(preset: .minimal)
    .fontSize(14)
    .enableSyntaxHighlighting(true)
    .build()
```

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

### Theme Integration

Apply themes to your configuration:

```swift
// Use built-in themes
config.display.theme = .xcode
config.display.theme = .vsDark
config.display.theme = .github
config.display.theme = .solarizedDark
config.display.theme = .minimal
config.display.theme = .presentation

// Themes automatically configure colors for:
// - Background and text
// - Syntax highlighting (keywords, strings, comments)
// - UI elements (selection, gutter, line numbers)
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

Save and load configurations as JSON:

```swift
// Export configuration to JSON string
if let jsonString = appState.exportConfigurationAsJSON() {
    // Save to file or share
    try jsonString.write(to: url, atomically: true, encoding: .utf8)
}

// Import configuration from JSON string
let jsonString = try String(contentsOf: url, encoding: .utf8)
if appState.importConfiguration(from: jsonString) {
    print("Configuration imported successfully")
} else {
    print("Invalid configuration format")
}

// Copy to clipboard (cross-platform)
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
NSPasteboard.general.setString(jsonString, forType: .string)
#else
UIPasteboard.general.string = jsonString
#endif
```

### Configuration Management

The sample app demonstrates comprehensive configuration management:

```swift
// Search and filter configuration options
struct UnifiedConfigurationView: View {
    @State private var searchText = ""
    
    // Searchable sections with keywords
    private var filteredSections: [SearchableSection] {
        // Implementation filters by keywords like:
        // "theme", "color", "font", "layout", "behavior"
    }
}

// Platform-specific import/export
// macOS: Uses NSOpenPanel/NSSavePanel
// iOS: Uses share sheet and clipboard
func shareConfiguration() {
    #if canImport(UIKit)
    let activityVC = UIActivityViewController(activityItems: [json], applicationActivities: nil)
    // Present share sheet
    #else
    // Copy to clipboard on macOS
    #endif
}
```

## Direct Binding Pattern (Recommended)

For SwiftUI applications, use direct property binding instead of the deprecated ConfigurationBindingBuilder:

```swift
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Display") {
                // ✅ Direct binding - no Sendable warnings
                Toggle("Show Line Numbers", 
                       isOn: $appState.currentConfiguration.display.isLineNumbersEnabled)
                
                Slider(value: $appState.currentConfiguration.display.fontSize,
                       in: 10...30,
                       step: 1) {
                    Text("Font Size: \(appState.currentConfiguration.display.fontSize, specifier: "%.0f")")
                }
            }
            
            Section("Layout") {
                Stepper("Tab Width: \(appState.currentConfiguration.layout.tabWidth)",
                        value: $appState.currentConfiguration.layout.tabWidth,
                        in: 1...8)
                
                Toggle("Wrap Lines",
                       isOn: $appState.currentConfiguration.layout.wrapLines)
            }
            
            Section("Behavior") {
                Toggle("Auto Indent",
                       isOn: $appState.currentConfiguration.behavior.autoIndent)
                
                Toggle("Code Completion",
                       isOn: $appState.currentConfiguration.behavior.enableCodeCompletion)
            }
        }
    }
}
```

**Why Direct Binding?**
- Works seamlessly with Swift 6 concurrency
- No complex binding builders needed
- Natural SwiftUI patterns
- Better performance
- Type-safe property access

## Best Practices

1. **Start with Presets**: Use built-in presets as a starting point
2. **Group Related Changes**: Update related settings together
3. **Use Environment**: Leverage SwiftUI's environment for clean propagation
4. **Test Configurations**: Verify settings work across all platforms
5. **Document Custom Configs**: Explain specialized configurations
6. **Prefer Direct Binding**: Use direct property binding in SwiftUI for better concurrency support

## See Also

- <doc:Configuration-Presets>
- <doc:Theme-System>
- <doc:SwiftUI-Integration>