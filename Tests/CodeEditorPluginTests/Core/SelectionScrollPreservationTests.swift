#if canImport(AppKit)
import AppKit
@testable import CodeEditorConfiguration
@testable import CodeEditorView
import XCTest

@MainActor
final class SelectionScrollPreservationTests: XCTestCase {
    func testAppKitSelectionPreservesVisibleOriginWhenAutoScrollIsDisabled() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        let editor = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 300, height: 1_000))
        editor.string = Array(repeating: "line", count: 100).joined(separator: "\n")
        var configuration = EditorConfiguration()
        configuration.behavior.autoScrollToCursor = false
        editor.configuration = configuration
        scrollView.documentView = editor
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 300))
        let originalOrigin = scrollView.contentView.bounds.origin

        editor.setSelectedRangeWithoutScrolling(NSRange(location: 0, length: 0))

        XCTAssertEqual(scrollView.contentView.bounds.origin, originalOrigin)
    }
}
#endif
