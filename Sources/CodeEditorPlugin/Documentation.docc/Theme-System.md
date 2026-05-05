# Theme System

@Metadata {
    @PageColor(purple)
}

Explore CodeEditorPlugin's comprehensive theme system with built-in themes and customization options.

## Overview

The theme system provides professionally designed color schemes optimized for different environments and use cases. Each theme includes complete color definitions for all editor elements, from syntax highlighting to UI components.

## Available Themes

### Xcode Default
A familiar light theme based on Xcode's default appearance:
```swift
let theme = ColorTheme.xcode
// Clean white background with system colors
```

### VS Code Dark
A popular dark theme inspired by Visual Studio Code:
```swift
let theme = ColorTheme.vsDark
// Dark gray background (#1E1E1E) with blue-tinted keywords
```

### GitHub Light
Clean and minimal light theme based on GitHub's design:
```swift
let theme = ColorTheme.github
// Pure white background with distinctive pink keywords
```

### Solarized Dark
The beloved Solarized dark color scheme:
```swift
let theme = ColorTheme.solarizedDark
// Deep blue-green background with balanced color palette
```

### Minimal
Stripped-down theme for distraction-free editing:
```swift
let theme = ColorTheme.minimal
// Pure white background with minimal color usage
```

### Presentation
High-contrast theme optimized for demos and presentations:
```swift
let theme = ColorTheme.presentation
// Very dark background with bright, readable colors
```

## Theme Components

Each theme defines colors for all editor elements:

### Background Elements
```swift
let theme = ColorTheme.vsDark

// Editor colors
let backgroundColor = theme.backgroundColor          // Main editing area
let selectedLineColor = theme.selectedLineColor     // Current line highlight
let selectionColor = theme.selectionColor           // Text selection background

// Gutter colors
let gutterBackground = theme.gutterBackgroundColor  // Line number area
let gutterText = theme.gutterTextColor              // Line numbers
```

### Text Colors
```swift
// Primary text
let textColor = theme.textColor                     // Default code text

// UI text
let gutterTextColor = theme.gutterTextColor         // Line numbers
```

### Syntax Highlighting
```swift
// Language tokens
let keywordColor = theme.keywordColor               // func, var, let, class
let stringColor = theme.stringColor                 // "Hello, World!"
let commentColor = theme.commentColor               // // Comments
let numberColor = theme.numberColor                 // 42, 3.14
let typeColor = theme.typeColor                     // String, Int, UIView
let functionColor = theme.functionColor             // Function names
```

## Token Type Mapping

Themes provide color mapping for syntax tokens:

```swift
let theme = ColorTheme.vsDark

// Get color for specific token type
let keywordColor = theme.colorForTokenType(.keyword)     // Blue keywords
let stringColor = theme.colorForTokenType(.string)       // Orange strings
let commentColor = theme.colorForTokenType(.comment)     // Green comments
let numberColor = theme.colorForTokenType(.number)       // Light green numbers
let typeColor = theme.colorForTokenType(.type)           // Teal types
let functionColor = theme.colorForTokenType(.function)   // Yellow functions

// Additional token types
let propertyColor = theme.colorForTokenType(.property)   // Orange properties
let operatorColor = theme.colorForTokenType(.operator)   // Default text color
let punctuationColor = theme.colorForTokenType(.punctuation) // Dimmed text
let preprocessorColor = theme.colorForTokenType(.preprocessor) // Pink
```

## Theme Integration

### SwiftUI Theme Selection

Create a theme selection interface:

```swift
struct ThemeConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTheme: ColorTheme = .xcode
    
    var body: some View {
        VStack {
            // Theme selection
            ForEach(ColorTheme.allCases, id: \.self) { theme in
                ThemeRow(
                    theme: theme,
                    isSelected: selectedTheme == theme,
                    onSelect: {
                        selectedTheme = theme
                        applyTheme(theme)
                    }
                )
            }
            
            // Live preview
            ThemePreview(theme: selectedTheme)
                .frame(height: 120)
        }
    }
    
    private func applyTheme(_ theme: ColorTheme) {
        appState.updateConfiguration { config in
            // Apply theme colors to configuration
            config.display.theme = theme
        }
    }
}
```

### Theme Preview Component

Create live theme previews:

```swift
struct ThemePreview: View {
    let theme: ColorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Simulated code with syntax highlighting
            HStack(spacing: 4) {
                Text("func").foregroundColor(Color(theme.keywordColor))
                Text("hello()").foregroundColor(Color(theme.functionColor))
                Text("{").foregroundColor(Color(theme.textColor))
            }
            
            HStack(spacing: 4) {
                Text("    let").foregroundColor(Color(theme.keywordColor))
                Text("message").foregroundColor(Color(theme.textColor))
                Text("=").foregroundColor(Color(theme.textColor))
                Text("\"Hello, World!\"").foregroundColor(Color(theme.stringColor))
            }
            
            HStack(spacing: 4) {
                Text("    // This is a comment")
                    .foregroundColor(Color(theme.commentColor))
                    .italic()
            }
            
            HStack(spacing: 4) {
                Text("    print(message)").foregroundColor(Color(theme.textColor))
            }
            
            HStack(spacing: 4) {
                Text("}").foregroundColor(Color(theme.textColor))
            }
        }
        .font(.system(.caption, design: .monospaced))
        .padding(12)
        .background(Color(theme.backgroundColor))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

### Theme Row Component

Display themes with color swatches:

```swift
struct ThemeRow: View {
    let theme: ColorTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Color preview swatches
                HStack(spacing: 2) {
                    ColorSwatch(color: theme.backgroundColor)
                    ColorSwatch(color: theme.keywordColor)
                    ColorSwatch(color: theme.stringColor)
                    ColorSwatch(color: theme.commentColor)
                }
                
                Text(theme.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}
```

## Platform Support

### Cross-Platform Colors

Themes use platform-abstracted colors for consistency:

```swift
// These adapt automatically to each platform
var backgroundColor: PlatformColor {
    switch self {
    case .xcode:
        return PlatformColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
    case .vsDark:
        return PlatformColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
    // etc.
    }
}

// Platform-specific implementations
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// macOS implementation with NSColor
#else
// iOS/Catalyst implementation with UIColor
#endif
```

### Hex Color Export

Export themes for sharing:

```swift
let theme = ColorTheme.vsDark
let themeConfig = theme.themeConfiguration

// Export as dictionary with hex values
print(themeConfig)
// Output:
// [
//   "name": "VS Code Dark",
//   "colors": [
//     "background": "#1E1E1E",
//     "keyword": "#569CD6", 
//     "string": "#CE9178"
//     // etc.
//   ]
// ]

// Convert colors to hex strings
extension PlatformColor {
    var hexString: String {
        // Cross-platform hex conversion
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS NSColor implementation
        #else
        // iOS/Catalyst UIColor implementation  
        #endif
    }
}
```

## Configuration Integration

### Applying Themes

Use themes with the configuration system:

```swift
// SwiftUI approach
struct ThemedEditor: View {
    @State private var config = EditorConfiguration()
    @State private var selectedTheme: ColorTheme = .xcode
    
    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration, config)
            .onChange(of: selectedTheme) { newTheme in
                // Apply theme colors to configuration
                config.display.theme = newTheme
            }
    }
}

// Direct configuration approach
var config = EditorConfiguration()
config.display.theme = .vsDark
config.apply(to: editorView)
```

### Configuration Integration

Theme integration is driven by `EditorConfiguration` and SwiftUI environment values:

```swift
var config = EditorConfiguration()
config.display.theme = .github

CodeEditor(text: $code)
    .environment(\.codeEditorConfiguration, config)
```

// In ThemeConfigurationSection.swift
private func applyTheme(_ theme: ColorTheme) {
    appState.updateConfiguration { config in
        // Theme integration point
        config.display.theme = theme
    }
}
```

## Best Practices

1. **Test All Platforms**: Verify themes work on macOS, iOS, and Catalyst
2. **Consider Accessibility**: Ensure sufficient contrast ratios for readability  
3. **Use Platform Colors**: Leverage `PlatformColor` for cross-platform consistency
4. **Provide Previews**: Show live previews when letting users choose themes
5. **Export Support**: Allow users to share and back up theme configurations
6. **Performance**: Use efficient color creation for frequently accessed themes
7. **Semantic Usage**: Use appropriate colors for each syntax element type

## Theme Development Tips

### Color Selection
- Use tools like Coolors.co or Adobe Color for palette creation
- Test with common syntax patterns (keywords, strings, comments)
- Ensure accessibility with contrast checkers
- Consider different lighting conditions

### Implementation
```swift
// Always provide fallback colors
var textColor: PlatformColor {
    switch self {
    case .custom:
        return customTextColor ?? PlatformColors.label
    default:
        return PlatformColors.label
    }
}

// Use computed properties for theme variations
var darkVariant: ColorTheme {
    // Return dark version of light theme
}
```

### Testing
- Test with various file types (Swift, JavaScript, Markdown, etc.)
- Verify readability in different screen brightnesses
- Check color-blind accessibility using tools like Stark
- Test on actual devices, not just simulators

## See Also

- <doc:Configuration-System>
- <doc:SwiftUI-Integration>
- <doc:Platform-Abstraction>
