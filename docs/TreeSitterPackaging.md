# Tree-sitter Packaging (Phase 7)

> How to extract, distribute, and consume the Tree-sitter module as an optional companion package.

**Date**: 2026-05-11  
**Status**: Architecture ready — extraction pending real C Tree-sitter integration.

## Architecture

```
┌─────────────────────────────────────────┐
│ CodeEditorPlugin umbrella + core targets│
│  ├── Language catalog (25 + plain text) │
│  ├── RangeHighlightProviding protocol   │
│  ├── RangeBasedHighlightingController   │
│  └── internal Tree-sitter scaffolding   │
│       └── not wired to public config    │
└──────────────┬──────────────────────────┘
               │ optional dependency
┌──────────────▼──────────────────────────┐
│ CodeEditorTreeSitterLanguages (~35 MB)  │
│  ├── Grammar binaries (.dylib/.xcframework)│
│  ├── Query files (.scm)                 │
│  ├── QueryCaptureMap (per-lang)    │
│  ├── EmbeddedLanguageInjectionLayer           │
│  ├── HeuristicFoldProvider             │
│  └── HeuristicSymbolProviderFacade           │
└─────────────────────────────────────────┘
```

## Current State (Phases 5-6)

After the target extraction, regex-query types are split across two source roots: `RegexRangeHighlightProvider.swift` stays in `CodeEditorView` because it references `CodeEditorView`; the parser/fold/symbol helper types live in `CodeEditorSyntaxHighlighting`. The pure-data Range-Query infrastructure (`RangeQueryParserProtocol`, `RangeQueryParseResult`, `RangeQueryCapture`, `RangeQueryParserError`) lives in `RangeQueryParser.swift` so it can be reused without depending on the editor view target.
```
Sources/CodeEditorView/SyntaxHighlighting/RegexQuery/
└── RegexRangeHighlightProvider.swift   # view-coupled — references CodeEditorView

Sources/CodeEditorSyntaxHighlighting/RegexQuery/
├── HeuristicFoldProvider.swift
├── HeuristicSymbolProviderFacade.swift
├── QueryCaptureMap.swift
├── RangeQueryParser.swift              # added during §6.2.7
└── RegexIncrementalRangeQueryParser.swift
```

The spike uses `RegexBackedRangeQueryParser` — a regex-backed implementation that proves the architecture without requiring C grammar binaries.

## Public Runtime Gate

There is currently no public runtime Tree-sitter gate. `Package.swift` does not define a Tree-sitter build flag by default, and `EditorConfiguration.Behavior` intentionally has no Tree-sitter option. Regex highlighting remains the only consumer-facing non-Swift path until a real grammar package exists.

## Extraction Checklist

The empty `Sources/CodeEditorTreeSitterLanguages/` directory exists as a namespace placeholder (a `.gitkeep` reserves the path in git). It has no SPM target yet — see the extraction checklist below.

- [ ] Create `CodeEditorTreeSitterLanguages` target in `Package.swift`
- [ ] Extract the portable parser/provider pieces from `Sources/CodeEditorSyntaxHighlighting/RegexQuery/` into the new target as needed
- [ ] Keep view-coupled adapters such as `RegexRangeHighlightProvider` in `Sources/CodeEditorView/SyntaxHighlighting/RegexQuery/`
- [ ] Replace `RegexBackedRangeQueryParser` with real C Tree-sitter integration
- [ ] Add grammar binaries as target resources
- [ ] Add query files as target resources
- [ ] Make `RangeQueryParserProtocol` public API
- [ ] Add consumer integration guide (this file serves as the draft)
- [ ] CI pipeline for grammar binary updates

## Consumer Opt-In

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", branch: "main"),
    .package(url: "https://github.com/ajmcclary/CodeEditorTreeSitterLanguages.git", branch: "main")
]
```

```swift
// App code
import CodeEditorPlugin
import CodeEditorTreeSitterLanguages

var config = EditorConfiguration()
config.performance.usesRangeBasedHighlighting = true
// Future companion package will register its provider explicitly.
```

## Binary Size Comparison

| Component | Size | Notes |
|-----------|------|-------|
| CodeEditorPlugin umbrella + core targets (regex only) | ~2 MB | Swift + SwiftSyntax + regex engine |
| CodeEditorTreeSitterLanguages | ~35 MB | Grammar binaries for the 25 concrete language catalog as XCFramework resources |
| Combined | ~37 MB | Full editor with Tree-sitter |

For comparison, CodeEditLanguages ships a 33 MB XCFramework for 41 language entries. Our core editor is significantly leaner because we keep the regex path as the default.

## What's Excluded from Extraction

These stay in the core editor regardless:

| Component | Why |
|-----------|-----|
| `LanguageDescriptor.parserName` | Data field — no code dependency |
| `RangeHighlightProviding` protocol | Core interface — used by LSP, spellcheck too |
| `RangeBasedHighlightingController` | Core pipeline — accepts any provider |
| `SyntaxHighlighterRangeAdapter` | Regex adapter — default provider |
