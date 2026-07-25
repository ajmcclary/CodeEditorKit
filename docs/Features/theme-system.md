# Theme System

Use CodeEditorKit's `Theme` value type to style editor text, syntax colors, chrome, gutter, minimap, completion rows, annotations, and selection behavior.

## Overview

Themes are applied independently from `EditorConfiguration`. Configuration controls behavior, layout, and performance. Theme selection is pushed through SwiftUI with `.codeTheme(_:)` or through the lower-level `apply(theme:)` methods on editor views and themeable subviews.

The package ships with a Zed-compatible theme loader and a bundled `"zed-trek"` family. The default theme is `Theme.lcarsDark`.

## Bundled Themes

Use the default theme directly:

```swift
let theme = Theme.lcarsDark

CodeEditor(text: $code)
    .codeLanguage(.swift)
    .codeTheme(theme)
```

The convenience aliases resolve to the same bundled theme:

```swift
CodeEditor(text: $code)
    .codeTheme(.default)

CodeEditor(text: $code)
    .codeTheme(.dark)
```

Load a specific bundled variant by family and variant name:

```swift
if let theme = Theme.bundled(family: "zed-trek", variant: "LCARS Dark") {
    CodeEditor(text: $code)
        .codeTheme(theme)
}
```

Inspect every variant in a bundled family:

```swift
if let family = ThemeFamily.bundled("zed-trek") {
    for theme in family.themes {
        CrossPlatformLogger.logger().info(theme.name)
    }
}
```

## Theme Components

A `Theme` is a complete visual surface:

```swift
let theme = Theme.lcarsDark

let editorBackground = theme.style.editor.background
let editorForeground = theme.style.editor.foreground
let gutterBackground = theme.style.editor.gutterBackground
let lineNumber = theme.style.editor.lineNumber
let activeLineNumber = theme.style.editor.activeLineNumber
let selection = theme.style.players[0].selection
let cursor = theme.style.players[0].cursor
```

Convert token colors to platform colors where you need to bridge into UIKit or AppKit:

```swift
let background = PlatformColor(tokens: theme.style.editor.background)
let foreground = PlatformColor(tokens: theme.style.editor.foreground)
```

Resolve syntax token colors through the theme-aware syntax color system:

```swift
let theme = Theme.lcarsDark
let keyword = theme.color(forToken: "keyword")
let string = theme.color(forToken: "string")
let comment = theme.color(forToken: "comment")
```

## SwiftUI Integration

Apply themes with `.codeTheme(_:)`:

```swift
struct ThemedEditor: View {
    @State private var code = "print(\"Hello\")"
    @State private var theme = Theme.lcarsDark

    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .codeTheme(theme)
    }
}
```

Theme and configuration can be changed independently:

```swift
struct ConfiguredEditor: View {
    @State private var code = ""
    @State private var configuration = EditorConfiguration.default
    @State private var theme = Theme.lcarsDark

    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration, configuration)
            .codeTheme(theme)
    }
}
```

Use the consolidated environment helper when you want to provide language, theme, and configuration together:

```swift
CodeEditor(text: $code)
    .codeEditorEnvironment(
        language: .swift,
        theme: .dark,
        configuration: EditorConfiguration.default
    )
```

## Direct View Integration

For lower-level UIKit/AppKit use, apply a theme to the editor view:

```swift
let editor = CodeEditorView()
editor.apply(theme: .lcarsDark)
```

Container and supporting views also conform to the themeable push model:

```swift
let container = CodeEditorContainerView()
container.apply(theme: .lcarsDark)
```

`apply(theme:)` is equality-gated, so reapplying the same theme is a no-op.

## Loading Custom Theme JSON

Decode a Zed-compatible theme family from a file:

```swift
let url = URL(fileURLWithPath: "/path/to/theme.json")
let family = try ThemeFamily(contentsOf: url)
let theme = family.theme(named: "My Dark Theme") ?? .lcarsDark
```

Collect non-fatal decode warnings while still loading usable fallbacks:

```swift
let data = try Data(contentsOf: url)
let (family, warnings) = try ThemeFamily.loaded(jsonData: data)

for warning in warnings {
    CrossPlatformLogger.logger().warning(warning)
}

let theme = family.themes.first ?? .lcarsDark
```

If JSON is missing optional platform fields, CodeEditorKit derives `PlatformExtension` values from the decoded style.

## Previews

Use token values from `Theme` when building previews or theme pickers:

```swift
struct ThemePreview: View {
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("func hello() {")
                .foregroundStyle(Color(tokens: theme.color(forToken: "keyword")))
            Text("    print(\"Hello\")")
                .foregroundStyle(Color(tokens: theme.style.editor.foreground))
            Text("}")
                .foregroundStyle(Color(tokens: theme.style.editor.foreground))
        }
        .font(.system(.caption, design: .monospaced))
        .padding(12)
        .background(Color(tokens: theme.style.editor.background))
    }
}
```

## Best Practices

Keep theme state separate from `EditorConfiguration`.

Use `.codeTheme(_:)` in SwiftUI and `apply(theme:)` for lower-level views.

Use `ThemeFamily.loaded(...)` when importing user-supplied JSON so warnings can be surfaced without rejecting an otherwise usable theme.

Verify custom themes on macOS and iOS because selection rendering and text-system details differ by platform.

## See Also

- [Configuration-System](../Configuration/system.md)
- [SwiftUI-Integration](../SwiftUI/integration.md)
- [Platform-Abstraction](../Platform/platform-abstraction.md)
