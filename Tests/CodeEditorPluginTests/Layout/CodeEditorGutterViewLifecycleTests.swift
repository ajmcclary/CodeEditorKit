#if canImport(AppKit)
import AppKit
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
}
#endif
