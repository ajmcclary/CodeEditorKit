#if canImport(AppKit)
import AppKit
import CodeEditorCompletion
import CodeEditorLanguages
@testable import CodeEditorView
import XCTest

/// The completion popup follows the text: it re-filters as the user types,
/// goes away when it no longer applies (so it never captures Return for a
/// stale list), and accepting replaces the word typed since it opened.
@MainActor
final class CompletionPopupLifecycleTests: XCTestCase {
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

    private let items = ["bar", "baz", "qux"].map { CompletionItemModel(label: $0) }

    private func makeEditor(_ text: String) -> CodeEditorView {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        self.window = window
        window.makeFirstResponder(view)
        view.string = text
        view.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
        return view
    }

    private func type(_ text: String, into view: CodeEditorView) {
        for character in text {
            view.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0))
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func visibleLabels(_ view: CodeEditorView) -> [String] {
        guard view.isCompletionActive,
              let controller = view.completionViewController as? CompletionViewController else { return [] }
        return controller.completionItems.map(\.label)
    }

    func testTypingRefiltersAndANonWordCharacterDismisses() {
        let view = makeEditor("foo.")
        view.showCompletionPopup(with: items, at: 4)
        XCTAssertEqual(visibleLabels(view), ["bar", "baz", "qux"])

        type("b", into: view)
        XCTAssertEqual(visibleLabels(view), ["bar", "baz"])

        type("z", into: view)
        XCTAssertEqual(visibleLabels(view), ["baz"])

        type(" ", into: view)
        XCTAssertFalse(view.isCompletionActive)
    }

    func testAcceptingReplacesTheTypedPrefix() throws {
        let view = makeEditor("foo.")
        view.showCompletionPopup(with: items, at: 4)
        type("ba", into: view)

        let controller = try XCTUnwrap(view.completionViewController as? CompletionViewController)
        controller.insertSelectedItem()

        XCTAssertEqual(view.string, "foo.bar")
        XCTAssertFalse(view.isCompletionActive)
    }

    func testMovingTheCaretOutOfTheWordDismisses() {
        let view = makeEditor("foo.")
        view.showCompletionPopup(with: items, at: 4)

        view.setSelectedRange(NSRange(location: 1, length: 0))
        spinUntil { !view.isCompletionActive } // not a fixed 50 ms

        XCTAssertFalse(view.isCompletionActive)
    }

    func testLosingFocusDismisses() {
        let view = makeEditor("foo.")
        view.showCompletionPopup(with: items, at: 4)
        XCTAssertTrue(view.isCompletionActive)

        window?.makeFirstResponder(nil)

        XCTAssertFalse(view.isCompletionActive)
    }

    func testAResultForAStaleCaretIsAnchoredToTheCurrentWord() {
        let view = makeEditor("foo.")
        // The request was made at 4; the user typed "q" before it returned.
        type("q", into: view)
        view.showCompletionPopup(with: items, at: 4)

        XCTAssertEqual(visibleLabels(view), ["qux"])
    }
}
#endif
