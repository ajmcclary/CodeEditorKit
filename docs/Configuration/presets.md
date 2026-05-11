# Configuration Presets

Use built-in configuration presets for common editing scenarios.

## Overview

CodeEditorPlugin includes eight configuration presets. Five are scenario presets (`default`, `minimal`, `readOnly`, `markdown`, `presentation`) and three are platform-oriented (`iOS`, `macOS`, `platformOptimized`). Each preset is a plain `EditorConfiguration` value and can be further customized.

## Available Presets

### Default

The standard configuration with all commonly-used features enabled:

```swift
let config = EditorConfiguration.default
```

Features:
- Line numbers visible
- Syntax highlighting enabled
- Tab width: 4 spaces
- Auto-indent enabled
- Hardware acceleration on
- Annotations visible

Best for: General development work

### Minimal

A clean, distraction-free configuration:

```swift
let config = EditorConfiguration.minimal
```

Features:
- No line numbers
- Syntax highlighting disabled
- Annotations disabled
- Code folding disabled
- Code completion disabled
- Focus on content

Best for: Writing, note-taking, or focused coding sessions

### Read Only

Optimized for viewing code without editing:

```swift
let config = EditorConfiguration.readOnly
```

Features:
- Editing disabled
- Selection enabled
- Line numbers visible
- Syntax highlighting on
- No cursor
- Optimized scrolling

Best for: Code reviews, documentation, or displaying examples

### Markdown

Tailored for Markdown document editing:

```swift
let config = EditorConfiguration.markdown
```

Features:
- Word wrapping enabled
- Automatic link detection enabled
- Quote and dash substitution enabled
- Code folding disabled

Best for: Writing documentation, blog posts, or README files

### Presentation

Large, high-contrast configuration for demos:

```swift
let config = EditorConfiguration.presentation
```

Features:
- Read-only behavior inherited from `.readOnly`
- Larger font (18pt)
- Line numbers hidden
- Annotations hidden
- Selected-line highlight disabled
- Word wrapping enabled
- Maximum readability

Best for: Live coding, screencasts, or conference presentations

## Platform-Specific Presets

### iOS

Optimized for iPhone and iPad:

```swift
let config = EditorConfiguration.iOS
```

Features:
- Font size 16 pt
- Wider gutter
- Smooth scrolling enabled
- Lower syntax-highlighting length limit
- Hardware acceleration enabled
- Automatic text replacement disabled

Best for: iOS applications

### macOS

Native macOS configuration:

```swift
let config = EditorConfiguration.macOS
```

Features:
- Desktop gutter width
- Hardware acceleration enabled
- Higher syntax-highlighting length limit
- Automatic text replacement enabled
- Automatic quote substitution enabled

Best for: Native macOS applications

### Platform Optimized

Automatically selects the best configuration for the current platform:

```swift
let config = EditorConfiguration.platformOptimized
```

Features:
- Compile-time platform detection
- Returns appropriate preset:
  - iOS builds → `.iOS`
  - macOS builds → `.macOS`
  - Other platforms → `.default`

Best for: Cross-platform applications where you want automatic optimization

## Using Presets

### SwiftUI

```swift
struct EditorView: View {
    @State private var code = ""
    
    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration, .minimal)
    }
}
```

### UIKit/AppKit

```swift
let editor = CodeEditorView()
let config = EditorConfiguration.presentation
config.apply(to: editor)
```

## Customizing Presets

Start with a preset and customize:

```swift
// Start with minimal preset
var config = EditorConfiguration.minimal

// Add specific customizations
config.display.isLineNumbersEnabled = true
config.display.fontSize = 16
config.layout.tabWidth = 2

// Apply customized configuration
config.apply(to: editor)
```

## Creating Custom Presets

Define your own presets:

```swift
extension EditorConfiguration {
    static var compactCoding: EditorConfiguration {
        var config = EditorConfiguration()
        
        // Display settings
        config.display.isLineNumbersEnabled = true
        config.display.fontSize = 12
        config.display.isMinimapVisible = true
        
        // Layout settings
        config.layout.tabWidth = 2
        config.layout.lineSpacing = 1.0
        config.layout.gutterWidth = 40
        
        // Behavior settings
        config.behavior.isAutoIndentEnabled = true
        config.behavior.autoCloseBrackets = true
        
        return config
    }
}
```

## Preset Comparison

| Feature | Default | Minimal | Read Only | Markdown | Presentation |
|---|:---:|:---:|:---:|:---:|:---:|
| Line numbers | ✓ | ✗ | ✓ | ✓ | ✗ |
| Editable | ✓ | ✓ | ✗ | ✓ | ✗ |
| Syntax highlighting | ✓ | ✗ | ✓ | ✓ | ✓ |
| Code completion | ✓ | ✗ | ✗ | ✓ | ✗ |
| Font size | 14 pt | 14 pt | 14 pt | 14 pt | 18 pt |
| Tab width | 4 | 4 | 4 | 4 | 4 |
| Word wrap | ✗ | ✗ | ✗ | ✓ | ✓ |
| Minimap | ✗ | ✗ | ✗ | ✗ | ✗ |
| Annotations | ✓ | ✗ | ✓ | ✓ | ✗ |

## Dynamic Preset Selection

Switch presets based on context:

```swift
class EditorViewModel: ObservableObject {
    @Published var configuration: EditorConfiguration = .default
    
    func selectPreset(for fileType: String) {
        switch fileType {
        case "md", "markdown":
            configuration = .markdown
        case "log", "txt":
            configuration = .readOnly
        case "config", "json", "yaml":
            configuration = .minimal
        default:
            configuration = .default
        }
    }
}
```

## Best Practices

1. **Start with Presets**: Use presets as a starting point
2. **Customize Sparingly**: Only override what you need
3. **Consider Context**: Choose presets based on use case
4. **Test Across Platforms**: Verify presets work on all targets
5. **Document Custom Presets**: Explain why custom presets exist

## See Also

- [Configuration-System](system.md)
- [Theme-System](../Features/theme-system.md)
- [SwiftUI-Integration](../SwiftUI/integration.md)
