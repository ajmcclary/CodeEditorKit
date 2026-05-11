# Tree-sitter Packaging (Phase 7)

> How to extract, distribute, and consume the Tree-sitter module as an optional companion package.

**Date**: 2026-05-11  
**Status**: Architecture ready — extraction pending real C Tree-sitter integration.

## Architecture

```
┌─────────────────────────────────────────┐
│ CodeEditorPlugin (core, ~2 MB)          │
│  ├── Language catalog (25 + plain text) │
│  ├── RangeHighlightProviding protocol   │
│  ├── RangeBasedHighlightingController   │
│  ├── EditorConfiguration.Behavior       │
│  │    └── useTreeSitterHighlighting     │
│  └── #if CAN_IMPORT_TREE_SITTER         │
│       └── TreeSitterRangeHighlightProvider│
└──────────────┬──────────────────────────┘
               │ optional dependency
┌──────────────▼──────────────────────────┐
│ CodeEditorTreeSitterLanguages (~35 MB)  │
│  ├── Grammar binaries (.dylib/.xcframework)│
│  ├── Query files (.scm)                 │
│  ├── TreeSitterCaptureMap (per-lang)    │
│  ├── TreeSitterInjectionLayer           │
│  ├── TreeSitterFoldProvider             │
│  └── TreeSitterSymbolProvider           │
└─────────────────────────────────────────┘
```

## Current State (Phases 5-6)

All Tree-sitter types are `internal` and live in:
```
Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/
├── TreeSitterRangeHighlightProvider.swift
├── TreeSitterCaptureMap.swift
├── TreeSitterInjectionLayer.swift
├── TreeSitterFoldProvider.swift
└── TreeSitterSymbolProvider.swift
```

The spike uses `RegexBackedTreeSitterParser` — a regex-backed implementation that proves the architecture without requiring C grammar binaries.

## Compile-Time Gate

`Package.swift` defines `CAN_IMPORT_TREE_SITTER` by default:

```swift
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableExperimentalFeature("StrictConcurrency"),
    .define("CAN_IMPORT_TREE_SITTER")
]
```

The wiring in `CodeEditorView+RangeBasedHighlightingExtensions.swift` is guarded:

```swift
#if CAN_IMPORT_TREE_SITTER
if configuration.behavior.useTreeSitterHighlighting {
    externalProvider = TreeSitterRangeHighlightProvider.makeSpikeProvider(for: language)
}
#endif
```

When excluded, `useTreeSitterHighlighting` has no effect — regex is always used.

## Extraction Checklist

- [ ] Create `CodeEditorTreeSitterLanguages` target in `Package.swift`
- [ ] Move `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/` to new target
- [ ] Replace `RegexBackedTreeSitterParser` with real C Tree-sitter integration
- [ ] Add grammar binaries as target resources
- [ ] Add query files as target resources
- [ ] Make `TreeSitterParserProtocol` public API
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
config.behavior.useTreeSitterHighlighting = true
```

## Binary Size Comparison

| Component | Size | Notes |
|-----------|------|-------|
| CodeEditorPlugin (regex only) | ~2 MB | Swift + SwiftSyntax + regex engine |
| CodeEditorTreeSitterLanguages | ~35 MB | Grammar binaries for the 25 concrete language catalog as XCFramework resources |
| Combined | ~37 MB | Full editor with Tree-sitter |

For comparison, CodeEditLanguages ships a 33 MB XCFramework for 41 language entries. Our core editor is significantly leaner because we keep the regex path as the default.

## What's Excluded from Extraction

These stay in the core editor regardless:

| Component | Why |
|-----------|-----|
| `LanguageDescriptor.treeSitterName` | Data field — no code dependency |
| `RangeHighlightProviding` protocol | Core interface — used by LSP, spellcheck too |
| `RangeBasedHighlightingController` | Core pipeline — accepts any provider |
| `EditorConfiguration.Behavior.useTreeSitterHighlighting` | Feature flag — just a Bool |
| `SyntaxHighlighterRangeAdapter` | Regex adapter — default provider |
