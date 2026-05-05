# ``CodeEditorPlugin/ConfigurationHotReload``

@Metadata {
    @PageColor(blue)
}

Enables hot reloading of editor configuration without recreating views, providing smooth runtime updates with history and validation.

## Overview

`ConfigurationHotReload` provides a reactive configuration system that allows you to update editor settings at runtime without recreating views. It features configuration history for undo/redo, validation rules, observer patterns, and pending change management. This makes it ideal for preferences windows, live customization, and dynamic configuration updates.

## Key Features

- **Live Updates**: Changes apply immediately without view recreation
- **History Management**: Full undo/redo support for configuration changes
- **Validation**: Built-in and custom validation rules
- **Observer Pattern**: React to configuration changes
- **Batch Updates**: Group multiple changes together
- **Pending Changes**: Stage changes before applying

## Basic Usage

### Creating a Hot Reload Instance

```swift
// Create with default configuration
let hotReload = ConfigurationHotReload()

// Create with custom configuration
let customConfig = EditorConfiguration.minimal
let hotReload = ConfigurationHotReload(configuration: customConfig)
```

### Updating Configuration

```swift
// Direct update
var newConfig = hotReload.configuration
newConfig.display.isLineNumbersEnabled = true
newConfig.display.fontSize = 16
hotReload.update(newConfig)

// Update specific properties
hotReload.updateProperties(
    ConfigurationUpdates(
        display: EditorConfiguration.Display(
            isLineNumbersEnabled: true,
            fontSize: 16
        )
    )
)

// Batch updates
hotReload.batchUpdate { config in
    config.display.isLineNumbersEnabled = true
    config.layout.tabWidth = 2
    config.behavior.autoIndent = true
}
```

## History Management

ConfigurationHotReload maintains a history of configuration changes:

```swift
// Make some changes
hotReload.batchUpdate { config in
    config.display.fontSize = 14
}

hotReload.batchUpdate { config in
    config.display.fontSize = 16
}

// Undo last change
if hotReload.canUndo {
    hotReload.undo() // fontSize back to 14
}

// Redo
if hotReload.canRedo {
    hotReload.redo() // fontSize back to 16
}

// Clear history
hotReload.clearHistory()
```

## Configuration Observers

React to configuration changes using observers:

```swift
// Define an observer
struct MyConfigObserver: ConfigurationObserver {
    func configurationDidChange(_ event: ConfigurationEvent) {
        switch event {
        case .configurationChanged(let old, let new, let changes):
            print("Configuration changed from \(old) to \(new)")
            for change in changes {
                print("Change: \(change)")
            }
            
        case .historyNavigated(let config, let isUndo):
            print("\(isUndo ? "Undo" : "Redo") to configuration: \(config)")
            
        case .validationFailed(let error):
            print("Validation failed: \(error)")
        }
    }
}

// Add observer
let observer = MyConfigObserver()
let token = hotReload.addObserver(observer)

// Remove observer later
token.remove()
```

## Validation Rules

Add custom validation rules to ensure configuration integrity:

```swift
// Add custom validation rule
hotReload.addValidationRule { config in
    // Ensure tab width is reasonable for the font size
    if config.layout.tabWidth > 8 && config.display.fontSize < 12 {
        return ConfigurationError.incompatibleSettings(
            "Large tab width with small font size may cause display issues"
        )
    }
    return nil
}

// Built-in validations include:
// - Font size: 8-72
// - Tab width: 1-16
// - Performance settings: non-negative values
```

## Pending Changes

Stage changes before applying them:

```swift
// Add pending changes
hotReload.addPendingChange(.display(
    old: hotReload.configuration.display,
    new: EditorConfiguration.Display(fontSize: 18)
))

hotReload.addPendingChange(.layout(
    old: hotReload.configuration.layout,
    new: EditorConfiguration.Layout(tabWidth: 4)
))

// Apply all pending changes at once
hotReload.applyPendingChanges()

// Or clear without applying
hotReload.clearPendingChanges()
```

## Configuration Presets

Apply predefined configuration presets:

```swift
// Apply built-in presets
hotReload.applyPreset(.minimal)
hotReload.applyPreset(.readOnly)
hotReload.applyPreset(.markdown)
hotReload.applyPreset(.presentation)

// Apply custom preset
let myPreset = EditorConfiguration(
    display: .init(fontSize: 20, isLineNumbersEnabled: false),
    layout: .init(showGutter: false, showMinimap: false)
)
hotReload.applyPreset(.custom(myPreset))
```

## SwiftUI Integration

ConfigurationHotReload integrates seamlessly with SwiftUI:

```swift
struct SettingsView: View {
    @StateObject private var hotReload = ConfigurationHotReload()
    
    var body: some View {
        VStack {
            // Direct binding to configuration
            Toggle("Show Line Numbers", 
                   isOn: hotReload.configurationBinding.display.isLineNumbersEnabled)
            
            Slider(value: hotReload.configurationBinding.display.fontSize, 
                   in: 8...72)
            
            // Undo/Redo buttons
            HStack {
                Button("Undo") { hotReload.undo() }
                    .disabled(!hotReload.canUndo)
                
                Button("Redo") { hotReload.redo() }
                    .disabled(!hotReload.canRedo)
            }
        }
    }
}
```

## CodeEditorView Integration

Connect hot reload to a CodeEditorView:

```swift
// In your view setup
let hotReload = ConfigurationHotReload()
let cancellable = codeEditorView.setupHotReload(with: hotReload)

// The editor will automatically update when configuration changes
hotReload.batchUpdate { config in
    config.display.theme = .dark
    config.display.fontSize = 14
}

// Remember to store the cancellable to maintain the subscription
```

## Platform Considerations

ConfigurationHotReload works across all platforms with some considerations:

- **macOS**: Full support for all features
- **iOS**: All features supported, optimized for touch interfaces
- **Mac Catalyst**: Full compatibility

## Best Practices

1. **Batch Updates**: Use `batchUpdate` for multiple related changes
2. **Validation**: Add validation rules for domain-specific constraints
3. **History Limits**: The history size is limited to prevent memory issues
4. **Observer Cleanup**: Always remove observers when no longer needed
5. **Thread Safety**: ConfigurationHotReload is marked with `@MainActor`

## Performance Notes

- Configuration updates are optimized to only trigger necessary view updates
- History is capped at a platform-specific limit (see `PlatformConstants.maxConfigurationHistorySize`)
- Validation rules are run synchronously, keep them lightweight
- Observer notifications happen on the main thread

## See Also

- ``EditorConfiguration``
- ``ConfigurationEvent``
- ``ConfigurationObserver``
- ``ConfigurationPreset``
- ``ConfigurationError``