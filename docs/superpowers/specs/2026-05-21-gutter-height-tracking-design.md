# Gutter Height Tracking — Design

**Status:** Approved
**Date:** 2026-05-21
**Bug class:** Layout / lifecycle
**Surface:** macOS (`CodeEditorGutterView`)

## Problem

On macOS, line numbers render correctly for the lines visible at the top of the editor but stop partway down the visible area once the user scrolls past the initial viewport. The remaining visible code rows have no line numbers next to them, even though they fall within the on-screen scroll viewport.

Reproduced visually in a downstream host (FilesMonster), but the defect is in `CodeEditorPlugin` — the host is incidental.

## Root cause

`Sources/CodeEditorView/Layout/CodeEditorGutterView.swift` floats the gutter over the scroll view via `addFloatingSubview(self, for: .horizontal)`. Its frame height is set **once at creation**:

- `Sources/CodeEditorView/Layout/ContainerViewInitializer.swift:190-195` — initial setup.
- `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift:55-60` — toggle path in `updateMacOSGutter`.

After creation, `updateMacOSGutter` only ever resets `gutter.frame.size.width`; `frame.size.height` is never touched. The two relevant observers in `CodeEditorGutterView.registerObservers` (`boundsDidChangeNotification` on the clip view for scroll, `frameDidChangeNotification` on the clip view for resize) both just set `needsDisplay = true`.

`GutterViewRenderer.draw` draws each line at `cellY = fragmentMinY + firstLine.typographicBounds.minY - scrollOffsetY` — i.e., in **viewport** coordinates. That math is correct, but the output is clipped to the gutter view's own `bounds`. If the gutter was created when the clip view was small (during initial SwiftUI layout, before the SwiftUI host gave the container its final size — or after a later resize that was not propagated), the renderer's correctly-positioned output is silently clipped to that stale strip, no matter how tall the actual visible viewport becomes.

This presents as "line numbers stop part-way down" once you scroll into a region the original stale-height gutter no longer covers.

## Goal

The gutter's `frame.size.height` must equal the enclosing scroll view's `contentView.bounds.height` at all times, so the renderer's viewport-coordinate drawing is never clipped short of the actual visible code area.

## Non-goals

- Reworking the choice of `addFloatingSubview(_:for:)` or the gutter's parent-view strategy (Approach C in brainstorm — out of scope).
- Switching to AppKit autoresizing masks (Approach B — explicitly rejected because behavior under `addFloatingSubview`'s internal container is not documented enough to rely on).
- Touching the iOS `GutterView` path. iOS already uses `PlatformAutoresizing.flexibleHeight` and is not reported broken.
- Changing how `updateMacOSGutter` drives `frame.size.width`. Width remains configuration-driven; only height becomes scroll-view-driven.

## Design

### Component

A new private method on `CodeEditorGutterView`:

```swift
private func syncFrameToClipView() {
    guard let scrollView = attachedScrollView else { return }
    let clipHeight = scrollView.contentView.bounds.height
    if !frame.size.height.isEqual(to: clipHeight) {
        frame.size.height = clipHeight
    }
}
```

The `isEqual(to:)` guard avoids redundant frame assignments during animated scrolls (when the bounds origin changes every frame but the height does not).

### Wiring

Three call sites, all in `CodeEditorGutterView`:

1. **`attach(to:textView:)`** — call `syncFrameToClipView()` immediately after `addFloatingSubview`. Covers the case where the initial constructor `frame.height` (read from `contentView.bounds.height` before SwiftUI had given the container its final size) was 0 or stale.

2. **`registerObservers` — `boundsDidChangeNotification`** — call `syncFrameToClipView()` from inside the existing `handleScrollOrResize` closure, before / alongside the existing `needsDisplay = true`. Pure scrolls won't change the height, so this is a no-op in the common case; but elastic scroll bounces and live-resize edges can mutate bounds.height, and the cost of a guarded assignment is negligible.

3. **`registerObservers` — `frameDidChangeNotification`** — call `syncFrameToClipView()` from inside the existing closure, before `needsDisplay = true`. This is the primary path: the clip view's frame changes when the window or container resizes, and that is when the gutter must grow or shrink to follow.

No other files change. `updateMacOSGutter` keeps owning width; `CodeEditorGutterView` now owns height.

### Data flow

Window or container resize:

```
NSScrollView relayout
  → clipView frame changes
  → frameDidChangeNotification
  → gutter.syncFrameToClipView() + needsDisplay
  → renderer redraws across full visible viewport
```

User scrolls vertically:

```
clipView bounds origin changes
  → boundsDidChangeNotification
  → gutter.syncFrameToClipView() (no-op for pure scroll) + needsDisplay
  → renderer recomputes scrollOffsetY and re-emits line numbers in viewport coords
```

### Origin handling

We do **not** touch `frame.origin`. AppKit's `addFloatingSubview(_:for:)` pinning algorithm owns positioning of floating subviews; manually setting `origin` would fight it. The bug is solely about height; height is the only thing this design changes.

### Error handling

None required. `attachedScrollView` is already a weak reference and the early `guard` returns when it has been torn down. `frame.size.height` assignment cannot fail. The `isEqual(to:)` guard prevents work amplification during animated scroll.

## Testing

1. **Behavioral test — macOS** (XCTest, in the existing CodeEditorView/CodeEditorPlugin test target that already exercises `CodeEditorContainerView`):

   - Build a `CodeEditorContainerView` with `display.isLineNumbersEnabled = true` and a multi-hundred-line document.
   - Force layout at a small scroll-view height (~12 line-heights), then resize to a larger height (~40 line-heights).
   - After each resize, assert `container.macGutterView?.frame.size.height ≈ scrollView.contentView.bounds.height` (within a `1pt` tolerance to absorb floating-point rounding).
   - Programmatically scroll to mid-document and assert the renderer emits line-number draw calls for every visible row through the new viewport bottom. (Use the renderer's draw path with a captured `CGContext`, or count `UnifiedDrawingCoordinator.drawLineNumber` invocations via a test seam if one exists.)

2. **Snapshot test (optional but recommended)**: render the editor scrolled to mid-document on a tall window, compare against a recorded baseline showing all visible rows with line numbers. `SnapshotTesting` is already wired up across the test targets.

If a test seam for counting draw calls does not exist, the snapshot test is sufficient: an image with line numbers visible for every code row in the viewport is the strongest regression guard.

## Risks and mitigations

- **AppKit fighting our manual height assignment.** `addFloatingSubview` puts the view in an internal container; if AppKit overrides our height on the next layout pass, the bug returns. Mitigation: the test above asserts the post-condition after a resize cycle, so the regression is caught by CI rather than slipping back to users.
- **Animated-scroll churn.** The `isEqual(to:)` short-circuit on height changes keeps the scroll-path assignment essentially free. No measurable performance impact expected.
- **Initial attach race.** If `attach` runs before the scroll view has any size at all, `contentView.bounds.height` is 0 and the initial sync sets the gutter to 0pt. The `frameDidChangeNotification` then fires once the scroll view gets its real size, and the gutter snaps to the right height. Behavior is correct.

## Out of scope

- Investigating whether the initial 0-height period causes a one-frame flash on cold start. If user testing surfaces it, address separately.
- Refactoring `updateMacOSGutter`'s width-only frame mutation. It remains correct under this design.
