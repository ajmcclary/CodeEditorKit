# Syntax Highlighting

@Metadata {
    @PageColor(green)
}

Learn about CodeEditorPlugin's sophisticated syntax highlighting system supporting 20 programming languages.

## Overview

CodeEditorPlugin provides best-in-class syntax highlighting using a hybrid approach:
- **SwiftSyntax** for native Swift AST analysis
- **Optimized Regex Patterns** for other languages
- **Viewport-Based Rendering** for performance
- **Background Processing** to maintain UI responsiveness

## Supported Languages

### Tier 1 Languages (Full Support)
- **Swift** - AST-based with SwiftSyntax
- **Python** - Keywords, strings, comments, decorators
- **JavaScript/TypeScript** - ES6+ syntax, JSX support
- **Rust** - Full syntax including macros
- **Go** - Complete syntax support

### Tier 2 Languages (Comprehensive Support)
- **C/C++** - Preprocessor directives, modern C++ keywords
- **Java** - Annotations, generics, lambdas
- **Ruby** - Blocks, symbols, interpolation
- **PHP** - Variables, heredoc, modern syntax
- **HTML/CSS** - Tag matching, CSS properties

### Data Formats
- **JSON** - Structural highlighting
- **YAML** - Indentation-aware
- **XML** - Tag matching
- **Markdown** - Headers, links, code blocks
- **SQL** - Keywords, functions
- **Shell** - Variables, commands

## Setting Language

### Automatic Detection

```swift
// Detect from file extension
editor.setLanguage(fileExtension: "swift")  // Swift
editor.setLanguage(fileExtension: "py")     // Python
editor.setLanguage(fileExtension: "js")     // JavaScript
```

### Manual Selection

```swift
// SwiftUI
CodeEditor(text: $code)
    .codeLanguage(.python)

// UIKit/AppKit
editor.language = .javascript
```

### Language Detection Service

```swift
// Detect from filename
let language = LanguageDetectionService.detect(from: "main.rs")
editor.language = language

// Detect from content
let language = LanguageDetectionService.detectFromContent(code)
editor.language = language
```

## Customization

### Theme Integration

Syntax highlighting adapts to the current theme:

```swift
config.display.theme = .vsDark
// Syntax colors automatically update
```

### Token Types

Each language defines tokens for consistent theming:

```swift
public enum TokenType {
    case keyword        // if, func, class
    case identifier     // variable names
    case string         // "text"
    case number         // 123, 0xFF
    case comment        // // comment
    case preprocessor   // #import
    case type           // String, Int
    case function       // function calls
    case property       // object.property
    case operator       // +, -, *, /
}
```

## Performance

### Viewport Rendering

Only visible text is highlighted:

```swift
config.performance.enableViewportRendering = true
config.performance.viewportExpansion = 100 // lines
```

### Background Processing

Highlighting happens off the main thread:

```swift
// Automatic with actor-based system
actor SyntaxHighlighter {
    func highlight(_ text: String) async -> [Token] {
        // Processing happens here
    }
}
```

### Large File Handling

Automatic optimizations for large files:

```swift
config.performance.maxSyntaxHighlightingLength = 500_000
// Files larger than this use progressive highlighting
```

## Advanced Features

### Contextual Highlighting

Some languages support context-aware highlighting:

```swift
// In HTML, CSS inside <style> tags is highlighted
<style>
    .class { color: red; }
</style>

// In Markdown, code blocks use appropriate language
```python
def hello():
    print("Hello")
```
```

### Incremental Updates

Only changed portions are re-highlighted:

```swift
// Automatic - no configuration needed
// Edits trigger minimal re-highlighting
```

### Custom Patterns

Add highlighting for custom keywords:

```swift
// Coming in v1.5
highlighter.addCustomPattern(
    pattern: #/TODO|FIXME|NOTE/#,
    tokenType: .comment,
    style: .bold
)
```

## SwiftSyntax Integration

Swift files get AST-based highlighting:

```swift
// Accurate highlighting for:
- Type inference
- Property wrappers
- Result builders
- Macros
- Async/await
- Actors
```

Benefits:
- 100% accurate syntax understanding
- Semantic highlighting
- Error detection
- Code folding hints

## Creating Custom Languages

Support for custom languages coming in v2.0:

```swift
// Future API
let customLanguage = Language(
    name: "MyLang",
    extensions: ["ml", "myl"],
    patterns: [
        .keywords(["func", "var", "let"]),
        .strings(delimiter: "\""),
        .comments(single: "//", multi: ("/*", "*/"))
    ]
)

LanguageRegistry.register(customLanguage)
```

## Best Practices

1. **Set Language Early**: Set language before setting text for best performance
2. **Use File Extensions**: Let the system detect language when possible
3. **Consider File Size**: Large files may benefit from progressive highlighting
4. **Test Themes**: Verify highlighting looks good in all themes
5. **Monitor Performance**: Use performance tools for optimization

## See Also

- <doc:Theme-System>
- <doc:Performance-Monitoring>
- <doc:Configuration-System>