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
}
#endif
