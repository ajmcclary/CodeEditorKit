# CodeEditSourceEditor Audit Notes

Audit target:

`/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor`

Compared against:

`/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin`

## Executive Summary

CodeEditSourceEditor is much smaller than CodeEditorPlugin, but its edit/render hot path is more directly built around editor-core primitives: Tree-sitter parsing, visible-range highlighting, reusable range storage, attachment-backed folding, dirty-rect gutter rendering, and a syntax-aware minimap.

CodeEditorPlugin is broader, cross-platform, and service-heavy. It has more public API surface, dependency injection, Swift 6 orientation, language coverage, and platform abstractions. The main opportunity is to make the core editing systems less heuristic and more grounded in shared semantic/range infrastructure.

## Key Lessons

### Parsing

CodeEditSourceEditor uses Tree-sitter as a shared semantic substrate for:

- Syntax highlighting
- Injected language layers
- Tag handling
- Jump-to-definition queries
- Smart editing behavior

Important files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/TreeSitterClient.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/TreeSitterState.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/LanguageLayer.swift`

CodeEditorPlugin uses SwiftSyntax for Swift and regex/lightweight tokenizers for most other languages. That is portable and broad, but weaker for non-Swift semantic correctness, embedded languages, and parser-backed folding.

Recommendation: evaluate Tree-sitter for non-Swift languages and injected-language support while keeping SwiftSyntax for Swift if it remains the best fit.

### Highlighting

CodeEditSourceEditor has a stronger large-document highlighting model:

- `HighlightProviding` abstracts providers.
- `Highlighter` coordinates text storage edits and visible ranges.
- `HighlightProviderState` tracks valid, pending, invalid, and visible ranges.
- Highlight queries are chunked.
- `StyledRangeContainer` merges style overlays by provider priority.

Important files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Highlighting/Highlighter.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Highlighting/HighlightProviderState.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Highlighting/StyledRangeContainer.swift`

CodeEditorPlugin has caching, async highlighting, streaming, viewport-oriented helpers, and adaptive modes, but incremental highlighting still falls back to full highlighting in places.

Recommendation: move toward provider overlays plus visible/valid/pending range tracking.

### Shared Range Storage

CodeEditSourceEditor's reusable rope-backed `RangeStore` is one of its best architectural assets. It is used for style runs and folding state.

Important file:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/RangeStore/RangeStore.swift`

CodeEditorPlugin has line caches and range utilities, but no similarly central run/interval store shared by highlighting, diagnostics, search, annotations, and folds.

Recommendation: add a shared range-run storage layer for editor overlays and use it across features.

### Code Folding

CodeEditSourceEditor separates folding into:

- Model: owns fold state and text edit updates.
- Calculator actor: computes folds asynchronously.
- Storage: uses `RangeStore`.
- Ribbon view: draws fold controls.
- Placeholder attachment: represents collapsed content.

Important files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/LineFolding/LineFoldModel.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/LineFolding/LineFoldCalculator.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/LineFolding/LineFoldStorage.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/LineFolding/LineFoldRibbonView.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/LineFolding/LineFoldPlaceholder.swift`

CodeEditorPlugin has broader provider coverage through `CodeFoldingEngine`, but fold detection is more heuristic and folded content is hidden with attributes. That can be fragile when syntax highlighting and other attributed-string features also write attributes.

Recommendation: replace attribute-hiding folds with stable placeholders/attachments and parser-backed fold ranges where possible.

### Rendering

CodeEditSourceEditor has a more concrete macOS rendering strategy:

- Gutter drawing is dirty-rect based.
- Line numbers are drawn only for visible lines.
- Fold controls are custom drawn and hover-aware.
- Minimap reuses the same text storage and syntax attributes.
- Minimap rendering draws compact colored bars instead of raw full text.

Important files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Gutter/GutterView.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Minimap/MinimapView.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Minimap/MinimapLineFragmentView.swift`

CodeEditorPlugin is more cross-platform, but its minimap is simpler and not syntax-aware.

Recommendation: make the minimap consume existing style runs rather than rendering raw tiny text.

### Configuration And State

CodeEditSourceEditor separates stable configuration from dynamic editor state:

- `SourceEditorConfiguration`: appearance, behavior, layout, peripherals.
- `SourceEditorState`: cursor positions, scroll position, find text, replace text, find panel visibility.

Important files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/SourceEditorConfiguration/SourceEditorConfiguration.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditSourceEditor/Sources/CodeEditSourceEditor/SourceEditorState/SourceEditorState.swift`

CodeEditorPlugin has a powerful `EditorConfiguration`, environment support, callbacks, and service injection, but it could benefit from a typed interaction state object.

Recommendation: add an `EditorInteractionState` for cursor, scroll, find, and fold state.

### Extensibility

CodeEditSourceEditor's extension points are small and practical:

- `HighlightProviding`
- `LineFoldProvider`
- `TextViewCoordinator`
- Completion and jump delegates

CodeEditorPlugin's event system and DI are broader, but heavier.

Recommendation: keep the existing service architecture, but add smaller feature-specific protocols for editor hot-path features.

## CodeEditorPlugin Risks Found During Comparison

- `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift` has incremental highlighting marked as TODO and falls back to full highlighting.
- `Sources/CodeEditorPlugin/Text/TextKit2RenderingOptimizer.swift` contains simplified fragment caching and simulated prefetch work.
- `Sources/CodeEditorPlugin/Performance/OptimizedLineIndexCache.swift` has a simplified multi-line edit path that does not incrementally update the tree.
- `Sources/CodeEditorPlugin/Text/TextKitBridge.swift` has simplified TextKit 2 rendering attribute handling.
- Brace folding is heuristic and can misread braces inside strings or comments.
- XML/HTML folding is regex-based and may mishandle nested same-name tags or edge cases.
- SwiftSyntax token offsets should be audited carefully because SwiftSyntax positions are UTF-8 offsets while `NSRange` is UTF-16 based.

## CodeEditSourceEditor Caveats

CodeEditSourceEditor should not be treated as a drop-in architecture:

- It is macOS/AppKit-only.
- It depends heavily on CodeEditTextView internals.
- It uses Tree-sitter plumbing that would need careful dependency and platform review.
- Some implementation details are lower-level and higher-risk than our current public API posture.
- The repository README describes it as not production-ready.

## Recommended Work Plan

1. Add a shared range-run storage layer for styles, folds, diagnostics, search, and annotations.
2. Rework highlighting around provider overlays and visible/valid/pending range tracking.
3. Evaluate Tree-sitter for non-Swift languages and injected languages.
4. Replace fold hiding attributes with stable placeholders or attachments.
5. Make the minimap syntax-aware by consuming existing style runs.
6. Add `EditorInteractionState` for cursor, scroll, find, and fold state.
7. Replace heuristic fold providers with parser-backed providers where possible.
8. Audit and either complete or remove performance scaffolding that is currently simplified.

## Main Takeaway

CodeEditSourceEditor's strongest lesson is not that we should copy its structure wholesale. The lesson is that editor features should share a semantic and range-oriented core. Parsing, highlighting, folding, diagnostics, minimap rendering, and annotations should all consume the same underlying range/run model instead of each feature rebuilding its own partial view of the document.

## Migration Status (2026-05-07)

Phases 0-6 complete. Phase 7 (Parser-Backed Providers) skipped — Tree-sitter gate (`defer`). Phase 8 (Integration) in progress.

| Phase | Status | Key Deliverable |
|-------|--------|----------------|
| 0 — Gates | Complete | 4 architecture decision docs |
| 1 — Correctness | Complete | UTF-8/UTF-16 fix, stub removal, EditorStateBridge cache |
| 2 — Range Storage | Complete | `RangeStore` (array-backed), `TextEditEventHub` |
| 3 — Highlighting Overlay | Complete | `RangeHighlightProviding`, `VisibleRangeProvider`, `HighlightProviderState`, `StyledRangeContainer` |
| 4 — Interaction State | Complete | `EditorInteractionState` + `EditorCursorPosition`, opt-in binding |
| 5 — Folding | Complete | `FoldStoreElement`, `LineFoldStorage`, `FoldPresentationStrategy`, facade refactor |
| 6 — Syntax-Aware Minimap | Complete | `MinimapStyleDataSource` protocol, `StyledMinimapStyleDataSource` |
| 7 — Parser-Backed | Skipped | Gate B = `defer` (Tree-sitter decision pending) |
| 8 — Integration | In Progress | Build/lint/test matrix, docs, benchmarks |

**Cumulative:** 77 tests across 17 suites. `swift build` clean. `swiftlint` 0 violations.

### New Files Created (57)

- `Documentation/Architecture/` — 5 decision docs + 1 audit
- `Text/RangeStore/` — `RangeStoreElement`, `RangeStoreRun`, `RangeStore`
- `Text/TextEditEventHub.swift`
- `SyntaxHighlighting/` — `RangeHighlightProviding`, `SyntaxHighlighterRangeAdapter`, `VisibleRangeProvider`, `HighlightProviderState`, `StyleElement`, `StyledRangeContainer`
- `Core/EditorInteractionState.swift`
- `Features/` — `FoldStoreElement`, `LineFoldStorage`, `FoldRegionAdapter`, `FoldPresentationStrategy`
- `Layout/MinimapStyleDataSource.swift`
- 8 test files across Core, Features, Layout, SyntaxHighlighting, SwiftUI, Text directories

### Feature Flags

- `EditorConfiguration.Performance.usesRangeBasedHighlighting` (default `false`) — gates range-based highlighting
- `CodeEditor.editorInteractionState(_:)` — opt-in binding modifier
