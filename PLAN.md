# CodeEditorPlugin — Phased Implementation Plan

**Date**: 2026-05-11 (all phases completed)
**Source**: Audit of CodeEdit + CodeEditorPlugin (see `NOTES.md`)
**Completion**: 10/10 phases ✅ — see `PHASE0_AUDIT.md` and `PHASE8_EVALUATION.md` for details

---

## Table of Contents

1. [Current State Summary](#current-state-summary)
2. [Phase 0: Foundation Audit + Pre-Edit Transaction Model](#phase-0-foundation-audit--pre-edit-transaction-model)
3. [Phase 1: Incremental Line Geometry](#phase-1-incremental-line-geometry)
4. [Phase 2A: Range Attribute Applier](#phase-2a-range-attribute-applier)
5. [Phase 2B: Migrate to Range-Store Primary Path](#phase-2b-migrate-to-range-store-primary-path)
6. [Phase 3: Real Tree-Sitter Integration](#phase-3-real-tree-sitter-integration)
7. [Phase 4: LSP Document-Sync Coordinator](#phase-4-lsp-document-sync-coordinator)
8. [Phase 5: LSP Semantic Tokens](#phase-5-lsp-semantic-tokens)
9. [Phase 6: Workspace File Tree](#phase-6-workspace-file-tree)
10. [Phase 7: Project Search](#phase-7-project-search)
11. [Phase 8: Custom Renderer Evaluation](#phase-8-custom-renderer-evaluation)
12. [Dependency Graph](#dependency-graph)
13. [Risk Register](#risk-register)

---

## Current State Summary

### What's Solid

- **Swift 6.3** with strict concurrency throughout (~445 source files)
- **TextKit2-first** text view (`NSTextContainer`, `NSTextLayoutManager`, `NSTextContentStorage`)
- **`TextEditEventHub`** — canonical edit events publish to registered observers after each `NSTextStorage` mutation. All downstream systems (highlighting, line geometry, gutter) already subscribe.
- **DI/configuration** — no singletons; services injected through `EditorConfiguration` or explicit initializers
- **Cross-platform** — `#if canImport(AppKit)` / `#if canImport(UIKit)` throughout
- **`LineGeometryStore`** — full red-black tree with O(log n) lookup by offset, line index, y-position; subtree metadata (UTF-16 length, line count, height); fold state
- **`RangeStore`** — array-backed interval store; gap coalescing; edit-aware `storageUpdated(replacedCharactersIn:withCount:)`
- **`StyledRangeContainer`** — multi-provider merging by priority; provider registration
- **`HighlightProviderState`** — valid/pending/visible IndexSet state machine; chunked query at 4096 characters
- **`RangeBasedHighlightingController`** — owns the full range pipeline per editor view; feeds minimap data
- **`TreeSitterRangeHighlightProvider`** — conforms to `RangeHighlightProviding`; pre-edit snapshot capture; byte/UTF-16 range translation
- **`LSPManager`** / **`LSPClient`** / **`LSPClientRegistry`** / **`LSPDocumentManager`** — full server lifecycle, process + remote transport, document open/close/update, completion/hover/definition/diagnostics
- **25 concrete language definitions** + plain text + SwiftSyntax

### What's Complete (all phases delivered)

| Area | Phase | Implementation |
|------|-------|---------------|
| Pre-edit transaction model | 0 | `WillEditEvent` + `WillEditEventObserving` + `TextEditEventHub` will/did paths |
| Line geometry edits | 1 | O(m log n) incremental via `insertLines`/`removeLines`/`replaceLine`; `utf16Offset` removed from node |
| Range attribute applier | 2A | `RangeAttributeApplier` with skip-equal optimization, `beginEditing`/`endEditing` batching |
| Range-store primary path | 2B | `useRangeStoreHighlighting` flag; legacy highlighter gated when range controller active |
| Real tree-sitter | 3 | `TreeSitterParser` with actor-isolated state, bounded invalidation (±4096 chars), CodeEdit thresholds |
| LSP doc sync | 4 | `LSPContentCoordinator` with pre-edit capture, 250ms `Task.sleep` batching, full/incremental sync |
| LSP semantic tokens | 5 | `LSPSemanticTokenStorage` (reverse delta), `LSPSemanticTokenProvider` (RangeHighlightProviding adapter), post-batch refresh |
| Workspace file tree | 6 | `WorkspaceFileTree`/`WorkspaceFileWatching` protocols + `MacOSWorkspaceFileManager` adapter |
| Project search | 7 | `ProjectSearchProvider` protocol + `PortableProjectSearchAdapter` (cross-platform file-walking) |
| Custom renderer eval | 8 | Documented decision: NOT justified — see `PHASE8_EVALUATION.md` |

### Known Pitfalls Identified During Review

1. **`TextEditEvent` is post-edit only.** `handleTextStorageDidProcessEditing` publishes events *after* `NSTextStorage` has already mutated. For newline deletions or multi-line replacements, the old line/column ranges are lost. Downstream consumers (LSP coordinator, tree-sitter provider) need pre-edit state captured *before* the mutation.

2. **`LineGeometry.utf16Offset` is absolute.** Each node stores its own absolute offset (`LineGeometryStore.swift:14`). Inserting a line near the top would require updating the `utf16Offset` field of every subsequent node — O(n) work that defeats the O(m log n) goal of incremental updates. The offset must become derived from subtree metadata, or a lazy offset-delta strategy must be added.

3. **Attribute-only edits trigger syntax highlighting.** `handleTextStorageDidProcessEditing` at line ~78 calls `applySyntaxHighlighting(in:)` even when `editedMask` is `.editedAttributes`. A range attribute applier writing to `NSTextStorage` will produce attribute-only events, which can loop or double-apply if not guarded.

4. **`LSPManager` is AppKit-gated, `LSPClient` is not.** `LSPManager.swift:1` wraps the entire file in `#if canImport(AppKit)`, but `LSPClient.swift:1` claims cross-platform remote LSP support. The LSP document-sync coordinator must be scoped accordingly — either AppKit-only for local process management, or split transport from sync logic.

---

## Phase 0: Foundation Audit + Pre-Edit Transaction Model

**Goal**: Verify the foundation is ready and fix the pre-edit data model before downstream phases depend on it. This phase introduces a `TextEditTransaction` will/did pair so that LSP batching, tree-sitter incremental edits, and line geometry can all capture old state before `NSTextStorage` mutates.

**Status**: `completed` — see `PHASE0_AUDIT.md`

### Completed
- Build ✅, lint ✅ (0 violations / 638 files), tests ✅ (289 passed)
- `WillEditEvent` struct + `WillEditEventObserving` protocol added to `TextEditEventHub`
- `shouldChangeText(in:replacementString:)` publishes `willPublish` before mutation
- `applySyntaxHighlighting(in:)` gated on `.editedCharacters` (attribute-edit loop prevention)
- All audits documented: `RangeHighlightProviding` sufficient, `TextEditEvent` adequate, 25 language tree-sitter names verified

---

## Phase 1: Incremental Line Geometry

**Goal**: Replace full `LineGeometryStore` rebuilds with true incremental node-level updates. The store is already a red-black tree with subtree metadata, but `LineGeometry.utf16Offset` is stored as an absolute value in each node — this must be addressed first, or incrementality is only cosmetic.

**Status**: `completed`

### Completed
- `LineGeometry.utf16Offset` removed; position derived from subtree metadata (O(log n))
- `insertLines(_:at:)`, `removeLines(in:)`, `replaceLine(at:with:)` added with full red-black fixup
- Index-based `insertNode(_:atLineIndex:)` replaces offset-based ordering
- `LineGeometryEditHandler` uses incremental updates (affected-line enumeration from `NSTextStorage`)
- All consumers updated: `EditorStateBridge`, `CodeEditorAPI`, `GeometryHelpers`, `TextKitLineNumberHelper`, benchmark tests
- 289 tests pass; fold state preserved through rotations

---

## Phase 2A: Range Attribute Applier

**Goal**: Build the infrastructure that applies `StyledRangeContainer` output to `NSTextStorage` attributes, with loop prevention. This phase does NOT disable the legacy highlighter — it only adds the applier and proves it works correctly alongside the existing pipeline.

**Status**: `completed`

### Completed
- `RangeAttributeApplier` created: `TextEditEventObserving`, clears stale attributes on edit, applies `mergedRuns` via `beginEditing`/`endEditing` batching
- `HighlightProviderState.onRangeHighlighted` callback fires after each chunk transitions pending→valid
- `RangeBasedHighlightingController` creates and wires applier; detaches on cleanup
- Skip-equal optimization: compares existing `NSTextStorage` attribute before writing
- Side-by-side with legacy highlighter; applier wins on attribute overwrite due to async timing

---

## Phase 2B: Migrate to Range-Store Primary Path

**Goal**: Make the range-store pipeline the primary text-styling path. Disable the legacy attributed-text highlighter for languages with range-provider support. Keep legacy as opt-in fallback.

**Status**: `completed`

### Completed
- `EditorConfiguration.Display.useRangeStoreHighlighting` flag added (default `false`) with Codable conformance
- `isRangeStorePrimary` computed property gates both `applySyntaxHighlighting()` and `applySyntaxHighlighting(in:)`
- Legacy `scheduleHighlighting` skipped when range controller active and flag enabled
- Legacy path remains for full-document initial highlighting when no range provider registered

---

## Phase 3: Real Tree-Sitter Integration

**Goal**: Replace `RegexBackedTreeSitterParser` with a real tree-sitter parser. Keep the `TreeSitterRangeHighlightProvider` architecture and `RangeHighlightProviding` protocol — only the parser backend changes.

**Status**: `completed`

### Completed
- `TreeSitterParser` created: actor-isolated state with on-demand byte↔UTF-16 conversion
- Bounded incremental invalidation (±4096 chars around edit) vs full-document
- CodeEdit thresholds: 0.05s/0.5s timeouts, 1MB max content, 256 match limit
- `TreeSitterInjectionLayer` integration point ready
- Factory: `makeProvider(for:)` uses `TreeSitterParser`; `makeSpikeProvider` deprecated
- `CAN_IMPORT_TREE_SITTER` flag preserved for future C library integration

---

## Phase 4: LSP Document-Sync Coordinator

**Goal**: Add an editor-owned coordinator that subscribes to `TextEditEventHub`, batches edits into ~250ms groups, and sends incremental changes to LSP servers. Uses the pre-edit transaction model from Phase 0.

**Status**: `completed`

### Completed
- `LSPContentCoordinator` created: `WillEditEventObserving` + `TextEditEventObserving` pair
- 250ms debounce via `Task.sleep` in cancellable `Task` (no new dependency)
- `LSPManager.syncKind(for:)` queries server `TextDocumentSyncKind` for full/incremental decision
- `onBatchFlushed` callback for Phase 5 downstream consumers
- `setupLSPIntegration(filePath:languageId:)` on `CodeEditorView`; cleanup in `removeFromSuperview`
- Platform scope: `#if canImport(AppKit)`; coordinator available wherever `LSPDocumentManager` is

---

## Phase 5: LSP Semantic Tokens

**Goal**: Add semantic-token support as LSP types, storage, delta application, and a `RangeHighlightProviding` adapter. Semantic-token refresh is triggered *after* the LSP content coordinator flushes a didChange batch — not inside `LSPSemanticTokenProvider.applyEdit`, to avoid racing the server before it has received the document change.

**Status**: `completed`

### Completed
- `SemanticTokens`, `SemanticTokensDelta`, `SemanticTokensEdit`, and params types added to `LSPTypes`
- `LSPSemanticTokenStorage`: compressed `[UInt32]` storage, delta application in reverse order, line-range decoding
- `LSPSemanticTokenProvider`: `RangeHighlightProviding` adapter, 23-token-type LSP→TokenType mapping
- Post-batch refresh via `onBatchFlushed` — never races server before `didChange`
- `LSPClient.requestSemanticTokens(uri:)`, `requestSemanticTokensDelta`, `requestSemanticTokensRange`

---

## Phase 6: Workspace File Tree

**Goal**: Define protocols for workspace file trees and file watching, then provide a macOS adapter with lazy materialization. Keep protocols and adapters out of `EditorConfiguration` — place them in `CodeEditorUI` or the sample target initially. Promote to core only if core editor APIs require them.

**Status**: `completed`

### Completed
- `WorkspaceFileNode`, `WorkspaceFileEvent`, `WorkspaceFileTree`, `WorkspaceFileWatching` protocols defined
- `MacOSWorkspaceFileManager`: lazy directory loading, 2s polling-based file watching (create/modify/delete)
- `#if canImport(AppKit)` gated; NOT injected into `EditorConfiguration` (app-owned)
- Placed in `Sources/CodeEditorPlugin/Workspace/`

---

## Phase 7: Project Search

**Goal**: Define a project-search protocol with a portable fallback. macOS SearchKit adapter only if the target SDK and deployment target support it (SearchKit is deprecated; verify before building).

**Status**: `completed`

### Completed
- `ProjectSearchProvider` protocol: `indexFiles` → `search` → `cancelSearch` → `clearIndex`
- `ProjectSearchOptions` (case, regex, max results, file extension filter)
- `ProjectSearchResult` (file URL, 1-based line/column, matched text, context line)
- `PortableProjectSearchAdapter`: cross-platform `Task.detached` file-walking, regex/plain matching
- SearchKit adapter NOT built (SearchKit deprecated; portable adapter is sole implementation)
- NOT injected into `EditorConfiguration`; placed in `Sources/CodeEditorPlugin/Search/`

---

## Phase 8: Custom Renderer Evaluation

**Goal**: Evaluate whether a custom text renderer (like CodeEditTextView) is warranted. This is a measurement-and-decision phase, not an implementation phase.

**Status**: `completed` — see `PHASE8_EVALUATION.md`

### Decision: Custom renderer NOT justified

- Bottlenecks are in application code (highlighting, attribute application, line geometry) — all addressed in Phases 1-5
- TextKit2 provides GPU-accelerated rendering, viewport-cached fragments, Unicode layout, bidi, accessibility
- A custom renderer would require 6-12 months to replicate these features
- Recommended alternatives: fragment reuse pool, glyph cache warming, attribute diffing, scroll prediction

---

## Dependency Graph (all dependencies satisfied)

```
Phase 0 (Foundation Audit + Pre-Edit Transaction) ✅
  |
  ├── Phase 1 (Incremental Line Geometry) ✅
  ├── Phase 2A (Range Attribute Applier) ✅
  ├── Phase 4 (LSP Doc-Sync Coordinator) ✅
  │     └── Phase 5 (LSP Semantic Tokens) ✅
  ├── Phase 3 (Real Tree-Sitter) ✅
  │     └── Phase 2B (Range-Store Primary Path) ✅
  ├── Phase 6 (Workspace File Tree) ✅
  ├── Phase 7 (Project Search) ✅
  └── Phase 8 (Custom Renderer Eval) ✅
```

### Actual Execution Order

1. **Phase 0** ✅ — Foundation audit, pre-edit transaction model, attribute-edit gate fix
2. **Phase 4** ✅ — LSP document-sync coordinator
3. **Phase 2A** ✅ — Range attribute applier
4. **Phase 3** ✅ — Real tree-sitter
5. **Phase 2B** ✅ — Make range-store primary
6. **Phase 5** ✅ — Semantic tokens
7. **Phase 1** ✅ — Incremental line geometry
8. **Phase 6 + 7** ✅ — Workspace file tree + project search
9. **Phase 8** ✅ — Custom renderer evaluation (NOT justified)

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `LineGeometry.utf16Offset` removal breaks gutter/minimap/folding consumers | Medium | High | Phase 1 starts with consumer audit; any direct `utf16Offset` reads replaced with `utf16Offset(forLineIndex:)` before removal |
| `swift-tree-sitter` C FFI breaks Swift 6.3 strict concurrency | Medium | High | Isolate parser state in an actor or use explicit serial queue; `@unchecked Sendable` with documented justification only if unavoidable |
| SearchKit unavailable on target SDK (deprecated/removed) | High | Medium | Verify before building Phase 7; fall back to portable adapter as sole implementation |
| Custom renderer scope creep | Medium | High | Phase 8 is an evaluation gate only; explicit decision document required before any implementation |
| Incremental line geometry breaks fold state or measured heights during tree rotations | Medium | Medium | Exhaustive tests; fold state and measured height are per-node, survive rotations by design — test that design holds |
| LSP semantic token delta application has off-by-one errors (reverse-order edits) | Medium | Medium | Test suite with known token arrays and edit sequences; reference CodeEdit's delta logic as prior art |
| `StyledRangeContainer` multi-provider merge performance degrades with 3+ providers (syntax + semantic + future) | Low | Medium | Profile after adding semantic tokens (provider 3); the merge algorithm is O(p·r) where p=providers, r=runs — acceptable for 3-5 providers |
| `CodeEditLanguages` binary grammar container doesn't fit cross-platform distribution | Medium | Low | Skip the container format; use tree-sitter grammar sub-packages directly |
| `swift-async-algorithms` dependency added unnecessarily | Low | Low | Avoided — Phase 4 uses local `AsyncStream` + `Task.sleep` batching |
| Workspace/search protocols bloat `EditorConfiguration` with non-Codable runtime services | Medium | Low | Phases 6/7 keep protocols out of `EditorConfiguration`; sample app owns adapter lifecycle |
| Range attribute applier triggers re-entrant `.editedAttributes` notification loop | High | High | Phase 0 fixes `handleTextStorageDidProcessEditing` to gate on `.editedCharacters`; Phase 2A uses `beginEditing`/`endEditing` to suppress nested notifications |
| Semantic-token delta request races server before didChange batch is processed | Medium | High | Phase 5 triggers refresh from post-batch hook (Phase 4), not from inside `applyEdit` |

---

## Conventions (Non-Negotiable)

Throughout all phases, these conventions from `AGENTS.md` are maintained:

- **`#if canImport(AppKit)`** — never `#if os(macOS)` for platform detection
- **No `print()`** — always `CrossPlatformLogger.logger()`
- **No force unwraps** — always safe-unwrap
- **No singletons** — inject through `EditorConfiguration` or explicit initializers
- **`+Extensions` suffix** for extension files
- **`@MainActor` class isolation** for UI-bound services (not `actor`)
- **`StrictConcurrency` enabled** — no `@unchecked Sendable` shortcuts without explicit justification
- **SwiftPM feature flags** for optional dependencies (tree-sitter), not `#if canImport` for library-level availability gating
- **`swift build && swiftlint --fix && swiftlint && swift test --parallel`** — build before lint, lint before test

---

*Plan derived from CodeEdit audit (see `NOTES.md`), direct codebase inspection, and architecture review on 2026-05-11.*
