# CodeEditorPlugin — Phased Implementation Plan

**Date**: 2026-05-11 (revised after architecture review)
**Source**: Audit of CodeEdit + CodeEditorPlugin (see `NOTES.md`)

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

### What's Incomplete

| Area | Current Status | Target |
|------|---------------|--------|
| Line geometry edits | Full rebuild on every character edit (O(n)) | Incremental node updates (O(m log n)) |
| Range highlighting | Opt-in minimap feed; legacy attributed highlighter still active | Primary text-styling path via attribute applier |
| Tree-sitter | Regex-backed spike (`RegexBackedTreeSitterParser`); full-document invalidation | Real C parser; incremental edits; injection layers |
| LSP doc sync | Manual `updateDocument()` calls; no editor integration | `TextEditEventHub`-backed batching coordinator; 250ms groups |
| LSP semantic tokens | Not present | Storage, delta application, range query; `RangeHighlightProviding` adapter |
| Workspace | `URL` property only | Protocol + lazy file tree + FSEvents adapter |
| Project search | Not present | Protocol + portable fallback; SearchKit only if verified viable on target SDK |
| Pre-edit transaction model | None; `TextEditEvent` published *after* storage mutation | Will/did event pair with pre-mutation snapshot of old range, replacement text, and line/column bounds |

### Known Pitfalls Identified During Review

1. **`TextEditEvent` is post-edit only.** `handleTextStorageDidProcessEditing` publishes events *after* `NSTextStorage` has already mutated. For newline deletions or multi-line replacements, the old line/column ranges are lost. Downstream consumers (LSP coordinator, tree-sitter provider) need pre-edit state captured *before* the mutation.

2. **`LineGeometry.utf16Offset` is absolute.** Each node stores its own absolute offset (`LineGeometryStore.swift:14`). Inserting a line near the top would require updating the `utf16Offset` field of every subsequent node — O(n) work that defeats the O(m log n) goal of incremental updates. The offset must become derived from subtree metadata, or a lazy offset-delta strategy must be added.

3. **Attribute-only edits trigger syntax highlighting.** `handleTextStorageDidProcessEditing` at line ~78 calls `applySyntaxHighlighting(in:)` even when `editedMask` is `.editedAttributes`. A range attribute applier writing to `NSTextStorage` will produce attribute-only events, which can loop or double-apply if not guarded.

4. **`LSPManager` is AppKit-gated, `LSPClient` is not.** `LSPManager.swift:1` wraps the entire file in `#if canImport(AppKit)`, but `LSPClient.swift:1` claims cross-platform remote LSP support. The LSP document-sync coordinator must be scoped accordingly — either AppKit-only for local process management, or split transport from sync logic.

---

## Phase 0: Foundation Audit + Pre-Edit Transaction Model

**Goal**: Verify the foundation is ready and fix the pre-edit data model before downstream phases depend on it. This phase introduces a `TextEditTransaction` will/did pair so that LSP batching, tree-sitter incremental edits, and line geometry can all capture old state before `NSTextStorage` mutates.

**Status**: `pending`

### Steps

1. **Run build, lint, then test** — per repo guidance (`AGENTS.md`):
   ```
   swift build && swiftlint --fix && swiftlint && swift test --parallel
   ```
   Confirm zero regressions against current `main`. Build must succeed before lint (SwiftLint checks source, not build artifacts). Lint must pass before tests (warnings are errors in strict mode). Tests run last.

2. **Design the pre-edit transaction model**
   - Introduce `TextEditTransaction` containing:
     - `preEditRange: NSRange` — the range that will be replaced (UTF-16)
     - `replacementText: String` — the new text being inserted
     - `preEditLineRange: ClosedRange<Int>` — the affected line numbers before the edit
     - `preEditSource: String?` — optional snapshot of the old source in the affected region (captured lazily, only when needed)
   - Add a `willApplyEdit(_:)` callback point on `TextEditEventHub` — published from `shouldChangeText(in:replacementString:)` or equivalent NSTextStorage delegate hook *before* the mutation occurs.
   - The existing `textStorageDidApplyEdit(_:)` path (post-edit `TextEditEvent`) remains for consumers that only need the post-edit state.
   - Add a `willEditEvent` observer protocol alongside the existing `TextEditEventObserving`.

3. **Audit `RangeHighlightProviding` protocol**
   - Confirm the protocol surface is sufficient for:
     - Real tree-sitter (incremental edits, injection layers, cancellation)
     - LSP semantic tokens (delta edits, compressed storage — note: `applyEdit` timing constraint, see Phase 5)
     - Any future provider (spell-check, AI suggestions)
   - If `willApplyEdit` needs to be added to the protocol, do it in this phase.

4. **Audit `TextEditEvent` struct**
   - Confirm it carries enough data for LSP edit batching: pre-edit range, change-in-length, document length, edited-characters flag.
   - With the pre-edit transaction model in place, the LSP coordinator can capture the old range content from the `willApply` side rather than reconstructing it from the post-edit state.

5. **Audit `LanguageDescriptor` tree-sitter names**
   - Confirm all 25 languages have correct `treeSitterName` mappings for grammar names used by the chosen tree-sitter Swift package.
   - Document any missing grammars — these languages will fall back to regex until grammars are added.

6. **Document the attribute-applier gap**
   - Trace `StyledRangeContainer.mergedRuns(in:)` → `NSTextStorage.addAttributes(_:range:)` path.
   - Identify where the hook should go (likely a new coordinator registered with `TextEditEventHub`, separate from the existing `handleTextStorageDidProcessEditing` handler).
   - Key constraint: the attribute applier must NOT trigger the legacy syntax-highlighting path. The current `handleTextStorageDidProcessEditing` calls `applySyntaxHighlighting(in:)` for both `.editedCharacters` and `.editedAttributes` edits. The applier must either use `textStorage?.beginEditing()` / `endEditing()` to suppress nested notifications, or the legacy path must be gated on `editedMask.contains(.editedCharacters)`.

### Deliverables
- Build/lint/test passing baseline
- `TextEditTransaction` will/did event pair integrated into `TextEditEventHub`
- Protocol audit notes (any changes to `RangeHighlightProviding`)
- Attribute-applier design sketch with loop-prevention strategy
- Updated `handleTextStorageDidProcessEditing` to gate syntax highlighting on `.editedCharacters` (not `.editedAttributes`)

---

## Phase 1: Incremental Line Geometry

**Goal**: Replace full `LineGeometryStore` rebuilds with true incremental node-level updates. The store is already a red-black tree with subtree metadata, but `LineGeometry.utf16Offset` is stored as an absolute value in each node — this must be addressed first, or incrementality is only cosmetic.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift`

### Critical Design Issue

`LineGeometry.utf16Offset` (line 14 of `LineGeometryStore.swift`) is an absolute value stored in each node. Inserting a line at index 5 would require updating the `utf16Offset` field of every subsequent node — O(n) work that defeats the goal of O(m log n) incremental edits. The red-black tree's subtree metadata (`subtreeUtf16Length`) already tracks the cumulative UTF-16 length of each subtree. Solution options:

- **Option A (preferred):** Remove `utf16Offset` from `LineGeometry` entirely. Derive every offset query from subtree metadata during tree traversal. The existing `utf16Offset(forLineIndex:)` and `lineIndex(forUtf16Offset:)` methods already walk the tree accumulating left-subtree lengths — they just need to stop reading the stored `utf16Offset` field and use purely accumulated metadata. This is a refactor of lookup methods, not a tree-structure change.
- **Option B:** Keep absolute offsets but add a lazy invalidation strategy: mark nodes after the edit point as "dirty" and recompute offsets on-demand during the next lookup. Adds complexity; avoid unless Option A proves problematic.

### Steps

1. **Remove or derive `LineGeometry.utf16Offset` from subtree metadata**
   - Evaluate whether any external code reads `utf16Offset` directly. Likely consumers: gutter rendering, minimap, folding, y-position calculations.
   - If consumers exist, provide a lookup method on `LineGeometryStore` instead (already exists: `utf16Offset(forLineIndex:)`).
   - Update `LineGeometry` to omit `utf16Offset` (or make it a computed property derived from the store).
   - Re-run all tests — this is a structural change that must not break existing offset-dependent features.

2. **Add incremental mutation methods to `LineGeometryStore`**
   - `insertLines(_:at:)` — insert one or more `LineGeometry` values at a line index. Each new node's metadata is local (length, height); offsets are derived from tree position.
   - `removeLines(in:)` — remove a range of line indices.
   - `replaceLine(at:with:)` — replace a single line's geometry (for height updates; fold changes via `setFolded` already exist).
   - Each method must maintain red-black invariants and propagate subtree metadata upward.
   - Each method is O(m log n) for m affected lines.
   - Add focused tests in `LineGeometryStoreTests` (including insertion at index 0, deletion of first line, etc.).

3. **Update `LineGeometryEditHandler.textStorageDidApplyEdit(_:)`**
   - Instead of `textView?.rebuildLineGeometryStoreFromCurrentTextStorage()`, compute the affected line range from the pre-edit transaction (available via Phase 0's `willApplyEdit` if needed).
   - Use `NSTextStorage` / `NSString` line enumeration only for the affected region.
   - Insert/remove/replace only the lines that changed.
   - Preserve measured heights and fold state for unaffected lines — these are per-node properties that survive tree rotations.

4. **Remove full-rebuild calls from `CodeEditorView` property setters**
   - `CodeEditorView+SetupExtensions.swift` — the initial `setupLineGeometryStore()` still needs a full build (cold start).
   - The `string`/`text`/`attributedText` property setters currently call `rebuildLineGeometryStoreFromCurrentTextStorage()` — these should be replaced with a full rebuild ONLY when the entire text storage is replaced wholesale (setter path), while incremental edits go through the event hub → handler path.
   - `CodeEditorView+TextKitExtensions.swift` line 104 — same pattern.
   - Ensure the two paths (bulk replacement vs incremental edit) don't conflict.

5. **Performance benchmark**
   - Instrument with os_signpost or a simple timing test.
   - Verify O(m log n) characteristic on large files (10k+ lines) with small edits.
   - Compare against the current O(n) rebuild baseline.

6. **Fold state preservation**
   - When lines shift due to insertions/deletions above them, fold state should move with the line content.
   - Add tests: fold a line, insert text above it, verify the folded line is still folded and at the correct index.
   - Verify fold state survives tree rotations during insertion/deletion fixup.

### Deliverables
- `LineGeometry.utf16Offset` removed or derived from subtree metadata
- `LineGeometryStore` incremental mutation methods with tests
- `LineGeometryEditHandler` using incremental updates
- Full-rebuild calls removed from incremental-edit paths
- Performance benchmark showing O(m log n) improvement
- Fold state preservation tests

---

## Phase 2A: Range Attribute Applier

**Goal**: Build the infrastructure that applies `StyledRangeContainer` output to `NSTextStorage` attributes, with loop prevention. This phase does NOT disable the legacy highlighter — it only adds the applier and proves it works correctly alongside the existing pipeline.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/StyledRangeContainer.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightProviderState.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeHighlightProviding.swift`

### Steps

1. **Fix attribute-only edit handling in `handleTextStorageDidProcessEditing`**
   - Currently, `applySyntaxHighlighting(in:)` is called regardless of whether the edit changed characters or only attributes (`CodeEditorView+SyntaxHighlightingExtensions.swift` line ~78).
   - Gate the `applySyntaxHighlighting` call on `editedMask.contains(.editedCharacters)` — attribute-only edits should not trigger re-highlighting.
   - This is a prerequisite: without this fix, the range attribute applier's writes to `NSTextStorage` will trigger `handleTextStorageDidProcessEditing` again with `.editedAttributes`, creating a potential loop.

2. **Build the `RangeAttributeApplier`**
   - Create `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift`.
   - Conforms to `TextEditEventObserving`.
   - On `textStorageDidApplyEdit`: if `.editedCharacters`, clear attributes in the edited range; if `.editedAttributes`, no-op (the applier itself produced those).
   - Subscribes to `HighlightProviderState` valid-set changes via a callback or delegate.
   - When ranges transition from pending→valid, reads `StyledRangeContainer.mergedRuns(in:)` and calls `NSTextStorage.addAttributes(_:range:)` / `removeAttribute(_:range:)`.
   - Maps `StyleElement.capture` → platform color/font attributes via `TokenType.adaptiveColor`.
   - Batches attribute applications within `textStorage?.beginEditing()` / `endEditing()` to suppress nested `.editedAttributes` notifications.
   - Skips already-correct ranges (compares prospective attributes against current `NSTextStorage` attributes before applying).

3. **Wire into `RangeBasedHighlightingController`**
   - Controller creates the applier on init.
   - Applier receives a callback from `HighlightProviderState` when ranges transition from pending→valid.
   - Controller already has the `container` — pass it to the applier.
   - The applier registers with `textEditEventHub` independently from the controller (the controller already subscribes for its own purposes).

4. **Test side-by-side with legacy highlighter**
   - Run with both legacy syntax highlighting AND range attribute applier active.
   - Verify no double-application (legacy writes one set of attributes, applier overwrites with another — last writer wins, should be consistent).
   - Snapshot tests comparing output with and without the applier.
   - Verify no notification loops.

### Deliverables
- Fixed `handleTextStorageDidProcessEditing` (`.editedCharacters` gate)
- `RangeAttributeApplier` component with loop prevention
- Integration with `RangeBasedHighlightingController`
- Side-by-side tests with legacy highlighter
- Snapshot tests for attribute correctness

---

## Phase 2B: Migrate to Range-Store Primary Path

**Goal**: Make the range-store pipeline the primary text-styling path. Disable the legacy attributed-text highlighter for languages with range-provider support. Keep legacy as opt-in fallback.

**Status**: `pending`

**Dependencies**: Phase 2A (applier must be stable before legacy is disabled).

### Steps

1. **Add feature flag for range-store primary highlighting**
   - `EditorConfiguration.display.useRangeStoreHighlighting` (default `false` initially, flipped to `true` after validation).
   - Per-language override: languages with tree-sitter support use range highlighting; others use legacy.

2. **Disable legacy highlighter when range path is active**
   - In `applySyntaxHighlighting()` and `applySyntaxHighlighting(in:)`, check the feature flag.
   - When range-store highlighting is primary, skip the `syntaxService.scheduleHighlighting` calls for character edits (the range applier handles those).
   - Keep the legacy path for full-document initial highlighting if no range provider is registered.

3. **Incremental attribute update strategy**
   - On document edits, `StyledRangeContainer.storageUpdated()` already adjusts stored ranges.
   - The applier responds to edits by clearing attributes only in the edited range, then `HighlightProviderState` re-queries visible invalid ranges and the applier re-applies.
   - Avoid clearing/repainting the entire visible viewport on each keystroke.
   - Measure: does the 4096-character chunking in `HighlightProviderState` cause visible flicker for edits near the chunk boundary? If so, reduce chunk size or add a "near-edit" priority band.

4. **Test and benchmark**
   - Visual regression: snapshot tests comparing legacy vs range-store output (should be identical for regex-backed languages).
   - Performance: large file typing latency before/after.
   - Correctness: verify no missing highlights, no stale highlights after edits.
   - Verify the applier does not trigger re-entrant highlighting.

### Deliverables
- Feature flag for range-store primary path
- Legacy highlighter gated behind flag for range-backed languages
- Performance benchmarks
- Full regression test suite

---

## Phase 3: Real Tree-Sitter Integration

**Goal**: Replace `RegexBackedTreeSitterParser` with a real tree-sitter parser. Keep the `TreeSitterRangeHighlightProvider` architecture and `RangeHighlightProviding` protocol — only the parser backend changes.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterRangeHighlightProvider.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterCaptureMap.swift`
- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift`
- `Package.swift`

### Steps

1. **Add tree-sitter dependency to `Package.swift`**
   - Use a Swift Package Manager tree-sitter wrapper (e.g., a thin C FFI layer or a community package providing `TSTree`, `TSParser`, `TSQuery` bindings).
   - Include tree-sitter runtime + per-language grammar packages.
   - **Gate by SwiftPM feature flag** (`TreeSitterFeature`), NOT by `#if canImport(AppKit)`. The tree-sitter C library compiles on Linux and can be used for headless highlighting. Platform gating should only apply if the chosen grammar distribution is macOS-only. Use `#if canImport(TreeSitter)` or the feature flag for conditional compilation.
   - Document which platforms are supported by the chosen wrapper.

2. **Implement `TreeSitterParser` (real) conforming to `TreeSitterParserProtocol`**
   - Owns parser state (`TSTree`, `TSParser`, `TSQuery` per capture name).
   - `setLanguage(_:)` — loads grammar, compiles queries for highlight captures.
   - `parse(source:)` — full parse, run queries, return `TreeSitterParseResult`.
   - `applyEdit(startByte:oldEndByte:newEndByte:)` — incremental edit via `ts_tree_edit`; return invalidated byte ranges.
   - Support cancellation via `Task.isCancelled` checks during long parses.
   - Replay pending edits if edits arrive during a running parse (queue edits, apply after current parse completes).
   - Use an actor or explicit serial queue for parser state (C tree-sitter objects are not Sendable).

3. **Adopt CodeEdit thresholds (as initial defaults)**
   - `matchLimit = 256`
   - `parserTimeout = 0.05s`
   - `maxSyncEditLength = 1024`
   - `maxSyncContentLength = 1_000_000`
   - `maxSyncQueryLength = 4096`
   - `charsToReadInBlock = 4096`
   - `longParseTimeout = 0.5s`
   - `taskSleepDuration = 10ms`
   - Tune with benchmarks after integration. Document these as starting points, not final values.

4. **Add injection layer support**
   - Primary language layer + injected language layers (e.g., JS in HTML, SQL in PHP, CSS in HTML).
   - Injections defined per language via `LanguageDescriptor` or query metadata.
   - Query results merged across layers with primary taking precedence at overlapping ranges.
   - Injection boundaries determined by tree-sitter query predicates (`#set!`, `injection.content`).

5. **Update `TreeSitterRangeHighlightProvider` factory**
   - Rename `makeSpikeProvider(for:)` → `makeProvider(for:)`.
   - Switch from `RegexBackedTreeSitterParser()` to `TreeSitterParser()`.
   - Add a feature flag: `TreeSitterProviderFeature.realParserEnabled` (default `false` until validated).
   - Fallback to regex for languages without tree-sitter grammar support.
   - The provider itself does not change — only the parser backend swaps.

6. **Byte ↔ UTF-16 correctness**
   - Preserve existing `byteRange(forUTF16Range:in:)` and `stringRange(forByteRange:in:)` helpers.
   - Add exhaustive tests for emoji (multi-UTF16), surrogate pairs, composed characters (é, 🌍).
   - Verify incremental edit byte ranges are correct after multi-byte insertions and deletions.
   - Test edge case: deleting a multi-byte character spanning the edit boundary.

7. **Remove or archive `RegexBackedTreeSitterParser`**
   - Keep as a test double or remove entirely once real parser is stable.
   - Update any tests that depend on the regex behavior to use either the real parser (integration) or a mock (unit).

### Deliverables
- Real `TreeSitterParser` implementing `TreeSitterParserProtocol`
- SwiftPM feature flag gating (not `canImport(AppKit)`)
- Incremental edit support with byte-range invalidation
- Injection layer support
- Cancellation and pending-edit replay
- UTF-16/byte boundary tests
- Regex-backed parser archived or removed

---

## Phase 4: LSP Document-Sync Coordinator

**Goal**: Add an editor-owned coordinator that subscribes to `TextEditEventHub`, batches edits into ~250ms groups, and sends incremental changes to LSP servers. Uses the pre-edit transaction model from Phase 0.

**Status**: `pending`

**Platform scope**: The document-sync coordinator itself is platform-agnostic (it observes edit events and calls `LSPDocumentManager`). Local LSP process management remains AppKit-only (`LSPManager` is already gated). Remote LSP connections (via `LSPClient.transport`) work on all platforms. The coordinator should be available wherever `LSPDocumentManager` is available.

**Key files**:
- `Sources/CodeEditorPlugin/LSP/LSPManager.swift` (AppKit only)
- `Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift`
- `Sources/CodeEditorPlugin/LSP/LSPClient.swift` (cross-platform remote, AppKit for local)
- `Sources/CodeEditorPlugin/Text/TextEditEventHub.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`

### Steps

1. **Design and implement `LSPContentCoordinator`**
   - New file: `Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift`.
   - Conforms to the `willApplyEdit` observer protocol (Phase 0) to capture pre-edit state.
   - Also conforms to `TextEditEventObserving` (post-edit) to know when to batch and flush.
   - Registers with `CodeEditorView.textEditEventHub`.
   - On `willApplyEdit`: snapshots the old source string (or just the affected range content) and old line/column range.
   - On `textStorageDidApplyEdit`: computes `TextDocumentContentChangeEvent` from pre-edit snapshot + post-edit state.
   - Pushes change events into a batcher (not directly into `LSPDocumentManager`).

2. **Implement edit batching (no external dependency)**
   - Use a local `AsyncStream` continuation + `Task.sleep` pattern for the ~250ms debounce window. Avoid adding `swift-async-algorithms` unless profiling proves the hand-rolled batcher is insufficient.
   - On each `textStorageDidApplyEdit`: append the change event to a buffer, (re)start the ~250ms timer.
   - When the timer fires: flush all buffered changes as a single `textDocument/didChange` notification with an array of `TextDocumentContentChangeEvent` values.
   - Falls back to full-document sync when the cumulative edit count or affected byte range exceeds a threshold (e.g., >50 edits or >50% of document touched).
   - Respects server `TextDocumentSyncKind` (None / Full / Incremental) — read from `LSPClient.serverCapabilities`.

3. **Integrate with `LSPDocumentManager`**
   - Coordinator calls `documentManager.updateDocument(filePath:content:changes:)` with batched changes.
   - Document version increments per batch, not per keystroke.
   - Coordinator is created per editor view → per document.
   - **Post-batch hook**: after a batch is flushed, the coordinator publishes a notification or calls a callback so that downstream systems (semantic tokens, diagnostics) can react to the known server-side document version.

4. **Pre-edit range capture (using Phase 0 model)**
   - The `willApplyEdit` observer captures the old range text BEFORE `NSTextStorage` mutates.
   - This is critical for newline deletions: after `\n` is deleted, the lines merge and the pre-edit line/column boundaries are lost.
   - Store old (range, source) pairs keyed by a monotonically increasing edit sequence number.

5. **Wire into `CodeEditorView` setup**
   - `CodeEditorView.setupLSPIntegration()` (new method in `+SetupExtensions`).
   - Creates `LSPContentCoordinator` when an `LSPManager` is configured.
   - Coordinator detaches on view deallocation.

6. **Server capabilities respect**
   - During LSP `initialize`, parse `ServerCapabilities.textDocumentSync`.
   - If server only supports full sync, skip incremental change computation entirely.
   - If server supports `TextDocumentSyncKind.Incremental`, use incremental change events.
   - Store sync kind in `LSPClient` state.

### Deliverables
- `LSPContentCoordinator` with pre-edit + post-edit observation
- 250ms edit batching via `AsyncStream` + `Task.sleep` (no new dependency)
- Full vs incremental sync based on server capabilities
- Post-batch flush hook for downstream consumers
- Integration with `CodeEditorView` lifecycle
- Platform scope: coordinator available wherever `LSPDocumentManager` is; local process management stays AppKit-only

**Dependency**: Phase 4 depends on Phase 0 (pre-edit transaction model). It otherwise depends only on `TextEditEventHub` (exists) and `LSPDocumentManager` (exists).

---

## Phase 5: LSP Semantic Tokens

**Goal**: Add semantic-token support as LSP types, storage, delta application, and a `RangeHighlightProviding` adapter. Semantic-token refresh is triggered *after* the LSP content coordinator flushes a didChange batch — not inside `LSPSemanticTokenProvider.applyEdit`, to avoid racing the server before it has received the document change.

**Status**: `pending`

**Dependencies**: Phase 4 (LSP doc-sync coordinator with post-batch hook) and Phase 2A (range attribute applier). Semantic tokens are a third provider in `StyledRangeContainer` (priority -1).

**Key files**:
- `Sources/CodeEditorPlugin/LSP/LSPTypes.swift`
- `Sources/CodeEditorPlugin/LSP/LSPClient.swift`
- New: `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenStorage.swift`
- New: `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift`

### Steps

1. **Extend `LSPTypes.swift` with semantic-token types**
   - `SemanticTokensLegend` (token types, token modifiers).
   - `SemanticTokens` (result ID, data array of u32).
   - `SemanticTokensDelta` (result ID, edits array).
   - `SemanticTokensEdit` (start, deleteCount, data).
   - `SemanticTokensRangeParams` / `SemanticTokensRangeResult`.
   - Request methods: `textDocument/semanticTokens/full`, `textDocument/semanticTokens/full/delta`, `textDocument/semanticTokens/range`.

2. **Add semantic-token capability to `ClientCapabilities`**
   - `textDocument.semanticTokens` with `dynamicRegistration`, `requests` (range, full, delta).
   - `TokenFormat.relative`.
   - Advertise these during LSP `initialize`.

3. **Implement `LSPSemanticTokenStorage`**
   - Stores compressed token data arrays (5 integers per token: deltaLine, deltaStartChar, length, tokenType, tokenModifiers).
   - Decodes tokens for a given line range into `(line, startChar, length, type, modifiers)` tuples.
   - Applies `SemanticTokensEdit` (delta) in reverse order (last edit first, to preserve earlier edit indices).
   - Returns invalidated line ranges after delta application.
   - Thread-safe: read-only queries from main actor, writes from LSP response handler (which may be on a different actor/queue).
   - Use a lock or actor for the storage.

4. **Implement `LSPSemanticTokenProvider` conforming to `RangeHighlightProviding`**
   - `setUp(textView:language:)` — request full semantic tokens from the server for the document.
   - `queryHighlights(textView:range:)` — decode tokens intersecting the range, convert to `HighlightedToken` with token type mapping.
   - `applyEdit(textView:range:delta:)` — **important**: does NOT directly request a delta from the server. Instead, it registers the invalidated line range and returns it. The actual delta request happens in step 5.
   - `willApplyEdit` — no-op (LSP server manages its own state; we capture pre-edit state in the coordinator).
   - Register with `StyledRangeContainer` at priority -1 (higher than syntax token priority 0).

5. **Semantic-token refresh ordering (critical)**
   - The `LSPSemanticTokenProvider` does NOT call the server inside `applyEdit`.
   - Instead, it subscribes to the `LSPContentCoordinator`'s post-batch flush hook (Phase 4).
   - After a didChange batch is sent and the server acknowledges it, the provider:
     - If the server supports deltas: calls `requestSemanticTokensDelta(uri:previousResultId:)` with the last known result ID.
     - If the server does not support deltas: calls `requestSemanticTokens(uri:)` for a full refresh.
   - Applies the response to `LSPSemanticTokenStorage`.
   - Invalidates the affected ranges in `HighlightProviderState`, which triggers re-query → `StyledRangeContainer` → attribute applier.
   - This ensures the server has processed the document change before we ask for updated tokens.

6. **Wire into `LSPManager` and `LSPClient`**
   - `LSPClient.requestSemanticTokens(uri:)` → full token array.
   - `LSPClient.requestSemanticTokensDelta(uri:previousResultId:)` → delta.
   - `LSPClient.requestSemanticTokensRange(uri:range:)` → range-limited tokens.
   - Handle `textDocument/semanticTokens` responses in `LSPClient.handleResponse`.

7. **Token type mapping**
   - Map LSP semantic token types (e.g., "namespace", "class", "enum", "function", "variable", "parameter", "typeParameter") to `TokenType`.
   - Map modifier flags (e.g., "declaration", "definition", "readonly", "static", "deprecated") to `TokenType` variants or additional style attributes (bold, italic, underline).
   - Define the legend per language or use the server-returned legend from `initialize` response.

### Deliverables
- Full LSP semantic-token type definitions in `LSPTypes`
- `LSPSemanticTokenStorage` with delta application
- `LSPSemanticTokenProvider` as a `RangeHighlightProviding` adapter
- Post-batch refresh ordering (no race with didChange)
- Token type mapping to `TokenType`
- Integration with `LSPClient` request/response handling
- Tests for delta application edge cases (reverse-order edits, overlapping edits)

---

## Phase 6: Workspace File Tree

**Goal**: Define protocols for workspace file trees and file watching, then provide a macOS adapter with lazy materialization. Keep protocols and adapters out of `EditorConfiguration` — place them in `CodeEditorUI` or the sample target initially. Promote to core only if core editor APIs require them.

**Status**: `pending`

**Key files**:
- New: `Sources/CodeEditorUI/Workspace/WorkspaceFileTreeProtocol.swift` (or `CodeEditorPlugin/Workspace/` if needed by core)
- New: `Sources/CodeEditorPlugin/Workspace/MacOSWorkspaceFileManager.swift`
- `Sources/CodeEditorSample/` — sample integration

### Steps

1. **Define `WorkspaceFileTree` protocol**
   - `var root: WorkspaceFileNode { get }`
   - `func children(of: WorkspaceFileNode) -> [WorkspaceFileNode]`
   - `func isDirectory(_: WorkspaceFileNode) -> Bool`
   - `func fileURL(for: WorkspaceFileNode) -> URL`
   - Lazy materialization: only root children loaded initially; deeper nodes loaded on demand.

2. **Define `WorkspaceFileWatching` protocol**
   - `func startWatching(root: URL) async throws`
   - `func stopWatching()`
   - Async stream of `WorkspaceFileEvent` (created, modified, deleted, renamed).
   - Repair strategy: only refresh already-cached directory nodes on FSEvents; don't eagerly load new directories.

3. **Implement `MacOSWorkspaceFileManager`**
   - Conforms to both `WorkspaceFileTree` and `WorkspaceFileWatching`.
   - Uses `FileManager` for directory enumeration.
   - Uses `FSEvents` API for file watching.
   - Lazy materialization: flat dictionary of file nodes + children map (CodeEdit pattern).
   - Weak observers for file-tree changes.
   - Source-control-aware refresh: watch `.git` directory events to trigger SCM status refresh.

4. **Placement decision: UI layer or core?**
   - Start in `CodeEditorUI` or the sample target. `EditorConfiguration` should NOT gain `workspaceFileManager` or `workspaceFileWatcher` existentials — these are app-shell concerns, not editor-core concerns.
   - If a core editor API later needs file-tree data (e.g., LSP workspace folders, project-wide symbol search), define a minimal protocol in `CodeEditorPlugin` and have the UI layer provide the adapter. Keep the core dependency surface small.
   - For now, the macOS adapter lives in a new `Sources/CodeEditorPlugin/Workspace/` directory gated by `#if canImport(AppKit)`, but it is NOT injected through `EditorConfiguration`. It's instantiated by the sample app or hosting application directly.

5. **Add sample integration in `CodeEditorSample`**
   - Example workspace browser using the macOS adapter.
   - Demonstrates lazy loading, file watching, and SCM refresh.
   - The sample app owns the adapter lifecycle.

### Deliverables
- `WorkspaceFileTree` and `WorkspaceFileWatching` protocols
- `MacOSWorkspaceFileManager` adapter (not injected into core config)
- Sample app integration
- Clear boundary: core editor has no workspace dependency

**Dependency**: Phase 6 is independent of all other phases. It's a self-contained protocol + adapter addition.

---

## Phase 7: Project Search

**Goal**: Define a project-search protocol with a portable fallback. macOS SearchKit adapter only if the target SDK and deployment target support it (SearchKit is deprecated; verify before building).

**Status**: `pending`

**Key files**:
- New: `Sources/CodeEditorPlugin/Search/ProjectSearchProtocol.swift`
- New: `Sources/CodeEditorPlugin/Search/PortableSearchAdapter.swift`
- New: `Sources/CodeEditorPlugin/Search/SearchKitAdapter.swift` (only if SearchKit is viable)

### Steps

1. **Verify SearchKit viability against target SDK**
   - Check availability annotations: `@available(macOS 10.5, *)` but deprecated. Determine if SearchKit symbols still link against the current macOS SDK used by this project.
   - If SearchKit is unavailable or deprecated with no replacement, skip the SearchKit adapter entirely and only build the portable adapter.
   - If a replacement exists (`NSMetadataQuery`, `FSIndex`, or `NaturalLanguage` framework), evaluate that instead.

2. **Define `ProjectSearchProvider` protocol**
   - `func indexFiles(urls: [URL]) async throws`
   - `func search(query: String, options: SearchOptions) async throws -> [SearchResult]`
   - `func cancelSearch()`
   - `func clearIndex()`
   - `SearchOptions`: case sensitivity, regex, file-type filter, max results.
   - `SearchResult`: file URL, line number, column, matched text, context lines.

3. **Implement `PortableProjectSearchAdapter`**
   - Simple file-walking + in-memory text index.
   - Suitable for small-to-medium projects.
   - No system dependencies; works on all platforms.
   - Use `Task.detached` for background indexing.
   - This is the baseline.

4. **Implement `SearchKitProjectSearchAdapter` (macOS only, if viable)**
   - Only if Step 1 confirms SearchKit is usable.
   - Uses `SKIndex` for full-text indexing.
   - Progressive search: index → search → stream results as they arrive.
   - Background indexing queue (not main actor).
   - Optional in-memory index for small projects.
   - Post-filter: use exact regex/text matching on SearchKit candidates.

5. **Placement decision**
   - Like Phase 6, keep search protocols in a new `Sources/CodeEditorPlugin/Search/` directory but do NOT add `projectSearchProvider` to `EditorConfiguration`.
   - The sample app or hosting application owns the search provider lifecycle.

6. **Add sample search UI in `CodeEditorSample`**
   - Search bar + results list.
   - Demonstrates progressive results.

### Deliverables
- `ProjectSearchProvider` protocol
- `PortableProjectSearchAdapter` (cross-platform baseline)
- `SearchKitProjectSearchAdapter` (macOS, only if SearchKit is verified viable on target SDK)
- Sample app search integration
- Clear boundary: core editor has no search dependency

**Dependency**: Phase 7 is independent of all other phases. Phases 6 and 7 are complementary but not dependent.

---

## Phase 8: Custom Renderer Evaluation

**Goal**: Evaluate whether a custom text renderer (like CodeEditTextView) is warranted. This is a measurement-and-decision phase, not an implementation phase.

**Status**: `pending` (deferred until Phases 1-7 are stable)

### Steps

1. **Benchmark TextKit2 performance**
   - Large file (10k, 50k, 100k lines) scrolling latency.
   - Typing latency with full range-store highlighting active.
   - Memory usage with `NSTextLayoutManager` on large documents.
   - Compare against CodeEditTextView metrics if available.

2. **Profile the current rendering path**
   - Instruments: Time Profiler, Allocations, Core Animation.
   - Identify the top 3 bottlenecks.
   - Determine if bottlenecks are in TextKit2 layout, glyph rendering, or application-level code (attribute application, highlight queries).

3. **Decision gate: proceed only if TextKit2 is the clear bottleneck**
   - If bottlenecks are in our Swift code (attribute application, highlight queries), fix those first.
   - If TextKit2 layout/rendering consumes >50% of frame time, custom rendering may be justified.
   - If custom rendering is justified, design a hybrid approach:
     - Keep `NSTextStorage` as the text model (preserves TextKit compatibility).
     - Replace `NSTextLayoutManager` with a custom layout engine.
     - Reuse `LineGeometryStore` for line metrics.
     - Implement `LineFragmentView` reuse (CodeEdit pattern).
     - Use `CATransaction` for layout reentry protection.

4. **If custom rendering is NOT justified**, document the decision with metrics and close Phase 8.

### Deliverables
- Performance benchmark report
- Bottleneck analysis
- Decision document: proceed or defer
- If proceeding: custom renderer design document

---

## Dependency Graph

```
Phase 0 (Foundation Audit + Pre-Edit Transaction)
  |
  ├── Phase 1 (Incremental Line Geometry) ── needs Phase 0 pre-edit model for line-range capture
  ├── Phase 2A (Range Attribute Applier) ── needs Phase 0 attribute-edit gate fix
  ├── Phase 4 (LSP Doc-Sync Coordinator) ── needs Phase 0 pre-edit model
  │     ├── Phase 5 (LSP Semantic Tokens) ── needs Phase 4 post-batch hook + Phase 2A applier
  ├── Phase 3 (Real Tree-Sitter) ── benefits from Phase 0 pre-edit snapshots; otherwise independent
  │     └── Phase 2B (Range-Store Primary Path) ── needs Phase 2A + Phase 3 for real provider
  ├── Phase 6 (Workspace File Tree) ── fully independent
  ├── Phase 7 (Project Search) ── fully independent
  └── Phase 8 (Custom Renderer Eval) ── gates on Phases 1-7 stable

Key constraint: Phase 2B (make range path primary) should not happen before
Phase 3 (real tree-sitter) is stable — without a real parser, the range path
has no advantage over the legacy regex highlighter.
```

### Recommended Execution Order

This order respects data-model dependencies and avoids touching the same highlighting surface concurrently:

1. **Phase 0** — 1-2 days. Foundation audit, pre-edit transaction model, attribute-edit gate fix. Blocks Phases 1, 2A, 4.
2. **Phase 4** — LSP document-sync coordinator. Depends on Phase 0 pre-edit model. Independent of highlighting work.
3. **Phase 2A** — Range attribute applier. Depends on Phase 0 attribute-edit gate fix. Unlocks Phase 2B and Phase 5.
4. **Phase 3** — Real tree-sitter. Independent of LSP; can run parallel with Phase 4 if staffing allows, but serial is safer since Phases 3 and 2A both touch highlighting. Provides the real provider that justifies Phase 2B.
5. **Phase 2B** — Make range-store primary. Depends on Phase 2A (applier stable) + Phase 3 (real tree-sitter giving it value).
6. **Phase 5** — Semantic tokens. Depends on Phase 4 (post-batch hook) + Phase 2A (applier). After Phase 2B, semantic tokens feed into the primary highlighting path.
7. **Phase 1** — Incremental line geometry. Depends on Phase 0 pre-edit model. Can be done anytime after Phase 0, but placed here because earlier phases don't benefit from it unless profiling proves line-geometry rebuilds are a bottleneck during Phase 3/5 testing. If profiling in Phase 3 shows line geometry is a top-3 bottleneck, move Phase 1 earlier.
8. **Phase 6 + Phase 7** — Workspace + search (independent, lower priority, may run in parallel).
9. **Phase 8** — Evaluation gate.

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
