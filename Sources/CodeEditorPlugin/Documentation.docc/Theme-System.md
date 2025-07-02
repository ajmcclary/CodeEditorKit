# Theme System

@Metadata {
    @PageColor(green)
}

Create beautiful, accessible themes for your code editor.

## Overview

CodeEditorPlugin includes a sophisticated theme system with built-in themes and full customization support. Themes automatically adapt to light/dark mode and provide consistent styling across all languages.

## Built-in Themes

Five professional themes are included:

### Xcode Theme
Apple's classic development theme:
```swift
config.display.theme = .xcode
```

### VS Code Dark
Popular dark theme from Visual Studio Code:
```swift
config.display.theme = .vsDark
```

### GitHub Theme
Clean, light theme inspired by GitHub:
```swift
config.display.theme = .github
```

### Solarized Themes
Scientific color palette themes:
```swift
config.display.theme = .solarizedLight
config.display.theme = .solarizedDark
```

## Theme Structure

Themes define colors for all syntax elements:

```swift
struct Theme {
    // Editor colors
    let backgroundColor: PlatformColor
    let textColor: PlatformColor
    let selectionColor: PlatformColor
    let cursorColor: PlatformColor
    
    // Gutter colors
    let gutterBackgroundColor: PlatformColor
    let lineNumberColor: PlatformColor
    let currentLineNumberColor: PlatformColor
    
    // Syntax colors
    let keywordColor: PlatformColor
    let stringColor: PlatformColor
    let numberColor: PlatformColor
    let commentColor: PlatformColor
    let typeColor: PlatformColor
    let functionColor: PlatformColor
    let variableColor: PlatformColor
    let preprocessorColor: PlatformColor
    let operatorColor: PlatformColor
}
```

## Creating Custom Themes

### Basic Custom Theme

```swift
extension Theme {
    static let myCustomTheme = Theme(
        backgroundColor: PlatformColor(hex: "#1E1E1E"),
        textColor: PlatformColor(hex: "#D4D4D4"),
        selectionColor: PlatformColor(hex: "#264F78"),
        cursorColor: PlatformColor(hex: "#AEAFAD"),
        
        gutterBackgroundColor: PlatformColor(hex: "#1A1A1A"),
        lineNumberColor: PlatformColor(hex: "#858585"),
        currentLineNumberColor: PlatformColor(hex: "#C6C6C6"),
        
        keywordColor: PlatformColor(hex: "#569CD6"),
        stringColor: PlatformColor(hex: "#CE9178"),
        numberColor: PlatformColor(hex: "#B5CEA8"),
        commentColor: PlatformColor(hex: "#6A9955"),
        typeColor: PlatformColor(hex: "#4EC9B0"),
        functionColor: PlatformColor(hex: "#DCDCAA"),
        variableColor: PlatformColor(hex: "#9CDCFE"),
        preprocessorColor: PlatformColor(hex: "#C586C0"),
        operatorColor: PlatformColor(hex: "#D4D4D4")
    )
}
```

### Adaptive Theme

Create themes that adapt to light/dark mode:

```swift
extension Theme {
    static let adaptive = Theme(
        backgroundColor: PlatformColor(
            light: "#FFFFFF",
            dark: "#1E1E1E"
        ),
        textColor: PlatformColor(
            light: "#000000",
            dark: "#D4D4D4"
        ),
        // ... more adaptive colors
    )
}
```

## Applying Themes

### SwiftUI

```swift
struct ThemedEditor: View {
    @State private var config = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .onAppear {
                config.display.theme = .vsDark
            }
            .environment(\.codeEditorConfiguration, config)
    }
}
```

### UIKit/AppKit

```swift
let editor = CodeEditorView()
var config = EditorConfiguration()
config.display.theme = .github
config.apply(to: editor)
```

## Theme Components

### Semantic Colors

Use semantic colors for consistency:

```swift
extension Theme {
    var successColor: PlatformColor {
        PlatformColor(hex: "#4CAF50")
    }
    
    var warningColor: PlatformColor {
        PlatformColor(hex: "#FF9800")
    }
    
    var errorColor: PlatformColor {
        PlatformColor(hex: "#F44336")
    }
}
```

### Font Integration

Themes can specify fonts:

```swift
struct ThemeWithFont {
    let theme: Theme
    let fontName: String
    let fontSize: CGFloat
    
    static let monokai = ThemeWithFont(
        theme: .monokai,
        fontName: "JetBrains Mono",
        fontSize: 14
    )
}
```

## Advanced Theming

### Language-Specific Overrides

Customize colors per language:

```swift
// Coming in v1.5
theme.setOverride(for: .markdown) { colors in
    colors.headerColor = PlatformColor(hex: "#FF6B6B")
    colors.linkColor = PlatformColor(hex: "#4ECDC4")
}
```

### Dynamic Themes

Create themes that change based on conditions:

```swift
class DynamicTheme: ObservableObject {
    @Published var current: Theme = .xcode
    
    func updateForTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        current = (hour >= 18 || hour <= 6) ? .vsDark : .github
    }
}
```

## Theme Persistence

Save user theme preferences:

```swift
// Save theme selection
UserDefaults.standard.set(theme.identifier, forKey: "selectedTheme")

// Load theme selection
if let themeID = UserDefaults.standard.string(forKey: "selectedTheme"),
   let theme = Theme.theme(withIdentifier: themeID) {
    config.display.theme = theme
}
```

## Accessibility

Ensure themes are accessible:

```swift
extension Theme {
    var meetsContrastRequirements: Bool {
        let textContrast = contrastRatio(
            between: textColor,
            and: backgroundColor
        )
        return textContrast >= 4.5 // WCAG AA standard
    }
}
```

## Theme Export/Import

Share themes with others:

```swift
// Export theme to JSON
let themeData = try theme.toJSON()

// Import theme from JSON
let importedTheme = try Theme.from(json: themeData)
```

## Best Practices

1. **Test in Both Modes**: Verify themes work in light and dark mode
2. **Consider Contrast**: Ensure sufficient contrast for readability
3. **Use Semantic Colors**: Leverage the platform's semantic color system
4. **Consistent Palette**: Use a limited, cohesive color palette
5. **Test All Languages**: Verify all syntax elements are visible

## See Also

- <doc:Configuration-System>
- <doc:Syntax-Highlighting>
- <doc:SwiftUI-Integration>