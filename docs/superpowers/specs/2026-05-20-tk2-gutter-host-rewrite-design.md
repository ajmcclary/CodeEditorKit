# TK2 Gutter Host Rewrite — Design

**Status:** Approved, ready for implementation plan.
**Date:** 2026-05-20
**Supersedes:** the "Replacing `NSRulerView` as the macOS host" non-goal in `docs/superpowers/specs/2026-05-14-tk2-gutter-rewrite-design.md`. That spec's other commitments (TK2-pure draw path, active-line color, renderer-as-single-source-of-truth) are preserved.

## Problem

Two correctness defects in the macOS gutter, both rooted in the same architectural mismatch: `LineNumberRulerView` is an `NSRulerView` subclass and `NSRulerView` was designed for the TextKit 1 layout-manager model.

1. **Scroll-position drift.** `GutterViewRenderer.calculateLineNumberYPosition` (macOS branch) returned a Y in the text view's document-coordinate space and drew it directly into the ruler's drawing context. The ruler's bounds do not auto-translate to match scroll, so line numbers stayed pinned to the same visual Y as the user scrolled. Patched on 2026-05-20 by subtracting `textView.visibleRect.origin.y` in two sites of `GutterViewRenderer.swift`. The patch is correct but is symptomatic of a coordinate-system that the renderer keeps having to reason about.
2. **Wrap misalignment.** `TextKitLineNumberHelper.getLineFragmentRect(for:)` falls back to `fragment.layoutFragmentFrame` — the full multi-visual-line block — when the first-line-fragment lookup fails. The renderer's `(lineRect.height - fontLineHeight) / 2` centering then drops the number into the middle of the wrapped block rather than anchoring it to the first visual line. Visible on any wrapped paragraph.

The structural cause is shared: the ruler's drawing context is one coordinate space, the TextKit 2 layout fragments live in another, and the renderer is bridging them with ad-hoc math. Every new bug class on this path comes from that bridge.

`NSRulerView` also brings no net benefit. Its built-in machinery (`ruleThickness` allocation, measurement-unit hash marks, ruler markers, accessory views) is unused; the only thing it gives the editor is automatic insetting of the document view inside the scroll view. That can be replicated with a one-line `textContainerInset.width` change.

## Goal

Replace `LineNumberRulerView` with a `CodeEditorGutterView : NSView` attached as a floating subview of the scroll view, driven entirely from TextKit 2 fragment frames. Eliminate the document-space → ruler-space coordinate bridge so wrap, scroll, fold-controls, and future overlays all draw in the same space the layout fragments live in. Apply the wrap-anchor fix to the renderer once; both platforms pick it up. Preserve visual parity with today's gutter (post-Approach-A patch) for non-wrapped content.

## Non-goals

- Replacing `NSTextView` with a custom `NSView` host (the STTextView model). Out of scope; far larger blast radius than the gutter alone justifies.
- Stealing `NSTextViewportLayoutController.delegate` from `NSTextView`. The text view depends on that slot for its own rendering. Notification-based observation gives equivalent timing for our needs.
- Per-cell `NSView` line numbers (the STTextView cell-pooling pattern). The renderer is already a flat-draw pipeline shared with iOS; introducing subview pooling triples the surface for marginal benefit. Tracked as a follow-up if accessibility-per-line-number lands.
- Unifying the iOS `GutterView` host with the macOS host. They already share the renderer — that's the unification.
- Public-API breakage. `LineNumberRulerView` is internal; removing it is invisible. `GutterViewRenderer.draw(...)` signature is unchanged. `GutterView` stays public (still the iOS host).
- A bespoke spec for the cross-platform `GutterView` cleanup or `GutterViewModel` reconciliation; both are tracked in "Out of scope (followups)".

## Approach

Four changes, all under `Sources/CodeEditorView/Layout/` plus one file under `Sources/CodeEditorView/`.

1. **New `CodeEditorGutterView : NSView`** (`Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`, macOS-only). Final class, `isFlipped = true`, attached to the scroll view via `addFloatingSubview(_, for: .horizontal)`. Owns the renderer instance, the four scroll/resize/text/selection observers, the active-line tracking, the theme fan-out target, and `mouseDown` fold-control hit-testing.

2. **Renderer macOS branch rewritten** (`Sources/CodeEditorView/Layout/GutterViewRenderer.swift`). Public `draw(...)` signature unchanged. The macOS path stops calling `TextKitLineNumberHelper.getVisibleLineRanges()` + `getLineFragmentRect(for:)` per line and instead walks `NSTextLayoutManager.enumerateTextLayoutFragments(from:options:)` over the viewport range directly. For each fragment, the first non-extra `NSTextLineFragment` is the anchor — its `typographicBounds` provides both cell Y and cell height. The wrap bug disappears by construction. The iOS branch gets the same fragment-walk shape so iOS picks up wrap correctness too.

3. **Container wiring updated** (`Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift` and `Sources/CodeEditorView/Layout/ContainerViewInitializer.swift`). `setupRulerView` → `setupGutterView`, attaches `CodeEditorGutterView`, sets `textView.textContainerInset.width = baseInsetWidth + gutterWidth + horizontalPadding`. `updateMacOSRuler` → `updateMacOSGutter`, calls `attach`/`detach` on configuration flips and recomputes the inset. `scrollView.hasVerticalRuler` / `rulersVisible` / `verticalRulerView` are no longer touched.

4. **Orphan cleanup** (`Sources/CodeEditorView/CodeEditorView+LineNumbersExtensions.swift` and `Sources/CodeEditorView/Layout/GutterView.swift`). `updateGutterVisibility` stops instantiating-then-removing a `GutterView` on macOS. `GutterView.draw(_:)`'s macOS short-circuit and `GutterView.observeScrollView`'s AppKit branch are deleted. The `GutterView` class stays public; only the dead macOS branches go.

After this lands the macOS gutter is a single TK2-coordinate-space view, and the renderer never bridges between scroll-relative and document-relative coordinates again.

## Surface changes

### New: `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorTheming

@MainActor
final class CodeEditorGutterView: NSView {
    weak var textView: CodeEditorView?
    let renderer = GutterViewRenderer()
    private(set) var lastActiveLineNumber: Int?
    private var lastScrollY: CGFloat = 0
    private var observers: [NSObjectProtocol] = []

    override var isFlipped: Bool { true }

    func attach(to scrollView: NSScrollView, textView: CodeEditorView) {
        if superview === scrollView { detach() }
        self.textView = textView
        scrollView.addFloatingSubview(self, for: .horizontal)
        registerObservers(on: scrollView, textView: textView)
    }

    func detach() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        removeFromSuperview()
        textView = nil
    }

    func apply(theme: Theme) {
        renderer.apply(theme: theme)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // background fill, renderer.draw(...), right-edge separator
    }

    override func mouseDown(with event: NSEvent) {
        // fold-control hit-test via TextKitLineNumberHelper
    }
}
#endif
```

`registerObservers` installs four notification observers, matching the current ruler's pattern: `NSView.boundsDidChangeNotification` and `NSView.frameDidChangeNotification` on `scrollView.contentView`, `NSText.didChangeNotification` on `textView`, and `NSTextView.didChangeSelectionNotification` on `textView`. The scroll observer keeps the `lastScrollY` comparison so pure horizontal scrolls do not invalidate.

`selectionDidChange()` computes the new `activeLineNumber` via `textView.lineGeometryStore.lineIndex(forUtf16Offset:)` and short-circuits when unchanged — verbatim from the prior ruler.

`mouseDown(with:)` lifts the existing `LineNumberRulerView.mouseDown` and `resolveLineNumber(at:)` implementations unchanged; both already route through `TextKitLineNumberHelper.lineNumber(at:)`.

### Modified: `Sources/CodeEditorView/Layout/GutterViewRenderer.swift`

Signature unchanged:

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

macOS branch rewritten to walk fragments directly. Sketch:

```swift
#if canImport(AppKit)
guard let textLayoutManager = textView.textLayoutManager,
      let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange else {
    return
}
textLayoutManager.ensureLayout(for: viewportRange)

let viewportBounds = textLayoutManager.textViewportLayoutController.viewportBounds
let scrollOffsetY = textView.visibleRect.origin.y - textView.textContainerOrigin.y

textLayoutManager.enumerateTextLayoutFragments(
    from: viewportRange.location,
    options: [.ensuresLayout]
) { fragment in
    if fragment.layoutFragmentFrame.minY >= viewportBounds.maxY { return false }
    guard let firstLine = fragment.textLineFragments.first(where: { !$0.isExtraLineFragment }) else {
        return fragment.layoutFragmentFrame.maxY < viewportBounds.maxY
    }
    let lineNumber = lineNumber(for: fragment, textView: textView)
    let cellY = fragment.layoutFragmentFrame.minY + firstLine.typographicBounds.minY - scrollOffsetY
    let cellHeight = firstLine.typographicBounds.height
    drawLineNumber(lineNumber, atY: cellY, height: cellHeight, color: …, context: …)
    if textView.configuration.display.areFoldingControlsVisible,
       textView.isFoldable(at: lineNumber) {
        drawFoldingControl(atY: cellY, height: cellHeight, …)
    }
    return fragment.layoutFragmentFrame.maxY < viewportBounds.maxY
}
#endif
```

`lineNumber(for:textView:)` is a private helper that resolves the fragment's first character location to a 1-based line index via `textView.lineGeometryStore.lineIndex(forUtf16Offset:)` (the same lookup the helper already uses; we just call it directly to avoid the `getVisibleLineRanges` indirection).

The centering math inside `drawLineNumber` now operates on `cellHeight = firstLine.typographicBounds.height` — a true single-visual-line height — so `(cellHeight - fontLineHeight) / 2` produces a top-of-line anchor regardless of how many visual lines the logical line wraps to.

iOS branch receives the equivalent fragment-walk, preserving its existing `textContainerInset.top - contentOffset.y` scroll-translation. The renderer's iOS path is otherwise unchanged.

**Deleted from the renderer:** the macOS-only call to `TextKitLineNumberHelper.getVisibleLineRanges()` and its per-line `getLineFragmentRect` follow-ups. The helper's `getLineFragmentRect` method itself stays — it's still used by other call sites — but the renderer stops routing through it.

### Modified: `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift`

`LineNumberRulerView` class **deleted** (including its `mouseDown` and `resolveLineNumber` extension, both of which migrate to `CodeEditorGutterView` unchanged).

`setupMacOSViews` no longer touches `scrollView.hasVerticalRuler` or `scrollView.verticalRulerView`. The ruler-setup block is replaced by `setupGutterView`. The `NSText.didChangeNotification` observer registration moves into `CodeEditorGutterView.registerObservers`.

`updateMacOSRuler` → `updateMacOSGutter`. It now:
- Creates and attaches `CodeEditorGutterView` when `display.isLineNumbersEnabled` is true and no gutter is attached.
- Calls `detach()` on the existing gutter when the flag is false.
- Recomputes `textView.textContainerInset.width = baseInsetWidth + configuration.layout.gutterWidth + horizontalPadding` after every flip.

`layoutViewsAppKit` keeps its existing scroll-position-preservation around `textContainer` mutations but no longer calls `scrollView.verticalRulerView?.needsDisplay = true`. The gutter redraws on its own through the bounds/frame observers it owns.

### Modified: `Sources/CodeEditorView/Layout/ContainerViewInitializer.swift`

`setupRulerView(for:scrollView:textView:)` → `setupGutterView(for:scrollView:textView:)`. Same call site, same lifecycle, new attachment. The function attaches `CodeEditorGutterView`, applies the current theme via `gutterView.apply(theme:)`, and sets the initial `textContainerInset.width`.

### Modified: `Sources/CodeEditorView/Layout/CodeEditorContainerView.swift`

Three changes:

1. Add a `weak var macGutterView: CodeEditorGutterView?` (macOS-only) alongside the existing cross-platform `public let gutterView: GutterView`. The cross-platform `gutterView` stays for iOS; macOS reads `macGutterView`. Assigned by `setupGutterView` / cleared by `updateMacOSGutter` on disable.
2. Add a `private(set) var baseTextContainerInsetWidth: CGFloat` to hold the non-gutter portion of `textView.textContainerInset.width`. Captured during initial setup before the gutter contribution is added. Used by `updateMacOSGutter` to recompute the inset on every flip: `textView.textContainerInset.width = baseTextContainerInsetWidth + configuration.layout.gutterWidth + horizontalPadding`.
3. `apply(theme:)` keeps its existing equality-gate and per-component fan-out. The macOS-only line uses the direct property:

```swift
#if canImport(AppKit)
macGutterView?.apply(theme: theme)
#endif
```

### Modified: `Sources/CodeEditorView/CodeEditorView+LineNumbersExtensions.swift`

`updateGutterVisibility` no longer constructs-then-removes a `GutterView` on macOS. The AppKit branch is replaced by a call to the container's `updateMacOSGutter`. iOS path unchanged.

### Modified: `Sources/CodeEditorView/Layout/GutterView.swift`

Two dead-code deletions:
- `draw(_:)`'s macOS short-circuit (the `// On macOS, GutterView should not be used` block) and the `guard superview != nil else { return }` early-return go away. The function becomes iOS-only via `#if canImport(UIKit)`.
- `observeScrollView(_:)`'s `#if canImport(AppKit)` branch is removed. The function becomes iOS-only.

The `GutterView` class stays public (still the iOS host). Its public surface is unchanged for external consumers.

## Data flow

### Draw (macOS)

1. A trigger fires: `clipView.boundsDidChange` (scroll), `clipView.frameDidChange` (resize), `textStorage.didProcessEditing` (text change), or `textView.didChangeSelection` (caret moved).
2. The observer marks `gutterView.needsDisplay = true`. Selection-change short-circuits when `lastActiveLineNumber` is unchanged; scroll short-circuits when only X changed (`lastScrollY` comparison).
3. AppKit invokes `gutterView.draw(dirtyRect)`.
4. `draw` fills background, fetches `NSGraphicsContext.current?.cgContext`, computes the new `activeLineNumber` from `textView.selectedRange().location` + `lineGeometryStore`, then calls `renderer.draw(in:context:textView:gutterBounds:fillBackground:activeLineNumber:)`.
5. Renderer (macOS branch) calls `textLayoutManager.ensureLayout(for: viewportRange)`, captures `scrollOffsetY = visibleRect.origin.y - textContainerOrigin.y`, and enumerates fragments from `viewportRange.location`.
6. Per fragment: pick first non-extra `textLineFragment`, compute `cellY = fragment.frame.minY + firstLine.typographicBounds.minY - scrollOffsetY`, `cellHeight = firstLine.typographicBounds.height`, draw line number with active or inactive color via `UnifiedDrawingCoordinator.drawLineNumber(...)`, optionally draw fold-control.
7. After enumeration, `draw` paints the right-edge separator.

### Fold-control click (macOS)

1. `gutterView.mouseDown(with:)` checks `point.x <= controlPadding + controlSize`.
2. Calls `TextKitLineNumberHelper(textView:).lineNumber(at:)` via `resolveLineNumber(at:)`.
3. If the resolved line is foldable, calls `textView.toggleFold(at:)` and sets `needsDisplay = true`.

Identical logic to the prior ruler; only the receiver changed.

### Selection-change refresh (macOS)

`NSTextView.didChangeSelectionNotification` → `gutterView.selectionDidChange()` → recomputes `lastActiveLineNumber`; if different, sets `needsDisplay = true`. Intra-line caret movement is a no-op.

### Draw (iOS)

Unchanged host (`GutterView`), corrected renderer fragment-walk for wrap. Existing observer pipeline preserved; `activeLineNumber` is recomputed on every draw and refreshes on the next natural redraw (text edit, scroll, theme change) — same trade-off the 2026-05-14 spec settled.

### Lifecycle

`ContainerViewInitializer.setupGutterView` calls `gutterView.attach(...)` when `display.isLineNumbersEnabled` is true at construction time. `updateMacOSGutter` calls `attach`/`detach` on configuration flips. `attach` is idempotent: a second `attach(...)` call on the same scroll view tears down stale observers before re-registering.

### What the gutter never does

No code reads `NSTextView.layoutManager`, instantiates or looks up `NSLayoutManager`, or calls `glyphRange(forBoundingRect:in:)`, `characterRange(forGlyphRange:)`, `lineFragmentRect(forGlyphAt:)`, `glyphIndexForCharacter(at:)`, or `characterIndex(for:in:fractionOfDistanceBetweenInsertionPoints:)`. The TK2-primary smoke test enforces this contract. (Carried verbatim from the 2026-05-14 spec.)

## Error handling

This is a rendering path; the errors are graceful-degradation cases, not exception propagation.

- **`textLayoutManager == nil`** — TK2 invariant violation. Renderer's macOS branch returns early after filling background. Mirrors the prior `getLineFragmentRect` nil-handling.
- **`viewportRange == nil`** — happens before first layout. Return early. The next bounds-change notification retries.
- **Empty document / no fragments** — `enumerateTextLayoutFragments` invokes the block zero times. Nothing to draw.
- **First non-extra `textLineFragment` missing** — extra-line fragments at document end have no rendered content. Iterator skips and continues. Line number silently omitted for that fragment, matching iOS behavior today.
- **Selection observer fires post-detach** — observer closure captures `[weak self]` and `weak gutterView`; no-ops when the gutter is gone.
- **`attach(...)` called twice** — idempotent: tears down stale observers before re-registering.
- **`textContainerInset.width` conflict** — `setupMacOSViews`/`updateMacOSGutter` is the single owner of the gutter contribution. The container view stores `baseInsetWidth` (the non-gutter base) and recomputes `inset.width = baseInsetWidth + gutterWidth + horizontalPadding` on every relevant configuration flip. SwiftUI-driven mutations roundtrip cleanly.
- **Horizontal-only scroll** — observer's `lastScrollY` comparison filters these out before invalidating.
- **Fold-control click on wrapped line** — `TextKitLineNumberHelper.lineNumber(at:)` already returns the logical line; clicking anywhere in the wrapped block's gutter area resolves to that logical line.
- **Theme applied during attach race** — `apply(theme:)` is safe to call before `attach(...)`; it only mutates the renderer's stored colors plus `needsDisplay`.

## Testing

Four test categories. The first two replace existing ruler test files; the third is new; the fourth extends an existing file.

### 1. Snapshot parity — `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift` (macOS-only)

Replaces `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift`. Same hosting pattern as today (windowed `NSWindow`, real `CodeEditorContainerView`). Cases:

- `testGutterRendersBaselineFiveLines` — re-records the existing fixture against the new host. Visual parity with the post-Approach-A ruler output.
- `testGutterRendersWrappedLine` — **new, this is the wrap bug.** A short fixed-width font + a narrow text container with one logical line wrapping to five visual lines. Asserts the number sits aligned with the first visual line, with empty gutter beside the four continuation lines. Without the fix the number lands in the middle of the block.
- `testGutterRendersAfterScroll` — **new, this is the scroll bug we already patched.** Render at scroll=0, programmatically set `contentView.bounds.origin.y = 200`, force layout, render again. Asserts visible numbers update and align with their lines. Locks in the patched behavior architecturally.
- `testGutterRendersActiveLine`, `testGutterRendersFoldedLine`, `testGutterRendersEmptyDocument`, `testGutterRendersLongLineNumbers` — carried over from the prior suite, re-recorded for the new host.

Snapshots are recorded with `isRecording: true` first and committed alongside the test file under `__Snapshots__/`. The existing `LineNumberRulerViewSnapshotTests.swift` file and its `__Snapshots__/` directory are deleted in the same commit.

### 2. TK2-primary smoke — `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewTK2Tests.swift` (macOS-only, XCTest)

Renames `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift`. Carries over its five tests with receivers retargeted at `CodeEditorGutterView`:

- `testDrawDoesNotSynthesizeLegacyLayoutManager` — captures `textView.textLayoutManager` before first paint, calls `view.window?.displayIfNeeded()`, asserts the reference is identical after.
- `testFoldControlClickDoesNotSynthesizeLegacyLayoutManager` — drives a synthetic `NSEvent.mouseDown` inside the fold-control band, asserts identity preservation of `textLayoutManager` and that `textView.toggleFold(at:)` is called with the expected line number.
- `testWrappedLogicalLineUsesFirstVisualLineFragmentForGutterPosition` — same shape as today, with the new gutter as the receiver.
- `testSelectionChangeOnNewLineUpdatesLastActiveLine` — caret moves across a line boundary; gutter is marked dirty; `lastActiveLineNumber` updates.
- `testSelectionChangeOnSameLineKeepsLastActiveLineStable` — caret moves within a line; gutter is not marked dirty; `lastActiveLineNumber` is unchanged.

### 3. Lifecycle — `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift` (macOS-only)

New file. Pure unit tests of attach/detach:

- `testAttachIsIdempotent` — `attach(...)` twice; assert `scrollView.floatingSubviews(for: .horizontal)` contains exactly one `CodeEditorGutterView`.
- `testDetachRemovesObservers` — attach, detach, fire a synthetic `NSView.boundsDidChangeNotification` on the clip view; assert no draw call and no crash.
- `testTextContainerInsetRoundtrips` — enable line numbers (gutter width 50), assert `textView.textContainerInset.width >= 50 + horizontalPadding`; disable, assert `textContainerInset.width` returns to the baseline value.
- `testGutterReceivesThemeOnAttach` — attach with a non-default theme set on the container; assert `renderer.themedLineNumberColor` matches the theme.

### 4. Renderer wrap correctness — extend `Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift` (cross-platform)

Add wrap cases to the existing active-line file:

- `testRendererAnchorsWrappedLineNumberToFirstLineFragment` — stub a `CodeEditorView` whose `textLayoutManager` reports one logical line with two visible `textLineFragment`s; render into a bitmap-backed `CGContext`; sample pixel rows at the Y of the first vs. second line fragment; assert the number is drawn at the first row only.
- Both platforms run this test (renderer is shared); on iOS the renderer's UIKit branch must produce the same anchoring.

### What's deliberately out of scope

- Snapshot coverage of the SwiftUI `CodeEditor` wrapper around the gutter — pass-through, already covered by `EditorController` tests.
- Benchmarks. Fragment iteration is O(visible lines); no new perf hazard.
- Headless fuzz of wrap geometry.
- Multi-window / detached-scroll scenarios.

## Risk

- **`addFloatingSubview(_, for:)` interaction with the minimap.** `CodeEditorContainerView` already adds the minimap as a subview of the container (not the scroll view) with `zPosition = 1_000`. The floating gutter is a subview of the scroll view, so the two are siblings of different parents — no z-order conflict. Sample-app smoke testing confirms.
- **`textContainerInset.width` mutations causing TK2 reflow.** `layoutViewsAppKit` already wraps width-related text-container mutations in a `CATransaction` that disables actions and preserves `scrollView.contentView.bounds.origin`. The gutter inset change reuses that pattern.
- **`viewportRange` returning a stale range during in-flight edits.** `enumerateTextLayoutFragments(from:options: [.ensuresLayout])` guarantees a fresh layout for the iterated range. The explicit `ensureLayout(for: viewportRange)` before enumeration is belt-and-braces.
- **Fold-control mouse-down landing on a row where the fragment first-line check failed.** `resolveLineNumber(at:)` falls through to `TextKitLineNumberHelper.lineNumber(at:)`, which is independent of fragment iteration. The click resolves correctly even if the visual gutter row didn't draw a number.
- **External code reading `scrollView.verticalRulerView`.** Grep confirms no external consumers; `verticalRulerView` is set to `nil` cleanly. If a downstream test or sample fixture is found to read it, that's a test-fixture update, not a design change.
- **Snapshot drift across macOS versions.** Same risk as the prior ruler snapshots; same mitigation (single macOS version in CI, drift is a re-record event).

## Out of scope (followups)

- Per-cell `NSView` line numbers (STTextView's cell-pooling pattern). Adds accessibility-per-line surface; revisit when there's a concrete need.
- iOS dedicated selection observer for sub-second active-line refresh on pure caret moves. Tracked from the 2026-05-14 spec; still deferred.
- `GutterViewModel.visibleLineNumbers` reconciliation with the live renderer path. Two iOS paths, one of them dead-ish; document or consolidate in its own spec.
- `LineGeometryStore` access patterns when the geometry store is partially populated (very large files mid-streaming). Out of scope here; the renderer treats missing geometry as a draw-time no-op.
- Removing `getLineFragmentRect` from `TextKitLineNumberHelper` once no caller uses it. Likely still has callers; leave in place until a sweep confirms.
- A bespoke macOS-only host that drops `NSTextView` for a custom `NSView` (the STTextView model). Major rewrite, not justified by the gutter alone.
