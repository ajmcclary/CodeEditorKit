#if canImport(AppKit)
import AppKit
import CodeEditorConfiguration
@testable import CodeEditorView
import XCTest

/// With word wrap on, a container layout pass used to invalidate and lay out
/// the whole document (twice) even when the wrapping width had not changed.
@MainActor
final class WrappedLayoutCostTests: XCTestCase {
    private var window: NSWindow?

    override func setUp() {
        super.setUp()
        window = nil
    }

    override func tearDown() {
        window?.orderOut(nil)
        window?.close()
        window = nil
        super.tearDown()
    }

    private func makeWrappedContainer(lines: Int) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        container.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        let window = NSWindow(contentRect: container.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = container
        self.window = window
        var configuration = EditorConfiguration()
        configuration.layout.wrapLines = true
        container.configuration = configuration
        container.textView.string = String(
            repeating: "    let value = editor.selectedRange.location + offset // some trailing commentary\n",
            count: lines
        )
        container.layoutSubtreeIfNeeded()
        return container
    }

    func testALayoutPassAtAnUnchangedWidthIsCheap() {
        let container = makeWrappedContainer(lines: 20_000)

        let start = Date()
        for _ in 0..<5 {
            container.needsLayout = true
            container.layoutSubtreeIfNeeded()
        }
        let elapsed = Date().timeIntervalSince(start)

        // Each pass used to cost ~0.7 s here (full invalidate + layout).
        XCTAssertLessThan(elapsed, 1, "5 layout passes took \(elapsed) s")
    }

    func testReapplyingConfigurationIsCheap() {
        let container = makeWrappedContainer(lines: 20_000)

        let start = Date()
        for _ in 0..<3 { container.applyConfiguration() }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1, "3 configuration applications took \(elapsed) s")
    }

    func testTheDocumentFrameStillCoversTheText() {
        let container = makeWrappedContainer(lines: 2_000)
        container.layoutSubtreeIfNeeded()

        // 2,000 lines of ~17 pt, wrapped or not.
        XCTAssertGreaterThan(container.textView.frame.height, 2_000 * 10)
    }
}
#endif
