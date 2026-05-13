# Syntax Highlighting

CodeEditorPlugin highlights Swift with SwiftSyntax and uses optimized local highlighters for the rest of the built-in language catalog.

## Overview

The current highlighting pipeline is:

- `SyntaxHighlightingCoordinator` routes highlighting requests by `Language`.
- Swift uses the SwiftSyntax / SwiftParser path.
- JSON uses the fast tokenizer path where appropriate.
- Other concrete languages use descriptor-backed regex definitions from `LanguageDescriptor` and `RegexSyntaxHighlighter`.
- `.plainText` is a first-class language case with no token styling.
- Optional range-based highlighting and the range-query parser spike live behind configuration flags.

## Supported Languages

The public `Language` enum currently contains 25 concrete languages plus plain text:

| Group | Languages |
|---|---|
| Apple / web / scripting | Swift, JavaScript, TypeScript, Python, Ruby, PHP, Shell |
| Systems / application | C, C++, C#, Java, Kotlin, Dart, Go, Rust |
| Markup / data | HTML, CSS, JSON, YAML, XML, Markdown, SQL, TOML, Dockerfile, Lua |
| Fallback | Plain Text |

The single source of truth is `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift`; update that descriptor, the regex definitions, and tests together when adding a language.

## Setting Language

### SwiftUI

```swift
CodeEditor(text: $code)
    .codeLanguage(.python)
```

### AppKit / UIKit view

```swift
editor.language = .javascript
editor.setLanguage(fileExtension: "swift")
```

### Detection service

```swift
let service = LanguageDetectionService()

let fromPath = service.detectLanguage(fromPath: "/project/Sources/App.swift")
let fromFilename = service.detectLanguage(fromFilename: "Dockerfile.dev")
let fromContent = service.detectLanguage(fromContent: source) ?? .plainText
```

## Configuration

Syntax highlighting is enabled through display configuration and can be tuned through performance settings:

```swift
var config = EditorConfiguration()
config.display.isSyntaxHighlightingEnabled = true
config.performance.maxSyntaxHighlightingLength = 500_000
config.performance.textChangeDebounceInterval = .milliseconds(100)
```

Range-based highlighting is available as an experimental path:

```swift
var config = EditorConfiguration()
config.performance.usesRangeBasedHighlighting = true
```

The range-query parser spike is internal only. There is no public runtime flag and the package does not ship C grammar binaries. Today the editor uses SwiftSyntax for Swift and regex definitions for other languages; see [Tree-sitter packaging](../TreeSitterPackaging.md) for the extraction plan.

## Performance

Large-file behavior is handled by the coordinator stack rather than by app-level viewport flags:

- `AsyncSyntaxHighlighter` debounces and cancels work during rapid edits.
- `BackgroundSyntaxHighlighter` handles background tokenization.
- `StreamingHighlighter` chunks large inputs.
- `OptimizedSyntaxHighlightingCoordinator` adds cache, chunking, and circuit-breaker behavior.
- `SyntaxHighlightingPerformanceTracker` records timing, token counts, and cache hit rate.

For app code, prefer the public configuration knobs:

```swift
var config = EditorConfiguration()
config.performance.maxSyntaxHighlightingLength = 1_000_000
config.performance.highlightingDebounceInterval = .milliseconds(150)
config.performance.usesRangeBasedHighlighting = true
```

## Theme Integration

Syntax colors are resolved through the active `Theme`:

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .codeTheme(.lcarsDark)
```

Token colors fall back through the theme system when a theme omits a token-specific color.

## See Also

- [Theme system](theme-system.md)
- [Performance monitoring](../Performance/monitoring.md)
- [Performance optimizations](../Performance/optimizations.md)
- [Tree-sitter packaging](../TreeSitterPackaging.md)
