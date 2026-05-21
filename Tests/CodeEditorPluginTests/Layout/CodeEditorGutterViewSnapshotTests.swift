#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SnapshotTesting
import XCTest

@MainActor
final class CodeEditorGutterViewSnapshotTests: XCTestCase {
    /// Toggle to `true` locally to re-record baselines after intentional
    /// visual changes. Keep `false` on commit.
    private static let isRecording = false

    override func setUp() {
        super.setUp()
        SnapshotTesting.isRecording = Self.isRecording
    }

    override func tearDown() {
        SnapshotTesting.isRecording = false
        super.tearDown()
    }

    /// Renders the gutter into a bitmap and returns the resulting NSImage.
    /// Bypasses the AppKit display cycle so the test does not depend on a
    /// real window appearing on-screen. Wraps `draw` in
    /// `performAsCurrentDrawingAppearance` so appearance-sensitive named
    /// colors (`NSColor.textColor` etc.) resolve against the gutter's own
    /// effective appearance instead of whatever the test runner's current
    /// drawing appearance happens to be.
    private func renderedImage(of gutter: LineNumberRulerView) throws -> NSImage {
        let rep = try XCTUnwrap(gutter.bitmapImageRepForCachingDisplay(in: gutter.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        gutter.effectiveAppearance.performAsCurrentDrawingAppearance {
            gutter.drawHashMarksAndLabels(in: gutter.bounds)
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: gutter.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    func testGutterRendersBaselineFiveLines() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.appearance = NSAppearance(named: .aqua)
        container.textView.string = """
        alpha
        beta
        gamma
        delta
        epsilon
        """
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        let gutter = try XCTUnwrap(container.macLineNumberRulerView)
        let image = try renderedImage(of: gutter)
        assertSnapshot(of: image, as: .image, named: "baseline")
    }

    /// Locks in the wrap-anchor behavior: a long logical line that wraps to
    /// multiple visual rows must show its line number against the **first**
    /// visual row only, with empty gutter beside continuation rows. Without
    /// the renderer's fragment-walk fix the number would land in the middle
    /// of the wrapped block.
    func testGutterRendersWrappedLine() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.appearance = NSAppearance(named: .aqua)
        var configuration = container.configuration
        configuration.layout.wrapLines = true
        configuration.display.isMinimapVisible = false
        configuration.display.isSelectedLineHighlighted = false
        container.configuration = configuration
        container.textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        container.textView.string = String(repeating: "wrapped ", count: 18) + "\nshort"
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        container.layoutSubtreeIfNeeded()
        container.textView.updateTextContainerSize()

        let gutter = try XCTUnwrap(container.macLineNumberRulerView)
        let image = try renderedImage(of: gutter)
        assertSnapshot(of: image, as: .image, named: "wrapped-line")
    }

    /// Locks in the scroll-position behavior: after a programmatic vertical
    /// scroll the gutter must show line numbers for the now-visible lines,
    /// not the original 1..N pinned at the top of the gutter (the
    /// pre-Approach-A scroll bug).
    func testGutterRendersAfterScroll() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.appearance = NSAppearance(named: .aqua)
        container.textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        container.textView.string = (1...100).map { "line \($0)" }.joined(separator: "\n")
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        container.layoutSubtreeIfNeeded()
        // Programmatically scroll past the first ~10 lines.
        container.scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: 200))
        container.scrollView.reflectScrolledClipView(container.scrollView.contentView)
        container.layoutSubtreeIfNeeded()

        let gutter = try XCTUnwrap(container.macLineNumberRulerView)
        let image = try renderedImage(of: gutter)
        assertSnapshot(of: image, as: .image, named: "after-scroll")
    }
}
#endif
