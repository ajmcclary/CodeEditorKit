#if canImport(AppKit)
import AppKit
import CodeEditorConfiguration
@testable import CodeEditorView
import XCTest

/// Moving the bare editor view to another superview must not leave it
/// accepting input without its delegate multiplexer or its features.
@MainActor
final class ReparentingTests: XCTestCase {
    func testAReparentedEditorKeepsItsDelegateAndFeatures() async throws {
        let first = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let second = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let editor = CodeEditorView(frame: first.bounds)
        var configuration = EditorConfiguration()
        configuration.display.isCodeFoldingEnabled = true
        editor.configuration = configuration
        editor.language = .swift
        first.addSubview(editor)
        let delegateBefore = try XCTUnwrap(editor.delegate)

        editor.removeFromSuperview()
        second.addSubview(editor)

        XCTAssertIdentical(editor.delegate, delegateBefore, "the delegate multiplexer was dropped")
        editor.string = "func f() {\n  a\n  b\n}\n"
        let deadline = Date().addingTimeInterval(5)
        while editor.codeFoldingEngine.foldableRegions.isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(editor.isFoldable(at: 1), "folding stopped after the move")
    }
}
#endif
