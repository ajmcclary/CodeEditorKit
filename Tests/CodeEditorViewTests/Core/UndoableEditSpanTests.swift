#if canImport(AppKit)
import AppKit
@testable import CodeEditorView
import XCTest

/// A host rewrite is applied as an edit of the span that differs. That span
/// must start and end on composed-character boundaries: cutting a surrogate
/// pair or a grapheme turned the halves into U+FFFD.
@MainActor
final class UndoableEditSpanTests: XCTestCase {
    private func assertRewrite(_ old: String, _ new: String, file: StaticString = #filePath, line: UInt = #line) {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        view.string = old
        view.applyAsUndoableEdit(new)
        XCTAssertEqual(view.string, new, file: file, line: line)
        XCTAssertFalse(view.string.unicodeScalars.contains("\u{FFFD}"), "replacement characters in \(view.string.debugDescription)", file: file, line: line)
    }

    func testEmojiChangedInsideItsSurrogatePair() {
        assertRewrite("a😀bx", "a😁bx")
        assertRewrite("😀", "😁")
        assertRewrite("x😀", "x😁")
    }

    func testFlagsSharingTheirFirstUnits() {
        assertRewrite("a🇺🇸b", "a🇬🇧b")
        assertRewrite("🇺🇸🇬🇧", "🇺🇸🇫🇷")
    }

    func testZWJSequences() {
        assertRewrite("a👨‍👩‍👧b", "a👨‍👩‍👦b")
        assertRewrite("👩‍💻", "👩‍🔬")
    }

    func testCombiningMarksAtBothEnds() {
        assertRewrite("cafe\u{301}", "cafe\u{300}")
        assertRewrite("e\u{301}x", "e\u{300}x")
        assertRewrite("ae\u{301}", "ae")
    }

    func testCRLFAtBothEnds() {
        assertRewrite("a\r\nb", "a\nb")
        assertRewrite("a\rb", "a\r\nb")
        assertRewrite("a\r\n", "a\r")
        assertRewrite("\r\nb", "\nb")
    }
}
#endif
