# TK2 Gutter Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the macOS `LineNumberRulerView` from reading `NSTextView.layoutManager` (which triggers AppKit's TK1 compatibility shim and flips the editor off TK2 at first paint). Route the ruler's draw and hit-test paths through the existing TK2-native `GutterViewRenderer` + `TextKitLineNumberHelper`. While here, wire the renderer's already-themed active-line color through both platforms.

**Architecture:** `LineNumberRulerView` remains an `NSRulerView` subclass (so `scrollView.verticalRulerView` integration is preserved), but its `drawHashMarksAndLabels(in:)` becomes a thin adapter that calls `GutterViewRenderer.draw(...)`. The renderer grows a defaulted `activeLineNumber: Int?` parameter that selects per-line color. Hit-testing for fold-control clicks uses `TextKitLineNumberHelper`. A `NSTextView.didChangeSelectionNotification` observer on macOS refreshes the gutter when the caret crosses lines.

**Tech Stack:** Swift 6.3 (`StrictConcurrency`), SwiftPM, AppKit + UIKit, TextKit 2 (`NSTextLayoutManager`), `swift-snapshot-testing` (existing fork), `swift-custom-dump`. Tests use both XCTest and Swift Testing (`@Suite` / `@Test`).

**Spec:** `docs/superpowers/specs/2026-05-14-tk2-gutter-rewrite-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift` | Modify | Add `activeLineNumber: Int?` parameter to `draw(...)`; route active vs. inactive color in `drawLineNumber`; remove vestigial `textColor` stored property. |
| `Sources/CodeEditorPlugin/Layout/GutterView.swift` | Modify | Compute `activeLineNumber` from `UITextView.selectedTextRange` and pass through to `renderer.draw(...)`. |
| `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift` | Modify | Rewrite `LineNumberRulerView` internals: TK2 draw + TK2 hit-test + `selectionDidChange()` + `apply(theme:)`. Delete dead TK1 helpers (`getLineRanges`, inline fold-control drawing, private `lineNumber(at:)`). Add selection observer in `setupMacOSViews`. |
| `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift` | Modify | Extend `apply(theme:)` fan-out to forward to the macOS ruler's renderer. |
| `Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift` | Create | Swift Testing suite for the new `activeLineNumber` parameter. Pure pixel-sampling test. |
| `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift` | Create | XCTest suite: TK2-primary smoke (`_layoutManager` ivar stays nil after draw), fold-click TK2 routing, selection-change redraw. macOS-only via `#if canImport(AppKit)`. |
| `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift` | Create | XCTest suite for visual parity — baseline, folded line, active line, empty doc, long line numbers. macOS-only. |
| `Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests/*.png` | Create (record) | Snapshot baselines committed alongside the test. |
| `Package.swift` | Modify | Add `"Layout/__Snapshots__"` to `CodeEditorPluginTests` excludes. |
| `NEXT.md` | Modify | Mark § B.5 as done. |

---

## Task 1: Add `activeLineNumber` parameter to `GutterViewRenderer`

**Files:**
- Create: `Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift`

- [ ] **Step 1.1: Write the failing Swift Testing suite for the active-line color**

```swift
// Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift
import CoreGraphics
import Testing
@testable import CodeEditorPlugin

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("GutterViewRenderer active line color")
@MainActor
struct GutterViewRendererActiveLineTests {

    /// Renders the gutter into a bitmap and reports the dominant color at each
    /// drawn line's vertical position. Returns one color per visible line in
    /// document order.
    private func dominantLineColors(
        renderer: GutterViewRenderer,
        textView: CodeEditorView,
        activeLineNumber: Int?,
        width: CGFloat = 50,
        height: CGFloat = 200
    ) -> [PlatformColor] {
        let size = CGSize(width: width, height: height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = Int(size.width) * 4
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }
        let rect = CGRect(origin: .zero, size: size)
        context.setFillColor(PlatformColors.windowBackground.cgColor)
        context.fill(rect)
        renderer.draw(
            in: rect,
            context: context,
            textView: textView,
            gutterBounds: rect,
            fillBackground: false,
            activeLineNumber: activeLineNumber
        )
        // Sample one pixel per line at a stable x-offset. The exact y-positions
        // come from the geometry store the renderer used; for a 3-line stub the
        // sample points are easy to compute.
        return GutterViewRendererActiveLineTests.sampleColors(context: context, size: size)
    }

    private static func sampleColors(context: CGContext, size: CGSize) -> [PlatformColor] {
        // Implementation: scan rows, pick the most-saturated non-background pixel
        // per visible line band. See Task 1, Step 1.2 for the helper body.
        return GutterPixelSampler(context: context, size: size).colorsForVisibleLines()
    }

    @Test("Active line is rendered in the active color; others in inactive color.")
    func activeLineUsesActiveColor() async throws {
        let textView = CodeEditorView.fixture(threeLines: "alpha\nbeta\ngamma")
        let renderer = GutterViewRenderer()
        let theme = Theme.fixtureWithDistinctActiveLineColor
        renderer.apply(theme: theme)

        // Activate line 2.
        let colors = dominantLineColors(renderer: renderer, textView: textView, activeLineNumber: 2)

        #expect(colors.count == 3)
        #expect(colors[0].isApproximately(renderer.themedLineNumberColor))
        #expect(colors[1].isApproximately(renderer.themedActiveLineNumberColor))
        #expect(colors[2].isApproximately(renderer.themedLineNumberColor))
    }

    @Test("Nil activeLineNumber renders every line in the inactive color.")
    func nilActiveRendersAllInactive() async throws {
        let textView = CodeEditorView.fixture(threeLines: "alpha\nbeta\ngamma")
        let renderer = GutterViewRenderer()
        let theme = Theme.fixtureWithDistinctActiveLineColor
        renderer.apply(theme: theme)

        let colors = dominantLineColors(renderer: renderer, textView: textView, activeLineNumber: nil)

        #expect(colors.count == 3)
        for color in colors {
            #expect(color.isApproximately(renderer.themedLineNumberColor))
        }
    }
}
```

- [ ] **Step 1.2: Add the pixel-sampling helper and test fixtures**

In the same test file, append at the bottom:

```swift
// MARK: - Helpers

/// Samples one color per visible-line vertical band. Picks the most-saturated
/// (non-background) pixel in each band.
private struct GutterPixelSampler {
    let context: CGContext
    let size: CGSize

    func colorsForVisibleLines() -> [PlatformColor] {
        guard let data = context.data else { return [] }
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let buffer = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)

        // We render 3-line fixtures, so chunk the image into 3 equal vertical bands.
        let bandCount = 3
        let bandHeight = height / bandCount

        var results: [PlatformColor] = []
        for band in 0..<bandCount {
            let startY = band * bandHeight
            let endY = startY + bandHeight
            var best: (color: PlatformColor, saturation: CGFloat)?
            for y in startY..<endY {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    let r = CGFloat(buffer[offset]) / 255
                    let g = CGFloat(buffer[offset + 1]) / 255
                    let b = CGFloat(buffer[offset + 2]) / 255
                    let saturation = saturationOf(r: r, g: g, b: b)
                    let color = PlatformColor(red: r, green: g, blue: b, alpha: 1)
                    if best == nil || saturation > best!.saturation {
                        best = (color, saturation)
                    }
                }
            }
            if let best { results.append(best.color) }
        }
        return results
    }

    private func saturationOf(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }
}

extension CodeEditorView {
    /// Test-only fixture: returns a CodeEditorView with three lines of text,
    /// laid out in a 200×200 frame, with a populated lineGeometryStore.
    static func fixture(threeLines text: String) -> CodeEditorView {
        let view = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        view.text = text
        view.layoutSubviews() // ensures geometry store is populated; see existing fixtures in IntegrationTests
        return view
    }
}

extension Theme {
    /// Test-only theme with two perceptually distinct line-number colors so
    /// the pixel sampler can tell active and inactive lines apart.
    static var fixtureWithDistinctActiveLineColor: Theme {
        var theme = Theme.zedTrekDark
        theme.style.editor.lineNumber = .init(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        theme.style.editor.activeLineNumber = .init(red: 1.0, green: 0.2, blue: 0.2, alpha: 1)
        return theme
    }
}

extension PlatformColor {
    /// Approximate equality for sampled colors — sub-pixel rendering and font
    /// AA introduce ±~10/255 noise per channel.
    func isApproximately(_ other: PlatformColor) -> Bool {
        var lhs = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), a: CGFloat(0))
        var rhs = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), a: CGFloat(0))
        getRed(&lhs.r, green: &lhs.g, blue: &lhs.b, alpha: &lhs.a)
        other.getRed(&rhs.r, green: &rhs.g, blue: &rhs.b, alpha: &rhs.a)
        let tolerance: CGFloat = 0.1
        return abs(lhs.r - rhs.r) < tolerance
            && abs(lhs.g - rhs.g) < tolerance
            && abs(lhs.b - rhs.b) < tolerance
    }
}
```

> **Note for the implementer:** if `CodeEditorView.fixture(threeLines:)` or `Theme.fixtureWithDistinctActiveLineColor` already exists in test helpers, use the existing version instead of re-introducing it. Check `Tests/CodeEditorPluginTests/IntegrationTests.swift` and `Tests/CodeEditorPluginTests/TestHelpers/` first.

- [ ] **Step 1.3: Run the test to verify it fails (no `activeLineNumber` parameter exists yet)**

Run: `swift test --filter GutterViewRendererActiveLineTests`
Expected: COMPILE FAIL with "extra argument 'activeLineNumber' in call" — the renderer signature does not yet accept the parameter.

- [ ] **Step 1.4: Update `GutterViewRenderer.draw(...)` signature and color routing**

Edit `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift`:

Add the parameter to `draw(...)` (replace the current signature near line 70):

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

In the `for (lineNumber, lineRange) in lineRanges` loop (near line 104), pick a color before calling `drawLineNumber`:

```swift
let color: PlatformColor = (lineNumber == activeLineNumber)
    ? themedActiveLineNumberColor
    : themedLineNumberColor

let drawingContext = LineDrawingContext(
    font: textViewFont,
    gutterBounds: gutterBounds,
    textView: textView
)

drawLineNumber(
    lineNumber,
    for: lineRange,
    color: color,
    context: drawingContext
)
```

- [ ] **Step 1.5: Update `drawLineNumber` to take `color`**

Replace the existing `drawLineNumber(_:for:context:)` (near line 142):

```swift
private func drawLineNumber(
    _ lineNumber: Int,
    for lineRange: NSRange,
    color: PlatformColor,
    context: LineDrawingContext
) {
    let yPosition = calculateLineNumberYPosition(
        lineNumber: lineNumber,
        lineRange: lineRange,
        font: context.font,
        textView: context.textView
    )

    let drawingPoint = CGPoint(x: 0, y: yPosition)

    UnifiedDrawingCoordinator.saveGraphicsState()
    UnifiedDrawingCoordinator.drawLineNumber(
        lineNumber,
        at: drawingPoint,
        font: context.font,
        color: color,
        alignment: .right,
        maxWidth: context.gutterBounds.width - rightPadding
    )
    UnifiedDrawingCoordinator.restoreGraphicsState()
}
```

- [ ] **Step 1.6: Remove the vestigial `textColor` stored property**

Delete the property and its initializer line (the `textColor` declaration near line 22 and its assignment in `apply(theme:)` near line 58). `themedLineNumberColor` is now the single source of truth for the inactive color.

After deletion, `apply(theme:)` becomes:

```swift
public func apply(theme: Theme) {
    themedLineNumberColor = PlatformColor(tokens: theme.style.editor.lineNumber)
    themedActiveLineNumberColor = PlatformColor(tokens: theme.style.editor.activeLineNumber)
    themedBackgroundFillColor = PlatformColor(tokens: theme.style.editor.gutterBackground)
}
```

- [ ] **Step 1.7: Run the tests to verify they pass**

Run: `swift test --filter GutterViewRendererActiveLineTests`
Expected: 2 tests pass.

If `nilActiveRendersAllInactive` passes but `activeLineUsesActiveColor` doesn't, the pixel sampler is finding a font-AA edge instead of the body of the digit. Tune `tolerance` in `isApproximately` first; if that doesn't fix it, switch the sampler to look for the highest-saturation pixel of any single channel rather than overall saturation.

- [ ] **Step 1.8: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift \
    Tests/CodeEditorPluginTests/Layout/GutterViewRendererActiveLineTests.swift
git commit -m "$(cat <<'EOF'
GutterViewRenderer: add activeLineNumber parameter

Routes per-line color to themedActiveLineNumberColor when the line index
matches; falls back to themedLineNumberColor. New parameter is defaulted
to nil for source compatibility with iOS callers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Pass `activeLineNumber` through the iOS `GutterView` draw path

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/GutterView.swift`

- [ ] **Step 2.1: Update `drawLineNumbers(in:)` to compute and pass `activeLineNumber`**

Edit `Sources/CodeEditorPlugin/Layout/GutterView.swift`, near line 255 (the `drawLineNumbers(in:)` extension method):

```swift
extension GutterView {
    func drawLineNumbers(in rect: CGRect) {
        guard let textView else { return }
        guard let context = UnifiedDrawingCoordinator.currentContext() else { return }

        #if canImport(AppKit)
        let fillBackground = false
        #else
        let fillBackground = true
        #endif

        let activeLineNumber = Self.computeActiveLineNumber(for: textView)

        renderer.draw(
            in: rect,
            context: context,
            textView: textView,
            gutterBounds: bounds,
            fillBackground: fillBackground,
            activeLineNumber: activeLineNumber
        )

        #if canImport(UIKit)
        updateAccessibilityElements()
        #endif
    }

    private static func computeActiveLineNumber(for textView: CodeEditorView) -> Int? {
        #if canImport(AppKit)
        let location = textView.selectedRange().location
        guard location != NSNotFound,
              textView.lineGeometryStore.lineCount > 0 else { return nil }
        return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
        #else
        guard let selectedTextRange = textView.selectedTextRange else { return nil }
        let location = textView.offset(from: textView.beginningOfDocument, to: selectedTextRange.start)
        guard textView.lineGeometryStore.lineCount > 0 else { return nil }
        return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
        #endif
    }
}
```

> **Note:** The macOS branch is reachable in principle but the AppKit short-circuit at `GutterView.draw(_:)` line ~178 still returns early. Having both branches keeps the helper honest if/when that short-circuit is removed (out-of-scope follow-up).

- [ ] **Step 2.2: Build to confirm the change compiles on both platforms**

Run: `swift build`
Expected: BUILD SUCCESS. (No new test — Task 1's renderer-level test exercises the activeLineNumber routing; macOS coverage lands in Task 3.)

- [ ] **Step 2.3: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/GutterView.swift
git commit -m "$(cat <<'EOF'
GutterView: pass activeLineNumber through iOS draw path

iOS draws via GutterView.drawLineNumbers; macOS draws via NSRulerView
(Task 3 wires that side). The activeLineNumber lookup uses
lineGeometryStore.lineIndex(forUtf16Offset:) and never touches
NSLayoutManager.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: TK2-primary draw on macOS — `LineNumberRulerView.drawHashMarksAndLabels`

**Files:**
- Create: `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`

- [ ] **Step 3.1: Write the failing TK2-primary smoke test**

Create `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift`:

```swift
#if canImport(AppKit)
import AppKit
import ObjectiveC.runtime
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class LineNumberRulerViewTK2Tests: XCTestCase {

    /// Reads NSTextView._layoutManager without going through the public getter,
    /// which would itself synthesize the TK1 compatibility shim.
    private func legacyLayoutManagerIvarValue(for textView: NSTextView) -> AnyObject? {
        guard let ivar = class_getInstanceVariable(NSTextView.self, "_layoutManager") else {
            XCTFail("NSTextView._layoutManager ivar not found — Apple may have renamed it. Update this test.")
            return nil
        }
        return object_getIvar(textView, ivar) as AnyObject?
    }

    func testDrawHashMarksAndLabelsDoesNotSynthesizeLegacyLayoutManager() throws {
        // Build a windowed container so NSScrollView issues a real ruler draw.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.textView.string = "alpha\nbeta\ngamma\ndelta\nepsilon"
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        // Force first paint.
        window.displayIfNeeded()

        // Probe the ivar — if the gutter draw read .layoutManager, AppKit
        // synthesized _NSTextViewLayoutManager and stored it in the ivar.
        let legacy = legacyLayoutManagerIvarValue(for: container.textView)
        XCTAssertNil(
            legacy,
            "NSTextView._layoutManager was synthesized during first paint. The gutter (or another draw-time path) is still reading textView.layoutManager and flipping the editor off TextKit 2."
        )

        // Sanity: the TK2 layout manager is still primary.
        XCTAssertNotNil(container.textView.textLayoutManager)
    }
}
#endif
```

- [ ] **Step 3.2: Run the test to verify it fails against the current (TK1-reading) ruler**

Run: `swift test --filter LineNumberRulerViewTK2Tests/testDrawHashMarksAndLabelsDoesNotSynthesizeLegacyLayoutManager`
Expected: FAIL with "NSTextView._layoutManager was synthesized during first paint."

If the test fails to find the ivar (`XCTFail("...ivar not found...")`), Apple renamed the underlying storage. Stop and re-evaluate before changing implementation code — the test no longer measures what we want.

- [ ] **Step 3.3: Add new stored properties and helpers on `LineNumberRulerView`**

Edit `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`. At the top of the `LineNumberRulerView` class (just after the existing stored properties near line 25), add:

```swift
/// Renderer that owns line-number drawing and themed colors. Allocated
/// once per ruler instance; theme updates arrive via `apply(theme:)`.
private let renderer = GutterViewRenderer()

/// Last line index containing the caret, used to short-circuit redraws on
/// intra-line caret movement.
private var lastActiveLineNumber: Int?
```

Then add (also inside the class, anywhere in the existing run of `// MARK:` blocks):

```swift
/// Forwards a theme to the renderer and triggers a redraw. Equality-gated
/// by the renderer; the ruler always redraws so themed background and
/// active-line color refresh together.
@MainActor
func apply(theme: Theme) {
    renderer.apply(theme: theme)
    needsDisplay = true
}

/// Computes the 1-based line number containing the caret. Returns nil
/// when no selection is set or the geometry store is empty.
@MainActor
private func computeActiveLineNumber(for textView: CodeEditorView) -> Int? {
    let location = textView.selectedRange().location
    guard location != NSNotFound,
          textView.lineGeometryStore.lineCount > 0 else { return nil }
    return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
}

/// Recomputes the active line and marks the ruler dirty only when the
/// line index changes. Called from the selection-change observer (Task 5).
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

- [ ] **Step 3.4: Rewrite `drawHashMarksAndLabels(in:)` to delegate to the renderer**

Replace the current `drawHashMarksAndLabels(in:)` body (lines ~86–198 in the existing file) with:

```swift
override func drawHashMarksAndLabels(in rect: NSRect) {
    backgroundColor.set()
    rect.fill()

    guard let textView = clientView as? CodeEditorView,
          let context = NSGraphicsContext.current?.cgContext else {
        return
    }

    let activeLineNumber = computeActiveLineNumber(for: textView)
    lastActiveLineNumber = activeLineNumber

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
```

- [ ] **Step 3.5: Delete the dead TK1 helpers inside `LineNumberRulerView`**

Remove these from the existing file:

- `private func getLineRanges(for:in:)` (around lines 202–230) — no callers after Step 3.4.
- The inline `extension LineNumberRulerView { func drawFoldingControl(at:in:) ... }` block at lines ~471–506 — the renderer's own fold-control path replaces this.
- The `private func drawFoldingIcon(in:isFolded:)` extension method at lines ~507–526 — same.

Keep `mouseDown(with:)`; Task 4 rewrites its internals. The private `lineNumber(at:)` extension method at lines ~558–582 stays for now; Task 4 deletes it.

- [ ] **Step 3.6: Remove the vestigial `font` and `textColor` stored properties on `LineNumberRulerView`**

Delete `var font` (line ~13) and `var textColor` (line ~16). The new draw path uses the renderer's font and themed colors. `backgroundColor`, `rightPadding`, and `weak var textView` stay — they have remaining callers in this file and in `setupMacOSViews`/`updateMacOSRuler`.

- [ ] **Step 3.7: Run the TK2 smoke test to verify it passes**

Run: `swift test --filter LineNumberRulerViewTK2Tests/testDrawHashMarksAndLabelsDoesNotSynthesizeLegacyLayoutManager`
Expected: PASS.

Also run `swift build` to confirm no callers of the deleted properties remain. If any do, they belong to test code that was poking at the legacy `font`/`textColor` — switch those tests to read the renderer's themed colors instead.

- [ ] **Step 3.8: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift \
    Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift
git commit -m "$(cat <<'EOF'
LineNumberRulerView: TK2-native drawHashMarksAndLabels

Delegates to GutterViewRenderer + TextKitLineNumberHelper. Asserts via
ivar introspection that NSTextView._layoutManager stays nil through first
paint, proving AppKit's TK1 compatibility shim is no longer synthesized.
Removes the dead getLineRanges helper and the inline NSBezierPath
fold-control drawing — both lived only inside the old draw path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: TK2-native fold-control hit-testing in `mouseDown`

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`

- [ ] **Step 4.1: Append the failing fold-click test**

Add to `LineNumberRulerViewTK2Tests.swift` inside the existing `final class`:

```swift
func testFoldControlClickResolvesLineNumberViaTK2() throws {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false
    )
    let container = CodeEditorContainerView(frame: window.contentLayoutRect)
    // Use a language whose folding provider recognises blocks so isFoldable
    // returns true at line 1.
    container.textView.string = """
    func example() {
        let value = 1
        return value
    }
    """
    container.configuration.display.isCodeFoldingEnabled = true
    container.configuration.display.areFoldingControlsVisible = true
    window.contentView = container
    window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    window.displayIfNeeded()

    // Capture the legacy layout-manager state before the click.
    XCTAssertNil(legacyLayoutManagerIvarValue(for: container.textView))

    guard let ruler = container.textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView else {
        XCTFail("Ruler not installed")
        return
    }

    // Synthesize a mouseDown inside the fold-control band at line 1's Y.
    let controlPadding = container.configuration.layout.foldingControlPadding
    let controlSize = container.configuration.layout.foldingControlSize
    let firstLineY = container.textView.lineGeometryStore.yPosition(forLineIndex: 0)
    let point = NSPoint(x: controlPadding + controlSize / 2, y: firstLineY + 2)

    let event = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: ruler.convert(point, to: nil),
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )
    XCTAssertNotNil(event)
    if let event { ruler.mouseDown(with: event) }

    // Post-click: the legacy ivar must still be nil. If the old TK1 lineNumber
    // path ran, it would have synthesized.
    XCTAssertNil(legacyLayoutManagerIvarValue(for: container.textView))
}
```

- [ ] **Step 4.2: Run the test to verify it fails**

Run: `swift test --filter LineNumberRulerViewTK2Tests/testFoldControlClickResolvesLineNumberViaTK2`
Expected: FAIL — the current `LineNumberRulerView.lineNumber(at:)` reads `textView.layoutManager`, synthesizing the legacy ivar on click.

- [ ] **Step 4.3: Add `resolveLineNumber(at:)` and switch `mouseDown` to use it**

In `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`, inside the `extension LineNumberRulerView` block that contains `mouseDown(with:)`, add:

```swift
@MainActor
private func resolveLineNumber(at point: NSPoint) -> Int? {
    guard let textView = self.textView as? CodeEditorView else { return nil }
    let textPoint = textView.convert(point, from: self)
    return TextKitLineNumberHelper(textView: textView).lineNumber(at: textPoint)
}
```

In `mouseDown(with:)`, replace `if let lineNumber = lineNumber(at: point)` with `if let lineNumber = resolveLineNumber(at: point)`.

- [ ] **Step 4.4: Delete the private TK1 `lineNumber(at:)`**

Remove the `private func lineNumber(at point: NSPoint) -> Int?` extension method at lines ~558–582. Its sole caller (`mouseDown`) now uses `resolveLineNumber(at:)`.

- [ ] **Step 4.5: Run the tests to verify both pass**

Run: `swift test --filter LineNumberRulerViewTK2Tests`
Expected: 2 tests pass (`testDrawHashMarksAndLabels...` and `testFoldControlClick...`).

- [ ] **Step 4.6: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift \
    Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift
git commit -m "$(cat <<'EOF'
LineNumberRulerView: TK2 fold-control hit-test via TextKitLineNumberHelper

mouseDown now resolves the clicked line index through the same TK2 helper
the iOS gutter uses. Deletes the legacy lineNumber(at:) NSLayoutManager
reader — its only caller now goes through resolveLineNumber(at:).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Selection-change observer wires the active-line redraw

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`

- [ ] **Step 5.1: Append the failing selection-redraw test**

Add to `LineNumberRulerViewTK2Tests.swift`:

```swift
func testSelectionChangeOnNewLineMarksRulerDirty() throws {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false
    )
    let container = CodeEditorContainerView(frame: window.contentLayoutRect)
    container.textView.string = "alpha\nbeta\ngamma"
    window.contentView = container
    window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    window.displayIfNeeded()

    guard let ruler = container.textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView else {
        XCTFail("Ruler not installed")
        return
    }

    // Caret on line 1 initially. Move to line 2 and confirm the ruler is dirtied.
    container.textView.setSelectedRange(NSRange(location: 0, length: 0))
    window.displayIfNeeded()
    XCTAssertFalse(ruler.needsDisplay, "Baseline expectation: post-display, ruler is clean")

    container.textView.setSelectedRange(NSRange(location: 8, length: 0)) // line 2
    // Notification fires synchronously, but the observer hops to main via Task.
    let dirtied = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in ruler.needsDisplay },
        object: nil
    )
    wait(for: [dirtied], timeout: 1.0)
}

func testSelectionChangeOnSameLineIsNoOp() throws {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false
    )
    let container = CodeEditorContainerView(frame: window.contentLayoutRect)
    container.textView.string = "alphabetagamma"
    window.contentView = container
    window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    window.displayIfNeeded()

    guard let ruler = container.textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView else {
        XCTFail("Ruler not installed")
        return
    }

    container.textView.setSelectedRange(NSRange(location: 2, length: 0))
    window.displayIfNeeded()
    XCTAssertFalse(ruler.needsDisplay)

    // Move caret within the same line — short-circuit means no redraw.
    container.textView.setSelectedRange(NSRange(location: 5, length: 0))
    // Give the main queue a single hop to drain the notification handler.
    let exp = expectation(description: "drain main queue")
    DispatchQueue.main.async { exp.fulfill() }
    wait(for: [exp], timeout: 1.0)
    XCTAssertFalse(ruler.needsDisplay, "Caret moved within line 1 — ruler must not be dirtied")
}
```

- [ ] **Step 5.2: Run to verify failure**

Run: `swift test --filter LineNumberRulerViewTK2Tests`
Expected: the two new tests FAIL — there is no selection observer wired yet.

- [ ] **Step 5.3: Wire the selection observer in `setupMacOSViews`**

Edit `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`, inside `setupMacOSViews()` near the existing `NSText.didChangeNotification` observer (around line 269):

```swift
// Existing observer (keep):
NotificationCenter.default.addObserver(
    rulerView,
    selector: #selector(rulerView.textDidChange(_:)),
    name: NSText.didChangeNotification,
    object: textView
)

// New: redraw the active-line color when the caret crosses a line boundary.
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

The `selectionDidChange()` method on `LineNumberRulerView` was added in Task 3 Step 3.3.

- [ ] **Step 5.4: Mirror the observer in `updateMacOSRuler` for the recreation path**

`updateMacOSRuler()` (around line 286) recreates the ruler if `verticalRulerView == nil`. Add the same observer setup inside that branch so toggling line numbers off and back on rewires the observer:

```swift
if scrollView.verticalRulerView == nil {
    let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
    rulerView.textView = textView
    scrollView.verticalRulerView = rulerView

    NotificationCenter.default.addObserver(
        rulerView,
        selector: #selector(rulerView.textDidChange(_:)),
        name: NSText.didChangeNotification,
        object: textView
    )

    NotificationCenter.default.addObserver(
        forName: NSTextView.didChangeSelectionNotification,
        object: textView,
        queue: .main
    ) { [weak rulerView] _ in
        Task { @MainActor in
            rulerView?.selectionDidChange()
        }
    }
}
```

(If `setupMacOSViews`'s and `updateMacOSRuler`'s ruler-creation blocks have drifted, factor the observer wiring into a private helper. Don't repeat the snippet three places.)

- [ ] **Step 5.5: Run to verify both new tests pass**

Run: `swift test --filter LineNumberRulerViewTK2Tests`
Expected: 4 tests pass.

- [ ] **Step 5.6: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift \
    Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewTK2Tests.swift
git commit -m "$(cat <<'EOF'
LineNumberRulerView: redraw on selection line-change

Observes NSTextView.didChangeSelectionNotification and dirties the ruler
only when the line index containing the caret changes. Intra-line caret
moves are a no-op, matching the existing short-circuit pattern used for
text changes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Theme fan-out to the macOS ruler

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift`
- Modify: `Tests/CodeEditorPluginTests/Layout/ApplyThemePropagationTests.swift` (or create a new test if the existing suite doesn't cover the ruler)

- [ ] **Step 6.1: Add a failing test asserting the ruler's renderer is themed after `apply(theme:)`**

The existing suite is at `Tests/CodeEditorPluginTests/Layout/ApplyThemePropagationTests.swift`. Inspect it first to see whether it already exercises the ruler. If yes, extend it. If not, add a new test there with this shape:

```swift
#if canImport(AppKit)
@Test("apply(theme:) propagates to LineNumberRulerView renderer")
@MainActor
func applyThemePropagatesToRuler() throws {
    let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    // Attach a scroll view so the ruler is installed.
    let scroll = NSScrollView(frame: container.bounds)
    scroll.documentView = container.textView
    scroll.hasVerticalRuler = true
    scroll.rulersVisible = true
    let ruler = LineNumberRulerView(scrollView: scroll, orientation: .verticalRuler)
    ruler.textView = container.textView
    scroll.verticalRulerView = ruler
    container.addSubview(scroll)

    let theme = Theme.fixtureWithDistinctActiveLineColor
    container.apply(theme: theme)

    let expected = PlatformColor(tokens: theme.style.editor.activeLineNumber)
    #expect(ruler.renderer.themedActiveLineNumberColor.isApproximately(expected))
}
#endif
```

> **Note:** `ruler.renderer` is `private`. For the test, either (a) add `@testable`-only `internal var rendererForTesting: GutterViewRenderer { renderer }` on `LineNumberRulerView`, or (b) expose `renderer` as `internal` (drop the `private`). Pick (b) — `LineNumberRulerView` is itself internal so widening the property to package-internal has zero public-API impact.

- [ ] **Step 6.2: Run the test to verify it fails**

Run: `swift test --filter applyThemePropagatesToRuler`
Expected: FAIL — `container.apply(theme:)` doesn't forward to the ruler today.

- [ ] **Step 6.3: Extend `CodeEditorContainerView.apply(theme:)` to fan out to the ruler**

Edit `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift` near line 48:

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

The `LineNumberRulerView.apply(theme:)` method was added in Task 3 Step 3.3.

- [ ] **Step 6.4: Run to verify pass**

Run: `swift test --filter applyThemePropagatesToRuler`
Expected: PASS.

- [ ] **Step 6.5: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift \
    Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift \
    Tests/CodeEditorPluginTests/Layout/ApplyThemePropagationTests.swift
git commit -m "$(cat <<'EOF'
CodeEditorContainerView: fan theme out to macOS ruler renderer

Extends the existing apply(theme:) fan-out (gutterView, minimapView,
textView) to also call into LineNumberRulerView.apply(theme:) on macOS,
so the renderer's themedActiveLineNumberColor refreshes when the user
switches themes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Snapshot parity for the macOS ruler

**Files:**
- Create: `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift`
- Create: `Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests/*.png`
- Modify: `Package.swift`

- [ ] **Step 7.1: Add the snapshot exclude to `Package.swift`**

Edit `Package.swift` near line 133 (the `CodeEditorPluginTests` `exclude` array):

```swift
.testTarget(
    name: "CodeEditorPluginTests",
    dependencies: [
        "CodeEditorPlugin",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ],
    exclude: [
        "__Snapshots__",
        "Theming/__Snapshots__",
        "Layout/__Snapshots__"
    ],
    swiftSettings: swiftSettings
),
```

- [ ] **Step 7.2: Create the snapshot test file with `isRecording: true` for first-run capture**

```swift
// Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift
#if canImport(AppKit)
import AppKit
import SnapshotTesting
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class LineNumberRulerViewSnapshotTests: XCTestCase {

    private static let isRecording = false // flip to true to re-record locally

    override func setUp() {
        super.setUp()
        SnapshotTesting.isRecording = Self.isRecording
    }

    private func makeContainer(text: String, width: CGFloat = 400, height: CGFloat = 300) -> CodeEditorContainerView {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        container.textView.string = text
        let window = NSWindow(
            contentRect: container.bounds,
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        return container
    }

    func testRulerRendersBaselineSwiftSource() {
        let source = (1...100).map { "line \($0)" }.joined(separator: "\n")
        let container = makeContainer(text: source)
        assertSnapshot(of: container, as: .image, named: "baseline")
    }

    func testRulerRendersActiveLine() {
        let source = (1...50).map { "line \($0)" }.joined(separator: "\n")
        let container = makeContainer(text: source)
        // Move caret onto line 42.
        let location = source.split(separator: "\n", maxSplits: 41, omittingEmptySubsequences: false)
            .prefix(41).map { String($0) }.joined(separator: "\n").count + 1
        container.textView.setSelectedRange(NSRange(location: location, length: 0))
        container.textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        container.window?.displayIfNeeded()
        assertSnapshot(of: container, as: .image, named: "active-line-42")
    }

    func testRulerRendersFoldedLine() {
        let source = """
        func example() {
            let value = 1
            return value
        }

        struct Other {}
        """
        let container = makeContainer(text: source)
        container.configuration.display.isCodeFoldingEnabled = true
        container.configuration.display.areFoldingControlsVisible = true
        container.window?.displayIfNeeded()
        // Fold the function block at line 1 if the folding provider supports it.
        _ = container.textView.toggleFold(at: 1)
        container.window?.displayIfNeeded()
        assertSnapshot(of: container, as: .image, named: "folded-line-1")
    }

    func testRulerRendersEmptyDocument() {
        let container = makeContainer(text: "")
        assertSnapshot(of: container, as: .image, named: "empty-doc")
    }

    func testRulerRendersLongLineNumbers() {
        let source = (1...10_000).map { "line \($0)" }.joined(separator: "\n")
        let container = makeContainer(text: source, height: 600)
        // Scroll to a region where 5-digit line numbers are visible.
        container.textView.scrollRangeToVisible(NSRange(location: source.count - 100, length: 0))
        container.window?.displayIfNeeded()
        assertSnapshot(of: container, as: .image, named: "long-line-numbers")
    }
}
#endif
```

- [ ] **Step 7.3: Record snapshots locally**

Edit `Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift` and set `private static let isRecording = true`.

Run: `swift test --filter LineNumberRulerViewSnapshotTests`
Expected: the suite "fails" the first time with messages like "No reference was found on disk. Automatically recorded snapshot to …" — that's the snapshot-testing convention for the recording pass.

Verify that the new PNGs are written to `Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests/`.

- [ ] **Step 7.4: Switch off recording and re-run**

Edit the file and set `private static let isRecording = false`.

Run: `swift test --filter LineNumberRulerViewSnapshotTests`
Expected: 5 tests pass.

- [ ] **Step 7.5: Commit the test, the exclude, and the snapshots**

```bash
git add Tests/CodeEditorPluginTests/Layout/LineNumberRulerViewSnapshotTests.swift \
    "Tests/CodeEditorPluginTests/Layout/__Snapshots__/" \
    Package.swift
git commit -m "$(cat <<'EOF'
Snapshot tests: LineNumberRulerView visual parity

Five baseline scenarios (default, active line, folded block, empty doc,
10k-line scroll). Adds Layout/__Snapshots__ to CodeEditorPluginTests
excludes so SPM doesn't try to compile the PNG fixtures.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Verify, clean up, update `NEXT.md`

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 8.1: Sweep for any remaining `textView.layoutManager` reads in the gutter area**

Run: `grep -rn "textView\.layoutManager\|\.glyphRange(forBoundingRect:\|\.characterRange(forGlyphRange:\|\.lineFragmentRect(forGlyphAt:\|\.glyphIndexForCharacter(at:" Sources/CodeEditorPlugin/Layout/`

Expected: zero matches. If anything turns up, evaluate whether it belongs to the gutter (must be rewritten) or to an unrelated path (out of scope, leave alone).

- [ ] **Step 8.2: Run the full lint + build + test pipeline**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

Expected: build succeeds; lint reports zero warnings (strict mode is on); all tests pass. If any pre-existing flake in `NEXT.md § D` reappears, that's not our regression — re-run the failing test in isolation to confirm.

- [ ] **Step 8.3: Update `NEXT.md` to mark § B.5 done**

Edit `NEXT.md` and change the § B.5 heading and body:

```markdown
### B.5 ~~NSRulerView gutter TextKit 1 island~~ — done
`LineNumberRulerView` now delegates to `GutterViewRenderer` + `TextKitLineNumberHelper`; `NSTextView._layoutManager` stays nil through first paint (asserted by `LineNumberRulerViewTK2Tests`). Active-line line-number coloring uses the theme's `editor.activeLineNumber` token. Implementation: see `docs/superpowers/specs/2026-05-14-tk2-gutter-rewrite-design.md`.
```

If the table at A.2 references the gutter, leave it; this task only resolves B.5.

- [ ] **Step 8.4: Final commit**

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
NEXT.md: mark B.5 (NSRulerView TK1 island) done

The macOS gutter no longer triggers AppKit's TK1 compatibility shim.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8.5: Confirm clean state**

Run: `git status && git log --oneline -10`

Expected: working tree clean; eight new commits on `main` (Task 1 through Task 8). Compare against the spec one more time and call out anything that didn't land.

---

## Notes for the implementer

- The renderer's existing fold-control draw path on macOS uses `CGContext` ellipses; the deleted `NSBezierPath` version in `LineNumberRulerView` rendered the same ovals. Visual parity is locked by Task 7's snapshots — if a snapshot diff shows a fold control shifting by ~1px after recording, that's the line-fragment rect vs the legacy lineFragmentRect difference. Accept the new snapshot.
- `TextKitLineNumberHelper.lineNumber(at:)` returns a 1-based line number. `lineGeometryStore.lineIndex(forUtf16Offset:)` returns a 0-based index. The spec consistently `+1`s the latter; mirror that in any new code.
- If `XCTNSPredicateExpectation` flakes under `--parallel` for Task 5's tests (similar to the `LineGeometryStoreBenchmarkTests` flake noted in `NEXT.md § D`), prefer a synchronous `RunLoop.current.run(until: Date().addingTimeInterval(0.05))` over the expectation API. Don't introduce a new flake just to gate parallel-runner behavior.
- This plan does not touch the iOS selection-observer plumbing; active-line color refreshes there on next-natural-redraw (text edit, scroll). If user-visible lag becomes a problem, the follow-up issue is "add KVO on `UITextView.selectedTextRange` in `GutterView.observeTextView()`" — see spec "Out of scope (followups)".
