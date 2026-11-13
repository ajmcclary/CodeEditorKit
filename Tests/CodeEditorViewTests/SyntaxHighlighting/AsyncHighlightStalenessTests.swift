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
        // Edit after the pass took its snapshot and before it applies, by
        // ordering rather than a 20 ms sleep (too short on a loaded machine
        // for the pass to start, too long on a fast one for it to be still
        // running). The main actor runs jobs in order: this yield lets the
        // pass run until its first suspension (its snapshot is taken before
        // it); its result can only be applied on the main actor, after the
        // edit below.
        await Task.yield()
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "// inserted\n")
        await pass.value

        XCTAssertEqual(highlighter.droppedStaleResultCount, dropped + 1)
    }
}
#endif
