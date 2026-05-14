#if canImport(AppKit)
import AppKit
import SnapshotTesting
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class LineNumberRulerViewSnapshotTests: XCTestCase {

    /// Toggle to `true` locally to re-record baselines after intentional
    /// visual changes. Keep `false` on commit.
    private static let isRecording = false

    override func setUp() {
        super.setUp()
        SnapshotTesting.isRecording = Self.isRecording
    }

    /// Renders the ruler into a bitmap and returns the resulting NSImage. The
    /// helper bypasses the AppKit display cycle so the test does not depend
    /// on a real window appearing on-screen.
    private func renderedImage(of ruler: LineNumberRulerView) throws -> NSImage {
        let rep = try XCTUnwrap(ruler.bitmapImageRepForCachingDisplay(in: ruler.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        ruler.drawHashMarksAndLabels(in: ruler.bounds)
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: ruler.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    func testRulerRendersBaselineFiveLines() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
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

        let ruler = try XCTUnwrap(container.textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)
        let image = try renderedImage(of: ruler)
        assertSnapshot(of: image, as: .image, named: "baseline")
    }
}
#endif
