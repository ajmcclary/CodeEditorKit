# Configuration Presets

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

Use built-in configuration presets for common editing scenarios.

## Overview

CodeEditorPlugin includes nine carefully crafted configuration presets that cover most common use cases. Five main presets are designed for specific editing scenarios, while four platform-specific presets optimize for different Apple platforms. Each preset is optimized for its specific purpose and can be further customized.

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
- No gutter
- Minimal UI chrome
- Focus on content
- Larger line spacing
- Simple theme

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
- Wider line spacing
- Word wrapping enabled
- Larger font size
- Tab width: 2 spaces
- Spell checking enabled
- Markdown-optimized theme

Best for: Writing documentation, blog posts, or README files

### Presentation

Large, high-contrast configuration for demos:

```swift
let config = EditorConfiguration.presentation
```

Features:
- Extra large font (20pt)
- High contrast theme
- Increased line spacing
- Bold keywords
- Simplified UI
- Maximum readability

Best for: Live coding, screencasts, or conference presentations

## Platform-Specific Presets

### iOS

Optimized for iPhone and iPad:

```swift
let config = EditorConfiguration.iOS
```

Features:
- Touch-optimized UI
- Larger tap targets
- Appropriate font sizes
- Memory-conscious settings
- Viewport rendering enabled
- Adapted for smaller screens

Best for: iOS applications

### Mac Catalyst

Tailored for Mac Catalyst apps:

```swift
let config = EditorConfiguration.catalyst
```

Features:
- Hybrid UI optimizations
- Mac-like font sizing
- Keyboard-focused interaction
- Full feature set enabled
- Native Mac feel
- Catalyst-specific adjustments

Best for: Mac Catalyst applications

### macOS

Native macOS configuration:

```swift
let config = EditorConfiguration.macOS
```

Features:
- Full desktop features
- Hardware acceleration
- Rich UI elements
- Professional tooling
- Maximum performance
- Desktop-oriented layout

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
  - Catalyst builds → `.catalyst`
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
        config.display.showMinimap = true
        
        // Layout settings
        config.layout.tabWidth = 2
        config.layout.lineSpacing = 1.0
        config.layout.gutterWidth = 40
        
        // Behavior settings
        config.behavior.autoIndent = true
        config.behavior.autoCloseBrackets = true
        
        return config
    }
}
```

## Preset Comparison

| Feature | Default | Minimal | Read Only | Markdown | Presentation |
|---------|---------|---------|-----------|----------|--------------|
| Line Numbers | ✓ | ✗ | ✓ | ✗ | ✓ |
| Editable | ✓ | ✓ | ✗ | ✓ | ✓ |
| Font Size | 14pt | 14pt | 13pt | 16pt | 20pt |
| Tab Width | 4 | 4 | 4 | 2 | 4 |
| Line Spacing | 1.2 | 1.5 | 1.2 | 1.6 | 1.4 |
| Word Wrap | ✗ | ✓ | ✗ | ✓ | ✗ |
| Minimap | ✗ | ✗ | ✗ | ✗ | ✗ |
| Annotations | ✓ | ✗ | ✓ | ✗ | ✓ |

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

- <doc:Configuration-System>
- <doc:Theme-System>
- <doc:SwiftUI-Integration>
