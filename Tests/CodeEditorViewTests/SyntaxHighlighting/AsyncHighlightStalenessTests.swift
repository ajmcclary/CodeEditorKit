#if canImport(AppKit)
import AppKit
import CodeEditorConfiguration
@testable import CodeEditorView
import XCTest

/// The Swift highlighter parses a snapshot off the main actor. A result for a
/// text that was edited before it arrived must be dropped, not painted at
/// offsets that now belong to other text.
@MainActor
final class AsyncHighlightStalenessTests: XCTestCase {
    func testAResultForAnEditedTextIsDropped() async throws {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        var configuration = view.configuration
        // Keep the view's own edit-triggered passes out of the way.
        configuration.display.isSyntaxHighlightingEnabled = false
        view.configuration = configuration
        view.language = .swift
        view.string = String(repeating: "let value = compute(1, \"two\") // three\n", count: 3_000)
        let highlighter = view.asyncHighlighter
        let dropped = highlighter.droppedStaleResultCount

        let pass = Task { await highlighter.highlightImmediately(for: view, language: .swift) }
        try await Task.sleep(nanoseconds: 20_000_000)
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "// inserted\n")
        await pass.value

        XCTAssertEqual(highlighter.droppedStaleResultCount, dropped + 1)
    }
}
#endif
