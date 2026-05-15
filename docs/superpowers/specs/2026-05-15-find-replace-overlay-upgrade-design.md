# Find/Replace Overlay Upgrade — Design

**Status:** Draft (brainstorming complete; awaiting user review)
**Date:** 2026-05-15
**Closes:** NEXT.md A.1 ("Find/Replace match highlighting") and A.3 #4 ("Find/Replace overlay should call `SearchReplaceEngine` for both navigation and decoration").
**Scope:** macOS only. iOS overlay is explicitly deferred.

## Context

NEXT.md describes two related sample-side gaps:

- **A.1**: "Find/Replace match highlighting. `EditorActions/FindReplaceOverlay.swift` tracks counts but doesn't decorate matches in the text. `SearchReplaceEngine` supports this."
- **A.3 #4**: "Find/Replace overlay should call `SearchReplaceEngine` for both navigation and decoration, not maintain its own match counter logic."

A read of the current code shows both claims are partially stale. `FindReplaceOverlay` already calls `editorController.find / findNext / findPrevious / replaceAll`, and `SearchReplaceEngine` already paints yellow persistent highlights via `addPersistentAttributes(.backgroundColor:)` when `SearchOptions.highlightResults == true` (the default). Match counts come from `EditorController.matchCount` / `currentMatchIndex`, which mirror the engine — the overlay does not maintain a separate counter.

The real, concrete gaps are subtler:

1. **No visual distinction between the active match and the others.** Every match gets the same yellow background; only a brief 0.3 s blue flash marks the active one on navigation.
2. **No options UI.** Case-sensitive, regex, and whole-word toggles are unexposed in the overlay even though the engine supports all three.
3. **No single-match replace.** Only "Replace All" is wired; the engine supports `replace(at:with:)`.
4. **No live search.** The user must hit Return or click the re-run button.
5. **Highlight lifecycle is implicit.** `EditorController.clearSearch()` only resets cached counters; its doc comment explicitly admits it does not clear highlights. Tab switch, overlay close, document edit, and language/theme change all leave stale yellow ranges.
6. **No snapshot coverage** of the overlay.

This spec closes those gaps with one small framework change and a self-contained sample-side rewrite. It also seeds the eventual AppState decomposition (NEXT.md A.3 #1) by lifting find/replace state into a feature-scoped `@Observable` model.

## Goals

- Visually distinguish the **current** match from the **other** matches.
- Surface case-sensitive, regex, and whole-word toggles in the overlay.
- Add a single-match Replace button alongside Replace All.
- Run searches live, debounced at 150 ms.
- Clear highlights on overlay close, document edit, tab switch, and language/theme change.
- Pull `findText`, `replaceText`, and overlay visibility off `AppState` into a `FindReplaceModel`.
- Snapshot-test the overlay's relevant states.
- Keep the framework change minimal and additive (one optional field on `SearchOptions`, one internal repaint hook, and a tightened `EditorController.clearSearch()` contract).

## Non-goals

- No iOS find/replace surface this round.
- No project-wide find. `ProjectSearchPanelView` (already shipped) is unaffected.
- No new search options beyond the three the engine already supports.
- No regex timeout or pathological-input defenses on the engine.
- No new public framework decoration provider abstraction.
- No work on NEXT.md B.3 (`EditorState.isDirty`) even though Replace All mutates the document.
- No timing-sensitive tests on the 150 ms debounce.

## Approach

Selected from three alternatives:

- **A. Framework grows `SearchOptions.currentMatchColor`; sample drives the rest.** *(chosen)*
- **B. Sample-only: drive the two-layer highlight from the sample.** Rejected — duplicates the engine's highlight bookkeeping in the sample, contrary to the spirit of NEXT.md A.3 #4.
- **C. Replace the engine's persistent-attributes layer with a `SearchHighlightProvider` decoration source.** Rejected on YAGNI grounds — no other decoration consumer is asking for the abstraction.

Approach A keeps the engine's "I own highlight painting" invariant intact. Future hosts that drive the engine (LSP-driven find, project-search jump-to-match) inherit current-match styling without re-implementing it.

## Architecture

### Framework changes

In `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`:

1. `SearchOptions` gains an optional `currentMatchColor: PlatformColor?` (default `nil`). When `nil`, all matches receive `highlightColor` exactly as today.
2. `highlightSearchResults(_:)` paints two layers when `currentMatchColor != nil`: clear → paint every result with `highlightColor` → over-paint `currentSearchResults[currentSearchIndex]` with `currentMatchColor`.
3. New private `repaintCurrentMatch()` helper. Called from `findNext()` and `findPrevious()` after `currentSearchIndex` moves; swaps colors for the two affected ranges.
4. `flashRange(_:)` consults `currentSearchIndex` before reapplying the post-flash color, so the active match returns to `currentMatchColor` rather than `highlightColor`.

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`:

5. `clearSearch()` actually clears in-editor highlights. Implementation: call a new private engine helper that wipes persistent `.backgroundColor` attributes over `fullRange` and resets `currentSearchResults` / `currentSearchIndex`. Synchronous — no scanning. The existing doc-comment apology is removed.
6. New public `replaceCurrent(with replacement: String) -> Bool` that wraps `engine.replace(at: currentSearchIndex, with:)` and refreshes the controller's mirrored counters. Returns `true` when a replacement happened.

### Sample changes

All under `Sources/CodeEditorSample/EditorActions/`:

7. **`FindReplaceOptions.swift`** — small `Hashable` value type bridging to framework `SearchOptions`.
8. **`FindReplaceModel.swift`** — `@Observable @MainActor` class owning the entire find/replace state surface (see API Surface section).
9. **`FindReplaceOverlay.swift`** — rewritten to read/write `FindReplaceModel`. Three-row layout: find row, replace row, optional options-disclosure row.
10. **`AppState`** — `findText`, `replaceText`, and `findOverlayVisible` removed; replaced by `let findReplace = FindReplaceModel()`. Command-palette entries, hotkeys, and `WindowBody.swift`'s `safeAreaInset` host all redirect through `appState.findReplace`.

### Files touched

| Path | Change |
|---|---|
| `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` | Add `currentMatchColor`, `repaintCurrentMatch()`, adjust `flashRange` and `highlightSearchResults`. |
| `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` | Tighten `clearSearch()` contract, add `replaceCurrent(with:)`. |
| `Sources/CodeEditorSample/App/AppState.swift` | Remove three find/replace properties; add `findReplace` model handle. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceOverlay.swift` | Rewrite. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift` | New. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceOptions.swift` | New. |
| `Sources/CodeEditorSample/App/WindowBody.swift` | Update `safeAreaInset` binding; install lifecycle `.onChange` hooks. |
| `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift` | Rebind ⌘F / ⌘G / ⇧⌘G to the model. |

## Data flow

`FindReplaceModel` exposes a single `Hashable` request:

```swift
struct SearchRequest: Hashable {
    var pattern: String
    var options: FindReplaceOptions
    var documentID: EditorDocument.ID?
    var documentRevision: Int
}
```

The overlay binds `.task(id: model.searchRequest(activeDocument:)) { await model.runDebouncedSearch(request:controller:) }`. SwiftUI cancels and restarts the task whenever any component of the request changes. Debounce, document edit, tab switch, and option toggles all flow through one path.

### Typing in the find field

1. `findText` writes through the `@Bindable` model.
2. `searchRequest` recomputes → task restarts.
3. Task sleeps 150 ms. If the user keeps typing, the task is cancelled before it ever runs.
4. After the sleep, `Task.isCancelled` guard, then `await controller.find(pattern, options:)`.
5. Engine paints both layers and scrolls to the first match.
6. Model reads `controller.matchCount` and `controller.currentMatchIndex` to drive the badge.
7. Empty `findText` → model calls `controller.clearSearch()` instead of `find("")`.

### ↑ / ↓ navigation

Button → `model.findPrevious(controller:)` / `findNext(controller:)` → `controller.findPrevious()` / `findNext()`. The engine mutates `currentSearchIndex`, calls `repaintCurrentMatch()`, and scrolls. The match badge updates because `controller.currentMatchIndex` is `@Observable`.

### Option toggle

Setter writes `model.options` → `searchRequest` changes → task restarts → re-search from scratch with the new `SearchOptions`. Acceptable cost: option toggles are manual, not per-keystroke.

### Replace (single)

`model.replaceCurrent(controller:)` → `controller.replaceCurrent(with: replaceText)` → engine mutates the document and adjusts indices via the existing `updateResultsAfterReplacement`. The engine's existing logic moves `currentSearchIndex` backward by one when the replaced index equals current (matches `currentSearchIndex >= index` → `max(0, index - 1)`); that is the desired behavior elsewhere but produces a backward jump for our "replace then advance" UX. `EditorController.replaceCurrent(with:)` therefore explicitly calls `engine.findNext(from: nil)` after the replace so the user moves forward through the remaining matches, matching Xcode and VS Code. Disabled when `matchCount == 0` or the active config is read-only.

### Replace All

Unchanged call path: `controller.replaceAll(pattern, with:)`. Engine clears results after replacing. Model triggers one final re-search so the user sees the post-replace state highlighted (often "0 matches").

### Close (ESC / × / ⌘F again)

ESC and the × button set `model.isOverlayVisible = false`. `.onChange(of: model.isOverlayVisible)` in `WindowBody.swift`: when `false`, `controller.clearSearch()` is invoked (now actually clears highlights). The model keeps `findText` / `replaceText` in memory so reopening restores them.

### Document edit

`.onChange(of: appState.activeDocument?.revision)` in `WindowBody.swift` calls `controller.clearSearch()` immediately so stale highlight ranges (which would render at shifted positions after the edit) vanish on the same frame as the keystroke. Independently, `appState.activeDocument.revision` is also part of `SearchRequest`, so the `.task(id:)` restarts and re-runs the search after the 150 ms debounce. Net effect: highlights briefly absent during the debounce window, then repainted at the new positions.

### Tab switch / language change / theme change

`.onChange(of: appState.activeDocument?.id)` calls `controller.clearSearch()` immediately so the old tab's highlights vanish without waiting for the debounce. The new `searchRequest` then triggers a re-search on the new document. Language and theme changes follow the same pattern.

## API surface

### Framework

```swift
// Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift

public struct SearchOptions {
    // ... existing fields unchanged ...

    /// Optional second color for the *active* match. When non-nil,
    /// `SearchReplaceEngine.highlightSearchResults(_:)` paints the
    /// active match (`currentSearchResults[currentSearchIndex]`) with
    /// this color and the other matches with `highlightColor`. When
    /// nil, behavior is identical to prior releases.
    public var currentMatchColor: PlatformColor?
}
```

```swift
// Sources/CodeEditorPlugin/SwiftUI/EditorController.swift

/// Replace the currently active match with `replacement` and let the
/// engine advance to the next match. Returns true if a replacement
/// happened. No-op when there is no current match.
@discardableResult
public func replaceCurrent(with replacement: String) -> Bool

/// Reset cached search state AND clear in-editor match highlights.
public func clearSearch()
```

`repaintCurrentMatch()` is private to the engine. The 150 ms debounce constant is internal to `FindReplaceModel.swift`.

### Sample

```swift
// Sources/CodeEditorSample/EditorActions/FindReplaceOptions.swift

struct FindReplaceOptions: Hashable {
    var caseSensitive: Bool = false
    var wholeWord: Bool = false
    var useRegularExpression: Bool = false
}

extension FindReplaceOptions {
    func toSearchOptions() -> SearchOptions {
        var o = SearchOptions()
        o.caseSensitive = caseSensitive
        o.wholeWord = wholeWord
        o.useRegularExpression = useRegularExpression
        o.highlightColor = PlatformColor.findHighlight
        o.currentMatchColor = PlatformColor.findActiveMatch
        return o
    }
}
```

```swift
// Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift

@Observable
@MainActor
final class FindReplaceModel {
    var findText: String = ""
    var replaceText: String = ""
    var isOverlayVisible: Bool = false
    var options: FindReplaceOptions = .init()
    var isOptionsExpanded: Bool = false

    private(set) var matchCount: Int = 0
    private(set) var currentMatchPosition: Int = 0
    private(set) var lastError: FindError?

    enum FindError: Equatable {
        case invalidRegex
    }

    struct SearchRequest: Hashable {
        var pattern: String
        var options: FindReplaceOptions
        var documentID: EditorDocument.ID?
        var documentRevision: Int
    }

    func searchRequest(activeDocument: EditorDocument?) -> SearchRequest
    func runDebouncedSearch(request: SearchRequest, controller: EditorController) async
    func findNext(controller: EditorController)
    func findPrevious(controller: EditorController)
    func replaceCurrent(controller: EditorController)
    func replaceAll(controller: EditorController) async
    func close(controller: EditorController)
    func canReplace(activeConfig: EditorConfiguration?) -> Bool
}
```

Two sample-local color tokens are added: `PlatformColor.findHighlight` (yellow @ 30% alpha, matching today's default) and `PlatformColor.findActiveMatch` (`NSColor.selectedTextBackgroundColor` on macOS).

## Error handling

- **Invalid regex.** When `options.useRegularExpression == true`, the model pre-validates the pattern via `NSRegularExpression(pattern:options:)`. On throw, `lastError = .invalidRegex`, the controller is not called, and the badge renders "Invalid regex" in place of the count.
- **Empty pattern.** Model calls `controller.clearSearch()` and resets counters; no `find("")` call.
- **Zero matches.** Badge renders `0` greyed out (matches today's lines 92–98). No flash, no scroll.
- **Replace with no current match.** `replaceCurrent` early-exits; the button is disabled in the view.
- **Read-only document.** `model.canReplace(activeConfig:)` returns `false`; both Replace buttons disable.
- **Rapid typing.** `.task(id:)` cancels prior task before starting a new one. Worst case: a stale completion writes mirror state that is overwritten on the next run. Acceptable.
- **Engine flash on the current match.** `flashRange` now consults `currentSearchIndex` and reapplies `currentMatchColor` to the current match.

Out of scope: regex timeouts, pathological-pattern defenses, multi-line patterns.

## Testing

### Framework — `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

1. `testSearchOptionsCurrentMatchColorPaintsTwoLayers`
2. `testFindNextRepaintsPreviousCurrentToHighlightColor`
3. `testFindPreviousRepaintsCorrectly`
4. `testClearSearchAlsoClearsHighlights`
5. `testReplaceCurrentAdvancesToNextMatch`
6. `testCurrentMatchColorNilPreservesLegacyBehavior`
7. `testFlashRangeReappliesCurrentMatchColorOnCurrentMatch`

All inspect `textKitBridge`'s attribute store directly. Test (7) sleeps past the 300 ms flash duration; the rest are synchronous.

### Sample — `Tests/CodeEditorSampleTests/FindReplaceModelTests.swift` (new)

1. `testSearchRequestEqualsWhenIdenticalInputs`
2. `testEmptyPatternCallsClearSearch`
3. `testRegexValidationFailureStoresLastError`
4. `testOptionsToggleResetsCurrentMatchPosition`
5. `testCloseClearsControllerAndHidesOverlay`
6. `testReplaceCurrentDisabledWhenNoMatches`

Uses a sample-local `FindReplaceControlling` protocol that the real `EditorController` conforms to via extension. Stub implementation supplied by the test target. The protocol is not exposed from the framework.

### Sample snapshots — `Tests/CodeEditorSampleTests/FindReplaceOverlaySnapshotTests.swift` (new)

1. `testOverlay_idleNoQuery`
2. `testOverlay_withMatches`
3. `testOverlay_zeroMatches`
4. `testOverlay_optionsExpanded`
5. `testOverlay_optionsExpanded_caseAndRegexOn`
6. `testOverlay_invalidRegex`
7. `testOverlay_readOnlyConfig`

Record with `isRecording: true`, commit the generated images. Snapshots write to `__Snapshots__/` (already gitignored per `Package.swift` excludes).

### Not tested

- Live-debounce per-millisecond timing (flaky, low value).
- The actual highlighted editor view via snapshot (the existing `EditorStatusBarSnapshots/*` SIGSEGV/SIGBUS issue on the flake list rules this out — see NEXT.md section D).
- iOS surface.

## Risks and open questions

- **`EditorDocument.revision` may not exist yet.** The data flow assumes a monotonic counter on the document that bumps on text mutation. If absent, the implementation plan must add one (small change — likely a `private(set) var revision: Int = 0` incremented in the document's text setter) or fall back to using `text.hashValue` (cheaper to compute on short documents than long ones, but stable).
- **Flash colour at the moment of a navigation event.** If the user spam-clicks ↑/↓ inside the 300 ms flash window, two `flashRange` tasks may overlap. Existing code already tolerates this (each task only cleans up its own range); the new repaint hook does not change that. Worth confirming during implementation.
- **`SearchOptions` is a struct, not a class.** The new `currentMatchColor` field bumps the storage size by one optional `PlatformColor` reference. No ABI implications because the package is source-distributed.

## Out of scope

- iOS find/replace surface (deferred; will surface as a follow-up NEXT.md item).
- Project-wide search wiring changes.
- New search options beyond case / whole-word / regex.
- Regex timeouts and pathological-input defenses.
- `EditorState.isDirty` writes triggered by Replace All (NEXT.md B.3 owns this).
- Full `AppState` decomposition (NEXT.md A.3 #1 owns this; this spec only carves out the find/replace slice).

## Follow-up NEXT.md edits

After this design lands and ships:

- Strike A.1 ("Find/Replace match highlighting") and A.3 #4.
- Annotate A.3 #1 ("AppState is a god object") to note `FindReplaceModel` as the first extraction.
- Add a new item under A.3 #7 ("iOS feature parity") tracking an iOS find/replace surface.
