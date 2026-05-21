#if canImport(AppKit)
import AppKit
@testable import CodeEditorTheming
@testable import CodeEditorView
import XCTest

@MainActor
final class CodeEditorGutterViewLifecycleTests: XCTestCase {
    func testAttachIsIdempotent() throws {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = CodeEditorView(frame: .zero)
        scrollView.documentView = textView

        let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
        gutter.attach(to: scrollView, textView: textView)
        gutter.attach(to: scrollView, textView: textView)

        XCTAssertIdentical(gutter.attachedScrollView, scrollView)

        gutter.detach()
        XCTAssertNil(gutter.attachedScrollView)
        XCTAssertNil(gutter.textView)
    }

    func testDetachClearsStateAndAllowsReattach() throws {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = CodeEditorView(frame: .zero)
        scrollView.documentView = textView

        let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
        gutter.attach(to: scrollView, textView: textView)
        gutter.detach()

        XCTAssertNil(gutter.attachedScrollView)
        XCTAssertNil(gutter.textView)

        // Re-attaching after detach should succeed and rebind the references.
        gutter.attach(to: scrollView, textView: textView)
        XCTAssertIdentical(gutter.attachedScrollView, scrollView)
        XCTAssertIdentical(gutter.textView, textView)
    }

    func testSelectionDidChangeUpdatesActiveLine() throws {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scrollView.documentView = textView
        textView.string = "alpha\nbeta\ngamma"

        let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
        gutter.attach(to: scrollView, textView: textView)

        textView.setSelectedRange(NSRange(location: 0, length: 0))
        gutter.selectionDidChange()
        XCTAssertEqual(gutter.lastActiveLineNumber, 1)

        textView.setSelectedRange(NSRange(location: 7, length: 0)) // inside "beta"
        gutter.selectionDidChange()
        XCTAssertEqual(gutter.lastActiveLineNumber, 2)
    }

    func testApplyThemeForwardsToRenderer() throws {
        let gutter = CodeEditorGutterView(frame: NSRect(x: 0, y: 0, width: 50, height: 300))
        let beforeColor = gutter.renderer.themedLineNumberColor

        gutter.apply(theme: .lcarsDark)

        XCTAssertNotEqual(beforeColor.cgColor, gutter.renderer.themedLineNumberColor.cgColor)
    }

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

    func testTextContainerInsetRoundtripsWithGutterToggle() throws {
        let container = CodeEditorContainerView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        // Disable line numbers so we observe the bare baseline first.
        var configWithout = container.configuration
        configWithout.display.isLineNumbersEnabled = false
        container.configuration = configWithout
        let baseline = container.baseTextContainerInsetWidth
        XCTAssertEqual(container.textView.textContainerInset.width, baseline, accuracy: 0.5)

        // Toggle on — inset should grow by at least gutterWidth.
        container.showsLineNumbers = true
        XCTAssertGreaterThanOrEqual(
            container.textView.textContainerInset.width,
            baseline + container.configuration.layout.gutterWidth
        )

        // Toggle off — inset should return to baseline.
        container.showsLineNumbers = false
        XCTAssertEqual(container.textView.textContainerInset.width, baseline, accuracy: 0.5)
    }
}
#endif
