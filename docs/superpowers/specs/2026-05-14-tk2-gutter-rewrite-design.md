# TK2 Gutter Rewrite — Design

**Status:** Approved, ready for implementation plan.
**Date:** 2026-05-14
**Closes:** `NEXT.md` § B.5 ("NSRulerView gutter TextKit 1 island").

## Problem

`Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift` hosts a `LineNumberRulerView` (an `NSRulerView` subclass) whose `drawHashMarksAndLabels(in:)` reads `textView.layoutManager` and walks the legacy TextKit 1 surface — `glyphRange(forBoundingRect:in:)`, `characterRange(forGlyphRange:)`, `lineFragmentRect(forGlyphAt:)`, `glyphIndexForCharacter(at:)`. The same file's private `lineNumber(at:)` (used by the fold-control mouseDown path) reads `textView.layoutManager.characterIndex(for:in:fractionOfDistanceBetweenInsertionPoints:)`.

The editor is otherwise TextKit 2-native: `CodeEditorView` conforms to `NSTextLayoutManagerDelegate`, never reads `textView.layoutManager`, and uses `NSTextContentStorage` + `NSTextLayoutManager` end-to-end. But AppKit synthesizes a TK1-compatibility `NSLayoutManager` lazily on first read of `NSTextView.layoutManager`. Once the gutter draws — which happens at first paint — the editor flips from TK2 to TK1 for layout queries. In headless test fixtures (no window, no ruler draw) the TK2 stack is preserved; in production the flip is silent and total.

This is a correctness bug, not a performance bug: the editor's documented TK2-only contract is false on macOS at runtime.

## Goal

Remove every `NSTextView.layoutManager` read inside the gutter. Route both drawing and hit-testing through the existing TK2-native pipeline (`TextKitLineNumberHelper` → `NSTextLayoutManager.enumerateTextLayoutFragments` + `LineGeometryStore`). Preserve visual parity with the current gutter and the `NSRulerView` host integration. Add active-line line-number coloring (the renderer already exposes `themedActiveLineNumberColor` but no caller uses it).

## Non-goals

- Replacing `NSRulerView` as the macOS host. Subclassing `NSRulerView` does not engage TK1; only `layoutManager` reads inside the subclass do. The free `NSScrollView` integration (auto-positioning, `rulersVisible`, scroll tracking, accessibility) stays.
- Unifying the iOS `GutterView` and macOS `LineNumberRulerView` into one host. They already share the renderer — that is the unification.
- Removing the `GutterView.draw(_:)` macOS short-circuit ("On macOS, GutterView should not be used"). Unrelated to the TK1 flip; tracked separately if desired.
- A bespoke macOS-only gutter that drops `NSRulerView` for a sibling subview. Adds layout/scroll-tracking burden with no correctness benefit.
- New public API on `CodeEditorPlugin`. The signature change on `GutterViewRenderer.draw(...)` is additive (new defaulted parameter).
- iOS-side correctness changes. iOS already uses the TK2 path; this design only wires `activeLineNumber` through the iOS draw call. No new iOS observers — active-line color refreshes on the next natural redraw (text edit, scroll, theme change).

## Approach

Three changes, all in `Sources/CodeEditorPlugin/Layout/`:

1. **`GutterViewRenderer.draw(...)` gains a defaulted `activeLineNumber: Int? = nil` parameter** and routes per-line color to `themedActiveLineNumberColor` vs. `themedLineNumberColor` based on the comparison `lineNumber == activeLineNumber`.

2. **`LineNumberRulerView` is rewritten to delegate to the renderer**: `drawHashMarksAndLabels(in:)` shrinks to ~15 lines that fetch the `CGContext` from `NSGraphicsContext.current`, compute `activeLineNumber` from `textView.selectedRange().location` via `lineGeometryStore.lineIndex(forUtf16Offset:)`, call `renderer.draw(...)`, and draw the right-edge separator. The dead AppKit helpers (`getLineRanges(for:in:)`, the inline `drawFoldingControl`/`drawFoldingIcon`, and the private `lineNumber(at:)`) are deleted. The `mouseDown` fold-control path switches to `TextKitLineNumberHelper.lineNumber(at:)`.

3. **A selection-change observer fires the gutter redraw on macOS** when the *line index* of the selection changes. The ruler observes `NSTextView.didChangeSelectionNotification` and calls `needsDisplay = true`, short-circuiting when the cursor moves within the same line. iOS does not gain a dedicated observer in this pass: the active-line color refreshes on the next natural redraw (text edit, scroll). Justified in the iOS surface-changes note below; tracked under "Out of scope (followups)".

After this, the gutter is TK2-pure on both platforms, and the line number containing the caret is rendered in the theme's active-line color.

## Surface changes

### `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift`

`draw(...)` gains `activeLineNumber`:

```swift
public func draw(
    in rect: CGRect,
    context: CGContext,
    textView: CodeEditorView,
    gutterBounds: CGRect,
    fillBackground: Bool = false,
    activeLineNumber: Int? = nil
)
```

The per-line color is computed inline:

```swift
let color: PlatformColor = (lineNumber == activeLineNumber)
    ? themedActiveLineNumberColor
    : themedLineNumberColor
```

`drawLineNumber(_:for:context:)` takes a `color: PlatformColor` parameter so the caller doesn't mutate `self.textColor` per-line. The existing `textColor` stored property is removed; `themedLineNumberColor` is the single source of truth.

No other renderer changes. Fold-control drawing, the `apply(theme:)` path, and the `LineDrawingContext` struct are untouched.

### `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`

`LineNumberRulerView` is rewritten internally. The class is internal (no `public` modifier), so the changes have no source-compatibility impact outside the package. The `textColor` and `font` stored properties become vestigial — the renderer is the source of truth for drawing colors and the ruler's own `font` is unused by the new draw path; both are removed to keep the type focused. `backgroundColor`, `rightPadding`, and `weak var textView` are retained because external code in the same package still sets them (`backgroundColor` from the container, `textView` from `setupMacOSViews`/`updateMacOSRuler`).

New stored properties:

```swift
private let renderer = GutterViewRenderer()
private var lastActiveLineNumber: Int?
```

`drawHashMarksAndLabels(in:)` becomes:

```swift
override func drawHashMarksAndLabels(in rect: NSRect) {
    backgroundColor.set()
    rect.fill()

    guard let textView = clientView as? CodeEditorView,
          let context = NSGraphicsContext.current?.cgContext else {
        return
    }

    let activeLineNumber = computeActiveLineNumber(for: textView)

    renderer.draw(
        in: rect,
        context: context,
        textView: textView,
        gutterBounds: bounds,
        fillBackground: false,
        activeLineNumber: activeLineNumber
    )

    PlatformColors.separator.set()
    NSRect(x: ruleThickness - 1, y: rect.minY, width: 1, height: rect.height).fill()
}

private func computeActiveLineNumber(for textView: CodeEditorView) -> Int? {
    let location = textView.selectedRange().location
    guard location != NSNotFound,
          textView.lineGeometryStore.lineCount > 0 else { return nil }
    return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
}
```

`mouseDown(with:)` in the folding-support extension switches to the TK2 helper:

```swift
private func resolveLineNumber(at point: NSPoint) -> Int? {
    guard let textView = self.textView as? CodeEditorView else { return nil }
    let textPoint = textView.convert(point, from: self)
    return TextKitLineNumberHelper(textView: textView).lineNumber(at: textPoint)
}
```

(`textView` here is the existing `weak var textView: NSTextView?` on the ruler; the cast to `CodeEditorView` is required for `TextKitLineNumberHelper` and matches the existing `as? CodeEditorView` guards in the fold path.)

**Deleted:**
- `getLineRanges(for:in:)` (lines 202–230 in the current file)
- The inline `drawFoldingControl(at:in:)` and `drawFoldingIcon(in:isFolded:)` extension methods (lines 473–526)
- The private `lineNumber(at:)` extension method (lines 558–582) — its single caller (`mouseDown`) now calls `resolveLineNumber(at:)`.

### `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift` — `setupMacOSViews`

Add a selection observer alongside the existing `NSText.didChangeNotification` observer:

```swift
NotificationCenter.default.addObserver(
    forName: NSTextView.didChangeSelectionNotification,
    object: textView,
    queue: .main
) { [weak rulerView] _ in
    Task { @MainActor in
        rulerView?.selectionDidChange()
    }
}
```

`selectionDidChange()` on `LineNumberRulerView` computes the active line and short-circuits if unchanged:

```swift
@MainActor
func selectionDidChange() {
    guard let textView = clientView as? CodeEditorView else { return }
    let newActive = computeActiveLineNumber(for: textView)
    if newActive != lastActiveLineNumber {
        lastActiveLineNumber = newActive
        needsDisplay = true
    }
}
```

### `Sources/CodeEditorPlugin/Layout/GutterView.swift`

Two changes:

1. `drawLineNumbers(in:)` derives `activeLineNumber` and passes it through:

```swift
let activeLineNumber: Int? = {
    guard let selectedTextRange = textView.selectedTextRange else { return nil }
    let location = textView.offset(from: textView.beginningOfDocument, to: selectedTextRange.start)
    guard textView.lineGeometryStore.lineCount > 0 else { return nil }
    return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
}()

renderer.draw(
    in: rect,
    context: context,
    textView: textView,
    gutterBounds: bounds,
    fillBackground: fillBackground,
    activeLineNumber: activeLineNumber
)
```

2. **iOS dedicated selection observer is deferred.** `GutterViewModel.updateVisibleLineNumbers()` populates a separate `[LineNumberDisplayInfo]` render path from the `GutterViewRenderer` path this design rewrites; reusing it would couple two architectures that are already drifting. `UITextView` does not expose a `textDidChangeSelectionNotification`, so the iOS-side dedicated selection observer would require either KVO on `selectedTextRange` or a new back-reference from `GutterViewModel`. On iOS, the active-line color refreshes on the next natural redraw (text edit, scroll, theme change). If UX feedback shows the lag is noticeable, the follow-up is a single `Observation.withObservationTracking` block in `GutterView.observeTextView()` keyed on `textView.selectedTextRange`. Out of scope for the TK2-flip fix.

### `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift` — theme fan-out

`CodeEditorContainerView.apply(theme:)` (line 48) already fans out to `gutterView`, `minimapView`, and `textView`. On macOS the cross-platform `gutterView` is short-circuited (`GutterView.draw(_:)` returns early), so its renderer's themed colors never reach the screen — the macOS-rendering `LineNumberRulerView`'s renderer needs a parallel call. Add a thin `LineNumberRulerView.apply(theme:)` that forwards to its `renderer.apply(theme:)` and sets `needsDisplay = true`, then extend the container's fan-out:

```swift
public func apply(theme: Theme) {
    if appliedTheme == theme { return }
    appliedTheme = theme
    gutterView.apply(theme: theme)
    minimapView.apply(theme: theme)
    textView.apply(theme: theme)
    #if canImport(AppKit)
    (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.apply(theme: theme)
    #endif
}
```

The `#if` guard keeps the iOS path untouched. `LineNumberRulerView.apply(theme:)` follows the same equality-gate pattern as `GutterView.apply(theme:)`.

## Data flow

### Draw on macOS

1. `NSScrollView` issues a ruler redraw (scroll, text change, or selection change).
2. `LineNumberRulerView.drawHashMarksAndLabels(in: rect)` fires.
3. Ruler reads `textView.selectedRange().location` → `lineGeometryStore.lineIndex(forUtf16Offset:)` → `activeLineNumber`.
4. Ruler pulls `NSGraphicsContext.current?.cgContext` and calls `renderer.draw(in:context:textView:gutterBounds:fillBackground:activeLineNumber:)`.
5. Renderer instantiates `TextKitLineNumberHelper(textView:)` and calls `getVisibleLineRanges()`. The helper walks `lineGeometryStore.lineGeometries(in: visibleRange)` — no `NSLayoutManager` involvement.
6. For each `(lineNumber, lineRange)` the renderer computes `yPosition` via `lineGeometryStore.yPosition(forLineIndex:)` and draws via `UnifiedDrawingCoordinator.drawLineNumber(...)` using the active or inactive color.
7. Renderer iterates fold-controls; each one asks `helper.getLineFragmentRect(for:)`, which calls `NSTextLayoutManager.enumerateTextLayoutFragments(from:)` and stops after the first fragment.
8. Ruler draws the right-edge separator.

### Hit-test on macOS (fold-control click)

1. `LineNumberRulerView.mouseDown(with:)` checks `point.x <= controlPadding + controlSize`.
2. Calls `TextKitLineNumberHelper.lineNumber(at:)` via the `resolveLineNumber(at:)` helper.
3. If the line is foldable, calls `textView.toggleFold(at:)` and sets `needsDisplay = true`.

### Selection-change observer (macOS)

`NSTextView.didChangeSelectionNotification` → `LineNumberRulerView.selectionDidChange()` → recomputes `lastActiveLineNumber`; if different, sets `needsDisplay = true`. Intra-line caret movement is a no-op.

### Selection-change refresh (iOS)

No dedicated observer (see Surface changes § `GutterView.swift` rationale). `GutterView.drawLineNumbers(in:)` recomputes `activeLineNumber` from `textView.selectedTextRange` on every draw, so the active-line color is correct the next time the gutter draws — which happens on text edits, scroll, theme changes, and configuration changes. Latency between caret move and active-line repaint is bounded by the next user-driven event.

### What the gutter never does

No code in this design reads `NSTextView.layoutManager`, instantiates or looks up `NSLayoutManager`, or calls `glyphRange(forBoundingRect:in:)`, `characterRange(forGlyphRange:)`, `lineFragmentRect(forGlyphAt:)`, `glyphIndexForCharacter(at:)`, or `characterIndex(for:in:fractionOfDistanceBetweenInsertionPoints:)`. The TK2-primary smoke test enforces this contract.

## Error handling

This is a rendering path. The errors are about graceful degradation when invariants don't hold.

- **No visible lines.** `TextKitLineNumberHelper.getVisibleLineRanges()` returns `[]` when the text view is missing or empty. The renderer already early-returns on `lineRanges.isEmpty`; no change.
- **Missing graphics context.** `NSGraphicsContext.current?.cgContext` is optional. If nil, the ruler logs via `CrossPlatformLogger` and returns. No fallback drawing — a partly-rendered ruler is worse than nothing.
- **Selected range out of bounds.** `textView.selectedRange().location` can be `NSNotFound`. `computeActiveLineNumber` returns `nil`; the renderer draws every line in the inactive color. Same when `lineGeometryStore.lineCount == 0`.
- **Geometry store stale during edit.** The geometry store is updated synchronously by the text storage delegate before `drawHashMarksAndLabels` is invoked. The existing draw path already depends on this ordering; no new hazard.
- **Fold-control fragment lookup returning nil.** `helper.getLineFragmentRect(for:)` can return nil if the fragment isn't laid out yet. The renderer already skips that fold-control draw. No change.
- **Selection observer firing during teardown.** The notification can fire after the ruler is detached from the scroll view. The observer guards on `clientView != nil`; otherwise it's a no-op. Matches the existing scroll-observer pattern.
- **Third-party `layoutManager` reads.** External AppKit code (menu actions, accessibility queries, third-party views) can still touch `textView.layoutManager` and trigger TK1 synthesis. The design only commits that *our* gutter stops triggering it; broader policing is out of scope.

## Testing

Three new test files; no changes to existing tests beyond keeping defaulted parameters working.

### 1. Snapshot parity — `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift` (macOS-only)

Uses the existing `swift-snapshot-testing` infrastructure. Hosts a `CodeEditorContainerView` in a windowed `NSWindow` (matches the pattern used by `EditorStatusBarSnapshots`). Tests:

- `testRulerRendersBaselineSwiftSource` — 100-line Swift source with the default theme. Locks the baseline.
- `testRulerRendersFoldedLine` — one collapsed region. Locks fold-control rendering.
- `testRulerRendersActiveLine` — caret on line 42. Locks the active-line color path.
- `testRulerRendersEmptyDocument` — locks the empty-state early-return.
- `testRulerRendersLongLineNumbers` — 10,000-line document. Locks right-alignment and rule thickness.

Snapshot images are recorded with `isRecording: true` first and committed alongside the test file under `__Snapshots__/`.

### 2. TK2-primary smoke — `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift` (macOS-only, XCTest)

- `testDrawHashMarksAndLabelsDoesNotFlipToTK1` — builds a `CodeEditorContainerView` in a window, captures `textView.textLayoutManager` before first paint, calls `view.window?.displayIfNeeded()`, asserts the reference is identical after. The contract is identity equality: if the gutter regresses to reading `layoutManager`, AppKit synthesizes a new TK1-backed network and the references diverge.
- `testFoldControlClickResolvesLineNumberViaTK2` — drives a synthetic `NSEvent.mouseDown` inside the fold-control band, asserts `textView.toggleFold(at:)` is called with the expected line number. The wired-up `TextKitLineNumberHelper.lineNumber(at:)` is what produces it.
- `testSelectionChangeTriggersRulerRedraw` — hosts the ruler, observes `needsDisplay`, moves the caret to a new line, asserts the ruler was marked dirty. Caret moves within the same line do not mark dirty (`lastActiveLineNumber` short-circuit).

### 3. Renderer active-line unit — `Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift` (cross-platform, Swift Testing)

Pure-function-level test of the new `activeLineNumber` parameter. Stubs a `CodeEditorView` with a known selection, calls `renderer.draw(...)` into a bitmap-backed `CGContext`, samples pixel colors at known line positions, asserts the active line matches `themedActiveLineNumberColor` and inactive lines match `themedLineNumberColor`. No window, no scroll view, runs on both platforms.

### What's deliberately out of scope

- No headless fuzz of the gutter.
- No benchmark of the renderer path (`LineGeometryStoreBenchmarkTests` already covers the geometry store; the renderer is straight iteration over it).
- No iOS TK1 probe — iOS has no `NSLayoutManager` to flip to.

## Risk

- **`NSRulerView` and `NSTextView` interaction edge cases.** `NSRulerView` was designed alongside TK1. The shell itself does not engage TK1, but it's possible some AppKit internal queries on the ruler indirectly read `clientView.layoutManager`. Mitigation: the TK2-primary smoke test catches regressions immediately. If a flip is observed despite our code being clean, the fallback is to drop `NSRulerView` for a sibling subview (Approach 2 from the design conversation) in a follow-up.
- **Active-line redraw cost.** On every line of caret movement the ruler invalidates and redraws the full visible range. `LineGeometryStore` is O(log n) and the renderer iterates visible lines only, so a 200-line viewport is ~200 cheap lookups plus the existing draw. No new perf hazard.
- **Snapshot stability across macOS versions.** Snapshot tests can drift on font metrics or sub-pixel rendering between OS versions. Mitigation: scope snapshot recording to a single macOS version in CI; treat drift as a re-record event, not a regression.

## Out of scope (followups)

- Removing the `GutterView.draw(_:)` macOS short-circuit and the AppKit early-returns in `observeTextView()` — irrelevant to the TK1 flip; tracked separately if desired.
- Active-line *background* highlighting (not just the line number). Different code path (`LineHighlightView`).
- iOS dedicated selection observer for sub-second active-line refresh on caret moves without scrolling. Add when/if the lag is reported.
- Reconciling the two iOS gutter render paths (`GutterViewModel.visibleLineNumbers` populated by `LineNumberService` vs. the live `GutterViewRenderer` path). Either consolidate or document why both exist.
- Gutter parity for the iOS `GutterInteractionHandler` (already TK2-clean; no work).
- Migrating any non-gutter `layoutManager` reads elsewhere in the codebase. `grep -rn "textView.layoutManager"` after this lands will confirm the gutter file is clean; broader sweeps are their own design pass.
