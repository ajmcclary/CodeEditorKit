# CodeEditorPlugin — Phased Implementation Plan

**Date**: 2026-05-11
**Source**: Audit of CodeEdit + CodeEditorPlugin (see `NOTES.md`)

---

## Table of Contents

1. [Current State Summary](#current-state-summary)
2. [Phase 0: Foundation Audit](#phase-0-foundation-audit)
3. [Phase 1: Incremental Line Geometry](#phase-1-incremental-line-geometry)
4. [Phase 2: Range-Store Highlighting as Primary Path](#phase-2-range-store-highlighting-as-primary-path)
5. [Phase 3: Real Tree-Sitter Integration](#phase-3-real-tree-sitter-integration)
6. [Phase 4: LSP Document-Sync Coordinator](#phase-4-lsp-document-sync-coordinator)
7. [Phase 5: LSP Semantic Tokens](#phase-5-lsp-semantic-tokens)
8. [Phase 6: Workspace File Tree](#phase-6-workspace-file-tree)
9. [Phase 7: Project Search](#phase-7-project-search)
10. [Phase 8: Custom Renderer Evaluation](#phase-8-custom-renderer-evaluation)
11. [Dependency Graph](#dependency-graph)
12. [Risk Register](#risk-register)

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
| Project search | Not present | Protocol + SearchKit adapter + portable fallback |

---

## Phase 0: Foundation Audit

**Goal**: Verify the foundation is ready before starting heavy implementation. This is a lightweight check phase.

**Status**: `pending`

### Steps

1. **Run full test suite** — `swift test --parallel` — confirm zero regressions against current `main`.
2. **Run SwiftLint** — `swiftlint --fix && swiftlint` (strict mode; warnings are errors).
3. **Audit `RangeHighlightProviding` protocol** — confirm the protocol surface is sufficient for:
   - Real tree-sitter (incremental edits, injection layers, cancellation)
   - LSP semantic tokens (delta edits, compressed storage)
   - Any future provider (spell-check, AI suggestions)
4. **Audit `TextEditEvent` struct** — confirm it carries enough data for LSP edit batching (pre-edit ranges, edit timing, source snapshot).
5. **Audit `LanguageDescriptor` tree-sitter names** — confirm all 25 languages have correct `treeSitterName` mappings for `swift-tree-sitter` grammar names.
6. **Document the attribute-applier gap** — trace `StyledRangeContainer.mergedRuns(in:)` → `NSTextStorage.addAttributes(_:range:)` path. Identify where the hook should go (likely `CodeEditorView+TextKitExtensions` or a new coordinator).

### Deliverables
- Test/lint passing baseline
- Protocol audit notes (any changes to `RangeHighlightProviding`)
- Attribute-applier design sketch

---

## Phase 1: Incremental Line Geometry

**Goal**: Replace full `LineGeometryStore` rebuilds with incremental node-level updates. The store is already a red-black tree with subtree metadata; the edit handler just needs to use the incremental API instead of calling `rebuildLineGeometryStoreFromCurrentTextStorage()`.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift`

### Steps

1. **Add incremental mutation methods to `LineGeometryStore`**
   - `insertLines(_:at:)` — insert one or more `LineGeometry` values at a line index
   - `removeLines(in:)` — remove a range of line indices
   - `replaceLine(at:with:)` — replace a single line's geometry (for height updates, fold changes already handled)
   - Each method must maintain red-black invariants and propagate subtree metadata
   - Each method is O(m log n) for m affected lines
   - Add focused tests in `LineGeometryStoreTests`

2. **Update `LineGeometryEditHandler.textStorageDidApplyEdit(_:)`**
   - Instead of `textView?.rebuildLineGeometryStoreFromCurrentTextStorage()`, call incremental methods
   - Compute affected line range from `event.editedRange` + `event.changeInLength`
   - Use `NSTextStorage` / `NSString` line enumeration only for the affected region
   - Rebuild only the lines whose offsets or lengths changed
   - Preserve measured heights and fold state for unaffected lines

3. **Remove full-rebuild calls from `CodeEditorView`**
   - `CodeEditorView+SetupExtensions.swift` — the initial `setupLineGeometryStore()` still needs a full build (cold start)
   - But the `string`/`text`/`attributedText` property setters currently call `rebuildLineGeometryStoreFromCurrentTextStorage()` — these should either be removed (if the event hub already triggers the handler) or replaced with a full rebuild ONLY when the entire text storage is replaced (not on incremental edits)
   - `CodeEditorView+TextKitExtensions.swift` line 104 — same pattern

4. **Performance benchmark**
   - Instrument with os_signpost or a simple timing test
   - Verify O(m log n) characteristic on large files (10k+ lines) with small edits

5. **Fold state preservation**
   - When lines shift due to insertions/deletions above them, fold state should move with the line content
   - Add tests: fold a line, insert text above it, verify the folded line is still folded and at the correct index

### Deliverables
- `LineGeometryStore` incremental mutation methods with tests
- `LineGeometryEditHandler` using incremental updates
- Performance benchmark showing improvement
- Fold state preservation tests

---

## Phase 2: Range-Store Highlighting as Primary Path

**Goal**: Make the range-store pipeline the primary text-styling path. Currently it feeds minimap data; the legacy attributed-text highlighter handles visible text styling. After this phase, `StyledRangeContainer.mergedRuns(in:)` drives `NSTextStorage` attributes.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/StyledRangeContainer.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightProviderState.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeHighlightProviding.swift` (check path)

### Steps

1. **Build the attribute applier**
   - Create `RangeAttributeApplier` — subscribes to `StyledRangeContainer` changes
   - When `HighlightProviderState` marks ranges valid, the applier reads `mergedRuns(in:)` and calls `NSTextStorage.addAttributes(_:range:)` / `removeAttribute(_:range:)`
   - Map `StyleElement.capture` → platform color/font attributes via `TokenType.adaptiveColor`
   - Batch attribute applications within a single `textStorage?.beginEditing()` / `endEditing()` block
   - Skip already-correct ranges (no-op when attributes haven't changed)

2. **Wire into `RangeBasedHighlightingController`**
   - Controller creates the applier on init
   - Applier receives a callback from `HighlightProviderState` when ranges transition from pending→valid
   - Controller already has the `container` — pass it to the applier

3. **Disable legacy highlighter for range-backed languages**
   - `CodeEditorView+SyntaxHighlightingExtensions.swift` — check where `SyntaxHighlighter.processEditing` or similar is called
   - When `RangeBasedHighlightingController` is active (opt-in / language gated), skip the legacy path
   - Keep legacy as fallback for languages without range provider support

4. **Incremental attribute updates**
   - On document edits, `StyledRangeContainer.storageUpdated()` already adjusts ranges
   - The applier should respond to edit events: clear attributes in the edited range, then let `HighlightProviderState` re-query and re-apply
   - Avoid clearing/repainting the entire visible viewport on each keystroke

5. **Test and benchmark**
   - Visual regression: snapshot tests comparing legacy vs range-store output
   - Performance: large file typing latency before/after
   - Correctness: verify no missing highlights, no stale highlights after edits

### Deliverables
- `RangeAttributeApplier` component
- Range-store pipeline driving visible text styling
- Legacy highlighter gated behind feature flag
- Snapshot tests for attribute correctness
- Performance benchmarks

**Dependency**: Phase 2 can start independently, but becomes more valuable after Phase 3 (real tree-sitter) and Phase 5 (semantic tokens) feed into it.

---

## Phase 3: Real Tree-Sitter Integration

**Goal**: Replace `RegexBackedTreeSitterParser` with a real C `tree-sitter` parser. Keep the `TreeSitterRangeHighlightProvider` architecture and `RangeHighlightProviding` protocol — only the parser backend changes.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterRangeHighlightProvider.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterCaptureMap.swift`
- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift`

### Steps

1. **Add `swift-tree-sitter` dependency to `Package.swift`**
   - Or a thin C FFI wrapper if direct linking is preferred
   - Include tree-sitter runtime + per-language grammar packages
   - Ensure the dependency is gated behind `#if canImport(AppKit)` or a feature flag — tree-sitter is macOS-centric for now

2. **Implement `TreeSitterParser` (real) conforming to `TreeSitterParserProtocol`**
   - Owns parser state (`TSTree`, `TSParser`, `TSQuery` per capture)
   - `setLanguage(_:)` — loads grammar, compiles queries for highlight captures
   - `parse(source:)` — full parse, run queries, return `TreeSitterParseResult`
   - `applyEdit(startByte:oldEndByte:newEndByte:)` — incremental edit via `ts_tree_edit`; return invalidated byte ranges
   - Support cancellation via `Task.isCancelled` checks during long parses
   - Replay pending edits if edits arrive during a running parse

3. **Adopt CodeEdit thresholds (as initial defaults)**
   - `matchLimit = 256`
   - `parserTimeout = 0.05s`
   - `maxSyncEditLength = 1024`
   - `maxSyncContentLength = 1_000_000`
   - `maxSyncQueryLength = 4096`
   - `charsToReadInBlock = 4096`
   - `longParseTimeout = 0.5s`
   - `taskSleepDuration = 10ms`
   - Tune with benchmarks after integration

4. **Add injection layer support**
   - Primary language layer + injected language layers (e.g., JS in HTML, SQL in PHP)
   - Injections defined per language via `LanguageDescriptor` or query metadata
   - Query results merged across layers with primary taking precedence

5. **Update `TreeSitterRangeHighlightProvider.makeSpikeProvider(for:)` → `makeProvider(for:)`**
   - Switch from `RegexBackedTreeSitterParser()` to `TreeSitterParser()`
   - Add a feature flag: `TreeSitterProviderFeature.realParserEnabled`
   - Fallback to regex for languages without tree-sitter grammar support

6. **Byte ↔ UTF-16 correctness**
   - Preserve existing `byteRange(forUTF16Range:in:)` and `stringRange(forByteRange:in:)` helpers
   - Add exhaustive tests for emoji, surrogate pairs, composed characters
   - Verify incremental edit byte ranges are correct after multi-byte insertions

7. **Remove or archive `RegexBackedTreeSitterParser`**
   - Keep as a test double or remove entirely once real parser is stable
   - Update any tests that depend on the regex behavior

### Deliverables
- Real `TreeSitterParser` implementing `TreeSitterParserProtocol`
- Incremental edit support with byte-range invalidation
- Injection layer support
- Cancellation and pending-edit replay
- Feature flag gating real vs regex parser
- UTF-16/byte boundary tests

---

## Phase 4: LSP Document-Sync Coordinator

**Goal**: Add an editor-owned coordinator that subscribes to `TextEditEventHub`, batches edits into ~250ms groups, and sends incremental changes to LSP servers. This replaces the current manual `updateDocument()` calls.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/LSP/LSPManager.swift`
- `Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift`
- `Sources/CodeEditorPlugin/LSP/LSPClient.swift`
- `Sources/CodeEditorPlugin/Text/TextEditEventHub.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`

### Steps

1. **Design and implement `LSPContentCoordinator`**
   - New file: `Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift`
   - Conforms to `TextEditEventObserving`
   - Registers with `CodeEditorView.textEditEventHub`
   - Captures pre-edit document state (source string, version) on `textStorageDidApplyEdit`
   - Computes `TextDocumentContentChangeEvent` from `event.editedRange` + old/new source
   - Pushes events into an `AsyncStream` for batching

2. **Implement edit batching**
   - Groups edits arriving within ~250ms windows using `swift-async-algorithms` (`chunked(by:)` or a timer-based debounce)
   - Sends grouped `textDocument/didChange` notifications with incremental `TextDocumentContentChangeEvent` array
   - Falls back to full-document sync when edit count or cumulative range exceeds a threshold
   - Respects server `TextDocumentSyncKind` (None / Full / Incremental)

3. **Integrate with `LSPDocumentManager`**
   - Coordinator calls `documentManager.updateDocument(filePath:content:changes:)` with batched changes
   - Document version increments per batch, not per keystroke
   - Coordinator is created per editor view → per document

4. **Pre-edit range capture**
   - Before the edit mutates `NSTextStorage`, capture the old range content
   - Use the `preEditSnapshots` pattern from `TreeSitterRangeHighlightProvider` (already proven)
   - Store old `(range, source)` pairs keyed by edit event for each coordinatee

5. **Wire into `CodeEditorView` setup**
   - `CodeEditorView.setupLSPIntegration()` (new method in `+SetupExtensions`)
   - Creates `LSPContentCoordinator` when an `LSPManager` is configured
   - Coordinator detaches on view deallocation

6. **Server capabilities respect**
   - During LSP `initialize`, parse `ServerCapabilities.textDocumentSync`
   - If server only supports full sync, skip incremental change computation
   - Store sync kind in `LSPClient` state

### Deliverables
- `LSPContentCoordinator` with `TextEditEventHub` integration
- 250ms edit batching via `AsyncStream` + `swift-async-algorithms`
- Full vs incremental sync based on server capabilities
- Pre-edit range capture
- Integration with `CodeEditorView` lifecycle

**Dependency**: Phase 4 is independent of Phases 1-3. It depends only on `TextEditEventHub` (already exists) and `LSPDocumentManager` (already exists).

---

## Phase 5: LSP Semantic Tokens

**Goal**: Add semantic-token support as LSP types, storage, delta application, and a `RangeHighlightProviding` adapter that feeds into `StyledRangeContainer` with higher priority than syntax tokens.

**Status**: `pending`

**Key files**:
- `Sources/CodeEditorPlugin/LSP/LSPTypes.swift`
- `Sources/CodeEditorPlugin/LSP/LSPClient.swift`
- New: `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenStorage.swift`
- New: `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift`

### Steps

1. **Extend `LSPTypes.swift` with semantic-token types**
   - `SemanticTokensLegend` (token types, token modifiers)
   - `SemanticTokens` (result ID, data array)
   - `SemanticTokensDelta` (result ID, edits array)
   - `SemanticTokensEdit` (start, deleteCount, data)
   - `SemanticTokensRangeParams` / `SemanticTokensRangeResult`
   - Request methods: `textDocument/semanticTokens/full`, `textDocument/semanticTokens/full/delta`, `textDocument/semanticTokens/range`

2. **Add semantic-token capability to `ClientCapabilities`**
   - `textDocument.semanticTokens` with `dynamicRegistration`, `requests` (range, full, delta)
   - `TokenFormat` (relative)
   - Advertise these during LSP `initialize`

3. **Implement `LSPSemanticTokenStorage`**
   - Stores compressed token data arrays (5 integers per token: deltaLine, deltaStartChar, length, tokenType, tokenModifiers)
   - Decodes tokens for a given line range into `(line, startChar, length, type, modifiers)` tuples
   - Applies `SemanticTokensEdit` (delta) in reverse order
   - Returns invalidated line ranges after delta application
   - Thread-safe storage (read-only queries from main actor, writes from LSP handler)

4. **Implement `LSPSemanticTokenProvider` conforming to `RangeHighlightProviding`**
   - `setUp(textView:language:)` — request full semantic tokens from server
   - `queryHighlights(textView:range:)` — decode tokens intersecting the range, convert to `HighlightedToken` with token type mapping
   - `applyEdit(textView:range:delta:)` — request semantic-token delta from server; apply to storage; return invalidated ranges
   - `willApplyEdit` — no-op (LSP server manages its own state)
   - Register with `StyledRangeContainer` at priority -1 (higher than syntax token priority 0)

5. **Wire into `LSPManager` and `LSPClient`**
   - `LSPClient.requestSemanticTokens(uri:)` → full token array
   - `LSPClient.requestSemanticTokensDelta(uri:previousResultId:)` → delta
   - `LSPClient.requestSemanticTokensRange(uri:range:)` → range-limited tokens
   - Handle `textDocument/semanticTokens` responses in `LSPClient.handleResponse`

6. **Token type mapping**
   - Map LSP semantic token types (e.g., "namespace", "class", "enum", "function", "variable", "parameter", "typeParameter") to `TokenType`
   - Map modifier flags (e.g., "declaration", "definition", "readonly", "static", "deprecated") to `TokenType` variants or additional attributes
   - Define the legend per language or use the server-returned legend

### Deliverables
- Full LSP semantic-token type definitions in `LSPTypes`
- `LSPSemanticTokenStorage` with delta application
- `LSPSemanticTokenProvider` as a `RangeHighlightProviding` adapter
- Token type mapping to `TokenType`
- Integration with `LSPClient` request/response handling
- Tests for delta application edge cases

**Dependency**: Phase 5 depends on Phase 4 (LSP doc-sync coordinator) for reliable document state and Phase 2 (range-store primary path) for the attribute applier to consume semantic tokens. It also needs basic LSP initialization working (already done).

---

## Phase 6: Workspace File Tree

**Goal**: Define protocols for workspace file trees and file watching, then provide a macOS adapter with lazy materialization. Keep this out of core editor logic — it's a protocol + optional adapter pattern.

**Status**: `pending`

**Key files**:
- New: `Sources/CodeEditorPlugin/Workspace/WorkspaceFileTreeProtocol.swift`
- New: `Sources/CodeEditorPlugin/Workspace/MacOSWorkspaceFileManager.swift`
- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`

### Steps

1. **Define `WorkspaceFileTree` protocol**
   - `var root: WorkspaceFileNode { get }`
   - `func children(of: WorkspaceFileNode) -> [WorkspaceFileNode]`
   - `func isDirectory(_: WorkspaceFileNode) -> Bool`
   - `func fileURL(for: WorkspaceFileNode) -> URL`
   - Lazy materialization: only root children loaded initially; deeper nodes loaded on demand

2. **Define `WorkspaceFileWatching` protocol**
   - `func startWatching(root: URL) async throws`
   - `func stopWatching()`
   - Async stream of `WorkspaceFileEvent` (created, modified, deleted, renamed)
   - Repair strategy: only refresh already-cached directory nodes on FSEvents; don't eagerly load new directories

3. **Implement `MacOSWorkspaceFileManager`**
   - Conforms to both `WorkspaceFileTree` and `WorkspaceFileWatching`
   - Uses `FileManager` for directory enumeration
   - Uses `FSEvents` API for file watching
   - Lazy materialization: flat dictionary of file nodes + children map (CodeEdit pattern)
   - Weak observers for file-tree changes
   - Source-control-aware refresh: watch `.git` directory events to trigger SCM status refresh

4. **Add workspace configuration to `EditorConfiguration`**
   - Optional `workspaceFileManager: (any WorkspaceFileTree)?`
   - Optional `workspaceFileWatcher: (any WorkspaceFileWatching)?`
   - Inject through the existing configuration pattern

5. **Add sample integration in `CodeEditorSample`**
   - Example workspace browser using the macOS adapter
   - Demonstrates lazy loading, file watching, and SCM refresh

### Deliverables
- `WorkspaceFileTree` and `WorkspaceFileWatching` protocols
- `MacOSWorkspaceFileManager` adapter
- `EditorConfiguration` workspace properties
- Sample app integration

**Dependency**: Phase 6 is independent of all other phases. It's a self-contained protocol + adapter addition.

---

## Phase 7: Project Search

**Goal**: Define a project-search protocol with a macOS SearchKit adapter and a portable fallback. Use SearchKit indexes to prefilter candidate files, then do exact regex/text matching.

**Status**: `pending`

**Key files**:
- New: `Sources/CodeEditorPlugin/Search/ProjectSearchProtocol.swift`
- New: `Sources/CodeEditorPlugin/Search/SearchKitAdapter.swift`
- New: `Sources/CodeEditorPlugin/Search/PortableSearchAdapter.swift`

### Steps

1. **Define `ProjectSearchProvider` protocol**
   - `func indexFiles(urls: [URL]) async throws`
   - `func search(query: String, options: SearchOptions) async throws -> [SearchResult]`
   - `func cancelSearch()`
   - `func clearIndex()`
   - `SearchOptions`: case sensitivity, regex, file-type filter, max results
   - `SearchResult`: file URL, line number, column, matched text, context lines

2. **Implement `SearchKitProjectSearchAdapter` (macOS only)**
   - Uses `SKIndex` for full-text indexing
   - Progressive search: index → search → stream results as they arrive
   - Background indexing queue (not main actor)
   - Optional in-memory index for small projects
   - Post-filter: use exact regex/text matching on SearchKit candidates

   **Caution**: SearchKit is deprecated. Evaluate `NSMetadataQuery` or `FSIndex` as alternatives. If no viable system API exists, fall back to the portable adapter even on macOS.

3. **Implement `PortableProjectSearchAdapter`**
   - Simple file-walking + in-memory text index
   - Suitable for small-to-medium projects
   - No system dependencies; works on all platforms
   - Use `Task.detached` for background indexing

4. **Wire into `EditorConfiguration`**
   - Optional `projectSearchProvider: (any ProjectSearchProvider)?`
   - Factory based on platform availability

5. **Add sample search UI in `CodeEditorSample`**
   - Search bar + results list
   - Demonstrates progressive results

### Deliverables
- `ProjectSearchProvider` protocol
- `SearchKitProjectSearchAdapter` (macOS, if SearchKit is viable)
- `PortableProjectSearchAdapter` (cross-platform fallback)
- Sample app search integration

**Dependency**: Phase 7 is independent of all other phases. Phases 6 and 7 are complementary (workspace trees feed search indexing) but not strictly dependent.

---

## Phase 8: Custom Renderer Evaluation

**Goal**: Evaluate whether a custom text renderer (like CodeEditTextView) is warranted. This is a measurement-and-decision phase, not an implementation phase.

**Status**: `pending` (deferred until Phases 1-7 are stable)

### Steps

1. **Benchmark TextKit2 performance**
   - Large file (10k, 50k, 100k lines) scrolling latency
   - Typing latency with full range-store highlighting active
   - Memory usage with `NSTextLayoutManager` on large documents
   - Compare against CodeEditTextView metrics from CodeEdit benchmarks

2. **Profile the current rendering path**
   - Instruments: Time Profiler, Allocations, Core Animation
   - Identify the top 3 bottlenecks
   - Determine if bottlenecks are in TextKit2 layout, glyph rendering, or attribute application

3. **Decision gate: proceed only if TextKit2 is the clear bottleneck**
   - If bottlenecks are in our Swift code (attribute application, highlight queries), fix those first
   - If TextKit2 layout/rendering consumes >50% of frame time, custom rendering may be justified
   - If custom rendering is justified, design a hybrid approach:
     - Keep `NSTextStorage` as the text model (preserves TextKit compatibility)
     - Replace `NSTextLayoutManager` with a custom layout engine
     - Reuse `LineGeometryStore` for line metrics
     - Implement `LineFragmentView` reuse (CodeEdit pattern)
     - Use `CATransaction` for layout reentry protection

4. **If custom rendering is NOT justified**, document the decision with metrics and close Phase 8.

### Deliverables
- Performance benchmark report
- Bottleneck analysis
- Decision document: proceed or defer
- If proceeding: custom renderer design document

---

## Dependency Graph

```
Phase 0 (Foundation Audit)
  |
  ├── Phase 1 (Incremental Line Geometry) ── independent
  ├── Phase 2 (Range-Store Primary Path) ── independent (but enriches Phase 3+5)
  ├── Phase 3 (Real Tree-Sitter) ── independent
  ├── Phase 4 (LSP Doc-Sync Coordinator) ── independent
  │     └── Phase 5 (LSP Semantic Tokens) ── depends on Phase 4 + Phase 2
  ├── Phase 6 (Workspace File Tree) ── independent
  ├── Phase 7 (Project Search) ── independent
  └── Phase 8 (Custom Renderer Eval) ── after Phases 1-7 stable

Parallelism: Phases 1, 2, 3, 4, 6, 7 can all start concurrently.
Phase 5 should wait for Phase 4 (needs the sync coordinator) and Phase 2 (needs the attribute applier).
Phase 8 is the final gate.
```

### Recommended Execution Order

Given team bandwidth, this order maximizes value delivery:

1. **Phase 0** — 1 day (verify foundation)
2. **Phase 1 + Phase 4** — in parallel (line geometry + LSP sync are independent)
3. **Phase 3** — tree-sitter is the highest-value P0 gap
4. **Phase 2** — range-store primary path (unlocks Phase 5)
5. **Phase 5** — semantic tokens (depends on Phase 2 + Phase 4)
6. **Phase 6 + Phase 7** — workspace + search (independent, lower priority)
7. **Phase 8** — evaluation gate

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `swift-tree-sitter` or C FFI breaks Swift 6.3 strict concurrency | Medium | High | Gate behind `@unchecked Sendable` with explicit synchronization; use actor isolation for parser state |
| SearchKit deprecation leaves no macOS full-text index API | High | Medium | Plan for `NSMetadataQuery` as fallback; portable adapter as baseline |
| Custom renderer scope creep | Medium | High | Phase 8 is an evaluation gate, not an implementation commitment |
| Incremental line geometry breaks fold state or measured heights | Medium | Medium | Exhaustive tests; fold state tracking is already per-node |
| LSP semantic token delta application has off-by-one errors | Medium | Medium | Test suite with known token arrays and edit sequences |
| `StyledRangeContainer` multi-provider merge performance degrades with 3+ providers | Low | Medium | Profile after adding semantic tokens (provider 3); optimize merge if needed |
| `CodeEditLanguages` binary grammar container doesn't fit cross-platform distribution | Medium | Low | Use `tree-sitter` grammar sub-packages directly; skip the container format |
| `swift-async-algorithms` adds a dependency | Low | Low | Already a transitive dependency in the ecosystem; lightweight addition |

---

## Conventions (Non-Negotiable)

Throughout all phases, these conventions from `AGENTS.md` are maintained:

- **`#if canImport(AppKit)`** — never `#if os(macOS)`
- **No `print()`** — always `CrossPlatformLogger.logger()`
- **No force unwraps** — always safe-unwrap
- **No singletons** — inject through `EditorConfiguration` or explicit initializers
- **`+Extensions` suffix** for extension files
- **`@MainActor` class isolation** for UI-bound services (not `actor`)
- **`StrictConcurrency` enabled** — no `@unchecked Sendable` shortcuts without explicit justification

---

*Plan derived from CodeEdit audit (see `NOTES.md`) and direct codebase inspection on 2026-05-11.*
