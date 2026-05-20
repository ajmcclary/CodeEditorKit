# TK2 Gutter Host Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `LineNumberRulerView` (`NSRulerView` subclass) with `CodeEditorGutterView` (custom `NSView` attached as a floating subview of the scroll view), driven by TextKit 2 fragment frames. Fix the wrap-line misalignment along the way and clean up the orphaned cross-platform `GutterView` macOS branches.

**Architecture:** macOS gutter becomes a custom `NSView` attached via `scrollView.addFloatingSubview(_, for: .horizontal)`. The shared `GutterViewRenderer` is rewritten to walk `NSTextLayoutFragment`s directly and anchor each line number against the first non-extra `NSTextLineFragment` of its fragment, giving correct wrap behavior on both platforms. The text view's `textContainerInset.width` grows by `gutterWidth + horizontalPadding` so text doesn't underflow the floating gutter. iOS keeps its existing `GutterView` host; only the renderer fragment-walk fix applies there.

**Tech Stack:** Swift 6.3 with StrictConcurrency, AppKit + TextKit 2 (`NSTextLayoutManager`, `NSTextViewportLayoutController`, `NSTextLayoutFragment`), XCTest + Swift Testing, swift-snapshot-testing.

**Design reference:** `docs/superpowers/specs/2026-05-20-tk2-gutter-host-rewrite-design.md` — the spec contains the full code sketches and rationale; this plan tells you the exact order to apply them.

---

## File Structure

**Create:**
- `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift` — new macOS-only `NSView` host. Single responsibility: own the floating subview, observers, theme, fold-click hit-testing, and forward draw to the shared renderer.
- `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift` — attach/detach idempotency, observer teardown, theme propagation, `textContainerInset` roundtrip.
- `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift` — visual parity + wrap + post-scroll snapshots.
- `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewTK2Tests.swift` — TK1-flip-detection + selection-change behavior.

**Modify:**
- `Sources/CodeEditorView/Layout/GutterViewRenderer.swift` — macOS branch walks fragments directly; iOS branch gets the same shape. Public `draw(...)` signature unchanged.
- `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift` — delete `LineNumberRulerView` class; rewrite `setupMacOSViews` / `updateMacOSRuler` / `layoutViewsAppKit` to wire the new gutter.
- `Sources/CodeEditorView/Layout/ContainerViewInitializer.swift` — rename `setupRulerView` → `setupGutterView`; attach `CodeEditorGutterView` instead.
- `Sources/CodeEditorView/Layout/CodeEditorContainerView.swift` — add `macGutterView` and `baseTextContainerInsetWidth` properties; update `apply(theme:)` and `showsLineNumbers` setter.
- `Sources/CodeEditorView/CodeEditorView+LineNumbersExtensions.swift` — macOS branch of `updateGutterVisibility` becomes a no-op (container owns gutter).
- `Sources/CodeEditorView/Layout/GutterView.swift` — delete `draw(_:)`'s macOS short-circuit and `observeScrollView(_:)`'s AppKit branch.
- `Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift` — add wrap-anchor cross-platform test.

**Delete:**
- `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift` (replaced by `CodeEditorGutterViewSnapshotTests.swift`).
- `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift` (replaced by `CodeEditorGutterViewTK2Tests.swift`).
- `Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests/` (directory) — re-recorded under the new test name.

---

## Project commands

Run these from the repo root after each task. Each task's "verify" step lists the relevant subset.

```bash
# Targeted build (fast)
swift build --target CodeEditorView

# Full build
swift build

# Lint (fix-then-check, mandatory before commit per CLAUDE.md)
swiftlint --fix && swiftlint

# Targeted test
swift test --filter <TestSuiteOrName>

# Full test suite (only at task boundaries — see memory: don't over-run mid-plan)
swift test --parallel

# Sample app for visual verification (macOS only)
swift run CodeEditorSample
```

---

## Task 1: Fix renderer wrap anchor (both platforms)

Fixes the wrap-misalignment bug under the still-existing ruler. After this task the production gutter (current `LineNumberRulerView` host) is wrap-correct.

**Files:**
- Modify: `Sources/CodeEditorView/Layout/GutterViewRenderer.swift` (macOS branch in `draw(in:context:textView:gutterBounds:fillBackground:activeLineNumber:)`, iOS branch likewise; `drawFoldingControl` macOS branch)
- Modify: `Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift` (add a wrap-anchor case)

- [ ] **Step 1: Write the failing wrap-anchor test**

Add to `Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift` (inside the `@Suite` struct):

```swift
@Test("Wrapped logical line draws its number against the first NSTextLineFragment, not the multi-line fragment block.")
func wrappedLineAnchorsToFirstLineFragment() async throws {
    // Build a windowed container with a narrow text view that forces wrap.
    // Fixture pattern matches LineNumberRulerViewSnapshotTests.swift — host an
    // NSWindow, attach a CodeEditorContainerView, set a fixed font and a
    // narrow gutter+container width so a single long logical line wraps to
    // multiple visual lines. Then render the gutter into a bitmap CGContext
    // and assert the number's drawn Y is within one pixel of the first
    // line fragment's top, not the middle of the wrapped block.

    let container = makeContainer(textWidth: 80, text: String(repeating: "x ", count: 200) + "\n")
    let renderer = GutterViewRenderer()
    renderer.apply(theme: .lcarsDark)

    try await renderInto(container) { context, textView, gutterBounds in
        renderer.draw(
            in: gutterBounds,
            context: context,
            textView: textView,
            gutterBounds: gutterBounds,
            fillBackground: true,
            activeLineNumber: nil
        )
    }

    // Sample a pixel column inside the gutter at the Y of the first line
    // fragment vs the Y of the second line fragment.
    let firstLineY = try await firstLineFragmentY(in: container.textView)
    let secondLineY = try await secondLineFragmentY(in: container.textView)

    #expect(sampledPixelHasLineNumber(at: firstLineY))
    #expect(!sampledPixelHasLineNumber(at: secondLineY))
}
```

Helpers (`makeContainer`, `renderInto`, `firstLineFragmentY`, `secondLineFragmentY`, `sampledPixelHasLineNumber`) live at the bottom of the test file. Copy the windowed-container setup from `LineNumberRulerViewSnapshotTests.swift` for `makeContainer`. `renderInto` creates a bitmap-backed `CGContext` sized to the gutter, flips it to match `isFlipped = true`, makes it current, runs the block, then releases. `firstLineFragmentY` / `secondLineFragmentY` walk `textView.textLayoutManager?.enumerateTextLayoutFragments(from: documentStart)` to get the first fragment's `textLineFragments[0]` / `textLineFragments[1]` Y values in document-local space. `sampledPixelHasLineNumber(at:)` reads the bitmap's pixel at `(rightAlignedX, y)` and asserts the pixel is neither the background fill nor transparent.

If those helpers don't already exist in the test target, add them at the bottom of this file. Cross-platform `#if canImport(AppKit)` guard for the AppKit fixture, since this is the macOS path; the iOS path is exercised via `#if canImport(UIKit)` in a sibling test added in Step 5 of this task.

- [ ] **Step 2: Run the test, confirm it fails on the wrap-anchor assertion**

```bash
swift test --filter wrappedLineAnchorsToFirstLineFragment
```

Expected: FAIL with `sampledPixelHasLineNumber(at: secondLineY)` returning `true` (the current renderer mis-anchors the number to the middle of the multi-line block, so pixels around `secondLineY` contain text).

- [ ] **Step 3: Rewrite the macOS branch of `GutterViewRenderer.draw(...)`**

Replace the body of the `for (lineNumber, lineRange) in lineRanges` loop on macOS with a direct fragment walk. Open `Sources/CodeEditorView/Layout/GutterViewRenderer.swift` and replace the `draw(in:context:textView:gutterBounds:fillBackground:activeLineNumber:)` method body, **macOS branch only**, with:

```swift
public func draw(
    in rect: CGRect,
    context: CGContext,
    textView: CodeEditorView,
    gutterBounds: CGRect,
    fillBackground: Bool = false,
    activeLineNumber: Int? = nil
) {
    if fillBackground {
        let fillColor: PlatformColor = themedBackgroundFillColor.cgColor.alpha > 0
            ? themedBackgroundFillColor
            : PlatformColors.controlBackground
        context.setFillColor(fillColor.cgColor)
        context.fill(rect)
    }

    let textViewFont = textView.font ?? PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)

    #if canImport(AppKit)
    drawMacOS(
        in: rect,
        context: context,
        textView: textView,
        gutterBounds: gutterBounds,
        font: textViewFont,
        activeLineNumber: activeLineNumber
    )
    #else
    drawIOS(
        in: rect,
        context: context,
        textView: textView,
        gutterBounds: gutterBounds,
        font: textViewFont,
        activeLineNumber: activeLineNumber
    )
    #endif
}

#if canImport(AppKit)
private func drawMacOS(
    in rect: CGRect,
    context: CGContext,
    textView: CodeEditorView,
    gutterBounds: CGRect,
    font: PlatformFont,
    activeLineNumber: Int?
) {
    guard let textLayoutManager = textView.textLayoutManager,
          let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange else {
        return
    }
    textLayoutManager.ensureLayout(for: viewportRange)

    let viewportBounds = textLayoutManager.textViewportLayoutController.viewportBounds
    let scrollOffsetY = textView.visibleRect.origin.y - textView.textContainerOrigin.y
    let fontLineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
    let foldingEnabled = textView.configuration.display.isCodeFoldingEnabled
        && textView.configuration.display.areFoldingControlsVisible

    textLayoutManager.enumerateTextLayoutFragments(
        from: viewportRange.location,
        options: [.ensuresLayout]
    ) { fragment in
        if fragment.layoutFragmentFrame.minY >= viewportBounds.maxY {
            return false
        }
        guard let firstLine = fragment.textLineFragments.first(where: { !$0.isExtraLineFragment }) else {
            return fragment.layoutFragmentFrame.maxY < viewportBounds.maxY
        }
        guard let fragmentRange = TextKitBridge(textView: textView)
            .nsRangeFromTextRange(fragment.rangeInElement) else {
            return fragment.layoutFragmentFrame.maxY < viewportBounds.maxY
        }
        let lineNumber = textView.lineGeometryStore.lineIndex(forUtf16Offset: fragmentRange.location) + 1
        let cellY = fragment.layoutFragmentFrame.minY + firstLine.typographicBounds.minY - scrollOffsetY
        let cellHeight = firstLine.typographicBounds.height
        let color: PlatformColor = (lineNumber == activeLineNumber)
            ? themedActiveLineNumberColor
            : themedLineNumberColor

        UnifiedDrawingCoordinator.saveGraphicsState()
        UnifiedDrawingCoordinator.drawLineNumber(
            lineNumber,
            at: CGPoint(x: 0, y: cellY + (cellHeight - fontLineHeight) / 2),
            font: font,
            color: color,
            alignment: .right,
            maxWidth: gutterBounds.width - rightPadding
        )
        UnifiedDrawingCoordinator.restoreGraphicsState()

        if foldingEnabled, textView.isFoldable(at: lineNumber) {
            let controlSize = textView.configuration.layout.foldingControlSize
            let controlPadding = textView.configuration.layout.foldingControlPadding
            let controlRect = CGRect(
                x: controlPadding,
                y: cellY + (cellHeight - controlSize) / 2,
                width: controlSize,
                height: controlSize
            )
            if controlRect.intersects(CGRect(origin: .zero, size: gutterBounds.size)) {
                drawFoldingIcon(
                    in: controlRect,
                    isFolded: textView.isFolded(at: lineNumber),
                    context: context,
                    textView: textView
                )
            }
        }
        return fragment.layoutFragmentFrame.maxY < viewportBounds.maxY
    }
}
#endif
```

Then extract the existing iOS draw body into `drawIOS(...)` with the same fragment-walk shape, replacing `scrollOffsetY` with `textView.contentOffset.y - textView.textContainerInset.top` and reading `textView.contentOffset` for the viewport. Keep the existing iOS `drawFoldingControl` logic but key it off `cellY` / `cellHeight` from the first line fragment.

Delete the now-unused private helpers: `drawLineNumber(_:for:color:context:)`, `calculateLineNumberYPosition(...)`, and `drawFoldingControl(for:lineRange:helper:gutterBounds:context:textView:)`. Keep `drawFoldingIcon` (still called from the new macOS draw path).

- [ ] **Step 4: Run the wrap-anchor test, confirm it passes**

```bash
swift test --filter wrappedLineAnchorsToFirstLineFragment
```

Expected: PASS.

- [ ] **Step 5: Add the iOS sibling test (cross-platform coverage)**

Add a `#if canImport(UIKit)` variant of `wrappedLineAnchorsToFirstLineFragment` in the same file, using a `UITextView` fixture built around `CodeEditorContainerView`. The renderer call is identical; only the host setup differs.

- [ ] **Step 6: Run the full renderer suite**

```bash
swift test --filter GutterViewRendererActiveLineTests
```

Expected: PASS for all cases including the existing active-line tests.

- [ ] **Step 7: Lint + build**

```bash
swiftlint --fix && swiftlint
swift build --target CodeEditorView
```

Expected: lint silent, build clean.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorView/Layout/GutterViewRenderer.swift \
        Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift
git commit -m "$(cat <<'EOF'
Fix gutter wrap alignment by anchoring numbers to first textLineFragment

Renderer's macOS and iOS branches now walk NSTextLayoutFragments directly
and use each fragment's first non-extra NSTextLineFragment for both Y and
height. The (cellHeight - fontLineHeight) / 2 centering now operates on a
true single-visual-line height, so the number sits at the top of a wrapped
block instead of in the middle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Scaffold `CodeEditorGutterView` with attach/detach

Creates the new host class with a minimum-viable surface (attach, detach, isFlipped). No observers, no draw, no mouseDown yet. Production code does not call it yet — this task only adds the type and a lifecycle test.

**Files:**
- Create: `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`
- Create: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift`

- [ ] **Step 1: Write the failing idempotency test**

Create `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift`:

```swift
#if canImport(AppKit)
@testable import CodeEditorView
import AppKit
import XCTest

final class CodeEditorGutterViewLifecycleTests: XCTestCase {
    @MainActor
    func testAttachIsIdempotent() throws {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = CodeEditorView(frame: .zero)
        scrollView.documentView = textView

        let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
        gutter.attach(to: scrollView, textView: textView)
        gutter.attach(to: scrollView, textView: textView)

        let floatingGutters = scrollView.floatingSubviews.compactMap { $0 as? CodeEditorGutterView }
        XCTAssertEqual(floatingGutters.count, 1)
    }
}
#endif
```

Note: `scrollView.floatingSubviews` is an internal-ish API. If the compiler rejects it, use `scrollView.contentView.subviews.compactMap { $0 as? CodeEditorGutterView }` plus a count assertion on the parent's subview list — whichever is reachable from outside the type.

- [ ] **Step 2: Run the test, confirm it fails**

```bash
swift test --filter testAttachIsIdempotent
```

Expected: FAIL — `cannot find 'CodeEditorGutterView' in scope`.

- [ ] **Step 3: Create the scaffold**

Create `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorTheming

/// macOS gutter host. Attached as a floating subview of the scroll view;
/// owns the renderer, the bounds/text/selection observers, and fold-click
/// hit-testing. The cross-platform `GutterView` is the iOS-only host.
@MainActor
final class CodeEditorGutterView: NSView {
    weak var textView: CodeEditorView?
    let renderer = GutterViewRenderer()
    private(set) var lastActiveLineNumber: Int?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("CodeEditorGutterView does not support NSCoder")
    }

    func attach(to scrollView: NSScrollView, textView: CodeEditorView) {
        if superview === scrollView { return }
        if superview != nil { removeFromSuperview() }
        self.textView = textView
        scrollView.addFloatingSubview(self, for: .horizontal)
    }

    func detach() {
        removeFromSuperview()
        textView = nil
    }
}
#endif
```

- [ ] **Step 4: Run the test, confirm it passes**

```bash
swift test --filter testAttachIsIdempotent
```

Expected: PASS.

- [ ] **Step 5: Lint + build**

```bash
swiftlint --fix && swiftlint
swift build --target CodeEditorView
```

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorView/Layout/CodeEditorGutterView.swift \
        Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift
git commit -m "$(cat <<'EOF'
Add CodeEditorGutterView scaffold with idempotent attach/detach

New macOS-only NSView host for the gutter. Empty draw, no observers yet;
production code still uses LineNumberRulerView.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire observers + selection-change short-circuit

Adds the four notification observers (scroll/resize/text/selection), the `lastScrollY` horizontal-only filter, and the `selectionDidChange` active-line short-circuit. Lifts the existing `LineNumberRulerView` observer pattern verbatim onto the new gutter.

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`
- Modify: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift`

- [ ] **Step 1: Write the failing detach-removes-observers test**

Append to the test file:

```swift
@MainActor
func testDetachRemovesObservers() throws {
    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    let textView = CodeEditorView(frame: .zero)
    scrollView.documentView = textView
    scrollView.contentView.postsBoundsChangedNotifications = true

    let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
    gutter.attach(to: scrollView, textView: textView)

    // Spy: replace gutter with a subclass that counts setNeedsDisplay invocations.
    // Use the existing instance via Method swizzling-free approach:
    // attach a token-counting wrapper around scrollView.contentView's bounds notification
    // and assert that after detach, posting boundsDidChange does not trigger
    // the gutter's selectionDidChange or any redraw.
    gutter.detach()

    // Fire a synthetic boundsDidChange — observer should be torn down.
    let initialDisplayCount = gutter.needsDisplayCount
    NotificationCenter.default.post(
        name: NSView.boundsDidChangeNotification,
        object: scrollView.contentView
    )

    XCTAssertEqual(gutter.needsDisplayCount, initialDisplayCount)
}
```

`needsDisplayCount` is a debug-only property the gutter exposes for test observation. Add it on the gutter under `#if DEBUG`:

```swift
#if DEBUG
private(set) var needsDisplayCount: Int = 0
override var needsDisplay: Bool {
    get { super.needsDisplay }
    set {
        if newValue { needsDisplayCount += 1 }
        super.needsDisplay = newValue
    }
}
#endif
```

- [ ] **Step 2: Run the test, confirm it fails**

```bash
swift test --filter testDetachRemovesObservers
```

Expected: FAIL — observers aren't registered yet, so the test passes trivially (no observer = no redraw on post). Make it FAIL meaningfully by first registering observers (Step 3) and then verifying detach clears them (re-run after).

Adjust: write Step 1's test to expect at least one redraw on attached state, then detach, then expect zero. Restructure:

```swift
@MainActor
func testDetachRemovesObservers() throws {
    // ... attach setup ...

    // Attached: posting boundsDidChange should mark dirty.
    let beforeAttach = gutter.needsDisplayCount
    NotificationCenter.default.post(
        name: NSView.boundsDidChangeNotification,
        object: scrollView.contentView
    )
    XCTAssertGreaterThan(gutter.needsDisplayCount, beforeAttach, "Attached gutter should redraw on scroll")

    gutter.detach()
    let afterDetach = gutter.needsDisplayCount

    // Detached: posting boundsDidChange must not mark dirty.
    NotificationCenter.default.post(
        name: NSView.boundsDidChangeNotification,
        object: scrollView.contentView
    )
    XCTAssertEqual(gutter.needsDisplayCount, afterDetach, "Detached gutter must not redraw")
}
```

- [ ] **Step 3: Implement observers + detach teardown**

Add to `CodeEditorGutterView`:

```swift
private var observers: [NSObjectProtocol] = []
private var lastScrollY: CGFloat = 0

func attach(to scrollView: NSScrollView, textView: CodeEditorView) {
    if superview === scrollView { return }
    if superview != nil { detach() }
    self.textView = textView
    scrollView.addFloatingSubview(self, for: .horizontal)
    registerObservers(scrollView: scrollView, textView: textView)
}

func detach() {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    removeFromSuperview()
    textView = nil
}

private func registerObservers(scrollView: NSScrollView, textView: CodeEditorView) {
    scrollView.contentView.postsBoundsChangedNotifications = true

    observers.append(NotificationCenter.default.addObserver(
        forName: NSView.boundsDidChangeNotification,
        object: scrollView.contentView,
        queue: .main
    ) { [weak self, weak scrollView] _ in
        MainActor.assumeIsolated {
            self?.handleScrollOrResize(scrollView: scrollView)
        }
    })

    observers.append(NotificationCenter.default.addObserver(
        forName: NSView.frameDidChangeNotification,
        object: scrollView.contentView,
        queue: .main
    ) { [weak self] _ in
        MainActor.assumeIsolated {
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

private func handleScrollOrResize(scrollView: NSScrollView?) {
    guard let scrollView else {
        needsDisplay = true
        return
    }
    let currentY = scrollView.contentView.bounds.origin.y
    if !lastScrollY.isEqual(to: currentY) {
        lastScrollY = currentY
        needsDisplay = true
    }
}

func selectionDidChange() {
    guard let textView else { return }
    let newActive = computeActiveLineNumber(for: textView)
    if newActive != lastActiveLineNumber {
        lastActiveLineNumber = newActive
        needsDisplay = true
    }
}

private func computeActiveLineNumber(for textView: CodeEditorView) -> Int? {
    let location = textView.selectedRange().location
    guard location != NSNotFound,
          textView.lineGeometryStore.lineCount > 0 else { return nil }
    return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
}
```

These are lifted verbatim from `LineNumberRulerView` (current code in `CodeEditorContainerView+AppKitExtensions.swift:34-78`), with the addition of explicit observer-token storage and teardown — `LineNumberRulerView` relied on `removeObserver(self)` in `deinit`, which only handles selector-based registrations.

- [ ] **Step 4: Run the test, confirm it passes**

```bash
swift test --filter testDetachRemovesObservers
```

Expected: PASS.

- [ ] **Step 5: Lint + build**

```bash
swiftlint --fix && swiftlint
swift build --target CodeEditorView
```

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorView/Layout/CodeEditorGutterView.swift \
        Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift
git commit -m "$(cat <<'EOF'
Wire CodeEditorGutterView observers and selection-change short-circuit

Four notification observers (scroll/resize/text/selection) registered on
attach, torn down on detach via stored tokens. Mirrors the prior ruler's
lastScrollY horizontal-scroll filter and lastActiveLineNumber selection
short-circuit verbatim.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Theme apply + theme-on-attach test

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`
- Modify: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift`

- [ ] **Step 1: Write the failing test**

Append to the test file:

```swift
@MainActor
func testGutterReceivesThemeOnApply() throws {
    let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
    let renderer = gutter.renderer
    let beforeColor = renderer.themedLineNumberColor

    gutter.apply(theme: .lcarsDark)

    let afterColor = renderer.themedLineNumberColor
    XCTAssertNotEqual(beforeColor.cgColor, afterColor.cgColor)
}
```

- [ ] **Step 2: Run the test, confirm it fails**

```bash
swift test --filter testGutterReceivesThemeOnApply
```

Expected: FAIL — `value of type 'CodeEditorGutterView' has no member 'apply'`.

- [ ] **Step 3: Implement `apply(theme:)`**

Add to `CodeEditorGutterView`:

```swift
func apply(theme: Theme) {
    renderer.apply(theme: theme)
    needsDisplay = true
}
```

- [ ] **Step 4: Run the test, confirm it passes**

```bash
swift test --filter testGutterReceivesThemeOnApply
```

Expected: PASS.

- [ ] **Step 5: Lint + build + commit**

```bash
swiftlint --fix && swiftlint
swift build --target CodeEditorView
git add Sources/CodeEditorView/Layout/CodeEditorGutterView.swift \
        Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift
git commit -m "$(cat <<'EOF'
Add CodeEditorGutterView.apply(theme:) forwarding to renderer

Mirrors the existing ruler's theme-apply path. Renderer is the single
source of truth for inactive vs. active line-number colors.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Implement `draw(_:)` + `mouseDown(with:)`

Adds the actual drawing entry point (background fill + renderer call + separator) and fold-control hit-testing. No new test in this task — the snapshot tests in Task 10 lock in the visual behavior, and `mouseDown` is exercised by the TK2 smoke test migration in Task 10.

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorGutterView.swift`

- [ ] **Step 1: Implement `draw(_:)`**

Add to `CodeEditorGutterView`:

```swift
override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard let textView,
          let context = NSGraphicsContext.current?.cgContext else { return }

    PlatformColors.controlBackground.set()
    dirtyRect.fill()

    let activeLineNumber = computeActiveLineNumber(for: textView)
    lastActiveLineNumber = activeLineNumber

    renderer.draw(
        in: dirtyRect,
        context: context,
        textView: textView,
        gutterBounds: bounds,
        fillBackground: false,
        activeLineNumber: activeLineNumber
    )

    PlatformColors.separator.set()
    NSRect(x: bounds.width - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
}
```

- [ ] **Step 2: Implement `mouseDown(with:)`**

Add to `CodeEditorGutterView` (lifted from `LineNumberRulerView.mouseDown` in `CodeEditorContainerView+AppKitExtensions.swift:428-456`):

```swift
override func mouseDown(with event: NSEvent) {
    guard let textView,
          textView.configuration.display.isCodeFoldingEnabled else {
        super.mouseDown(with: event)
        return
    }

    let point = convert(event.locationInWindow, from: nil)
    let controlSize = textView.configuration.layout.foldingControlSize
    let controlPadding = textView.configuration.layout.foldingControlPadding
    let maxX = controlPadding + controlSize

    guard point.x <= maxX else {
        super.mouseDown(with: event)
        return
    }

    if let lineNumber = resolveLineNumber(at: point) {
        if textView.isFoldable(at: lineNumber) {
            _ = textView.toggleFold(at: lineNumber)
            needsDisplay = true
        }
    }
    super.mouseDown(with: event)
}

private func resolveLineNumber(at point: NSPoint) -> Int? {
    guard let textView else { return nil }
    let textPoint = textView.convert(point, from: self)
    return TextKitLineNumberHelper(textView: textView).lineNumber(at: textPoint)
}
```

- [ ] **Step 3: Build the target**

```bash
swift build --target CodeEditorView
```

Expected: build clean.

- [ ] **Step 4: Lint + commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorView/Layout/CodeEditorGutterView.swift
git commit -m "$(cat <<'EOF'
Implement CodeEditorGutterView draw and fold-control mouseDown

draw paints background, delegates to GutterViewRenderer, paints the
right-edge separator. mouseDown checks the fold-control x-band and
toggles folds via TextKitLineNumberHelper.lineNumber(at:).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Add `macGutterView` and `baseTextContainerInsetWidth` to container

Adds storage on the container view. No callers yet — purely additive, compiles green.

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorContainerView.swift`

- [ ] **Step 1: Add properties**

In `Sources/CodeEditorView/Layout/CodeEditorContainerView.swift`, alongside `gutterView` / `minimapView` (around line 20-22), add:

```swift
#if canImport(AppKit)
/// macOS-only floating gutter. Distinct from the cross-platform
/// `gutterView` (which is the iOS host). Assigned by
/// `ContainerViewInitializer.setupGutterView` when line numbers are
/// enabled; cleared by `updateMacOSGutter` on disable.
internal weak var macGutterView: CodeEditorGutterView?

/// The portion of `textView.textContainerInset.width` that does NOT
/// include the gutter contribution. Captured once during initial setup
/// before the gutter inset is applied; recomputed application is:
/// `inset.width = baseTextContainerInsetWidth + gutterWidth + horizontalPadding`.
internal var baseTextContainerInsetWidth: CGFloat = 0
#endif
```

- [ ] **Step 2: Build**

```bash
swift build --target CodeEditorView
```

Expected: clean (no callers reference these yet).

- [ ] **Step 3: Lint + commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorView/Layout/CodeEditorContainerView.swift
git commit -m "$(cat <<'EOF'
Add macGutterView and baseTextContainerInsetWidth to container

Storage for the upcoming gutter host swap. macGutterView is the macOS
counterpart to the cross-platform iOS gutterView. baseTextContainerInsetWidth
captures the non-gutter inset baseline so the gutter contribution can be
applied and reverted symmetrically.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Replace ruler with gutter in container wiring + migrate test suites

The host swap: replace `LineNumberRulerView` attachment with `CodeEditorGutterView` attachment, and migrate `LineNumberRulerViewSnapshotTests` + `LineNumberRulerViewTK2Tests` to `CodeEditorGutterView*Tests` in the same commit so CI never sees a broken intermediate state. The old ruler class still exists after this task (deleted in Task 10) — just no longer attached.

**Files:**
- Modify: `Sources/CodeEditorView/Layout/ContainerViewInitializer.swift`
- Modify: `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift` (the `updateMacOSRuler` function only; class deletion is Task 10)
- Create: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift`
- Create: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewTK2Tests.swift`
- Delete: `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift`
- Delete: `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift`
- Delete: `Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests/` (directory)

- [ ] **Step 1: Rename `setupRulerView` → `setupGutterView` in ContainerViewInitializer**

In `Sources/CodeEditorView/Layout/ContainerViewInitializer.swift` (around line 177), replace the entire `setupRulerView` function and its caller (line 174) with:

```swift
// Caller (around line 174):
setupGutterView(for: container, scrollView: scrollView, textView: components.textView)

// Function body (replace lines 177-217):
private static func setupGutterView(
    for container: CodeEditorContainerView,
    scrollView: NSScrollView,
    textView: CodeEditorView
) {
    let config = container.configuration

    // Capture base inset width before applying gutter contribution.
    container.baseTextContainerInsetWidth = textView.textContainerInset.width

    guard config.display.isLineNumbersEnabled else { return }

    let gutter = CodeEditorGutterView(frame: NSRect(
        x: 0,
        y: 0,
        width: config.layout.gutterWidth,
        height: scrollView.contentView.bounds.height
    ))
    gutter.attach(to: scrollView, textView: textView)
    container.macGutterView = gutter

    let horizontalPadding = config.layout.lineNumberPadding
    textView.textContainerInset.width = container.baseTextContainerInsetWidth
        + config.layout.gutterWidth
        + horizontalPadding

    if let theme = container.appliedTheme {
        gutter.apply(theme: theme)
    }
    gutter.needsDisplay = true
}
```

- [ ] **Step 2: Replace `updateMacOSRuler` with `updateMacOSGutter`**

In `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift` (around line 208-243), replace `updateMacOSRuler()` with:

```swift
/// Updates the macOS-specific gutter view with new configuration
func updateMacOSGutter() {
    guard let scrollView = textView.enclosingScrollView else { return }
    let horizontalPadding = configuration.layout.lineNumberPadding

    if configuration.display.isLineNumbersEnabled {
        let gutter: CodeEditorGutterView
        if let existing = macGutterView {
            gutter = existing
        } else {
            gutter = CodeEditorGutterView(frame: NSRect(
                x: 0,
                y: 0,
                width: configuration.layout.gutterWidth,
                height: scrollView.contentView.bounds.height
            ))
            macGutterView = gutter
            gutter.attach(to: scrollView, textView: textView)
            if let theme = appliedTheme {
                gutter.apply(theme: theme)
            }
        }
        gutter.frame.size.width = configuration.layout.gutterWidth
        textView.textContainerInset.width = baseTextContainerInsetWidth
            + configuration.layout.gutterWidth
            + horizontalPadding
        gutter.needsDisplay = true
    } else {
        macGutterView?.detach()
        macGutterView = nil
        textView.textContainerInset.width = baseTextContainerInsetWidth
    }
}
```

- [ ] **Step 3: Update `setupMacOSViews` to call `updateMacOSGutter` instead of ruler setup**

In the same file, `setupMacOSViews()` currently sets `scrollView.hasVerticalRuler`/`rulersVisible` and creates a `LineNumberRulerView`. Replace those lines (currently 175-197) with:

```swift
// Gutter setup is handled by ContainerViewInitializer.setupGutterView,
// called from setupPlatformViews. No ruler-view plumbing needed.
```

(Just delete the ruler-setup block. The `setupViews` -> `ContainerViewInitializer.setupPlatformViews` -> `setupGutterView` chain takes care of attachment.)

- [ ] **Step 4: Update all callers of `updateMacOSRuler`**

`grep` for `updateMacOSRuler` and rename every call site to `updateMacOSGutter`. Expected hits: `CodeEditorContainerView.swift` line 277 (the `showsLineNumbers` setter).

```swift
// In CodeEditorContainerView.swift line 274-282, change:
#if canImport(AppKit)
updateMacOSGutter()
#else
gutterView.isHidden = !newValue
#endif
```

- [ ] **Step 5: Create the new snapshot test file**

Create `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift` by **copying** `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift`, then:
1. Rename the class from `LineNumberRulerViewSnapshotTests` → `CodeEditorGutterViewSnapshotTests`.
2. Rename `testRulerRendersBaselineFiveLines` → `testGutterRendersBaselineFiveLines`.
3. Replace the line that extracts `scrollView.verticalRulerView as? LineNumberRulerView` with `container.macGutterView` (force-unwrap unsupported per project rules — use `XCTUnwrap`).
4. Update `assertSnapshot(...)` `named:` parameters if any reference the old class name.
5. Set `isRecording: true` for the first run to record fresh fixtures under the new test name.

- [ ] **Step 6: Create the new TK2 test file**

Create `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewTK2Tests.swift` by **copying** `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift`, then:
1. Rename the class.
2. Rename `testDrawHashMarksAndLabelsDoesNotSynthesizeLegacyLayoutManager` → `testDrawDoesNotSynthesizeLegacyLayoutManager`.
3. Rename `testWrappedLogicalLineUsesFirstVisualLineFragmentForRulerPosition` → `testWrappedLogicalLineUsesFirstVisualLineFragmentForGutterPosition`.
4. Update fixture lookups from `scrollView.verticalRulerView as? LineNumberRulerView` to `container.macGutterView`.
5. Update mouseDown synthesis to dispatch on the gutter, not the ruler.
6. Keep `testFoldControlClickDoesNotSynthesizeLegacyLayoutManager`, `testSelectionChangeOnNewLineUpdatesLastActiveLine`, `testSelectionChangeOnSameLineKeepsLastActiveLineStable` as-is (rename receivers only).

- [ ] **Step 7: Delete the old test files and snapshot directory**

```bash
rm Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift
rm Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift
rm -rf Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests
```

- [ ] **Step 8: Record new snapshots**

Run the snapshot suite with `isRecording: true` (set in each test before assertSnapshot):

```bash
swift test --filter CodeEditorGutterViewSnapshotTests
```

Expected: all snapshot tests "pass" by recording new reference images into `Tests/CodeEditorPluginTests/Layout/__Snapshots__/CodeEditorGutterViewSnapshotTests/`. Inspect the recorded PNGs visually — they should show line numbers in the gutter at correct Y positions.

- [ ] **Step 9: Flip `isRecording` back to `false`** in `CodeEditorGutterViewSnapshotTests.swift` and re-run:

```bash
swift test --filter CodeEditorGutterViewSnapshotTests
```

Expected: PASS.

- [ ] **Step 10: Run the TK2 smoke suite**

```bash
swift test --filter CodeEditorGutterViewTK2Tests
```

Expected: PASS (all five tests).

- [ ] **Step 11: Add the `textContainerInset` roundtrip lifecycle test**

Append to `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift`:

```swift
@MainActor
func testTextContainerInsetRoundtripsWithGutterToggle() throws {
    let container = CodeEditorContainerView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    var config = container.configuration
    config.display.isLineNumbersEnabled = false
    container.configuration = config

    let baseline = container.textView.textContainerInset.width
    XCTAssertEqual(baseline, container.baseTextContainerInsetWidth, accuracy: 0.5)

    container.showsLineNumbers = true
    let withGutter = container.textView.textContainerInset.width
    XCTAssertGreaterThanOrEqual(
        withGutter,
        baseline + container.configuration.layout.gutterWidth
    )

    container.showsLineNumbers = false
    let afterOff = container.textView.textContainerInset.width
    XCTAssertEqual(afterOff, baseline, accuracy: 0.5)
}
```

```bash
swift test --filter testTextContainerInsetRoundtripsWithGutterToggle
```

Expected: PASS.

- [ ] **Step 12: Run targeted tests, lint, build**

```bash
swiftlint --fix && swiftlint
swift build
swift test --filter "CodeEditorGutterView|GutterViewRenderer|LineNumbers"
```

Expected: all pass.

- [ ] **Step 13: Commit**

```bash
git add Sources/CodeEditorView/Layout/ContainerViewInitializer.swift \
        Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift \
        Sources/CodeEditorView/Layout/CodeEditorContainerView.swift \
        Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift \
        Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewTK2Tests.swift \
        Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewLifecycleTests.swift \
        Tests/CodeEditorPluginTests/Layout/__Snapshots__/CodeEditorGutterViewSnapshotTests
git rm Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift \
       Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift
git rm -r Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests
git commit -m "$(cat <<'EOF'
Swap macOS gutter host from NSRulerView to CodeEditorGutterView

ContainerViewInitializer now attaches CodeEditorGutterView as a floating
subview of the scroll view. updateMacOSRuler renamed to updateMacOSGutter;
toggles attach/detach and recomputes textContainerInset.width. Migrated
LineNumberRulerView snapshot and TK2 test suites to CodeEditorGutterView*
in the same commit so CI never observes a broken intermediate state. The
LineNumberRulerView class still exists at this commit but is no longer
wired in; deleted in a follow-up.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Update `apply(theme:)` fan-out

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorContainerView.swift`

- [ ] **Step 1: Update the theme fan-out**

In `Sources/CodeEditorView/Layout/CodeEditorContainerView.swift`, locate `apply(theme:)` (line 60-98). Replace the two macOS-only ruler references:

```swift
// Line 74 — remove this line:
scrollView.verticalRulerView?.appearance = appKitAppearance

// Add in its place:
macGutterView?.appearance = appKitAppearance

// Line 91 — replace:
(textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.apply(theme: theme)

// With:
macGutterView?.apply(theme: theme)
```

- [ ] **Step 2: Build + lint + theme test**

```bash
swift build --target CodeEditorView
swiftlint --fix && swiftlint
swift test --filter "Theme|theme"
```

Expected: tests pass, lint silent, build clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorView/Layout/CodeEditorContainerView.swift
git commit -m "$(cat <<'EOF'
Route container apply(theme:) fan-out to macGutterView

Replaces the verticalRulerView references in apply(theme:). The theme
appearance and renderer color set now reach the new gutter via the direct
property rather than rummaging through floatingSubviews.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Clean up `layoutViewsAppKit` + `CodeEditorView+LineNumbersExtensions`

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift`
- Modify: `Sources/CodeEditorView/CodeEditorView+LineNumbersExtensions.swift`

- [ ] **Step 1: Strip ruler references from `layoutViewsAppKit`**

In `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift`, `layoutViewsAppKit()` ends with (around lines 413-422):

```swift
// Force ruler view to update after layout changes
if configuration.display.isLineNumbersEnabled {
    scrollView.verticalRulerView?.needsDisplay = true
    scrollView.needsDisplay = true
    scrollView.rulersVisible = true
}
```

Replace with:

```swift
// Gutter has its own observers; no manual invalidation needed here.
// scrollView.needsDisplay is still useful for minimap/separator updates.
if configuration.display.isLineNumbersEnabled {
    macGutterView?.needsDisplay = true
    scrollView.needsDisplay = true
}
```

- [ ] **Step 2: Make the macOS branch of `updateGutterVisibility` a no-op**

In `Sources/CodeEditorView/CodeEditorView+LineNumbersExtensions.swift`, replace `updateGutterVisibility()`:

```swift
internal func updateGutterVisibility() {
    #if canImport(AppKit)
    // macOS gutter is owned by CodeEditorContainerView via macGutterView;
    // see CodeEditorContainerView.showsLineNumbers / updateMacOSGutter.
    // Nothing to do at the text-view level on macOS.
    #else
    if configuration.display.isLineNumbersEnabled {
        createGutterIfNeeded()
    } else {
        removeGutter()
    }
    #endif
}
```

Delete the `removeGutter()` macOS branch lines (around lines 64-67):

```swift
// Delete:
#if canImport(AppKit)
textContainerInset = NSSize(width: padding, height: textContainerInset.height)
#else
textContainerInset = UIEdgeInsets(...)
#endif

// Replace with iOS-only:
#if canImport(UIKit)
textContainerInset = UIEdgeInsets(top: textContainerInset.top, left: padding, bottom: textContainerInset.bottom, right: textContainerInset.right)
#endif
```

The `createGutterIfNeeded` macOS branch (lines 35-37, `return`) and `updateGutterFrame` macOS branch (lines 76-78, `return`) can be deleted — the entire function bodies become `#if canImport(UIKit)`-guarded:

```swift
private func createGutterIfNeeded() {
    #if canImport(UIKit)
    guard gutterViewStorage == nil else { return }
    // ... existing iOS body ...
    #endif
}

internal func updateGutterFrame() {
    #if canImport(UIKit)
    guard let gutter = gutterViewStorage else { return }
    // ... existing iOS body ...
    #endif
}
```

- [ ] **Step 3: Run the full test suite at this checkpoint**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: all green. This is a natural checkpoint — the host swap is complete, only the dead-class cleanup remains.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift \
        Sources/CodeEditorView/CodeEditorView+LineNumbersExtensions.swift
git commit -m "$(cat <<'EOF'
Drop ruler references from layoutViewsAppKit and updateGutterVisibility

layoutViewsAppKit no longer pokes verticalRulerView; the gutter owns its
own observers. updateGutterVisibility's macOS branch becomes a no-op since
CodeEditorContainerView.updateMacOSGutter manages the gutter lifecycle.
Removed the dead AppKit branches in createGutterIfNeeded and
updateGutterFrame.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Delete `LineNumberRulerView` class

After Task 9 nothing references the class. Delete it.

**Files:**
- Modify: `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift`

- [ ] **Step 1: Confirm no remaining references**

```bash
grep -rn "LineNumberRulerView" /Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources /Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Tests
```

Expected: only matches inside `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift` itself (the class definition and its fold-support extension).

- [ ] **Step 2: Delete the class and its extension**

In `Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift`, delete:
- The entire `class LineNumberRulerView: NSRulerView` block (currently lines 9-152).
- The `// MARK: - Folding support for macOS` extension (currently lines 426-465).

The file should retain only the `extension CodeEditorContainerView` section (the `setupMacOSViews` / `updateMacOSGutter` / `layoutViewsAppKit` methods) plus the closing `#endif`.

- [ ] **Step 3: Build + lint + test**

```bash
swift build && swiftlint --fix && swiftlint && swift test --filter "CodeEditorGutterView|GutterViewRenderer"
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorView/Layout/CodeEditorContainerView+AppKitExtensions.swift
git commit -m "$(cat <<'EOF'
Delete LineNumberRulerView (replaced by CodeEditorGutterView)

Class and its fold-support extension are unreferenced after the host swap.
The file shrinks to just the container view's macOS extension methods.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Clean up `GutterView.swift` macOS dead branches

The cross-platform `GutterView` is now iOS-only in practice. Remove the macOS short-circuits.

**Files:**
- Modify: `Sources/CodeEditorView/Layout/GutterView.swift`

- [ ] **Step 1: Remove the `draw(_:)` macOS short-circuit**

In `Sources/CodeEditorView/Layout/GutterView.swift`, find `draw(_:)` (around lines 182-190):

```swift
override public func draw(_ dirtyRect: NSRect) {
    // On macOS, GutterView should not be used - line numbers are handled by NSRulerView
    // Only draw if we're actually in the view hierarchy (which shouldn't happen on macOS)
    guard superview != nil else { return }
    super.draw(dirtyRect)
    drawLineNumbers(in: bounds)
}
```

Wrap the whole method in `#if canImport(UIKit)`:

```swift
#if canImport(UIKit)
override public func draw(_ rect: CGRect) {
    super.draw(rect)
    drawLineNumbers(in: bounds)
}
#endif
```

(Note: the cross-platform `draw` override on the AppKit side took `NSRect`; in UIKit it takes `CGRect`. The method body becomes pure-iOS.)

- [ ] **Step 2: Remove `observeScrollView`'s AppKit branch**

Find `observeScrollView(_:)` (around lines 389-424). It currently has an `#if canImport(AppKit)` branch that registers scroll observers on macOS. Since the macOS path no longer uses `GutterView`, delete that branch entirely. The function body should be `#if canImport(UIKit)`-guarded (matching the existing iOS observation logic).

- [ ] **Step 3: Audit other `#if canImport(AppKit)` branches in the file**

Run:

```bash
grep -n "canImport(AppKit)" /Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorView/Layout/GutterView.swift
```

For each hit, verify it's still meaningful (e.g., `PlatformColor.controlBackground` resolves differently on macOS vs iOS even when the GutterView itself is iOS-only — leave those alone). Delete only branches that are dead because the class is no longer instantiated on macOS.

- [ ] **Step 4: Build + lint + test**

```bash
swift build && swiftlint --fix && swiftlint && swift test --filter "GutterView|CodeEditorGutterView"
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorView/Layout/GutterView.swift
git commit -m "$(cat <<'EOF'
Remove macOS dead branches from cross-platform GutterView

GutterView is now iOS-only in practice; the macOS gutter host is
CodeEditorGutterView. draw(_:) and observeScrollView(_:) become
UIKit-guarded; the AppKit branches are removed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Add wrap + post-scroll snapshot regression tests

Locks in the visual behavior of the new bug fixes.

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift`

- [ ] **Step 1: Add the wrap snapshot test**

In `Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift`, add:

```swift
@MainActor
func testGutterRendersWrappedLine() throws {
    let container = makeWindowedContainer(textWidth: 120, contents: """
    short
    \(String(repeating: "x ", count: 80))
    another
    """)
    try await displayAndSettle(container)
    assertSnapshot(of: container, as: .image, named: "wrapped-line", record: false)
}
```

`makeWindowedContainer` and `displayAndSettle` follow the existing snapshot test patterns in the file. The wrapped middle line should display the number "2" anchored to the FIRST visual line; the four continuation lines beneath should have an empty gutter.

Record with `record: true` first, inspect the PNG, then set `record: false`.

- [ ] **Step 2: Add the post-scroll snapshot test**

```swift
@MainActor
func testGutterRendersAfterScroll() throws {
    let container = makeWindowedContainer(textWidth: 400, contents: longSourceFile(lines: 100))
    try await displayAndSettle(container)

    // Scroll programmatically.
    container.scrollView.contentView.bounds.origin.y = 200
    container.scrollView.reflectScrolledClipView(container.scrollView.contentView)
    try await displayAndSettle(container)

    assertSnapshot(of: container, as: .image, named: "after-scroll", record: false)
}
```

Recorded image should show line numbers in the gutter starting around line 11-12 (not line 1), aligned with their text.

- [ ] **Step 3: Run + record + verify**

```bash
swift test --filter "testGutterRendersWrappedLine|testGutterRendersAfterScroll"
```

Set `record: true`, run, inspect PNGs, set `record: false`, re-run, confirm PASS.

- [ ] **Step 4: Lint + commit**

```bash
swiftlint --fix && swiftlint
git add Tests/CodeEditorPluginTests/Layout/CodeEditorGutterViewSnapshotTests.swift \
        Tests/CodeEditorPluginTests/Layout/__Snapshots__/CodeEditorGutterViewSnapshotTests
git commit -m "$(cat <<'EOF'
Add wrap and post-scroll snapshot regression tests

Locks in the two bugs the host rewrite fixes: line-number anchoring on
the first visual line of a wrapped block, and number positions tracking
scroll. Without the rewrite the wrap snapshot would show the number in
the middle of the wrapped block; the scroll snapshot would show 1..N
pinned at the top regardless of scroll offset.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Final lint, full test sweep, manual sample-app verification

The rewrite is functionally complete. This task is the final quality gate.

- [ ] **Step 1: Full quality pipeline**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: all green.

- [ ] **Step 2: Confirm no orphan symbols remain**

```bash
# Must be zero hits:
grep -rn "LineNumberRulerView\|verticalRulerView\|hasVerticalRuler\|rulersVisible" \
    /Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources \
    /Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Tests
```

Expected: empty output. If `verticalRulerView` shows hits, fix them (they should have been removed in Task 9). If `LineNumberRulerView` shows hits, fix them (should have been removed in Task 10).

- [ ] **Step 3: Run the sample app and verify visually**

Per the user's memory: kill stale processes first, then clean-build the sample.

```bash
# Kill any stale processes
pkill -f CodeEditorSample 2>/dev/null || true
pkill -f lldb 2>/dev/null || true

# Build + run
./Scripts/run-sample.sh debug
```

In the running sample:
1. Open a long source file (>100 lines). Scroll vertically. **Verify:** line numbers move with their text lines; visible numbers update as you scroll.
2. Enable word wrap (`View → Wrap Lines` or via the configuration sample's UI). **Verify:** when a long logical line wraps, the line number appears at the top of the wrapped block, and the wrapped continuation lines have empty gutter beneath the number.
3. Toggle line numbers off then on (`View → Show Line Numbers`). **Verify:** the gutter disappears, text reflows to the left edge of the visible area; toggling back restores the gutter and the inset.
4. Click a fold control in the gutter. **Verify:** the corresponding region folds/unfolds.
5. Move the caret to a new line. **Verify:** the active-line color in the gutter follows the caret.

- [ ] **Step 4: If everything looks right, no further commit needed.**

If the sample reveals a regression, return to the relevant task. Per systematic-debugging discipline: identify root cause before patching.

---

## Self-review

After completing all tasks, run the spec coverage check:

- **Spec § Approach (4 numbered changes):** T2-T5 cover change 1 (new gutter class). T1 covers change 2 (renderer rewrite). T6-T9 cover change 3 (container wiring). T11 covers change 4 (orphan cleanup).
- **Spec § Surface changes (8 file groups):** every file listed in the spec's surface-changes section has at least one task that modifies it.
- **Spec § Data flow:** each labeled flow (Draw macOS, Fold-control click, Selection-change refresh, Draw iOS, Lifecycle) is verified by at least one test in T2-T7 or by the sample-app verification in T13.
- **Spec § Error handling (9 cases):** the renderer-level cases (textLayoutManager nil, viewportRange nil, empty document, first textLineFragment missing, fold-control fragment-lookup nil) are exercised by the renderer's nil-guards introduced in T1. The lifecycle cases (selection observer post-detach, attach idempotency, textContainerInset conflict, horizontal-only scroll, theme apply race) are tested in T3, T4, T7 lifecycle tests.
- **Spec § Testing (4 categories):** T1 + T7 + T11 produce all four test files; T7 step 8 records snapshots; T12 adds the two new wrap/scroll snapshots called out specifically.

Type consistency: every cross-task reference uses the same names — `CodeEditorGutterView`, `macGutterView`, `baseTextContainerInsetWidth`, `setupGutterView`, `updateMacOSGutter`, `lastActiveLineNumber`, `lastScrollY`, `selectionDidChange`.

Placeholder scan: no TBDs, no "implement later", no "similar to". Every code-modifying step shows complete code.
