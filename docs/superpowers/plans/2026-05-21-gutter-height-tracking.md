# Gutter Height Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the macOS `CodeEditorGutterView` track its enclosing scroll view's clip-view height so the gutter renderer's viewport-coordinate output is never clipped short — fixing the symptom where line numbers stop part-way down once the user scrolls past the viewport that was visible when the gutter was first created.

**Architecture:** Single-file change in `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`. Add a private `syncFrameToClipView()` helper, and call it from `attach(to:textView:)` plus the two existing clip-view notification observers (bounds-changed for scroll, frame-changed for resize). Also defensively enable `postsFrameChangedNotifications` on the clip view so the existing frame-changed observer actually fires on resize. Width remains externally driven by `updateMacOSGutter`; height becomes self-managed.

**Tech Stack:** Swift 6.3, AppKit, XCTest, SwiftLint (strict).

**Spec:** `docs/superpowers/specs/2026-05-21-gutter-height-tracking-design.md`

---

## File Structure

- **Modify:** `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift` — add `syncFrameToClipView()`, wire it into `attach` and the two observers, enable `postsFrameChangedNotifications` on the clip view.
- **Modify:** `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift` — add two behavioral tests under the existing `@MainActor` `XCTestCase`.

No other files change. The pre-existing `__Snapshots__/CodeEditorGutterViewSnapshotTests/testGutterRendersAfterScroll.after-scroll.png` baseline (already in the repo) acts as an additional regression guard via `CodeEditorGutterViewSnapshotTests` — if the fix accidentally regresses the rendered output, that snapshot test will catch it without us touching the snapshot suite.

---

### Task 1: Add failing behavioral tests for height tracking

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift`

These tests cover the two distinct entry points where the gutter height must be re-synced: the initial `attach` (catches stale constructor frame) and a clip-view frame change (catches window/container resize). Both must fail on `main` HEAD before any production code is touched.

- [ ] **Step 1: Add the two failing tests**

Insert these two methods inside the existing `final class CodeEditorGutterViewLifecycleTests: XCTestCase { ... }` body in `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift`, after `testApplyThemeForwardsToRenderer` and before `testTextContainerInsetRoundtripsWithGutterToggle`:

```swift
    func testAttachSyncsGutterHeightToClipView() throws {
        // Simulate the production race: gutter was created with a stale
        // (small) frame before SwiftUI gave the container its final size.
        // After `attach`, the gutter's frame.size.height must match the
        // scroll view's clip-view bounds.height — otherwise the renderer's
        // viewport-coordinate output gets clipped short of the visible code.
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        let textView = CodeEditorView(frame: .zero)
        scrollView.documentView = textView

        let staleHeight: CGFloat = 12 // pretend pre-layout viewport
        let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: staleHeight))

        gutter.attach(to: scrollView, textView: textView)

        XCTAssertEqual(
            gutter.frame.size.height,
            scrollView.contentView.bounds.height,
            accuracy: 1.0,
            "Gutter height must equal clip-view height after attach"
        )
    }

    func testGutterHeightFollowsClipViewFrameChange() throws {
        // Simulate a window/container resize after the gutter has been
        // attached. The clip view's frameDidChangeNotification must drive
        // the gutter to grow (or shrink) so the renderer can draw across
        // the full new visible viewport.
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = CodeEditorView(frame: .zero)
        scrollView.documentView = textView

        let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
        gutter.attach(to: scrollView, textView: textView)

        // Grow the scroll view; AppKit propagates this to the clip view.
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 900)
        scrollView.tile()

        // Force the frame-changed notification synchronously so the test
        // doesn't depend on run-loop draining.
        NotificationCenter.default.post(
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )

        XCTAssertEqual(
            gutter.frame.size.height,
            scrollView.contentView.bounds.height,
            accuracy: 1.0,
            "Gutter height must follow clip-view bounds.height on frame change"
        )
    }
```

- [ ] **Step 2: Run the new tests and verify they FAIL**

Run:

```bash
swift test --filter CodeEditorGutterViewLifecycleTests/testAttachSyncsGutterHeightToClipView
swift test --filter CodeEditorGutterViewLifecycleTests/testGutterHeightFollowsClipViewFrameChange
```

Expected: both tests **fail**.

- `testAttachSyncsGutterHeightToClipView` will fail with the gutter height stuck at the `staleHeight` (`12`) versus the clip view's roughly-`600`pt height.
- `testGutterHeightFollowsClipViewFrameChange` will fail with the gutter height stuck at `300` versus the clip view's roughly-`900`pt height.

If either test passes on unchanged production code, stop and re-check the setup before continuing — the bug is not what we think it is.

- [ ] **Step 3: Do NOT commit yet**

A failing test is not a checkpoint we commit. Continue to Task 2.

---

### Task 2: Implement the height sync

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`

- [ ] **Step 1: Add the `syncFrameToClipView()` private method**

Insert this method after `selectionDidChange()` (around line 126) and before `activeLineNumber(for:)` (around line 128) in `CodeEditorGutterView.swift`:

```swift
    /// Resizes the gutter so its frame height equals the enclosing scroll
    /// view's clip-view bounds height. The renderer draws line numbers in
    /// viewport coordinates and is clipped to this view's bounds, so the
    /// gutter must be exactly as tall as the visible code area or numbers
    /// past the gutter's height will be silently clipped.
    private func syncFrameToClipView() {
        guard let scrollView = attachedScrollView else { return }
        let clipHeight = scrollView.contentView.bounds.height
        if !frame.size.height.isEqual(to: clipHeight) {
            frame.size.height = clipHeight
        }
    }
```

(The `isEqual(to:)` guard matches the existing convention at `lastScrollY.isEqual(to: currentY)` in `handleScrollOrResize` and avoids redundant assignments during animated scroll.)

- [ ] **Step 2: Call `syncFrameToClipView()` after `addFloatingSubview` in `attach`**

In the `attach(to:textView:)` method (lines 40-47), insert one call right after `scrollView.addFloatingSubview(self, for: .horizontal)`. The method becomes:

```swift
    /// Attaches the gutter as a floating subview of `scrollView` and binds
    /// it to `textView`. Idempotent: re-attaching to the same scroll view
    /// is a no-op; re-attaching to a different scroll view tears down the
    /// previous attachment first.
    func attach(to scrollView: NSScrollView, textView: CodeEditorView) {
        if attachedScrollView === scrollView, self.textView === textView { return }
        if attachedScrollView != nil { detach() }
        self.textView = textView
        attachedScrollView = scrollView
        scrollView.addFloatingSubview(self, for: .horizontal)
        syncFrameToClipView()
        registerObservers(scrollView: scrollView, textView: textView)
    }
```

- [ ] **Step 3: Enable `postsFrameChangedNotifications` and call sync from both observers**

NSView's `postsFrameChangedNotifications` defaults to `false`. The existing `frameDidChangeNotification` observer is registered against `scrollView.contentView` but won't fire unless this flag is enabled — flipping it on is part of the fix.

Replace the existing `registerObservers(scrollView:textView:)` method (lines 135-177) with:

```swift
    private func registerObservers(scrollView: NSScrollView, textView: CodeEditorView) {
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.contentView.postsFrameChangedNotifications = true

        observers.append(NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self, weak scrollView] _ in
            MainActor.assumeIsolated {
                self?.syncFrameToClipView()
                self?.handleScrollOrResize(scrollView: scrollView)
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncFrameToClipView()
                self?.needsDisplay = true
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.needsDisplay = true
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.selectionDidChange()
            }
        })
    }
```

The only behavioral changes versus the original are:
1. `scrollView.contentView.postsFrameChangedNotifications = true` added below the existing bounds-notification enable.
2. `self?.syncFrameToClipView()` added inside both the bounds-changed and frame-changed observer closures.

The two other observers (`NSText.didChangeNotification`, `NSTextView.didChangeSelectionNotification`) are unchanged and reproduced verbatim because the engineer may be reading this task without looking at the original file.

- [ ] **Step 4: Run the two failing tests from Task 1 and verify they PASS**

Run:

```bash
swift test --filter CodeEditorGutterViewLifecycleTests/testAttachSyncsGutterHeightToClipView
swift test --filter CodeEditorGutterViewLifecycleTests/testGutterHeightFollowsClipViewFrameChange
```

Expected: both tests **pass**.

- [ ] **Step 5: Run the rest of the lifecycle and snapshot tests to confirm no regression**

Run:

```bash
swift test --filter CodeEditorGutterViewLifecycleTests
swift test --filter CodeEditorGutterViewSnapshotTests
swift test --filter GutterViewRendererActiveLineTests
swift test --filter GutterViewThemeTests
swift test --filter CodeEditorGutterViewTK2Tests
```

Expected: all pass. The pre-existing `testGutterRendersAfterScroll` snapshot is the primary regression guard for actual rendered output — if it fails, the visible behavior has changed and we need to look at the snapshot diff before continuing.

If the snapshot test fails but the diff is *better* (line numbers now visible where they were missing before), that is the intended outcome — re-record the snapshot in Task 3.

---

### Task 3: Re-record snapshot baseline if it captured the bug

**Files:**
- Conditionally modify: `Tests/CodeEditorPluginTests/Layout/__Snapshots__/CodeEditorGutterViewSnapshotTests/testGutterRendersAfterScroll.after-scroll.png`
- Possibly modify: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift` (only if a temporary `isRecording: true` flip is needed)

Skip this task entirely if `testGutterRendersAfterScroll` passed in Task 2 Step 5. Only execute if the snapshot test failed and the failure shows the fix is now drawing line numbers in the previously-empty region.

- [ ] **Step 1: Inspect the snapshot diff**

The snapshot-testing library writes a `.diff.png` next to the failing baseline. Open both the baseline and the diff, and confirm the new output shows line numbers across the full scrolled viewport (i.e., the fix worked) rather than misaligned numbers or missing rows (i.e., the fix regressed something else).

- [ ] **Step 2: Re-record the baseline**

Open `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift`, find the `testGutterRendersAfterScroll` test, temporarily set its `isRecording: true` (or the suite-wide equivalent — match whatever pattern the existing snapshot test uses), run:

```bash
swift test --filter CodeEditorGutterViewSnapshotTests/testGutterRendersAfterScroll
```

Then revert `isRecording` back to its original value and re-run the same command:

Expected: PASS against the freshly recorded baseline.

- [ ] **Step 3: Inspect the new baseline image**

Open `Tests/CodeEditorPluginTests/Layout/__Snapshots__/CodeEditorGutterViewSnapshotTests/testGutterRendersAfterScroll.after-scroll.png` and confirm it visually shows line numbers across the entire scrolled viewport. Do not commit a baseline whose pixels you have not eyeballed.

---

### Task 4: Quality gates and commit

**Files:** none modified — verification + commit only.

- [ ] **Step 1: Lint auto-fix + strict lint**

Run:

```bash
swiftlint --fix && swiftlint
```

Expected: clean. The project runs SwiftLint in strict mode (warnings treated as errors). The new code uses only constructs already present in the same file (`isEqual(to:)`, `[weak self]` capture inside notification closures, `MainActor.assumeIsolated`), so no new violations are expected.

- [ ] **Step 2: Full build**

Run:

```bash
swift build
```

Expected: clean build with no warnings.

- [ ] **Step 3: Full parallel test run**

Run:

```bash
swift test --parallel
```

Expected: all tests pass. This catches anything the targeted filters missed.

- [ ] **Step 4: Commit**

Stage and commit only the two changed files (and the snapshot, if Task 3 ran):

```bash
git add \
  Sources/CodeEditorView/Layout/CodeEditorGutterView.swift \
  Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift

# Add the snapshot only if Task 3 ran:
# git add Tests/CodeEditorPluginTests/Layout/__Snapshots__/CodeEditorGutterViewSnapshotTests/testGutterRendersAfterScroll.after-scroll.png

git commit -m "$(cat <<'EOF'
Sync gutter frame height to clip view on scroll/resize

CodeEditorGutterView floats over the scroll view via
addFloatingSubview(_:for:). Its frame height was set once at creation
and never re-synced when the clip view grew or shrank, so the renderer's
viewport-coordinate output got silently clipped past the original
height. Symptom: line numbers stopped part-way down once the user
scrolled past the initial viewport.

Adds a syncFrameToClipView() helper called from attach and from both
the bounds-changed and frame-changed clip-view observers. Also enables
postsFrameChangedNotifications on the clip view so the existing
frame-changed observer actually fires on resize.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Verify the commit**

Run:

```bash
git status
git log -1 --stat
```

Expected: clean working tree, one new commit containing exactly the two (or three, if the snapshot was re-recorded) modified files.

---

## Self-Review Notes

- **Spec coverage:** Every goal-section of the design spec maps to a task. Root cause → Task 2 Step 1. Wiring at three call sites → Task 2 Steps 2–3. Behavioral macOS test → Task 1. Snapshot regression guard → Task 2 Step 5 + Task 3 (conditional). Quality gates → Task 4.
- **Placeholder scan:** No "TBD", "TODO", "etc.", or "similar to". Each step shows full code or full commands.
- **Type consistency:** Single new symbol is `syncFrameToClipView()` (no parameters, returns `Void`); referenced identically in Task 2 Steps 1, 2, and 3.
- **Risk acknowledged in spec:** "AppKit fighting our manual height assignment" — Task 1's tests assert the *post-condition* via real `attach` and notification flows, so if AppKit silently overrides our height, both tests fail and we catch it before merge.
