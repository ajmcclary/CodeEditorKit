# Code Folding

Use code folding to collapse foldable regions detected for the current language.

## Overview

`CodeEditorView` exposes a compact public folding API:

- `toggleFold(at:) -> Bool`
- `fold(at:) -> Bool`
- `unfold(at:) -> Bool`
- `isFoldable(at:) -> Bool`
- `isFolded(at:) -> Bool`
- `foldAll()`
- `unfoldAll()`

Line numbers are 1-based. The Boolean methods return `false` when code folding is disabled or when no matching foldable region exists at that line.

## Configuration

```swift
var config = EditorConfiguration.default
config.display.isCodeFoldingEnabled = true
config.display.areFoldingControlsVisible = true
config.display.minimumFoldableLines = 3
config.performance.animateCodeFolding = true

config.apply(to: editor)
```

SwiftUI:

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .isCodeFoldingEnabled(true)
    .areFoldingControlsVisible(true)
    .minimumFoldableLines(3)
    .animateCodeFolding(true)
```

## Basic Usage

```swift
let editor = CodeEditorView()
editor.language = .swift

var config = EditorConfiguration.default
config.display.isCodeFoldingEnabled = true
config.apply(to: editor)

if editor.isFoldable(at: 10) {
    _ = editor.toggleFold(at: 10)
}
```

## Folding and Unfolding

```swift
if editor.fold(at: 42) {
    CrossPlatformLogger.logger().info("Folded region at line 42")
}

if editor.unfold(at: 42) {
    CrossPlatformLogger.logger().info("Unfolded region at line 42")
}

if editor.isFolded(at: 42) {
    CrossPlatformLogger.logger().info("Line 42 is currently folded")
}
```

## Bulk Operations

`foldAll()` and `unfoldAll()` operate on every currently detected foldable region. They do not return counts.

```swift
editor.foldAll()
editor.unfoldAll()
```

## Language Behavior

The folding engine adapts to the current `Language`:

```swift
editor.language = .swift
editor.language = .javascript
editor.language = .python
```

Set the language before expecting fold regions to be detected.

## Troubleshooting

If folding calls return `false`:

1. Verify `configuration.display.isCodeFoldingEnabled` is `true`.
2. Verify the editor's `language` is set.
3. Check that the line starts or belongs to a foldable construct.
4. Allow detection to complete for large files; folding updates are debounced.

```swift
CrossPlatformLogger.logger().info("Folding enabled: \(editor.configuration.display.isCodeFoldingEnabled)")
CrossPlatformLogger.logger().info("Language: \(editor.language)")
CrossPlatformLogger.logger().info("Line 10 foldable: \(editor.isFoldable(at: 10))")
```

## See Also

- [Configuration system](../Configuration/system.md)
- [Syntax highlighting](syntax-highlighting.md)
- [Performance monitoring](../Performance/monitoring.md)
