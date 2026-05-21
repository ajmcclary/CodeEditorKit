# Gutter Line-Numbers Stop Part-Way After Scroll — Investigation Log

**Status:** RESOLVED on 2026-05-21.

**Date opened:** 2026-05-21

## Resolution

The root cause was the macOS host choice, not TextKit layout or
line-number drawing. `CodeEditorGutterView` used
`scrollView.addFloatingSubview(self, for: .horizontal)`, but AppKit's
floating-document-subview compositor only presented a partial strip of that
view after vertical scrolling. Runtime diagnostics already showed the
renderer visited and drew every visible line; those draw calls were being
lost after the renderer.

The fix removes the floating-subview host and restores an AppKit-owned
vertical ruler:

- `Sources/CodeEditorView/Layout/LineNumberRulerView.swift` now hosts macOS
  line numbers as an `NSRulerView`.
- `CodeEditorContainerView` installs it through
  `scrollView.verticalRulerView` and toggles `hasVerticalRuler` /
  `rulersVisible`.
- macOS text insets once again contain only internal editor padding; the
  scroll view's ruler slot owns the gutter width.
- Regression coverage now asserts the vertical-ruler host is installed and
  updates the ruler lifecycle / TK2 / snapshot tests accordingly.

The rest of this file is the historical investigation log that led to this
resolution.

## The Bug (observed)

In `CodeEditorSample` running locally, with any document larger than the visible viewport:

- **Initial state (scroll position 0):** All visible code rows show line numbers in the gutter (e.g., 1 through ~38 visible, all numbered).
- **After scrolling down past the initial viewport:** Only the top ~11 rows of the visible viewport show line numbers (e.g., 55–65 visible, 66 onward shown without numbers even though their code is visible).

The pattern is consistent: **always ~11 numbered rows at the top of the visible viewport, regardless of scroll position; the rest of the visible code area has no line numbers next to it.**

Screenshots reproducing the bug are in the conversation history (images 2–4 of session 2026-05-21).

### Important context that was initially misunderstood

- The user's screenshots show `CodeEditorSample` (this repo's own app), not an external host. The label `/Users/ajmcclary/Dev/Filesmonster` at the bottom of those screenshots is the *workspace directory* the user has opened inside `CodeEditorSample` — not a separate application. Earlier responses treated "FilesMonster" as an external consumer; that was wrong.
- The bug therefore reproduces directly in this repo's `CodeEditorSample` target. No external integration is involved.

## Code Path (verified)

```
SwiftUI CodeEditor (CodeEditorSwiftUI/CodeEditor+AppKitExtensions.swift:29)
  → makeNSView() returns CodeEditorContainerView
CodeEditorContainerView (CodeEditorView/Layout/CodeEditorContainerView.swift)
  → ContainerViewInitializer.setupGutterView creates CodeEditorGutterView (line 190)
  → CodeEditorGutterView.attach(to:textView:) — line 40 of CodeEditorGutterView.swift
    → scrollView.addFloatingSubview(self, for: .horizontal)
CodeEditorGutterView.draw(_ dirtyRect:)  (line 67)
  → calls GutterViewRenderer.draw(in: dirtyRect, context:, textView:, gutterBounds: bounds, ...)
GutterViewRenderer.draw (CodeEditorView/Layout/GutterViewRenderer.swift:81)
  → iterates NSTextLayoutFragments in viewportController.viewportRange
  → for each visible fragment, calls UnifiedDrawingCoordinator.drawLineNumber(...)
```

The macOS gutter is a layer-backed `NSView` (`wantsLayer = true`), attached as a *floating subview* of the document scroll view, owned end-to-end by `CodeEditorContainerView`. There is no separate code path for SwiftUI vs. AppKit hosts on macOS.

## Investigation Timeline

### Attempt 1 — Gutter frame height tracking (committed, did not fix)

**Hypothesis:** `CodeEditorGutterView.frame.size.height` is set once at creation (to `scrollView.contentView.bounds.height` at that moment) and is never re-synced when the clip view grows or shrinks. The renderer's viewport-coordinate output gets clipped to that stale `bounds.height`.

**Evidence the hypothesis was based on:**
- `ContainerViewInitializer.swift:190` sets height to `scrollView.contentView.bounds.height` at create time.
- `CodeEditorContainerView+AppKitExtensions.swift:55` only ever mutates `frame.size.width`; height is never touched again.
- The two observers in `CodeEditorGutterView.registerObservers` for `boundsDidChangeNotification` and `frameDidChangeNotification` only set `needsDisplay = true`; they did not adjust frame height.
- `postsFrameChangedNotifications` was not enabled on the clip view (it defaults to `false`), so the existing frame-changed observer was a no-op anyway.

**What was changed (committed in `4b9ab5f2`):**
1. Added `private func syncFrameToClipView()` to `CodeEditorGutterView` that reassigns `frame.size.height` to `attachedScrollView.contentView.bounds.height` if different.
2. Called `syncFrameToClipView()` from `attach(to:textView:)` immediately after `addFloatingSubview`.
3. Called `syncFrameToClipView()` from both the bounds-changed and frame-changed clip-view observers.
4. Set `scrollView.contentView.postsFrameChangedNotifications = true` so the frame-changed observer actually fires.
5. Added two XCTests in `CodeEditorGutterViewLifecycleTests.swift`:
   - `testAttachSyncsGutterHeightToClipView` — verifies that a gutter created with a stale 12pt height is resized to the clip view's full height on `attach`.
   - `testGutterHeightFollowsClipViewFrameChange` — verifies that growing the scroll view triggers a height sync via the `frameDidChangeNotification` observer.

**Result:** Both XCTests pass. **The user-visible bug is unchanged.** Side-by-side screenshots before and after the commit are identical.

**Why the tests passed but the user-visible bug didn't move:** The XCTests verified the *frame.size.height postcondition*, but they did not exercise the actual rendering pipeline at scroll time. Looking at the runtime diagnostic data (below), `gutterH=776.0` was already correct before this commit — the gutter was already the full viewport height in practice; the frame.size.height mutation was real but invisible because that wasn't the actual cause of the symptom. **This is a process-failure lesson, not a code lesson:** the CLAUDE.md rule "for UI changes, start the dev server and use the feature in a browser before reporting the task as complete" was ignored.

This commit is still in tree. It is a real-but-invisible improvement; it should not be reverted thoughtlessly because it does prevent the gutter from being clipped if the clip view's bounds.height ever does diverge in some real scenario (e.g., the gutter being attached before SwiftUI has sized the host). But it is not the fix for the reported symptom.

### Diagnostic instrumentation (uncommitted, since removed)

After Attempt 1 failed visually, I added temporary `os_log` instrumentation to `GutterViewRenderer.draw` to capture the actual state at draw time:

```swift
defer {
    diagLog.info("draw: gutterH=… dirty=… visTop=… visBot=… iterRange=[…..<…] fragsYielded=… numsDrawn=… firstFragMinY=… lastFragMaxY=…")
}
```

The user ran the rebuilt Sample, opened the repo's `Package.swift` (464 lines), scrolled past line 50, and `log stream --subsystem com.codeeditor.plugin --category GutterDiag` captured the data. **The data is the most important artifact in this investigation — preserve it.**

#### Diagnostic data (representative draw calls)

```
# Initial draw (top of file)
gutterH=776.0  dirty=(-360.5, -76.0, 1415.0, 880.0)
visTop=0.0     visBot=776.0    iterRange=[0..<1563]
fragsYielded=39  numsDrawn=39
firstFragMinY=0.0   lastFragMaxY=795.6

# Mid-scroll
gutterH=776.0  dirty=(-360.5, 0.0, 1415.0, 1054.0)
visTop=250.0   visBot=1026.0   iterRange=[636..<2057]
fragsYielded=39  numsDrawn=39
firstFragMinY=244.8  lastFragMaxY=1040.4

# Most-scrolled (steady state) — this is the buggy frame
gutterH=776.0  dirty=(-360.5, 494.5, 1415.0, 880.0)
visTop=570.5   visBot=1346.5   iterRange=[1143..<2547]
fragsYielded=38  numsDrawn=38
firstFragMinY=550.8   lastFragMaxY=1346.4
```

#### What the data proves and disproves

| Claim | Evidence | Status |
|---|---|---|
| Gutter is the full viewport height | `gutterH=776.0` on every draw | **Confirmed.** Attempt 1's height-tracking is in effect, not the bug. |
| Renderer iterates the full visible range | `firstFragMinY≈visTop`, `lastFragMaxY≈visBot`, `fragsYielded` ≈ 35–40 across the 776pt viewport | **Confirmed.** The `viewportController.viewportRange ?? documentRange` path covers the full visible area. |
| `enumerateTextLayoutFragments` stops early | `fragsYielded` ≈ number of visible rows; `numsDrawn` == `fragsYielded` | **Disproved.** The iteration is not stopping at line 65; it iterates all visible rows. |
| `UnifiedDrawingCoordinator.drawLineNumber` is being called for every visible row | `numsDrawn=37` (or 38, 39) per buggy draw | **Confirmed.** ~37 draw calls happen, but the user reports ~11 visible. So ~26 draw calls produce no visible pixels. |
| `dirtyRect` is partial | `dirty=(-360.5, 494.5, 1415.0, 880.0)`; intersected with `bounds=(0, 0, 50, 776)` in the gutter's flipped coords gives an effective clip strip of roughly y=[494.5, 776], height ≈ 281pt, about 11–14 line-heights | **Strongly suggested.** Pixel count matches "~11 numbered rows visible." |
| Direction of clipping | In flipped coords (`isFlipped = true`), y=0 is top; dirtyRect's effective y-range [494.5..776] is the bottom half of the gutter, *but the rendered numbers actually visible are at the top of the viewport (lines 55–65), not the bottom* | **Anomaly.** This contradicts the simple "AppKit clips to dirtyRect" theory. Either the dirtyRect is not in flipped-view coords, or another mechanism is at work. See "Anomaly" below. |

### Attempt 2 — `wantsDefaultClipping = false` (uncommitted, did not fix)

**Hypothesis:** `NSView.wantsDefaultClipping` defaults to `true`, which causes AppKit to set the CGContext's clip to the dirtyRect ∩ bounds before calling `draw(_:)`. With the partial dirtyRect observed in the diag, this would discard ~26 of the ~37 line-number draw calls.

**Change made (still in the working tree as an uncommitted edit on `CodeEditorGutterView.swift`):**

```swift
/// The renderer walks every layout fragment in the visible viewport and
/// draws each line number at its own viewport-relative Y. AppKit's
/// default clipping confines drawing to `dirtyRect`, which for a
/// floating subview during scroll is often only a partial strip of the
/// view's bounds — and any renderer output that lands outside the
/// strip gets discarded, producing the "line numbers stop part-way down
/// after scroll" bug. Opting out makes the renderer's full output
/// commit to the layer on every draw.
override var wantsDefaultClipping: Bool { false }
```

**Result:** **User reports: "It's still not working."** No visible change. Attempt 2 also did not fix the bug.

## The Anomaly That Is Now Blocking Progress

The diagnostic data shows the renderer producing 37–38 draw calls per scrolled frame, but the user sees only ~11 line numbers. The simplest theory ("AppKit's default clip is masking the rest of the draw calls") was tested and failed. So at least one of the following is true:

1. **`wantsDefaultClipping = false` isn't doing what its docs say** for layer-backed floating subviews. The override may be ignored because the gutter is layer-backed (`wantsLayer = true`) and AppKit composites via the layer, not the CGContext clip. The CALayer itself may be `masksToBounds = true` with a clip rect that is *not* the view's bounds.
2. **The CGContext we draw into isn't the visible compositing surface.** For a floating subview, AppKit may be drawing into a snapshot bitmap that has different bounds. Our draw calls outside the snapshot's bounds become no-ops at presentation time.
3. **The pixels are written but immediately re-clipped by an ancestor layer.** `addFloatingSubview` stashes the view in an AppKit-private internal container; that container's layer may apply a clip we don't control.
4. **The cellY math is right for some draws and wrong for others.** Less likely given the consistency of `firstFragMinY≈visTop` and `lastFragMaxY≈visBot`, but not ruled out — we have not logged the actual `cellY` values being passed to `drawLineNumber`.

### Direction-of-clipping anomaly

The dirtyRect's y-range `[494.5, 776]` in the gutter's flipped coordinate system maps to the *bottom* half of the gutter. The renderer draws line numbers using cellY computed in flipped coords (cellY=0 at viewport top, cellY≈775 at viewport bottom). So under "AppKit clips to flipped dirtyRect," the *bottom* line numbers (lines 80–93, near `cellY≈600..775`) should be visible.

But the user actually sees the *top* line numbers (lines 55–65, at `cellY≈0..220`). This is the opposite. Possible explanations:

- The dirtyRect's coordinate frame is the **layer**, not the **flipped view**. Layers are unflipped by default. If dirtyRect y is unflipped (y=0 at bottom, y=776 at top of the layer-backed view), then `[494.5, 776]` is the upper half — matching what's visible.
- Or there's a coordinate transform we're not accounting for somewhere in `addFloatingSubview`'s compositing.

Either way, the anomaly points at a layer/compositing issue rather than a CGContext clip issue, which is consistent with `wantsDefaultClipping = false` not helping.

## Hypotheses Now on the Table (untested)

In rough order of plausibility:

1. **Layer masking.** The gutter's backing `CALayer.masksToBounds` is `true`, and the layer's bounds are something other than the view's bounds (possibly the layer for `addFloatingSubview`'s private container). Test: log `self.layer?.bounds` and `self.layer?.masksToBounds` from `draw(_:)`. Fix would likely be `layer?.masksToBounds = false` or restructuring how the gutter is added.

2. **Floating-subview compositing snapshot.** `addFloatingSubview(_:for:)` may render the floating view into a snapshot the first time it's drawn, and on subsequent scrolls only invalidate part of the snapshot. The fix would be to bypass `addFloatingSubview` and place the gutter as a normal subview of `CodeEditorContainerView` (not the scroll view), then manage its frame manually to track the clip view's visible rect.

3. **Wrong `superview` for floating-subview math.** When AppKit composites floating subviews, the dirty rect coordinates may be in the AppKit-private container's coord system. If our cellY values are correct in *view* coords but the compositing happens in *container* coords with an offset, draws land outside the visible region. Test: log `self.convert(bounds, to: nil)` (window coords) and `window.convertToScreen(_:)`.

4. **`isFlipped` ignored by the compositing path.** Despite `isFlipped = true`, the layer's contents may still be composited in unflipped coords, so the renderer's flipped-y cellY values are actually drawing upside-down or in mirror positions. Test: render with cellY explicitly transformed (or test with `isFlipped = false` to compare).

5. **Wrong attach axis.** `addFloatingSubview(self, for: .horizontal)` means the floating subview is anchored *against horizontal* scrolling. The vertical-scroll behavior of floating subviews-for-horizontal-axis is not what we think it is. The Apple-recommended pattern for a gutter would more naturally be a ruler view (`NSScrollView.verticalRulerView`) or a sibling view of the scroll view that observes its bounds-changed notifications.

## Hypotheses Ruled Out

- **"Gutter frame height is stale and clipping the output"** — disproved by diag (`gutterH=776.0` is correct on every draw).
- **"`viewportRange` is too small and the renderer's iteration stops early"** — disproved by diag (`fragsYielded=35–39` across the full visible viewport on every draw).
- **"`enumerateTextLayoutFragments` never reaches fragments past line 65 because layout hasn't been ensured"** — disproved by diag (`lastFragMaxY` reaches the actual visible bottom on every draw).
- **"AppKit's default CGContext clip is the only thing masking the output"** — disproved by Attempt 2 (overriding `wantsDefaultClipping` to `false` produced no visible change).

## State of the Working Tree

Two commits on `main` ahead of `origin/main`, both un-pushed:

- `300acafe` — Add gutter-height-tracking design spec
- `4b9ab5f2` — Sync gutter frame height to clip view on scroll/resize

One uncommitted change still in the working tree:

- `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift` — Attempt 2's `override var wantsDefaultClipping: Bool { false }` is still present. It has no effect on the bug but is also not harmful in isolation. Decide whether to revert before the next session.

The diagnostic instrumentation in `GutterViewRenderer.swift` has been removed. The renderer is back to its pre-investigation state.

## What NOT To Try Again

These have already been tried and disproved by either the diag data or direct user-visible test:

- Adjusting `frame.size.height` of `CodeEditorGutterView` or hooking more lifecycle events to keep it synced. The height is already correct in the buggy frames.
- Forcing `viewportController.layoutViewport()` at the top of `GutterViewRenderer.draw`. The viewport range is already covering the right span.
- Replacing `viewportController.viewportRange ?? documentRange` with just `documentRange`. The iteration range is already correct.
- Calling `setNeedsDisplay(bounds)` instead of `needsDisplay = true` in the scroll observer (Attempt 2 already invalidates the full bounds via `wantsDefaultClipping = false` and the symptom persists, so partial-invalidation at the *view* level is not the cause).
- Adding more `os_log` instrumentation at the same layer of the renderer. We have enough data from that layer; the next bit of data must come from below (CALayer, AppKit compositing) or laterally (re-checking the `cellY` values actually used and the bitmap that ends up on screen).

## Suggested Next Steps (for the next session)

In order:

1. **Capture layer state at draw time.** Add one-shot logging of `self.layer?.bounds`, `self.layer?.masksToBounds`, `self.layer?.superlayer?.bounds`, `self.layer?.superlayer?.masksToBounds`, and `self.convert(self.bounds, to: nil)` from inside `CodeEditorGutterView.draw(_:)` for the first 3 draws after a scroll. Compare against the dirtyRect data already captured. The goal is to find the layer or transform that is *actually* masking the output.

2. **Bypass `addFloatingSubview` entirely as a diagnostic.** Add a feature-flagged code path that places the gutter as a normal subview of `CodeEditorContainerView` (peer of the scroll view, not floating), with the frame manually pinned to the clip view's visible rect on every bounds-changed notification. If the bug disappears with the floating subview replaced, the root cause is in `addFloatingSubview`'s compositing model. If it persists, the root cause is somewhere in the renderer's cellY math or the layer/compositing layer.

3. **Take a screenshot of the *failing draw frame's CGContext*.** AppKit will let you write the current CGContext's contents to a CGImage. Compare the bitmap with what's on screen — if they match (bitmap also shows only ~11 numbers), the clipping happens at or before the CGContext. If the bitmap shows all ~37 numbers but the screen shows only 11, the clipping is in the compositing path (layer, snapshot, etc.).

4. **Reconsider whether `addFloatingSubview` is the right tool.** The fact that the diagnostic data shows the renderer doing the right thing while the user sees something wrong, combined with two failed surface-level fixes, suggests an architectural mismatch. The Apple-blessed primitive for a gutter is `NSScrollView.verticalRulerView` / `NSRulerView`. The repo previously used `NSRulerView` (commit `dbec997a` "Swap macOS gutter host from NSRulerView to CodeEditorGutterView"); reverting that decision is on the table as a last resort.

## Lessons for Process (write to memory)

Two failures that need to be reflected in saved feedback:

- **"My XCTest passed" is not "the bug is fixed."** Both attempted fixes passed their XCTests but the user-visible symptom did not change. The CLAUDE.md rule about running the actual UI before claiming done was violated on Attempt 1. For UI bugs, no fix is complete until verified in the running app.
- **Three rounds of meticulous specs/plans without empirical evidence wasted time.** The brainstorm → spec → plan → execute pipeline produces a confident-looking artifact that masks an unverified hypothesis. For a UI bug whose root cause is unknown, the very first move should be diagnostic instrumentation in the running app — not a design doc.

## Diagnostic Reproduction Recipe (for next session)

```bash
# 1. Kill any stale processes
pkill -f CodeEditorSample
pkill -f "swift run CodeEditorSample"
pkill -f "log stream"

# 2. Add new diagnostic instrumentation (layer state, cellY values, etc.)

# 3. Build only the sample target (faster than full build)
swift build --target CodeEditorSample

# 4. Stream logs and launch the app in parallel (use absolute path for /usr/bin/log
#    because zsh has a 'log' builtin)
/usr/bin/log stream --level info \
  --predicate 'subsystem == "com.codeeditor.plugin" && category == "GutterDiag"' \
  --style compact > /tmp/gutter-diag.log 2>&1 &
swift run CodeEditorSample > /tmp/sample-stdout.log 2>&1 &

# 5. Open the repo's Package.swift in the running sample (464 lines, long enough
#    to repro). Scroll past line 50. Reproduce the buggy state.

# 6. Read the logs
cat /tmp/gutter-diag.log

# 7. When done, clean up
pkill -f CodeEditorSample
pkill -f "log stream"
```
