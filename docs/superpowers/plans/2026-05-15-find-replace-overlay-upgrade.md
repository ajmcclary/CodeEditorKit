# Find/Replace Overlay Upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land NEXT.md A.1 + A.3 #4. Add `SearchOptions.currentMatchColor` to the framework, tighten `EditorController.clearSearch()`, add `replaceCurrent(with:)`, and rewrite the sample's find/replace overlay with case/whole-word/regex toggles, live debounced search, current-vs-other styling, and a feature-scoped `FindReplaceModel`.

**Architecture:** One small additive framework change (optional `currentMatchColor` on `SearchOptions`, two-layer painting in `SearchReplaceEngine`, plus a tightened `clearSearch()` and new `replaceCurrent(with:)` on `EditorController`). Everything else lives in the sample — a new `@Observable @MainActor FindReplaceModel`, a rewritten `FindReplaceOverlay`, lifecycle hooks in `WindowBody`, and rebindings in `CommandPaletteCatalog`.

**Tech Stack:** Swift 6.3 (`StrictConcurrency`), SwiftUI, AppKit (macOS-only), XCTest, swift-snapshot-testing.

**Spec:** `docs/superpowers/specs/2026-05-15-find-replace-overlay-upgrade-design.md`

---

## File structure

| Path | Status | Responsibility |
|---|---|---|
| `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` | Modify | Add `currentMatchColor`, two-layer paint, `repaintCurrentMatch`, flash adjustment, public `clearAll()` helper. |
| `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` | Modify | Tighten `clearSearch()` (actually clears), add `replaceCurrent(with:)`. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceOptions.swift` | Create | `Hashable` value type + bridge to `SearchOptions`. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceColors.swift` | Create | `PlatformColor.findHighlight` + `PlatformColor.findActiveMatch`. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceControlling.swift` | Create | Sample-local protocol over `EditorController` for testing; conformance via extension. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift` | Create | `@Observable @MainActor` state container; debounced search, regex pre-validation. |
| `Sources/CodeEditorSample/EditorActions/FindReplaceOverlay.swift` | Rewrite | Three-row layout view bound to `FindReplaceModel`. |
| `Sources/CodeEditorSample/App/AppState.swift` | Modify | Remove `findText`, `replaceText`, `findOverlayVisible`; add `let findReplace = FindReplaceModel()`. |
| `Sources/CodeEditorSample/App/WindowBody.swift` | Modify | Bind overlay to model; install `.task(id:)` and `.onChange` lifecycle hooks. |
| `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift` | Modify | Rebind ⌘F / Find Next / Find Previous through the model. |
| `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift` | Modify | Append seven new framework tests. |
| `Tests/CodeEditorSampleTests/FindReplaceModelTests.swift` | Create | Six new model-level tests using `FindReplaceControlling` stub. |
| `Tests/CodeEditorSampleTests/FindReplaceOverlaySnapshotTests.swift` | Create | Seven snapshot tests of the overlay view. |

---

## Task 1: Framework — `SearchOptions.currentMatchColor`

Add the optional `currentMatchColor` field and teach `highlightSearchResults` to paint two layers.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`
- Test: `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`, inside the existing `final class FeatureBehaviorTests: CleanupTestCase` body. (The `backgroundColor(at:in:)` helper is used by every subsequent search-highlighting test in this plan — define it once on the class.)

```swift
    private func backgroundColor(at location: Int, in editor: CodeEditorView) -> PlatformColor? {
        let range = NSRange(location: location, length: 1)
        guard let attrs = editor.textKitBridge.attributedSubstring(in: range) else { return nil }
        return attrs.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? PlatformColor
    }

    func testCurrentMatchColorNilPreservesLegacyBehavior() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = false
        XCTAssertNil(options.currentMatchColor)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)

        let firstLoc = NSString(string: editor.text ?? "").range(of: "alpha").location
        let secondLoc = NSString(string: editor.text ?? "").range(of: "alpha", options: [.backwards]).location

        XCTAssertEqual(backgroundColor(at: firstLoc, in: editor), options.highlightColor)
        XCTAssertEqual(backgroundColor(at: secondLoc, in: editor), options.highlightColor)
    }

    func testSearchOptionsCurrentMatchColorPaintsTwoLayers() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = false
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)

        let firstLoc = NSString(string: editor.text ?? "").range(of: "alpha").location
        let secondLoc = NSString(string: editor.text ?? "").range(of: "alpha", options: [.backwards]).location

        XCTAssertEqual(engine.currentSearchIndex, 0)
        XCTAssertEqual(backgroundColor(at: firstLoc, in: editor), options.currentMatchColor)
        XCTAssertEqual(backgroundColor(at: secondLoc, in: editor), options.highlightColor)
    }
```

- [ ] **Step 2: Run the tests and verify they fail**

```
swift test --filter testCurrentMatchColorNilPreservesLegacyBehavior 2>&1 | tail -20
swift test --filter testSearchOptionsCurrentMatchColorPaintsTwoLayers 2>&1 | tail -20
```

Expected:
- The first test FAILS at the `XCTAssertNil(options.currentMatchColor)` line with "value of type 'SearchOptions' has no member 'currentMatchColor'".
- The second test FAILS at `options.currentMatchColor = ...` for the same reason.

- [ ] **Step 3: Add `currentMatchColor` to `SearchOptions`**

Edit `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`. In the `public struct SearchOptions` body (around line 457), append after `flashColor`:

```swift
    /// Optional second color for the *active* match. When non-nil,
    /// `SearchReplaceEngine.highlightSearchResults(_:)` paints the
    /// active match (`currentSearchResults[currentSearchIndex]`) with
    /// this color and the other matches with `highlightColor`. When
    /// nil, behavior is identical to prior releases.
    public var currentMatchColor: PlatformColor?
```

- [ ] **Step 4: Teach `highlightSearchResults` to paint two layers**

Replace the body of `private func highlightSearchResults(_ results: [SearchResult])` (around line 349) with:

```swift
    private func highlightSearchResults(_ results: [SearchResult]) {
        guard let textView else { return }
        let bridge = textView.textKitBridge
        let fullRange = TextRangeUtilities.fullRange(in: bridge.documentString)

        bridge.removePersistentAttribute(.backgroundColor, range: fullRange)

        for result in results {
            bridge.addPersistentAttributes(
                [.backgroundColor: searchOptions.highlightColor],
                range: result.range
            )
        }

        if let currentColor = searchOptions.currentMatchColor,
           results.indices.contains(currentSearchIndex) {
            bridge.addPersistentAttributes(
                [.backgroundColor: currentColor],
                range: results[currentSearchIndex].range
            )
        }
    }
```

- [ ] **Step 5: Run the tests and verify they pass**

```
swift test --filter testCurrentMatchColorNilPreservesLegacyBehavior 2>&1 | tail -10
swift test --filter testSearchOptionsCurrentMatchColorPaintsTwoLayers 2>&1 | tail -10
```

Expected: both PASS.

- [ ] **Step 6: Lint and build**

```
swiftlint --fix && swiftlint && swift build
```

Expected: clean build, no SwiftLint violations.

- [ ] **Step 7: Commit**

```
git add Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift \
        Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift
git commit -m "SearchReplaceEngine: optional currentMatchColor (two-layer paint)"
```

---

## Task 2: Framework — `repaintCurrentMatch` on navigation

Re-paint the two affected ranges whenever `currentSearchIndex` moves via `findNext` / `findPrevious`.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`
- Test: `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `FeatureBehaviorTests`:

```swift
    func testFindNextRepaintsPreviousCurrentToHighlightColor() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha gamma alpha"

        var options = SearchOptions()
        options.flashResult = false
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)
        XCTAssertEqual(engine.currentSearchIndex, 0)

        _ = engine.findNext(from: nil)
        XCTAssertEqual(engine.currentSearchIndex, 1)

        let firstRange = engine.currentSearchResults[0].range
        let secondRange = engine.currentSearchResults[1].range

        XCTAssertEqual(
            backgroundColor(at: firstRange.location, in: editor),
            options.highlightColor,
            "previous current should revert to highlightColor"
        )
        XCTAssertEqual(
            backgroundColor(at: secondRange.location, in: editor),
            options.currentMatchColor,
            "new current should adopt currentMatchColor"
        )
    }

    func testFindPreviousRepaintsCorrectly() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha gamma alpha"

        var options = SearchOptions()
        options.flashResult = false
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)
        _ = engine.findNext(from: nil)
        _ = engine.findNext(from: nil)
        XCTAssertEqual(engine.currentSearchIndex, 2)

        _ = engine.findPrevious(from: nil)
        XCTAssertEqual(engine.currentSearchIndex, 1)

        let secondRange = engine.currentSearchResults[1].range
        let thirdRange = engine.currentSearchResults[2].range

        XCTAssertEqual(backgroundColor(at: secondRange.location, in: editor), options.currentMatchColor)
        XCTAssertEqual(backgroundColor(at: thirdRange.location, in: editor), options.highlightColor)
    }
```

- [ ] **Step 2: Run and verify FAIL**

```
swift test --filter testFindNextRepaintsPreviousCurrentToHighlightColor 2>&1 | tail -15
swift test --filter testFindPreviousRepaintsCorrectly 2>&1 | tail -15
```

Expected: both FAIL. After `findNext`, both ranges still carry `currentMatchColor` (because the legacy paint applied it to all matches when the index was 0) or only the new current carries it but the previous one remains as it was — depending on engine internals. The point is the test exercises the new repaint hook that doesn't exist yet.

- [ ] **Step 3: Add `repaintCurrentMatch` and wire it into `findNext` / `findPrevious`**

In `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`, after the `highlightSearchResults(_:)` function add:

```swift
    private func repaintCurrentMatch(previousIndex: Int) {
        guard let textView else { return }
        guard searchOptions.highlightResults else { return }
        guard searchOptions.currentMatchColor != nil else { return }
        let bridge = textView.textKitBridge

        if currentSearchResults.indices.contains(previousIndex) {
            let range = currentSearchResults[previousIndex].range
            bridge.removePersistentAttribute(.backgroundColor, range: range)
            bridge.addPersistentAttributes(
                [.backgroundColor: searchOptions.highlightColor],
                range: range
            )
        }

        if let currentColor = searchOptions.currentMatchColor,
           currentSearchResults.indices.contains(currentSearchIndex) {
            let range = currentSearchResults[currentSearchIndex].range
            bridge.removePersistentAttribute(.backgroundColor, range: range)
            bridge.addPersistentAttributes(
                [.backgroundColor: currentColor],
                range: range
            )
        }
    }
```

Then locate `public func findNext(from: NSRange?) -> SearchResult?` (around line 98). After the existing index advance and before the `scrollToResult` call, capture the previous index and call the repaint:

```swift
    public func findNext(from currentRange: NSRange?) -> SearchResult? {
        guard !currentSearchResults.isEmpty else { return nil }

        let previousIndex = currentSearchIndex
        // ... existing index-advance logic ...

        repaintCurrentMatch(previousIndex: previousIndex)
        scrollToResult(currentSearchResults[currentSearchIndex])
        return currentSearchResults[currentSearchIndex]
    }
```

Mirror the same change in `public func findPrevious(from:)`. Use a single shared helper if both methods already share advance logic; otherwise apply the two-line `previousIndex` + `repaintCurrentMatch(previousIndex:)` change to each.

Read the existing bodies first to preserve their wrap-around behavior — do not rewrite the index math, only thread `previousIndex` through.

- [ ] **Step 4: Run and verify PASS**

```
swift test --filter testFindNextRepaintsPreviousCurrentToHighlightColor 2>&1 | tail -10
swift test --filter testFindPreviousRepaintsCorrectly 2>&1 | tail -10
```

Expected: both PASS.

- [ ] **Step 5: Run the existing search/replace tests to confirm no regression**

```
swift test --filter SearchReplace 2>&1 | tail -20
```

Expected: all existing tests pass.

- [ ] **Step 6: Lint and build**

```
swiftlint --fix && swiftlint && swift build
```

- [ ] **Step 7: Commit**

```
git add Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift \
        Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift
git commit -m "SearchReplaceEngine: repaint current match on findNext/findPrevious"
```

---

## Task 3: Framework — flash respects current-match color

After the 300 ms flash window, reapply `currentMatchColor` (not `highlightColor`) to the active match.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`
- Test: `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `FeatureBehaviorTests`:

```swift
    func testFlashRangeReappliesCurrentMatchColorOnCurrentMatch() async throws {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = true
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)
        XCTAssertEqual(engine.currentSearchIndex, 0)

        // Wait past the 300 ms flash window.
        try await Task.sleep(nanoseconds: 450_000_000)

        let firstRange = engine.currentSearchResults[0].range
        XCTAssertEqual(
            backgroundColor(at: firstRange.location, in: editor),
            options.currentMatchColor,
            "post-flash, the active match must return to currentMatchColor"
        )
    }
```

- [ ] **Step 2: Run and verify FAIL**

```
swift test --filter testFlashRangeReappliesCurrentMatchColorOnCurrentMatch 2>&1 | tail -10
```

Expected: FAIL — after the flash, the active match reverts to `highlightColor` (the legacy `flashRange` always reapplies `searchOptions.highlightColor`).

- [ ] **Step 3: Update `flashRange` to consult `currentSearchIndex`**

In `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`, replace the body of `private func flashRange(_ range: NSRange)` (around line 382):

```swift
    private func flashRange(_ range: NSRange) {
        guard let textView else { return }
        let bridge = textView.textKitBridge

        let flashColor = searchOptions.flashColor

        bridge.addPersistentAttributes([.backgroundColor: flashColor], range: range)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, let textView = self.textView else { return }
            let bridge = textView.textKitBridge
            bridge.removePersistentAttribute(.backgroundColor, range: range)

            guard self.searchOptions.highlightResults else { return }

            let isCurrent = self.currentSearchResults.indices.contains(self.currentSearchIndex)
                && self.currentSearchResults[self.currentSearchIndex].range == range
            let color = isCurrent
                ? (self.searchOptions.currentMatchColor ?? self.searchOptions.highlightColor)
                : self.searchOptions.highlightColor
            bridge.addPersistentAttributes([.backgroundColor: color], range: range)
        }
    }
```

- [ ] **Step 4: Run and verify PASS**

```
swift test --filter testFlashRangeReappliesCurrentMatchColorOnCurrentMatch 2>&1 | tail -10
```

Expected: PASS.

- [ ] **Step 5: Lint, build, full framework test sweep**

```
swiftlint --fix && swiftlint && swift build && swift test --filter SearchReplace 2>&1 | tail -20
```

Expected: clean.

- [ ] **Step 6: Commit**

```
git add Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift \
        Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift
git commit -m "SearchReplaceEngine: flash reapplies currentMatchColor to the active match"
```

---

## Task 4: Framework — `clearSearch` actually clears highlights

`EditorController.clearSearch()` today only resets cached counters. Make it actually wipe in-editor highlights.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`
- Test: `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `FeatureBehaviorTests`:

```swift
    func testClearSearchAlsoClearsHighlights() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = false

        let controller = EditorController()
        controller.attach(to: editor)
        _ = await controller.find("alpha", options: options)
        XCTAssertEqual(controller.matchCount, 2)

        let firstLoc = NSString(string: editor.text ?? "").range(of: "alpha").location
        XCTAssertNotNil(backgroundColor(at: firstLoc, in: editor))

        controller.clearSearch()

        XCTAssertEqual(controller.matchCount, 0)
        XCTAssertEqual(controller.currentMatchIndex, -1)
        XCTAssertNil(
            backgroundColor(at: firstLoc, in: editor),
            "clearSearch must remove in-editor highlights"
        )
    }
```

- [ ] **Step 2: Run and verify FAIL**

```
swift test --filter testClearSearchAlsoClearsHighlights 2>&1 | tail -10
```

Expected: FAIL at the final `XCTAssertNil` — highlights stick around.

- [ ] **Step 3: Add `clearAll()` to the engine**

In `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`, immediately after the `replaceAll(...)` public function, add:

```swift
    /// Drop all search state and clear in-editor match highlights.
    /// Synchronous — no scanning happens.
    public func clearAll() {
        currentSearchResults = []
        currentSearchIndex = -1
        updateStatistics(for: [])

        guard let textView else { return }
        let bridge = textView.textKitBridge
        let fullRange = TextRangeUtilities.fullRange(in: bridge.documentString)
        bridge.removePersistentAttribute(.backgroundColor, range: fullRange)
    }
```

- [ ] **Step 4: Tighten `EditorController.clearSearch()`**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` replace the existing `clearSearch()` (around lines 268–274):

```swift
    /// Reset cached search state AND clear in-editor match highlights.
    public func clearSearch() {
        matchCount = 0
        currentMatchIndex = -1
        codeEditorView?.searchEngine.clearAll()
    }
```

- [ ] **Step 5: Run and verify PASS**

```
swift test --filter testClearSearchAlsoClearsHighlights 2>&1 | tail -10
```

Expected: PASS.

- [ ] **Step 6: Lint, build**

```
swiftlint --fix && swiftlint && swift build
```

- [ ] **Step 7: Commit**

```
git add Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift \
        Sources/CodeEditorPlugin/SwiftUI/EditorController.swift \
        Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift
git commit -m "EditorController.clearSearch: actually clear in-editor highlights"
```

---

## Task 5: Framework — `EditorController.replaceCurrent(with:)`

Replace the active match, then advance forward.

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`
- Test: `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `FeatureBehaviorTests`:

```swift
    func testReplaceCurrentAdvancesToNextMatch() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha gamma alpha"

        var options = SearchOptions()
        options.flashResult = false

        let controller = EditorController()
        controller.attach(to: editor)
        _ = await controller.find("alpha", options: options)
        XCTAssertEqual(controller.matchCount, 3)
        XCTAssertEqual(controller.currentMatchIndex, 0)

        _ = controller.findNext()
        XCTAssertEqual(controller.currentMatchIndex, 1)

        let replaced = controller.replaceCurrent(with: "OMEGA")
        XCTAssertTrue(replaced)
        XCTAssertEqual(controller.matchCount, 2, "one match consumed")
        XCTAssertEqual(controller.currentMatchIndex, 1, "engine decremented then findNext advanced")

        let resultText = editor.text ?? ""
        XCTAssertEqual(resultText, "alpha beta OMEGA gamma alpha")
    }

    func testReplaceCurrentNoOpWhenNoMatches() async {
        let editor = createCodeEditorView()
        editor.text = "no matches here"

        let controller = EditorController()
        controller.attach(to: editor)

        let replaced = controller.replaceCurrent(with: "anything")
        XCTAssertFalse(replaced)
        XCTAssertEqual(editor.text, "no matches here")
    }
```

- [ ] **Step 2: Run and verify FAIL**

```
swift test --filter testReplaceCurrentAdvancesToNextMatch 2>&1 | tail -10
swift test --filter testReplaceCurrentNoOpWhenNoMatches 2>&1 | tail -10
```

Expected: both FAIL with "value of type 'EditorController' has no member 'replaceCurrent'".

- [ ] **Step 3: Add `replaceCurrent(with:)`**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`, after `replaceAll(_:with:options:)` (around line 266):

```swift
    /// Replace the currently active match with `replacement` and advance
    /// to the next match. Returns true if a replacement happened. No-op
    /// when there is no current match. Compensates for the engine's
    /// existing `updateResultsAfterReplacement` index-decrement so the
    /// UX matches Xcode / VS Code "replace then advance".
    @discardableResult
    public func replaceCurrent(with replacement: String) -> Bool {
        guard let view = codeEditorView else { return false }
        let engine = view.searchEngine
        let index = engine.currentSearchIndex
        guard engine.currentSearchResults.indices.contains(index) else { return false }

        let didReplace = engine.replace(at: index, with: replacement)
        guard didReplace else { return false }

        if !engine.currentSearchResults.isEmpty {
            _ = engine.findNext(from: nil)
        }
        matchCount = engine.currentSearchResults.count
        currentMatchIndex = engine.currentSearchIndex
        return true
    }
```

- [ ] **Step 4: Run and verify PASS**

```
swift test --filter testReplaceCurrentAdvancesToNextMatch 2>&1 | tail -10
swift test --filter testReplaceCurrentNoOpWhenNoMatches 2>&1 | tail -10
```

Expected: both PASS. If the index assertion fails, walk the engine's `replace(at:with:)` + `updateResultsAfterReplacement` and confirm the count matches expectation — the test asserts the *observable* outcome (one fewer match, next match active), not the intermediate index dance.

- [ ] **Step 5: Lint, build, full framework test sweep**

```
swiftlint --fix && swiftlint && swift build && swift test --filter FeatureBehavior 2>&1 | tail -30
```

Expected: clean and all framework feature-behavior tests pass.

- [ ] **Step 6: Commit**

```
git add Sources/CodeEditorPlugin/SwiftUI/EditorController.swift \
        Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift
git commit -m "EditorController: replaceCurrent(with:) — replace then advance"
```

---

## Task 6: Sample — `FindReplaceOptions` value type

Tiny `Hashable` struct that bridges to framework `SearchOptions`.

**Files:**
- Create: `Sources/CodeEditorSample/EditorActions/FindReplaceOptions.swift`

- [ ] **Step 1: Write the file**

Create `Sources/CodeEditorSample/EditorActions/FindReplaceOptions.swift`:

```swift
import CodeEditorPlugin
import Foundation

struct FindReplaceOptions: Hashable, Sendable {
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

This depends on `PlatformColor.findHighlight` / `findActiveMatch` (added in Task 7). Build will fail until Task 7 lands — that's expected; commit the bridge first.

- [ ] **Step 2: Run build (expect failure on the two color symbols)**

```
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: "type 'PlatformColor' has no member 'findHighlight'" and similarly for `findActiveMatch`. This confirms the bridge expects the new colors.

- [ ] **Step 3: Commit the file as-is**

```
git add Sources/CodeEditorSample/EditorActions/FindReplaceOptions.swift
git commit -m "Sample: FindReplaceOptions value type + SearchOptions bridge"
```

The next task introduces the color tokens that resolve the build.

---

## Task 7: Sample — color tokens for find highlight + active match

**Files:**
- Create: `Sources/CodeEditorSample/EditorActions/FindReplaceColors.swift`

- [ ] **Step 1: Write the file**

Create `Sources/CodeEditorSample/EditorActions/FindReplaceColors.swift`:

```swift
import CodeEditorPlugin

#if canImport(AppKit)
import AppKit

extension PlatformColor {
    /// Yellow @ 30 % alpha — matches the framework's legacy
    /// `SearchOptions.highlightColor` default.
    static var findHighlight: PlatformColor {
        PlatformColor.yellow.withAlphaComponent(0.3)
    }

    /// Selection blue for the *active* match.
    static var findActiveMatch: PlatformColor {
        PlatformColor.selectedTextBackgroundColor
    }
}
#else
import UIKit

extension PlatformColor {
    static var findHighlight: PlatformColor {
        PlatformColor.systemYellow.withAlphaComponent(0.3)
    }

    static var findActiveMatch: PlatformColor {
        PlatformColor.systemBlue.withAlphaComponent(0.45)
    }
}
#endif
```

The iOS branch keeps the symbols compilable even though the overlay itself is macOS-only this round — `FindReplaceOptions.toSearchOptions()` is referenced cross-platform from `FindReplaceModel`.

- [ ] **Step 2: Build and confirm both branches compile**

```
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: build now succeeds (or fails on something else — anything mentioning `FindReplaceColors` should be gone).

- [ ] **Step 3: Lint**

```
swiftlint --fix && swiftlint
```

- [ ] **Step 4: Commit**

```
git add Sources/CodeEditorSample/EditorActions/FindReplaceColors.swift
git commit -m "Sample: PlatformColor.findHighlight + findActiveMatch tokens"
```

---

## Task 8: Sample — `FindReplaceControlling` protocol

Sample-local protocol that lets `FindReplaceModelTests` stub the controller.

**Files:**
- Create: `Sources/CodeEditorSample/EditorActions/FindReplaceControlling.swift`

- [ ] **Step 1: Write the file**

Create `Sources/CodeEditorSample/EditorActions/FindReplaceControlling.swift`:

```swift
import CodeEditorPlugin
import Foundation

/// Sample-local protocol over `EditorController`'s find / replace
/// surface. Exists so `FindReplaceModel` can be unit-tested with a
/// stub. Conformance for the real controller is provided below.
@MainActor
protocol FindReplaceControlling: AnyObject {
    var matchCount: Int { get }
    var currentMatchIndex: Int { get }

    func find(_ pattern: String, options: SearchOptions?) async -> [SearchResult]
    @discardableResult func findNext() -> SearchResult?
    @discardableResult func findPrevious() -> SearchResult?
    @discardableResult func replaceCurrent(with replacement: String) -> Bool
    @discardableResult func replaceAll(_ pattern: String, with replacement: String, options: SearchOptions?) async -> Int
    func clearSearch()
}

extension EditorController: FindReplaceControlling {}
```

- [ ] **Step 2: Build**

```
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: clean.

- [ ] **Step 3: Lint**

```
swiftlint --fix && swiftlint
```

- [ ] **Step 4: Commit**

```
git add Sources/CodeEditorSample/EditorActions/FindReplaceControlling.swift
git commit -m "Sample: FindReplaceControlling protocol + EditorController conformance"
```

---

## Task 9: Sample — `FindReplaceModel`

The state container. TDD: write tests against the model using a stub before implementing the body.

**Files:**
- Create: `Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift`
- Create: `Tests/CodeEditorSampleTests/FindReplaceModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/CodeEditorSampleTests/FindReplaceModelTests.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

@MainActor
final class FindReplaceModelTests: XCTestCase {

    func testSearchRequestEqualsWhenIdenticalInputs() {
        let model = FindReplaceModel()
        model.findText = "alpha"
        let lhs = model.searchRequest(activeDocumentID: UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let rhs = model.searchRequest(activeDocumentID: UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(lhs, rhs)
    }

    func testSearchRequestDiffersWhenOptionsChange() {
        let model = FindReplaceModel()
        model.findText = "alpha"
        let a = model.searchRequest(activeDocumentID: nil)
        model.options.caseSensitive = true
        let b = model.searchRequest(activeDocumentID: nil)
        XCTAssertNotEqual(a, b)
    }

    func testEmptyPatternCallsClearSearch() async {
        let stub = ControllerStub()
        let model = FindReplaceModel()
        model.findText = ""

        await model.runSearch(controller: stub)

        XCTAssertEqual(stub.clearSearchCalls, 1)
        XCTAssertEqual(stub.findCalls.count, 0)
    }

    func testRegexValidationFailureStoresLastError() async {
        let stub = ControllerStub()
        let model = FindReplaceModel()
        model.findText = "[invalid"
        model.options.useRegularExpression = true

        await model.runSearch(controller: stub)

        XCTAssertEqual(model.lastError, .invalidRegex)
        XCTAssertEqual(stub.findCalls.count, 0)
    }

    func testRunSearchClearsLastErrorOnSuccess() async {
        let stub = ControllerStub(matchCount: 2)
        let model = FindReplaceModel()
        model.findText = "[invalid"
        model.options.useRegularExpression = true
        await model.runSearch(controller: stub)
        XCTAssertEqual(model.lastError, .invalidRegex)

        model.findText = "alpha"
        model.options.useRegularExpression = false
        await model.runSearch(controller: stub)

        XCTAssertNil(model.lastError)
        XCTAssertEqual(stub.findCalls.last, "alpha")
    }

    func testCloseClearsControllerAndHidesOverlay() {
        let stub = ControllerStub()
        let model = FindReplaceModel()
        model.isOverlayVisible = true

        model.close(controller: stub)

        XCTAssertFalse(model.isOverlayVisible)
        XCTAssertEqual(stub.clearSearchCalls, 1)
    }

    func testCanReplaceFalseWhenNoMatchesOrReadOnly() {
        let stub = ControllerStub(matchCount: 0)
        let model = FindReplaceModel()
        XCTAssertFalse(model.canReplace(matchCount: stub.matchCount, isReadOnly: false))
        XCTAssertFalse(model.canReplace(matchCount: 3, isReadOnly: true))
        XCTAssertTrue(model.canReplace(matchCount: 3, isReadOnly: false))
    }
}

@MainActor
final class ControllerStub: FindReplaceControlling {
    var matchCount: Int
    var currentMatchIndex: Int
    private(set) var findCalls: [String] = []
    private(set) var clearSearchCalls: Int = 0
    private(set) var replaceCurrentCalls: [String] = []
    private(set) var replaceAllCalls: [(String, String)] = []

    init(matchCount: Int = 0, currentMatchIndex: Int = -1) {
        self.matchCount = matchCount
        self.currentMatchIndex = currentMatchIndex
    }

    func find(_ pattern: String, options: SearchOptions?) async -> [SearchResult] {
        findCalls.append(pattern)
        return []
    }
    @discardableResult func findNext() -> SearchResult? { nil }
    @discardableResult func findPrevious() -> SearchResult? { nil }
    @discardableResult func replaceCurrent(with replacement: String) -> Bool {
        replaceCurrentCalls.append(replacement)
        return true
    }
    @discardableResult func replaceAll(_ pattern: String, with replacement: String, options: SearchOptions?) async -> Int {
        replaceAllCalls.append((pattern, replacement))
        return 0
    }
    func clearSearch() {
        clearSearchCalls += 1
        matchCount = 0
        currentMatchIndex = -1
    }
}
#endif
```

- [ ] **Step 2: Run and verify FAIL (cannot find type 'FindReplaceModel')**

```
swift test --filter FindReplaceModelTests 2>&1 | tail -10
```

Expected: build error pointing at the missing `FindReplaceModel`.

- [ ] **Step 3: Write the model**

Create `Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift`:

```swift
import CodeEditorPlugin
import Foundation
import Observation

private let searchDebounce: Duration = .milliseconds(150)

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
    private(set) var documentRevision: Int = 0

    enum FindError: Equatable {
        case invalidRegex
    }

    struct SearchRequest: Hashable {
        var pattern: String
        var options: FindReplaceOptions
        var activeDocumentID: UUID?
        var documentRevision: Int
    }

    func searchRequest(activeDocumentID: UUID?) -> SearchRequest {
        SearchRequest(
            pattern: findText,
            options: options,
            activeDocumentID: activeDocumentID,
            documentRevision: documentRevision
        )
    }

    func markDocumentEdited() {
        documentRevision &+= 1
    }

    func runDebouncedSearch(controller: FindReplaceControlling) async {
        try? await Task.sleep(for: searchDebounce)
        guard !Task.isCancelled else { return }
        await runSearch(controller: controller)
    }

    func runSearch(controller: FindReplaceControlling) async {
        if findText.isEmpty {
            controller.clearSearch()
            matchCount = 0
            currentMatchPosition = 0
            lastError = nil
            return
        }

        if options.useRegularExpression {
            do {
                _ = try NSRegularExpression(pattern: findText)
            } catch {
                lastError = .invalidRegex
                return
            }
        }

        lastError = nil
        _ = await controller.find(findText, options: options.toSearchOptions())
        matchCount = controller.matchCount
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func findNext(controller: FindReplaceControlling) {
        _ = controller.findNext()
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func findPrevious(controller: FindReplaceControlling) {
        _ = controller.findPrevious()
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func replaceCurrent(controller: FindReplaceControlling) {
        guard controller.matchCount > 0 else { return }
        _ = controller.replaceCurrent(with: replaceText)
        matchCount = controller.matchCount
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func replaceAll(controller: FindReplaceControlling) async {
        guard !findText.isEmpty else { return }
        _ = await controller.replaceAll(findText, with: replaceText, options: options.toSearchOptions())
        matchCount = controller.matchCount
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func close(controller: FindReplaceControlling) {
        isOverlayVisible = false
        controller.clearSearch()
        matchCount = 0
        currentMatchPosition = 0
        lastError = nil
    }

    func canReplace(matchCount: Int, isReadOnly: Bool) -> Bool {
        matchCount > 0 && !isReadOnly
    }
}
```

- [ ] **Step 4: Run the model tests and verify PASS**

```
swift test --filter FindReplaceModelTests 2>&1 | tail -20
```

Expected: all seven model tests PASS.

- [ ] **Step 5: Lint and build**

```
swiftlint --fix && swiftlint && swift build
```

- [ ] **Step 6: Commit**

```
git add Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift \
        Tests/CodeEditorSampleTests/FindReplaceModelTests.swift
git commit -m "Sample: FindReplaceModel + unit tests"
```

---

## Task 10: Sample — rewrite `FindReplaceOverlay`

Three-row layout reading and writing the model. No business logic in the view.

**Files:**
- Modify: `Sources/CodeEditorSample/EditorActions/FindReplaceOverlay.swift`

- [ ] **Step 1: Overwrite the file**

Replace the contents of `Sources/CodeEditorSample/EditorActions/FindReplaceOverlay.swift`:

```swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Xcode-style overlay banner pinned to the top of the editor pane.
/// View-only: reads / writes `FindReplaceModel`, calls the model's
/// helpers which dispatch into the framework.
struct FindReplaceOverlay: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var model: FindReplaceModel
    let controller: EditorController
    let isReadOnly: Bool

    @FocusState private var focusedField: Field?
    private enum Field { case find, replace }

    var body: some View {
        VStack(spacing: 0) {
            findRow
            Divider().background(Color(tokens: theme.style.borders.variant))
            replaceRow
            if model.isOptionsExpanded {
                Divider().background(Color(tokens: theme.style.borders.variant))
                optionsRow
            }
        }
        .padding(8)
        .background(panelBackground)
        .padding(10)
        .onAppear { focusedField = .find }
    }

    // MARK: - Find row

    private var findRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 16)
            TextField("Find", text: $model.findText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($focusedField, equals: .find)
            badge
            Button {
                Task { await model.runSearch(controller: controller) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Re-run search")
            Button { model.findPrevious(controller: controller) } label: {
                Image(systemName: "chevron.up")
            }
            .help("Previous match")
            Button { model.findNext(controller: controller) } label: {
                Image(systemName: "chevron.down")
            }
            .help("Next match")
            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    model.isOptionsExpanded.toggle()
                }
            } label: {
                Image(systemName: model.isOptionsExpanded ? "chevron.up.square" : "chevron.down.square")
            }
            .help("Options")
            Button { model.close(controller: controller) } label: {
                Image(systemName: "xmark")
            }
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close")
        }
        .buttonStyle(.plain)
        .controlSize(.small)
    }

    @ViewBuilder
    private var badge: some View {
        if model.lastError == .invalidRegex {
            Text("Invalid regex")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        } else if model.matchCount > 0 {
            Text("\(model.currentMatchPosition) / \(model.matchCount)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(tokens: theme.style.elements.element.background))
                )
        } else if !model.findText.isEmpty {
            Text("0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Replace row

    private var replaceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 16)
            TextField("Replace", text: $model.replaceText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($focusedField, equals: .replace)
            Spacer()
            Button("Replace") {
                model.replaceCurrent(controller: controller)
            }
            .disabled(!model.canReplace(matchCount: model.matchCount, isReadOnly: isReadOnly))
            Button("All") {
                Task { await model.replaceAll(controller: controller) }
            }
            .disabled(!model.canReplace(matchCount: model.matchCount, isReadOnly: isReadOnly))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Options row

    private var optionsRow: some View {
        HStack(spacing: 14) {
            optionToggle(label: "Aa", help: "Match case", isOn: $model.options.caseSensitive)
            optionToggle(label: "|W|", help: "Whole word", isOn: $model.options.wholeWord)
            optionToggle(label: ".*", help: "Regular expression", isOn: $model.options.useRegularExpression)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func optionToggle(label: String, help: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOn.wrappedValue
                            ? Color.accentColor.opacity(0.3)
                            : Color(tokens: theme.style.elements.element.background))
                )
                .foregroundStyle(isOn.wrappedValue
                    ? Color.accentColor
                    : Color(tokens: theme.style.text.muted))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(tokens: theme.style.chrome.elevatedSurfaceBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(tokens: theme.style.borders.base), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }
}
```

- [ ] **Step 2: Build (expect failure — `WindowBody` still references old AppState properties)**

```
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: errors in `WindowBody.swift` around `FindReplaceOverlay(appState:)` (now needs `model:controller:isReadOnly:`). Those land in Task 12.

- [ ] **Step 3: Lint the new file**

```
swiftlint --fix Sources/CodeEditorSample/EditorActions/FindReplaceOverlay.swift
swiftlint Sources/CodeEditorSample/EditorActions/FindReplaceOverlay.swift
```

- [ ] **Step 4: Commit (build still red — that is intentional; the next tasks fix it)**

```
git add Sources/CodeEditorSample/EditorActions/FindReplaceOverlay.swift
git commit -m "Sample: rewrite FindReplaceOverlay as view-only bound to FindReplaceModel"
```

---

## Task 11: Sample — slim `AppState`

Remove `findText`, `replaceText`, `findOverlayVisible`. Add `let findReplace = FindReplaceModel()`.

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

- [ ] **Step 1: Delete the three properties**

In `Sources/CodeEditorSample/App/AppState.swift`, remove lines 71–79 (the `findOverlayVisible`, `findText`, `replaceText` block including their doc comments).

- [ ] **Step 2: Add `findReplace` handle**

In the same file, immediately above the `gotoLineSheetVisible` line that remains, insert:

```swift
    /// Find / replace feature-scoped model. Owns query text, options,
    /// overlay visibility, debounce / clear lifecycle, and the
    /// derived match counters. First step in the broader AppState
    /// decomposition (NEXT.md A.3 #1).
    let findReplace = FindReplaceModel()
```

- [ ] **Step 3: Build (expect failure — `CommandPaletteCatalog` and `WindowBody` still reference the old properties)**

```
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: errors in `CommandPaletteCatalog.swift` and `WindowBody.swift`. Those land in Tasks 12 and 13.

- [ ] **Step 4: Commit (build still red — intentional)**

```
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "Sample AppState: extract find/replace state into FindReplaceModel"
```

---

## Task 12: Sample — wire `WindowBody` with `.task(id:)` and lifecycle hooks

**Files:**
- Modify: `Sources/CodeEditorSample/App/WindowBody.swift`

- [ ] **Step 1: Read the surrounding context first**

Open `Sources/CodeEditorSample/App/WindowBody.swift` and locate the `safeAreaInset` block (around line 101–106) plus the host view body that contains the editor pane. The exact line numbers may have drifted; read the file before editing.

- [ ] **Step 2: Replace the overlay site**

Find:

```swift
if appState.findOverlayVisible {
    FindReplaceOverlay(appState: appState)
```

Replace with:

```swift
if appState.findReplace.isOverlayVisible {
    FindReplaceOverlay(
        model: appState.findReplace,
        controller: appState.editorController,
        isReadOnly: appState.configuration.behavior.isReadOnly
    )
```

(Preserve any existing transition / animation modifiers on the surrounding scope.)

- [ ] **Step 3: Attach lifecycle hooks**

In the same view body (immediately after the editor pane's `.safeAreaInset`), add:

```swift
.task(id: appState.findReplace.searchRequest(activeDocumentID: appState.documents.activeID)) {
    await appState.findReplace.runDebouncedSearch(controller: appState.editorController)
}
.onChange(of: appState.findReplace.isOverlayVisible) { _, isVisible in
    if !isVisible {
        appState.editorController.clearSearch()
    }
}
.onChange(of: appState.documents.activeID) { _, _ in
    appState.editorController.clearSearch()
}
.onChange(of: appState.documents.active?.text) { _, _ in
    appState.editorController.clearSearch()
    appState.findReplace.markDocumentEdited()
}
.onChange(of: appState.documents.active?.language?.identifier) { _, _ in
    appState.editorController.clearSearch()
    appState.findReplace.markDocumentEdited()
}
.onChange(of: appState.theme.id) { _, _ in
    appState.editorController.clearSearch()
    appState.findReplace.markDocumentEdited()
}
```

Notes:
- `appState.documents.active?.language?.identifier` may need to be `appState.documents.active?.language?.rawValue` or similar depending on the `Language` enum's `Hashable` shape — read `Sources/CodeEditorPlugin/Languages/Language.swift` first and pick the simplest stable identifier.
- If `Theme` has no `id`, use `\.theme` directly (any `Equatable` value works — pick whatever the existing `.codeEditorTheme` modifier passes).
- The `markDocumentEdited()` bump after each clear is so the `.task(id:)` request changes and the re-search fires.

- [ ] **Step 4: Build**

```
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: clean. If `appState.theme.id` isn't a thing, the build error tells you the right key path — pick the smallest stable `Equatable` identifier you can.

- [ ] **Step 5: Lint**

```
swiftlint --fix && swiftlint
```

- [ ] **Step 6: Commit**

```
git add Sources/CodeEditorSample/App/WindowBody.swift
git commit -m "Sample WindowBody: wire FindReplaceOverlay via FindReplaceModel + lifecycle hooks"
```

---

## Task 13: Sample — rebind `CommandPaletteCatalog`

**Files:**
- Modify: `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`

- [ ] **Step 1: Update the find-action block**

In `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`, replace the body of `appendFindActions(...)` (lines 116–136):

```swift
    @MainActor
    private static func appendFindActions(
        into items: inout [CommandPaletteItem],
        actions: inout [CommandPaletteItem.ID: () -> Void],
        appState: AppState
    ) {
        let openOverlay = CommandPaletteItem(title: "Find / Replace…", kind: .action, shortcut: "⌘F")
        actions[openOverlay.id] = { appState.findReplace.isOverlayVisible = true }
        items.append(openOverlay)

        let findNext = CommandPaletteItem(title: "Find Next", kind: .action)
        actions[findNext.id] = {
            appState.findReplace.findNext(controller: appState.editorController)
        }
        items.append(findNext)

        let findPrev = CommandPaletteItem(title: "Find Previous", kind: .action)
        actions[findPrev.id] = {
            appState.findReplace.findPrevious(controller: appState.editorController)
        }
        items.append(findPrev)
    }
```

- [ ] **Step 2: Search for any other references to the old AppState properties**

```
grep -rn "findOverlayVisible\|appState\.findText\|appState\.replaceText" Sources/CodeEditorSample 2>&1
```

Expected: zero hits.

- [ ] **Step 3: Build the whole sample target**

```
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: clean.

- [ ] **Step 4: Lint**

```
swiftlint --fix && swiftlint
```

- [ ] **Step 5: Run the sample's existing test suite to confirm no regression**

```
swift test --filter CodeEditorSampleTests 2>&1 | tail -30
```

Expected: every existing sample test still passes.

- [ ] **Step 6: Commit**

```
git add Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift
git commit -m "Sample CommandPalette: rebind Find / Find Next / Find Previous through FindReplaceModel"
```

---

## Task 14: Sample — snapshot tests for the overlay

**Files:**
- Create: `Tests/CodeEditorSampleTests/FindReplaceOverlaySnapshotTests.swift`

- [ ] **Step 1: Write the test file**

Create `Tests/CodeEditorSampleTests/FindReplaceOverlaySnapshotTests.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class FindReplaceOverlaySnapshotTests: XCTestCase {

    private func makeHost(_ configure: (FindReplaceModel) -> Void) -> some View {
        let model = FindReplaceModel()
        configure(model)
        return FindReplaceOverlay(
            model: model,
            controller: EditorController(),
            isReadOnly: false
        )
        .frame(width: 540)
        .padding()
    }

    func testOverlay_idleNoQuery() {
        let view = makeHost { _ in }
        assertSnapshot(of: view, as: .image)
    }

    func testOverlay_withMatches() {
        let view = makeHost { model in
            model.findText = "search"
            model.replaceText = "replace"
            // Tests live in the same module; setting private(set) values
            // directly requires a small @testable hook — see TODO note below.
            model._setMockCounts(match: 7, position: 2)
        }
        assertSnapshot(of: view, as: .image)
    }

    func testOverlay_zeroMatches() {
        let view = makeHost { model in
            model.findText = "nothing"
        }
        assertSnapshot(of: view, as: .image)
    }

    func testOverlay_optionsExpanded() {
        let view = makeHost { model in
            model.isOptionsExpanded = true
        }
        assertSnapshot(of: view, as: .image)
    }

    func testOverlay_optionsExpanded_caseAndRegexOn() {
        let view = makeHost { model in
            model.isOptionsExpanded = true
            model.options.caseSensitive = true
            model.options.useRegularExpression = true
        }
        assertSnapshot(of: view, as: .image)
    }

    func testOverlay_invalidRegex() {
        let view = makeHost { model in
            model.findText = "[invalid"
            model.options.useRegularExpression = true
            model._setMockError(.invalidRegex)
        }
        assertSnapshot(of: view, as: .image)
    }

    func testOverlay_readOnlyConfig() {
        let model = FindReplaceModel()
        model.findText = "search"
        model._setMockCounts(match: 3, position: 1)
        let view = FindReplaceOverlay(
            model: model,
            controller: EditorController(),
            isReadOnly: true
        )
        .frame(width: 540)
        .padding()
        assertSnapshot(of: view, as: .image)
    }
}
#endif
```

- [ ] **Step 2: Expose test hooks on `FindReplaceModel`**

The snapshot tests need to set `matchCount`, `currentMatchPosition`, and `lastError`, which are `private(set)`. Add at the bottom of `Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift`:

```swift
#if DEBUG
extension FindReplaceModel {
    /// Internal test hook. Do not call from production code.
    func _setMockCounts(match: Int, position: Int) {
        matchCount = match
        currentMatchPosition = position
    }

    /// Internal test hook.
    func _setMockError(_ error: FindError) {
        lastError = error
    }
}
#endif
```

- [ ] **Step 3: Run the tests in record mode**

In each `assertSnapshot` call, temporarily add `record: true` (or set the `SNAPSHOT_TESTING_RECORD=true` env var). Run:

```
SNAPSHOT_TESTING_RECORD=true swift test --filter FindReplaceOverlaySnapshotTests 2>&1 | tail -30
```

Expected: every test "fails" with "No reference was found ... A new snapshot was recorded." — that is the recording mode message. Inspect the generated `__Snapshots__/FindReplaceOverlaySnapshotTests/` images and confirm they look right.

- [ ] **Step 4: Remove `record: true` (or unset the env var), re-run, verify PASS**

```
swift test --filter FindReplaceOverlaySnapshotTests 2>&1 | tail -30
```

Expected: all seven tests PASS.

- [ ] **Step 5: Lint, build**

```
swiftlint --fix && swiftlint && swift build
```

- [ ] **Step 6: Commit, including the recorded images**

```
git add Tests/CodeEditorSampleTests/FindReplaceOverlaySnapshotTests.swift \
        Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift \
        Tests/CodeEditorSampleTests/__Snapshots__/FindReplaceOverlaySnapshotTests
git commit -m "Sample: FindReplaceOverlay snapshot tests (7 cases)"
```

---

## Task 15: Quality pipeline + NEXT.md edits

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 1: Run the full quality pipeline**

```
swift build && swiftlint --fix && swiftlint && swift test --parallel 2>&1 | tail -40
```

Expected: clean build, no SwiftLint violations. Test parallel run — if any new flake appears, identify whether it is one of the pre-existing flakes documented in NEXT.md section D (`ScrollPositionPreservationTests`, `LineGeometryStoreBenchmarkTests`, `EditorStatusBarSnapshots/*`, `PerformanceObservationTests.restartAfterStopResumesRefreshTicks`, etc.). Do not touch those — they belong to a separate test-hygiene pass.

- [ ] **Step 2: Smoke-run the sample app**

```
swift run CodeEditorSample
```

Manually verify:
- ⌘F opens the overlay with the find field focused
- Typing reproduces matches highlighted with the yellow tone
- The current match has the selection-color treatment
- ↑ / ↓ navigate, current-match styling moves
- Toggling Options reveals the Aa / |W| / .* row; toggling case-sensitive re-runs immediately
- Typing "[invalid" with regex on shows "Invalid regex" badge
- Replace consumes one match and advances
- Replace All clears highlights
- ESC closes; highlights vanish
- Switching tabs clears highlights; reopening on the new tab re-runs the search

Quit the sample.

- [ ] **Step 3: Update NEXT.md**

In `NEXT.md`, in section A.1, strike the "Find/Replace match highlighting" bullet:

```
~~**Find/Replace match highlighting.**~~ — done. `FindReplaceOverlay` rewritten as a view-only host bound to a feature-scoped `FindReplaceModel`; framework `SearchOptions` gained `currentMatchColor` and the engine paints two layers + repaints on navigation. `EditorController.clearSearch` now actually clears highlights, and `replaceCurrent(with:)` lands the Xcode-style "replace then advance". Spec: `docs/superpowers/specs/2026-05-15-find-replace-overlay-upgrade-design.md`; plan: `docs/superpowers/plans/2026-05-15-find-replace-overlay-upgrade.md`.
```

In section A.3, strike item 4 the same way (referencing the same spec/plan).

In section A.3 item 1 ("AppState is a god object"), append a note:

```
> First slice extracted: `FindReplaceModel` (find/replace state, debounce, lifecycle). The remaining decomposition (Theme / Configuration / Annotations / etc.) is unchanged in scope.
```

- [ ] **Step 4: Commit the NEXT.md update**

```
git add NEXT.md
git commit -m "NEXT.md: mark Find/Replace overlay upgrade (A.1, A.3 #4) done"
```

---

## Self-review checklist (already run; for executor reference)

- Spec coverage: all goals — current-vs-other styling (Task 1–3), options UI (Task 10), single-match replace (Task 5/9), live debounce (Task 9), clear lifecycle (Task 12), `FindReplaceModel` extraction (Task 9/11), snapshot tests (Task 14) — have tasks.
- No placeholders: every code step shows actual code; every command has expected output.
- Type consistency: `FindReplaceControlling` protocol, `FindReplaceModel` method names, `SearchOptions.currentMatchColor`, and `EditorController.replaceCurrent(with:)` are referenced identically across all tasks.
- Pre-existing flake guard: Task 15 explicitly calls out that pre-existing flakes (NEXT.md D) are not in scope.
