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
    private func renderedImage(of gutter: CodeEditorGutterView) throws -> NSImage {
        let rep = try XCTUnwrap(gutter.bitmapImageRepForCachingDisplay(in: gutter.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        gutter.effectiveAppearance.performAsCurrentDrawingAppearance {
            gutter.draw(gutter.bounds)
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

        let gutter = try XCTUnwrap(container.macGutterView)
        let image = try renderedImage(of: gutter)
        assertSnapshot(of: image, as: .image, named: "baseline")
    }
}
#endif
