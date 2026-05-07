# CodeEditSourceEditor Deep Analysis

## 1. Parsing — Tree-sitter Integration

### Architecture Overview

CodeEditSourceEditor uses Tree-sitter as the single parsing substrate via three collaborating types:

```
TreeSitterClient  (HighlightProviding conformance — external API)
    ├── TreeSitterState   (owns the layer tree, injection management)
    │   └── LanguageLayer[]  (per-language parser, tree, query, ranges)
    └── TreeSitterExecutor   (thread-safe sync/async queue)
```

### `TreeSitterClient` (`TreeSitter/TreeSitterClient.swift`)

This is the public facade and the `HighlightProviding` conformance point. Key methods:

**`setUp(textView:codeLanguage:)`**
- Creates a `TreeSitterState` with the language and text-view callbacks.
- The operation is dispatched to `TreeSitterExecutor` — either sync (if `forceSyncOperation`) or async at `.reset` priority.
- All prior operations are cancelled (`executor.cancelAll(below: .all)`), ensuring a clean slate.

**`applyEdit(textView:range:delta:completion:)`**
- Captures `oldEndPoint` (set by `willApplyEdit`) to tell Tree-sitter the pre-edit document end.
- Creates an `InputEdit` struct (range, delta, oldEndPoint, textView).
- Routes to sync or async execution based on heuristics:
  - Sync if edit length ≤ `maxSyncEditLength` (1024) AND document ≤ `maxSyncContentLength` (1_000_000).
  - Otherwise async at `.edit` priority.
- On async cancellation: the edit is appended to `pendingEdits` (an `Atomic<[InputEdit]>`) and the completion is called with `.operationCancelled`.

**`queryHighlightsFor(textView:range:completion:)`**
- Same sync/async routing logic as `applyEdit`, but uses `maxSyncQueryLength` (4096) threshold.
- Async queries run at `.access` priority (lower than `.edit`), meaning edits preempt highlight queries.

**`willApplyEdit(textView:range:)`**
- Simple: stores `oldEndPoint` by converting `range.max` to a `Point` via the text view. This is called *before* the text storage actually changes, so the point is accurate.

**Design decisions:**
- `maxSyncEditLength = 1024` — Keeps small edits on the main thread for responsiveness.
- `maxSyncQueryLength = 4096` — Larger queries forced async.
- `matchLimit = 256` — Prevents query-cursor runaway (from Neovim/Helix research).
- `parserTimeout = 0.05s` — Tree-sitter will yield after 50ms. Combined with `longParseTimeout = 0.5s`, the system fires `longParse`/`longParseFinished` notifications for UI feedback.
- `taskSleepDuration = 10ms` — The polling interval for queued async tasks. Strikes a balance between lock contention and responsiveness.

### `TreeSitterState` (`TreeSitter/TreeSitterState.swift`)

Manages the layer tree — a list of `LanguageLayer` objects representing the primary language and injected languages.

**`init(codeLanguage:readCallback:readBlock:)`**
- Creates the primary `LanguageLayer` for the given language.
- Calls `setLanguage()` which builds `layers[0]` with parser, query, and injection support.
- Calls `parseDocument()` which does the initial full-document parse AND walks the tree for injections.

**`parseDocument(readCallback:readBlock:)`**
- Sets `parser.timeout = 0.0` (no timeout) for the initial parse — it must complete.
- Parses `layers[0]`, then iterates through all layers (including newly added ones) calling `updateInjectedLanguageLayer()`.
- The `while idx < layers.count` pattern handles the fact that `updateInjectedLanguageLayer` can append to `layers` during the loop.

**`updateInjectedLanguageLayer(readCallback:readBlock:layer:layerSet:touchedLayers:)`**
- Executes the injections query on a layer's tree.
- For each `(languageName, ranges)` pair found:
  - Skips if the language matches the primary layer ID.
  - Creates a temp `LanguageLayer` for set membership testing.
  - If the layer is already in `layerSet`: removes from `touchedLayers` (still alive).
  - If new: calls `addLanguageLayer()`, parses the sub-tree, adds to `layerSet`, and records `updatedRanges`.
- After all layers are processed, any remaining entries in `touchedLayers` are removed.

**`updateInjectedLayers(readCallback:readBlock:touchedLayers:)`**
- Called after edits. Performs the same injection walk but additionally:
  - Returns an `IndexSet` of all ranges that need re-highlighting.
  - Removes orphaned layers (those in `touchedLayers` that weren't re-encountered).

**`copy()`**
- Creates a disconnected copy. Tree-sitter trees use copy-on-write via a global ref counter, so this is cheap.

### `LanguageLayer` (`TreeSitter/LanguageLayer.swift`)

**`findChangedByteRanges(edits:timeout:readBlock:)`**
- The core edit-handling method.
- Calls `calculateNewState()` to get the new tree after edits.
- If cancelled: returns `[]` (no ranges). The caller should retry.
- If there was no prior tree: does a full parse and returns the root node's range.
- Otherwise: calls `changedByteRanges(oldTree, newTree)` to compute the delta.

**`calculateNewState(tree:parser:edits:readBlock:)`**
- Applies all edits to the old tree via `tree.edit(edit)`.
- Enters a `while newTree == nil` loop that:
  - Checks `Task.isCancelled` each iteration.
  - Sends `longParse` notification after `longParseTimeout` (0.5s).
  - Calls `parser.parse(tree:tree, readBlock:readBlock)`, which respects `parser.timeout`.
- This loop handles Tree-sitter's timeout behavior: a timed-out parse returns `nil`, and re-calling `parse` on the same tree continues where it left off.

**`Parser.reset()` extension**
- Uses `Mirror` reflection to reach `internalParser` OpaquePointer and call `ts_parser_reset()`. This is a workaround since SwiftTreeSitter v0.4 doesn't expose `reset()` on `Parser`. Resetting the parser on cancellation prevents stale state.

### `TreeSitterExecutor` (`TreeSitter/TreeSitterExecutor.swift`)

A thread-safe priority queue for sync/async Tree-sitter operations.

**`execSync<T>(_ operation:)`**
- Acquires the lock. If the queue is empty, inserts a nil-task marker and runs the operation synchronously.
- If the queue is non-empty (an async op is in progress), returns `.failure(.syncUnavailable)`.
- Thread-safe because `addSyncTask()` uses `lock.lock()`/`unlock()`.

**`execAsync(priority:operation:onCancel:)`**
- Creates a detached `Task(priority: .userInitiated)`.
- The task sleeps (`taskSleepDuration`) while it can't acquire the queue head.
- Uses `canTaskExec(id:priority:)` to check if it's next:
  - For `.access` priority: allows concurrent access operations.
  - For `.edit`/`.reset`: must be the first item in the queue.
- Once at head: executes the operation, then removes itself from the queue.

**`cancelAll(below:)`**
- Cancels all tasks with priority lower than the given threshold.
- E.g., `cancelAll(below: .reset)` kills all `.edit` and `.access` operations.

**`Priority` ordering: `.access < .edit < .reset < .all`**

### Comparison with CodeEditorPlugin

| Aspect | CodeEditSourceEditor | CodeEditorPlugin |
|--------|---------------------|------------------|
| Parser | Tree-sitter (C library) | SwiftSyntax (Swift) + regex/lightweight tokenizers (others) |
| Injection | Native Tree-sitter injections query | Not supported |
| Incremental | Tree edit API returns changed byte ranges | Regenerates or falls back to full highlighting |
| Threading | `TreeSitterExecutor` priority queue | Swift Concurrency, async/await |

### Key Methods Summary

| Method | File | Line | Purpose |
|--------|------|------|---------|
| `setUp(textView:codeLanguage:)` | TreeSitterClient.swift | 114 | Initializes state + layer tree |
| `applyEdit(textView:range:delta:completion:)` | TreeSitterClient.swift | 148 | Applies edit, returns invalidated index set |
| `queryHighlightsFor(textView:range:completion:)` | TreeSitterClient.swift | 207 | Queries highlight ranges for a text range |
| `willApplyEdit(textView:range:)` | TreeSitterClient.swift | 198 | Captures pre-edit document endpoint |
| `setLanguage(_:)` | TreeSitterState.swift | 52 | Resets layers for a new language |
| `parseDocument(readCallback:readBlock:)` | TreeSitterState.swift | 76 | Initial full parse + injection discovery |
| `updateInjectedLanguageLayer(...)` | TreeSitterState.swift | 207 | Injection query, layer add/update/remove |
| `updateInjectedLayers(...)` | TreeSitterState.swift | 159 | Post-edit injection update, returns invalidated ranges |
| `findChangedByteRanges(edits:timeout:readBlock:)` | LanguageLayer.swift | 89 | Edit application, returns changed ranges |
| `calculateNewState(tree:parser:edits:readBlock:)` | LanguageLayer.swift | 129 | Core parse loop with timeout + cancellation |
| `execSync<T>(_ operation:)` | TreeSitterExecutor.swift | 65 | Synchronous execution (if queue empty) |
| `execAsync(priority:operation:onCancel:)` | TreeSitterExecutor.swift | 93 | Async execution with priority ordering |
| `cancelAll(below:)` | TreeSitterExecutor.swift | 166 | Cancel queued tasks below priority |

---

## 2. Highlighting System

### Architecture Overview

```
Highlighter (NSTextStorageDelegate, coordinator)
├── HighlightProviderState[]   (one per provider — tracks valid/pending/visible)
│   └── HighlightProviding     (TreeSitterClient, LSP, spellcheck, etc.)
├── StyledRangeContainer       (merges provider results by priority)
│   └── RangeStore[]           (one per provider — rope-backed interval store)
└── VisibleRangeProvider       (tracks visible text + minimap range)
```

### `HighlightProviding` (`Highlighting/HighlightProviding/HighlightProviding.swift`)

The protocol that all highlight providers conform to. Four methods:

- **`setUp(textView:codeLanguage:)`** — Called once during initialization and on language changes.
- **`willApplyEdit(textView:range:)`** — Called before text storage changes; default implementation is empty.
- **`applyEdit(textView:range:delta:completion:)`** — Returns an `IndexSet` of indices invalidated by the edit.
- **`queryHighlightsFor(textView:range:completion:)`** — Returns `[HighlightRange]` for a given text range.

### `Highlighter` (`Highlighting/Highlighter.swift`)

The `@MainActor` coordinator that wires everything together.

**`init(textView:minimapView:providers:attributeProvider:language:)`**
- Creates `VisibleRangeProvider` (with text view + minimap for combined visible range tracking).
- Creates `StyledRangeContainer` with one provider ID per initial provider.
- Creates `HighlightProviderState` for each provider — each calls `setUp` on its provider during init.
- Sets itself as delegate on both `styleContainer` and `visibleRangeProvider`.

**`textStorage(_:didProcessEditing:range:changeInLength:)`**
- The `NSTextStorageDelegate` method (runs on main thread).
- Guards on `.editedCharacters` to avoid re-highlighting on attribute-only changes.
- Calls `styleContainer.storageUpdated()` to keep all `RangeStore` instances in sync.
- If `delta > 0` (insertion), inserts the edited range into `visibleRangeProvider.visibleSet` — ensures inserted text is immediately considered visible for highlighting.
- Calls `visibleRangeProvider.visibleTextChanged()` to update visible indices.
- Passes the pre-delta range (`editedRange.location` to `editedRange.location + editedRange.length - delta`) to each `HighlightProviderState.storageDidUpdate()`.

**`textStorage(_:willProcessEditing:range:changeInLength:)`**
- Also guards on `.editedCharacters`.
- Calls `willApplyEdit` on each provider before the edit actually happens.

**`styleContainerDidUpdate(in range:)`**
- Called when `StyledRangeContainer` finishes merging provider results.
- Iterates runs from `styleContainer.runsIn(range:)`.
- For each run, calls `attributeProvider.attributesFor(run.value?.capture)` to get the theme attributes.
- Sets attributes on `textView.textStorage` within `beginEditing()`/`endEditing()` to batch the change.

**`visibleSetDidUpdate(_:)`**
- Called when the visible range changes (scroll, resize, etc.).
- Calls `highlightInvalidRanges()` on all provider states to fill in newly visible text.

**`setLanguage(language:)`**
- First clears all attributes to plain text (immediate visual feedback).
- Then calls `setLanguage` on each `HighlightProviderState`, which calls `setUp` on the underlying provider.

**`setProviders(_:)`**
- Uses `difference(from:)` with `inferringMoves()` to compute minimal provider changes.
- Handles insert (new provider setup), remove (cleanup), and move (priority reordering).
- Each new provider gets a unique incrementing `providerIdCounter`.

### `HighlightProviderState` (`Highlighting/HighlightProviding/HighlightProviderState.swift`)

Tracks valid, pending, and visible ranges for a single provider. This is the state machine that drives incremental highlighting.

**State model:**
- `validSet: IndexSet` — Ranges known to have correct highlights.
- `pendingSet: IndexSet` — Ranges where highlights have been requested but not yet applied.
- `visibleSet: IndexSet` — Retrieved from `VisibleRangeProvider`.
- `documentSet: IndexSet` — The entire document range.

**`storageDidUpdate(range:delta:)`**
- Calls `highlightProvider.applyEdit()` which returns invalidated indices.
- Unions the invalidated set with the edited range (to cover any unaccounted-for indices).
- Calls `invalidate(_:)` with the union.

**`getNextRange()`**
- Core of the incremental strategy. Computes:
  ```
  documentSet - validSet = invalid indices
  invalid ∩ visibleSet = visible invalid indices
  visible invalid - pendingSet = ranges to actually query
  ```
- Takes the first range from the result and chunks it to `rangeChunkLimit` (4096).
- This ensures: (a) only visible text is highlighted, (b) nothing already-requested is duplicated, (c) ranges are chunked for responsiveness.

**`queryHighlights(for:)`**
- For each range, calls `highlightProvider.queryHighlightsFor()`.
- On completion:
  - Removes the range from `pendingSet`.
  - Inserts the range into `validSet`.
  - On success: calls `delegate.applyHighlightResult()` (which is `StyledRangeContainer`).
  - On `.operationCancelled`: re-invalidates the range (it will be retried on the next pass).

**`invalidate()`**
- Clears `validSet` and `pendingSet`, then calls `highlightInvalidRanges()` to restart.

**`invalidate(_ set:)`**
- Subtracts the given set from `validSet`, then calls `highlightInvalidRanges()` to queue those ranges.

### `StyledRangeContainer` (`Highlighting/StyledRangeContainer/StyledRangeContainer.swift`)

The merge layer that combines highlight results from multiple providers.

**Storage: `[ProviderID: (store: RangeStore<StyleElement>, priority: Int)]`**

Each provider has its own `RangeStore` with a priority (lower = higher priority, matching insertion order).

**`StyleElement`**
- Contains `capture: CaptureName?` and `modifiers: CaptureModifierSet`.
- `isEmpty`: true when both capture and modifiers are empty.
- `combineLowerPriority(_:)`: keeps own capture, unions modifiers.
- `combineHigherPriority(_:)`: takes other's capture, unions modifiers.

**`applyHighlightResult(provider:highlights:rangeToHighlight:)`**
- Converts `[HighlightRange]` into `[RangeStoreRun<StyleElement>]` for the provider's `RangeStore`.
- Handles gaps: inserts empty runs for ranges not covered by any highlight.
- Handles overlaps: skips highlights whose lower bound is less than `lastIndex`.
- Calls `storage.set(runs:for:)` on the provider's store.
- Calls `delegate?.styleContainerDidUpdate(in:)` to trigger attribute application.

**`storageUpdated(editedRange:changeInLength:)`**
- Propagates the edit to every provider's `RangeStore`.

### `StyledRangeContainer+runsIn` (`StyledRangeContainer+runsIn.swift`)

**`runsIn(range:)`**
- The core coalescing algorithm.
- Collects all runs from all providers (sorted by priority, lower = higher priority).
- Iteratively finds the minimum-length run across all providers.
- For each other provider at the same position:
  - If its priority is higher (lower index): calls `combineHigherPriority`.
  - If its priority is lower: calls `combineLowerPriority`.
- Trims consumed lengths from each provider's runs.
- Appends the merged run and continues with the next shortest run.
- Returns the reversed accumulated list (built in reverse order internally).

**Complexity:** O(n × m) where n = total runs across providers, m = number of providers. Efficient because runs are inherently small (they only span visible ranges).

### `VisibleRangeProvider` (`Highlighting/VisibleRangeProvider.swift`)

**`visibleTextChanged()`**
- Computes `visibleSet` as an `IndexSet` from `textView.visibleTextRange`.
- If the minimap is visible, unions in `minimapView.visibleTextRange`.
- Calls `delegate?.visibleSetDidUpdate(visibleSet)`.

Listens to:
- `NSView.frameDidChangeNotification` on the scroll view and text view.
- `NSView.boundsDidChangeNotification` on the scroll view's content view.

### Comparison with CodeEditorPlugin

| Aspect | CodeEditSourceEditor | CodeEditorPlugin |
|--------|---------------------|------------------|
| Provider model | `HighlightProviding` protocol — multiple providers, priority stack | `SyntaxHighlightingProvider` protocol — single active provider |
| Incremental model | Valid/pending/visible state machine, chunked queries | Caching + async, but `OptimizedSyntaxHighlightingCoordinator` has TODO: falls back to full highlighting |
| Range merging | `StyledRangeContainer` with priority-based coalescing | N/A — single provider model |
| Visible tracking | `VisibleRangeProvider` — combined editor + minimap range | Viewport-oriented helpers |
| Storage | Per-provider `RangeStore` (rope-backed) | Attribute-based, line caches |

### Key Methods Summary

| Method | File | Line | Purpose |
|--------|------|------|---------|
| `textStorage(_:didProcessEditing:range:changeInLength:)` | Highlighter.swift | 220 | Edit handling, range store sync, visible tracking |
| `styleContainerDidUpdate(in:)` | Highlighter.swift | 256 | Apply merged styles to NSTextStorage |
| `visibleSetDidUpdate(_:)` | Highlighter.swift | 278 | Trigger highlighting for newly visible text |
| `setProviders(_:)` | Highlighter.swift | 155 | Diff-based provider add/remove/reorder |
| `storageDidUpdate(range:delta:)` | HighlightProviderState.swift | 138 | Propagate edit to provider, invalidate ranges |
| `getNextRange()` | HighlightProviderState.swift | 160 | Compute next range to highlight (valid/pending/visible logic) |
| `queryHighlights(for:)` | HighlightProviderState.swift | 179 | Query provider, update valid/pending on completion |
| `applyHighlightResult(provider:highlights:rangeToHighlight:)` | StyledRangeContainer.swift | 140 | Store provider results, convert to runs |
| `runsIn(range:)` | StyledRangeContainer+runsIn.swift | 19 | Priority-based multi-provider coalescing |
| `visibleTextChanged()` | VisibleRangeProvider.swift | 62 | Update visible indices on scroll/resize |

---

## 3. Shared Range Storage — `RangeStore`

### `RangeStore<Element>` (`RangeStore/RangeStore.swift`)

A generic rope-backed interval store. The most architecturally significant component in CodeEditSourceEditor.

**Core type:**
```swift
struct RangeStore<Element: RangeStoreElement>: Sendable {
    typealias Run = RangeStoreRun<Element>
    typealias RopeType = Rope<StoredRun>
    var _guts = RopeType()
}
```

Uses `_RopeModule` (from swift-collections), providing O(log n) insertion, deletion, and query on large documents.

**`init(documentLength:)`**
- Creates a rope with a single `StoredRun` of the document length with a nil value.
- This represents "no data" for the entire document.

**`runs(in:) -> [Run]`**
- Converts a range query into an array of `RangeStoreRun` values.
- Uses a cache (`private var cache: (range: Range<Int>, runs: [Run])?`) for repeated identical queries.
- Walks the rope from the index containing the range start, collecting runs until the range end.
- Handles partial runs (offset into the first run, clipping the last run).

**`set(value:for:)`**
- Wraps a single value + range into `set(runs:for:)`.

**`set(runs:for:)`**
- Replaces a subrange of the rope with new runs.
- Handles range clamping if the range extends beyond the current length.
- Calls `coalesceNearby(range:)` to merge adjacent identical values.
- Invalidates the cache.

**`storageUpdated(editedRange:changeInLength:)`**
- Sync adapter: converts NSTextStorage edit (range + delta) into rope operations.
- Deletion (`editedRange.length == 0`): removes the range (`range.location..<range.location - delta`) because `delta` is negative.
- Insertion/replacement: replaces the pre-edit range with a new empty run of `editedRange.length`.
- Clamps to valid range and calls `coalesceNearby`.

**`storageUpdated(replacedCharactersIn:withCount:)`**
- The rope-level sync method.
- If `newLength != 0`: replaces the range with an empty run.
- If `newLength == 0`: removes the subrange from the rope.
- Coalesces nearby runs to prevent fragmentation.

**`coalesceNearby(range:)`**
- Not fully shown in the excerpt, but described as merging adjacent runs with identical values on either side of the edit boundary.

**Usage in the codebase:**
- `StyledRangeContainer` stores per-provider `RangeStore<StyleElement>` for syntax highlighting.
- `LineFoldStorage` stores `RangeStore<FoldStoreElement>` for fold regions.

### `RangeStoreRun<Element>` and `StoredRun`

Not fully shown in the excerpt, but from usage:
- `RangeStoreRun`: has `length: Int` and `value: Element?`.
- Has an `.empty(length:)` static factory for nil-value runs.
- `StoredRun`: the internal rope element, with `length` and `value`.

### `RangeStoreElement` Protocol

From usage in `StyleElement` and `FoldStoreElement`:
```swift
protocol RangeStoreElement {
    var isEmpty: Bool { get }
}
```
This determines whether adjacent runs can be coalesced.

### Comparison with CodeEditorPlugin

| Aspect | CodeEditSourceEditor | CodeEditorPlugin |
|--------|---------------------|------------------|
| Shared storage | `RangeStore` — rope-backed, used for styles + folds | No equivalent — line caches, range utilities |
| Edit sync | `storageUpdated(editedRange:changeInLength:)` | N/A (each feature syncs independently) |
| Query | O(log n) rope traversal | Attribute-based runs via `NSTextStorage` |
| Coalescing | `coalesceNearby` automatic | Not applicable |

### Key Methods Summary

| Method | Line | Purpose |
|--------|------|---------|
| `runs(in:)` | 41 | Query runs in a range, cached for repeat queries |
| `set(value:for:)` | 76 | Write a single value to a range |
| `set(runs:for:)` | 86 | Replace a subrange with runs, auto-coalesce |
| `storageUpdated(editedRange:changeInLength:)` | 112 | NSTextStorage edit → rope sync |
| `storageUpdated(replacedCharactersIn:withCount:)` | 131 | Rope-level insert/delete |

---

## 4. Code Folding

### Architecture Overview

```
LineFoldModel (NSTextStorageDelegate, ObservableObject, conductor)
├── LineFoldCalculator (actor — async fold computation)
│   ├── LineFoldProvider (protocol — per-line fold detection)
│   │   └── LineIndentationFoldProvider (default impl — indent-based)
│   └── ChunkedLineIterator (AsyncSequence — main-actor-safe line iteration)
├── LineFoldStorage (Sendable — rope-backed fold cache)
│   └── RangeStore<FoldStoreElement>
└── FoldRange (stable ID, depth, range, collapse state)
```

```
LineFoldRibbonView (NSView — gutter ribbon drawing)
└── LineFoldRibbonView+Draw (dirty-rect fold marker rendering)
    └── FoldCapInfo (top/bottom cap logic for adjacent folds)

LineFoldPlaceholder (TextAttachment — collapsed region visual)
```

### `LineFoldModel` (`LineFolding/Model/LineFoldModel.swift`)

The conductor between fold calculation, storage, and UI.

**`init(controller:foldView:)`**
- Creates an `AsyncStream<Void>` for text change notifications.
- Creates `LineFoldCalculator` with the fold provider, controller, and text-change stream.
- Registers itself as an `NSTextStorageDelegate` on the text view.
- Starts an async `cacheListenTask` that `for await`s the calculator's `valueStream` and updates `@Published foldCache`.

**`textStorage(_:didProcessEditing:range:changeInLength:)`**
- On `.editedCharacters`: updates `foldCache.storageUpdated()` and yields to the text change stream.

**`getFolds(in:)`**
- Passes through to `foldCache.folds(in:)`. Returns all folds in a character range.

**`getCachedDepthAt(lineNumber:)` / `getCachedFoldAt(lineNumber:)`**
- Finds the deepest fold at a line number.
- For collapsed folds: prefers the deepest one (highest depth).
- For expanded folds: prefers the shallowest one (lowest depth).
- This ensures the ribbon shows the most relevant fold indicator.

**`emphasizeBracketsForFold(_:)`**
- When hovering a fold, checks if the characters just before/after the fold range are matching brackets.
- Uses `BracketPairs.matches()` for validation.
- Adds `Emphasis` objects with `.standard` style via the text view's emphasis manager.
- Calls `clearEmphasis()` first to avoid stale highlights.

**`placeholderDiscarded(fold:)`**
- Toggles the fold's collapse state in the cache.
- Triggers a redraw and re-yields to the text-change stream.

### `LineFoldCalculator` (`LineFolding/Model/LineFoldCalculator.swift`)

An `actor` that computes fold regions asynchronously.

**`listenToTextChanges(textChangedStream:)`**
- Creates a `textChangedTask` that iterates the stream: each event triggers `buildFoldsForDocument()`.

**`buildFoldsForDocument()`**
- Creates a `ChunkedLineIterator` that walks `textView.layoutManager.lineStorage`.
- For each chunk of 50 lines:
  - If `lineInfo.depth > currentDepth`: starts a new fold at that depth.
  - If `lineInfo.depth < currentDepth`: closes all open folds deeper than the new depth.
  - Appends completed folds to `foldCache`.
- After the loop: closes any remaining open folds at the document end.
- Calls `yieldNewStorage()` to create and emit a `LineFoldStorage`.

**`yieldNewStorage(newFolds:controller:documentRange:)`**
- Collects existing `LineFoldPlaceholder` attachments to preserve collapse state.
- Creates `DepthStartPair` for each attachment (depth + attachment range start).
- Builds `LineFoldStorage` with raw folds and the collapsed range set.
- Yields via `valueStreamContinuation`.

**`ChunkedLineIterator`**
- An `@MainActor AsyncSequence` that iterates the text line storage on the main thread.
- Processes 50 lines per chunk.
- Calls `foldProvider.foldLevelAtLine()` for each line.
- Tracks `previousDepth` across chunks for continuity.

### `LineFoldProvider` (`LineFolding/LineFoldProviders/LineFoldProvider.swift`)

```swift
public protocol LineFoldProvider: AnyObject {
    func foldLevelAtLine(
        lineNumber: Int,
        lineRange: NSRange,
        previousDepth: Int,
        controller: TextViewController
    ) -> [LineFoldProviderLineInfo]
}
```

Returns `[LineFoldProviderLineInfo]` — each entry is either `.startFold(rangeStart:newDepth:)` or `.endFold(rangeEnd:newDepth:)`.

### `LineIndentationFoldProvider` (`LineFolding/LineFoldProviders/LineIndentationFoldProvider.swift`)

The default implementation. Uses whitespace-based indentation:

- Computes `leadingDepth = leadingIndent / indentOption.charCount`.
- If `leadingDepth < previousDepth`: emits `.endFold` at the start of the line's whitespace.
- If the next line has more leading whitespace than the current line: emits `.startFold` at the current line's trailing whitespace position.

### `LineFoldStorage` (`LineFolding/Model/LineFoldStorage.swift`)

A `Sendable` struct that wraps `RangeStore<FoldStoreElement>`.

**`updateFolds(from:collapsedRanges:)`**
- Builds a `reuseMap` from existing `FoldRange` values keyed by `(depth, start)` to preserve IDs and collapse state.
- Clears the entire `RangeStore` and rebuilds it from raw folds.
- For each raw fold: reuses the prior ID if available, otherwise assigns a new one.
- Preserves `isCollapsed` if the fold existed before or if it's in `collapsedRanges`.

**`toggleCollapse(forFold:)`**
- Toggles `isCollapsed` on the stored `FoldRange`.

**`folds(in:)`**
- Queries the `RangeStore` for runs in the query range.
- Deduplicates by `FoldIdentifier` (since a fold may span multiple runs).
- Returns sorted by range start.

### `FoldRange` (`LineFolding/Model/FoldRange.swift`)

A simple `Sendable` struct with:
- `id: UInt32` — stable identifier for reuse across recalculations.
- `depth: Int` — nesting depth.
- `range: Range<Int>` — character range.
- `isCollapsed: Bool` — collapse state.

### `LineFoldRibbonView` (`LineFolding/View/LineFoldRibbonView.swift`)

**Drawing approach:** Custom `draw(_:)` implementation. Chosen over per-fold subviews for performance — no view reuse management, only draws what AppKit requests.

**Hover system:**
- `HoverAnimationDetails` with fold reference, animation timer, and progress.
- `CACurrentMediaTime()`-based animation (not Core Animation) because the draw path is manual.
- First hover: animates over 0.2s at 60fps via `Timer.scheduledTimer`.
- Subsequent hovers: instant (progress = 1.0).
- Tracks hover fold mask for clipping collapsed-fold indicators that overlap hovered folds.

**`mouseDown(with:)`**
- Determines which line was clicked from the y-position.
- Finds the deepest fold at that line via `getCachedFoldAt(lineNumber:)`.
- If a `LineFoldPlaceholder` attachment exists: removes it (unfold).
- If no attachment: creates a new `LineFoldPlaceholder` and adds it (fold).
- Toggles collapse state in the fold cache.

### `LineFoldRibbonView+Draw` (`LineFolding/View/LineFoldRibbonView+Draw.swift`)

**`draw(_:)`**
- Converts the dirty rect to text lines via `textLineForPosition()`.
- Gets folds within the text range via `getDrawingFolds()`.
- Computes `FoldCapInfo` for adjacent fold detection.
- Draws non-collapsed folds first, then collapsed folds on top (z-order).

**`getDrawingFolds(forTextRange:layoutManager:)`**
- Gets actual folds from `model.getFolds(in:)`.
- **Key detail:** Inserts "fake" folds for depths 1..<minimumDepth to create continuous background bars under nested folds. This gives the illusion of depth layers even when the queried range only contains deep folds.

**Three drawing modes:**
1. **Collapsed fold:** Filled rectangle + chevron (play-button-like triangle pointing right).
2. **Hovered fold:** Rounded rect with animation progress alpha, plus top/bottom chevrons.
3. **Nested fold:** Rounded rect with optional top/bottom caps (when adjacent folds exist on the same line). Light outline for depth > 0.

**`FoldCapInfo`**
- Precomputes sets of start/end line indices for collapsed and non-collapsed folds.
- Determines whether a fold marker needs a rounded cap on top or bottom.
- `adjustFoldRect()` extends marker rects by half-line-height when caps are needed (to close visual gaps).

### `LineFoldPlaceholder` (`LineFolding/Placeholder/LineFoldPlaceholder.swift`)

A `TextAttachment` subclass that represents collapsed content.

**`draw(in:context:rect:)`**
- Draws a rounded pill background (selected or normal color).
- Draws three small ellipses (pill dots with spacing based on `charWidth`).
- When selected: uses accent color, inverts text/background.

**`attachmentAction()`**
- Returns `.discard` — the attachment will be removed when interacted with.
- Calls `delegate.placeholderDiscarded(fold:)` to toggle the fold state.

### Comparison with CodeEditorPlugin

| Aspect | CodeEditSourceEditor | CodeEditorPlugin |
|--------|---------------------|------------------|
| Fold detection | `LineFoldProvider` protocol — indent-based default, extensible | `CodeFoldingEngine` — heuristic, regex-based |
| Fold storage | `RangeStore` in `LineFoldStorage` | Inline attributes |
| Collapsed visual | `LineFoldPlaceholder` (TextAttachment) | Hidden with attributes |
| Async computation | `LineFoldCalculator` actor + `AsyncStream` | Synchronous |
| State reuse | Stable `FoldIdentifier` across recalculations | N/A |
| UI | Custom-drawn `LineFoldRibbonView` with hover animation | Attribute-based inline |

### Key Methods Summary

| Method | File | Line | Purpose |
|--------|------|------|---------|
| `textStorage(_:didProcessEditing:range:changeInLength:)` | LineFoldModel.swift | 60 | Edit → storage sync → trigger recalc |
| `getCachedFoldAt(lineNumber:)` | LineFoldModel.swift | 83 | Find deepest fold at a line |
| `emphasizeBracketsForFold(_:)` | LineFoldModel.swift | 99 | Bracket pair highlight on hover |
| `buildFoldsForDocument()` | LineFoldCalculator.swift | 59 | Async fold computation loop |
| `yieldNewStorage(newFolds:controller:documentRange:)` | LineFoldCalculator.swift | 116 | Build storage from folds + preserve collapse |
| `updateFolds(from:collapsedRanges:)` | LineFoldStorage.swift | 49 | Rebuild fold storage, preserve IDs |
| `folds(in:)` | LineFoldStorage.swift | 88 | Query folds in a character range |
| `foldLevelAtLine(...)` | LineIndentationFoldProvider.swift | 23 | Indent-based fold detection |
| `mouseDown(with:)` | LineFoldRibbonView.swift | 121 | Click to toggle fold collapse |
| `setHoveredFold(fold:)` | LineFoldRibbonView.swift | 187 | Hover animation management |
| `draw(_:)` | LineFoldRibbonView+Draw.swift | 20 | Dirty-rect fold marker rendering |
| `getDrawingFolds(forTextRange:layoutManager:)` | LineFoldRibbonView+Draw.swift | 76 | Get folds + fake depth layers |
| `draw(in:context:rect:)` | LineFoldPlaceholder.swift | 41 | Collapsed region pill + dots |

---

## 5. Rendering

### Gutter View

#### `GutterView` (`Gutter/GutterView.swift`)

A `NSView` subclass that functions as the scroll view's ruler view for line numbers. It sits on top of the text view.

**Key properties:**
- `edgeInsets: EdgeInsets` — 20px leading, 12px trailing padding around line numbers.
- `backgroundEdgeInsets: EdgeInsets` — 0px leading, 8px trailing padding for the background fill. Allows 8px of text to scroll under the gutter before being overlapped.
- `foldingRibbonPadding: CGFloat = 4` — Space between line numbers and the fold ribbon.
- `maxLineNumberWidth` / `maxLineLength` — Tracks the widest line number for layout.

**`updateWidthIfNeeded()`**
- Computes the required width from the widest line number + insets + folding ribbon width.
- Reserves at least 3 digits of space (`max(3, ...)`).
- If width changed: updates `frame.size.width` and calls `delegate?.gutterViewWidthDidUpdate()`.

**`draw(_:)`** — Three-layer drawing:
1. **`drawBackground(_:dirtyRect:)`** — Fills background color, respecting `backgroundEdgeInsets` and excluding the folding ribbon width. Uses `dirtyRect` for efficient partial redraws.
2. **`drawSelectedLines(_:)`** — Draws selected-line highlights. Iterates `selectionManager.textSelections`, finds the text line for each empty selection via `textLineForOffset()`, and fills a rect behind each line. Skips already-drawn lines (tracked by line `UUID`).
3. **`drawLineNumbers(_:dirtyRect:)`** — Draws line numbers only for lines visible in the dirty rect.
   - Builds a `selectionRangeMap: IndexSet` for all selection ranges.
   - Iterates `layoutManager.linesStartingAt(_:until:)` — only queries lines in the dirty rect.
   - For each line position: creates a `CTLine` from the line number string in the correct font/color.
   - Selected lines use `selectedLineTextColor`; others use `textColor`.
   - Y-position: `linePosition.yPos + ascent + (fragmentHeightDifference)/2 + fontHeightDifference` — accounts for the difference between the font's typographic bounds and the line fragment's height.
   - X-position: `edgeInsets.leading + (maxLineNumberWidth - lineNumberWidth)` — right-aligns within the number column.

**Selection notification:** Listens to `TextSelectionManager.selectionChangedNotification` and marks itself for display.

### Minimap

#### `MinimapView` (`Minimap/MinimapView.swift`)

Displays a compact representation of the editor contents as colored "bubbles" (not raw tiny text).

**Subviews (back-to-front):**
```
MinimapView
├── separatorView      (1px leading line)
├── documentVisibleView (draggable visible-region indicator)
└── scrollView
    └── contentView    (contains MinimapLineFragmentView instances)
```

**`init(textView:theme:)`**
- Creates a `MinimapLineRenderer` (custom `LineFragmentRenderer`).
- Creates a `ForwardingScrollView` that forwards scroll events to the editor's scroll view.
- Sets up a `TextLayoutManager` sharing the same `textStorage` as the main editor — **this is the key architecture: the minimap uses the existing text storage, not a copy.**
- Sets up a `TextSelectionManager` for drawing selections in the minimap.
- Listens to editor scroll/bounds changes to update the visible-region indicator.

**`updateDocumentVisibleViewPosition()`**
- Computes the position and height of the visible-region box based on the editor-to-minimap height ratio.

**`updateContentViewHeight()`**
- Computes the minimap content height from `layoutManager.estimatedHeight()`.
- Accounts for overscroll: `containerHeight * overscrollAmount * (estimatedContentHeight / editorEstimatedHeight)`.
- Clamps to not exceed the text view's frame height.

**`hitTest(_:)`**
- Optimized: only checks the `documentVisibleView` and the visible rect — avoids hit-testing individual line fragment views for performance.

#### `MinimapLineFragmentView` (`Minimap/MinimapLineFragmentView.swift`)

**`setLineFragment(_:fragmentRange:renderer:)`**
- Receives a `LineFragment` (which includes the content runs — text runs and attachments).
- For each text run (`case .text`): calls `addDrawingRunsUntil()` to build colored runs from the text storage's foreground color attributes.
- For each attachment run: creates a clear-colored run.
- **Whitespace filtering:** Within the `addDrawingRunsUntil` method, for each range sharing the same foreground color, it splits the range at whitespace boundaries. Only non-whitespace characters get drawing runs. This produces the "bubble" effect.

**`addDrawingRunsUntil(max:position:textStorage:fragmentRange:)`**
- Uses `textStorage.attribute(.foregroundColor, at:position, longestEffectiveRange:in:)` to find the longest continuous color run.
- Within that run, splits at whitespace/newline characters (using `CharacterSet.whitespacesAndNewlines`).
- Appends `Run(color:range:)` for each non-whitespace segment.

**`appendDrawingRun(color:range:fragmentRange:)`**
- Normalizes the range to be fragment-relative (subtracts `fragmentRange.location`).
- Applies 0.4 alpha to the color.
- Appends to `drawingRuns`.

**`draw(_:)`**
- For each cached `Run`: draws a tiny rectangle at `x: 8 + (location * 1.5), y: 0.25, width: length * 1.5, height: 2.0`.
- This creates a 2px tall bar at a scaled position, producing a "colored bar chart" of the code structure.

### Comparison with CodeEditorPlugin

| Aspect | CodeEditSourceEditor | CodeEditorPlugin |
|--------|---------------------|------------------|
| Gutter drawing | Dirty-rect based, only visible lines | Cross-platform, custom |
| Line number alignment | Right-aligned within column, typographic ascent correction | Standard |
| Selection background | Drawn in gutter, matches text view seamlessly | Present but simpler |
| Minimap content | Colored bubbles from existing `foregroundColor` attributes | Simple/minimal, not syntax-aware |
| Minimap storage | Shares `NSTextStorage` with main editor | Separate approach |
| Minimap line rendering | `MinimapLineFragmentView` with whitespace filtering | No equivalent |
| Visible region | Draggable `documentVisibleView` overlay | Not present |

### Key Methods Summary

| Method | File | Line | Purpose |
|--------|------|------|---------|
| `updateWidthIfNeeded()` | GutterView.swift | 188 | Dynamic gutter width based on line count |
| `draw(_:)` | GutterView.swift | 322 | Three-layer gutter rendering |
| `drawBackground(_:dirtyRect:)` | GutterView.swift | 218 | Dirty-rect background fill |
| `drawSelectedLines(_:)` | GutterView.swift | 233 | Selection highlighting in gutter |
| `drawLineNumbers(_:dirtyRect:)` | GutterView.swift | 272 | Dirty-rect line number drawing |
| `setLineFragment(_:fragmentRange:renderer:)` | MinimapLineFragmentView.swift | 46 | Build drawing runs from fragment contents |
| `addDrawingRunsUntil(max:position:textStorage:fragmentRange:)` | MinimapLineFragmentView.swift | 74 | Color-run building with whitespace filtering |
| `draw(_:)` | MinimapLineFragmentView.swift | 137 | Bubble rendering |
| `updateContentViewHeight()` | MinimapView.swift | 289 | Minimap height sync with editor |

---

## 6. Configuration And State

### `SourceEditorConfiguration` (`SourceEditorConfiguration/SourceEditorConfiguration.swift`)

A clear separation between **configuration** (stable settings) and **state** (dynamic editor state).

**Four categories:**
- **`Appearance`** — theme, font, line height multiple, letter spacing, wrap lines, cursor style, tab width, bracket pair emphasis.
- **`Behavior`** — editable, selectable, indent option, reformat column.
- **`Layout`** — overscroll amount, content insets, additional text insets.
- **`Peripherals`** — gutter visibility, minimap visibility, reformatting guide, folding ribbon, invisible characters config, warning characters.

**`didSetOnController(controller:oldConfig:)`**
- Called when configuration changes. Each sub-struct has its own `didSetOnController` that diffs against the old config and applies only changed properties.
- Examples:
  - Font change: updates `textView.font`, `typingAttributes`, `gutterView.font`, invalidates highlighter.
  - Theme change: sets attributes on entire text storage, updates selection colors, gutter colors, minimap theme.
  - Tab width change: regenerates `paragraphStyle`, triggers layout.
  - Indent option change: calls `setUpTextFormation()`.
  - Gutter visibility: toggles `isHidden`, updates content/text insets.

### `SourceEditorState` (`SourceEditorState/SourceEditorState.swift`)

A `Sendable, Codable` struct for dynamic editor state that changes during editing:

- `cursorPositions: [CursorPosition]?` — Saved cursor positions.
- `scrollPosition: CGPoint?` — Saved scroll offset.
- `findText: String?` — Current find query.
- `replaceText: String?` — Current replace text.
- `findPanelVisible: Bool?` — Find panel visibility.

All optional: allows partial application (e.g., only restore scroll position without changing find text).

### Comparison with CodeEditorPlugin

| Aspect | CodeEditSourceEditor | CodeEditorPlugin |
|--------|---------------------|------------------|
| Config vs state | Explicit separation: `SourceEditorConfiguration` vs `SourceEditorState` | `EditorConfiguration` covers both, no typed interaction state object |
| Change detection | `didSetOnController` with per-property diffing | Various mechanisms |
| State serialization | `Codable` + `Sendable` on state struct | N/A |
| Config granularity | Four sub-structs with clear boundaries | Flatter structure |

### Key Methods Summary

| Method | File | Line | Purpose |
|--------|------|------|---------|
| `didSetOnController(controller:oldConfig:)` | SourceEditorConfiguration.swift | 76 | Top-level config change → sub-struct delegation |
| `Appearance.didSetOnController(controller:oldConfig:)` | +Appearance.swift | 83 | Font/theme/line-height/tab-width change handling |
| `Behavior.didSetOnController(controller:oldConfig:)` | +Behavior.swift | 36 | Editability/selectability/indent change handling |
| `Layout.didSetOnController(controller:oldConfig:)` | +Layout.swift | 33 | Overscroll/inset change handling |
| `Peripherals.didSetOnController(controller:oldConfig:)` | +Peripherals.swift | 48 | Gutter/minimap/ribbon visibility toggles |

---

## 7. Extensibility

CodeEditSourceEditor's extension points are small, focused protocols:

| Protocol | Purpose | Line |
|----------|---------|------|
| `HighlightProviding` | Syntax highlighting provider (TreeSitterClient, LSP, spellcheck) | HighlightProviding.swift:19 |
| `LineFoldProvider` | Fold region detection (indent-based, could be parser-backed) | LineFoldProvider.swift:44 |
| `GutterViewDelegate` | Gutter width change notifications | GutterView.swift:12 |
| `VisibleRangeProviderDelegate` | Visible range change notifications | VisibleRangeProvider.swift:12 |
| `HighlightProviderStateDelegate` | Highlight result application bridge | HighlightProviderState.swift:14 |
| `StyledRangeContainerDelegate` | Style update notification bridge | StyledRangeContainer.swift:11 |
| `LineFoldPlaceholderDelegate` | Placeholder theme color queries | LineFoldPlaceholder.swift:11 |

The extension model is practical: define a protocol, implement it, register with the controller. No dependency injection framework — just direct constructor injection and protocol conformance.

Compared to CodeEditorPlugin's event system and DI, this is lighter weight but less flexible for cross-cutting concerns.

---

## 8. Architecture Patterns

### Pattern 1: Rope-Backed Interval Storage

`RangeStore` is the foundational data structure. It provides O(log n) interval operations and is used for both syntax highlighting and folding. The pattern:
- Each feature stores its data as a `RangeStore` keyed by character range.
- `storageUpdated()` keeps the rope in sync with text edits.
- `runs(in:)` queries for display.

This is the single most important architectural insight: **share a range-run storage model across features instead of each feature building its own partial view.**

### Pattern 2: Valid/Pending/Visible State Machine

`HighlightProviderState` models highlighting as three sets:
- **Valid** — already highlighted.
- **Pending** — requested but not yet applied.
- **Visible** — currently in viewport.

New ranges to highlight = (document - valid) ∩ visible - pending.

This eliminates redundant work and naturally throttles to visible-only content.

### Pattern 3: Priority-Based Provider Overlays

`StyledRangeContainer` merges multiple highlight providers by priority. Each provider independently stores its results in a `RangeStore`. The `runsIn()` coalescing algorithm merges them on demand. This lets different providers (Tree-sitter, LSP, spellcheck) coexist without conflicts.

### Pattern 4: Async Actor Computation with Sync Storage

`LineFoldCalculator` (actor) computes folds asynchronously and yields `LineFoldStorage` (Sendable struct) to the main thread. The `LineFoldModel` observes the stream via a `Task` and updates `@Published foldCache`. This cleanly separates computation from storage.

### Pattern 5: Attachment-Backed Folding

Folding uses `TextAttachment` subclasses (`LineFoldPlaceholder`) rather than attribute manipulation. This avoids conflicts with other features (like syntax highlighting) that also modify attributes. The attachment is a self-contained visual and behavioral unit.

### Pattern 6: Dirty-Rect Gutter Drawing

The gutter draws only what AppKit requests via `draw(_ dirtyRect:)`. Line numbers are queried via `linesStartingAt(_:until:)` which only returns lines intersecting the dirty rect. This is scroll-performant without view reuse overhead.

---

## 9. Risks and Limitations Noted in the Source

### In CodeEditSourceEditor Itself

1. **Parser.reset() via Mirror reflection** (`LanguageLayer.swift:14-22`): Uses `Mirror` to access the private `internalParser` property on `SwiftTreeSitter.Parser`. This is a fragile workaround for a missing API. Any change to the `Parser` type's internal structure will break this silently.

2. **Full-document fold recalculation** (`LineFoldCalculator.swift:59`): Every edit triggers a full `buildFoldsForDocument()`, which re-processes the entire document. For large files this could be expensive despite being on an actor.

3. **Chunked line iteration** (`LineFoldCalculator.swift:169`): Processes 50 lines per chunk but on the main actor. For very large files, this could block the main thread briefly every 50 lines.

4. **Rope coalescence not shown** : `coalesceNearby(range:)` on `RangeStore` is mentioned but the implementation details aren't visible in the excerpt. Incorrect coalescence could cause fragmentation.

5. **No cancellation of `ChunkedLineIterator`** : Once started, the fold calculation iterates the entire document. Unlike Tree-sitter's `parserTimeout`, there's no per-chunk timeout.

6. **macOS/AppKit only** : The entire rendering layer (GutterView, MinimapView, LineFoldRibbonView) is `NSView`-based with Core Graphics drawing. Porting to other platforms would require rewriting the rendering layer entirely.

### Cross-Referenced with CodeEditorPlugin

7. **Incremental highlighting TODO** : `OptimizedSyntaxHighlightingCoordinator` has incremental highlighting marked as TODO and falls back to full highlighting.

8. **Simplified performance scaffolding** : `TextKit2RenderingOptimizer` has simulated prefetch work; `OptimizedLineIndexCache` has a simplified multi-line edit path that doesn't incrementally update the tree.

9. **Token offset mismatch** : SwiftSyntax positions are UTF-8 offsets while `NSRange` is UTF-16 based. This is a known risk for any Swift syntax highlighting.

10. **Heuristic folding** : Brace folding can misread braces inside strings or comments; XML/HTML folding is regex-based and may mishandle nested same-name tags.

---

## 10. Recommended Migration Path

Based on the deep analysis, the following approach is recommended for bringing CodeEditSourceEditor patterns into CodeEditorPlugin:

1. **Add `RangeStore` as a shared layer** (low risk, high impact). This is a pure data structure with no platform dependencies. It can be used by highlighting, folding, diagnostics, and annotations.

2. **Adopt the valid/pending/visible state machine** for highlighting providers. This replaces the current fallback-to-full-highlighting pattern.

3. **Evaluate Tree-sitter for non-Swift languages.** The `TreeSitterExecutor` pattern (priority queue with sync/async fallback) is well-designed and could be ported.

4. **Replace attribute-based fold hiding with `TextAttachment`-based placeholders.** This eliminates attribute conflicts.

5. **Make the minimap consume style runs** (from the shared `RangeStore`), producing colored bars like `MinimapLineFragmentView` instead of raw tiny text.

6. **Add `EditorInteractionState`** modeled after `SourceEditorState` for cursor, scroll, find, and fold state.

7. **Replace heuristic fold providers** with parser-backed providers using the `LineFoldProvider` protocol.

8. **Audit and complete or remove performance scaffolding** that is currently simplified (TextKit2RenderingOptimizer, OptimizedLineIndexCache).
