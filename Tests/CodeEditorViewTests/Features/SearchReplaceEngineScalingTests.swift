#if canImport(AppKit)
import AppKit
@testable import CodeEditorView
import XCTest

/// In-document Find used to copy and split the document prefix once per
/// match (O(matches × document)); a one-letter query on a few thousand lines
/// took minutes. These bound the work on a sized input.
@MainActor
final class SearchReplaceEngineScalingTests: XCTestCase {
    private func makeView(_ text: String) -> CodeEditorView {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.string = text
        return view
    }

    func testFindingACommonLetterInALargeDocumentIsFast() async {
        let line = "    let value = editor.selectedRange.location + offset\n"
        let lineCount = 4_000
        let view = makeView(String(repeating: line, count: lineCount))
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = false

        let start = Date()
        let results = await engine.findAll(pattern: "e", options: options, selectFirstResult: false)
        let elapsed = Date().timeIntervalSince(start)

        let perLine = line.filter { $0 == "e" }.count
        XCTAssertEqual(results.count, perLine * lineCount)
        XCTAssertEqual(results.first?.lineNumber, 1)
        XCTAssertEqual(results.last?.lineNumber, lineCount)
        // The quadratic version took ~125 s here; linear work is well under a second.
        XCTAssertLessThan(elapsed, 10, "find took \(elapsed) s")
    }

    func testLineNumbersCountCRLFAsOneLineBreak() async {
        let view = makeView("alpha\r\nbeta\r\n\r\nalpha")
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = false
        options.highlightResults = false

        let results = await engine.findAll(pattern: "alpha", options: options, selectFirstResult: false)

        XCTAssertEqual(results.map(\.lineNumber), [1, 4])
        XCTAssertEqual(results.map(\.matchedText), ["alpha", "alpha"])
    }

    func testANewerFindCancelsTheOlderOne() async {
        let view = makeView(String(repeating: "abc def ghi\n", count: 20_000))
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = false
        options.highlightResults = false

        let older = Task { await engine.findAll(pattern: " ", options: options, selectFirstResult: false) }
        await Task.yield()
        let newer = await engine.findAll(pattern: "ghi", options: options, selectFirstResult: false)
        let olderResults = await older.value

        XCTAssertEqual(newer.count, 20_000)
        XCTAssertEqual(engine.currentSearchResults.count, 20_000)
        XCTAssertTrue(olderResults.isEmpty || olderResults.count == 40_000)
    }

    private func backgroundRuns(in view: CodeEditorView) -> Int {
        guard let storage = view.textContentStorage?.textStorage else { return 0 }
        var runs = 0
        storage.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if value != nil { runs += 1 }
        }
        return runs
    }

    func testClearingInsideTheFlashLeavesNoHighlightBehind() async throws {
        let view = makeView("alpha beta alpha")
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = true

        _ = await engine.findAll(pattern: "alpha", options: options, selectFirstResult: true)
        engine.clearAll()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(backgroundRuns(in: view), 0)
    }

    func testShorteningTheTextInsideTheFlashIsSafe() async throws {
        let view = makeView("one two three four five alpha")
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = true

        _ = await engine.findAll(pattern: "alpha", options: options, selectFirstResult: true)
        view.string = "one"
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(view.string, "one")
    }

    // MARK: - Results bound to the text they were computed from

    func testTextReplacedDuringAScanDoesNotKeepStaleResults() async {
        let view = makeView(String(repeating: "abc def ghi\n", count: 60_000))
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = false

        let search = Task { await engine.findAll(pattern: "def", options: options, selectFirstResult: false) }
        await Task.yield()
        view.string = "line one has def here\nzzzz\n"
        let results = await search.value

        XCTAssertTrue(results.isEmpty || results.count == 1, "returned \(results.count) results")
        let current = engine.currentSearchResults
        guard current.count == 1, let only = current.first else {
            return XCTFail("engine holds \(current.count) results for a one-match text")
        }
        XCTAssertEqual(only.range, NSRange(location: 13, length: 3))
    }

    func testReplacingAResultThatNoLongerMatchesTouchesNothing() async throws {
        let view = makeView("foo one\nfoo two\n")
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = false
        _ = await engine.findAll(pattern: "foo", options: options, selectFirstResult: true)

        // The text changes without a new search (another edit path, an undo).
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "XY")

        XCTAssertFalse(engine.replace(at: 0, with: "Q"))
        XCTAssertEqual(view.string, "XYfoo one\nfoo two\n")
    }

    func testReplaceThenUndoThenReplaceEditsOnlyMatches() async throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = makeView("foo one\nfoo two\nfoo three\n")
        window.contentView = view
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = false
        _ = await engine.findAll(pattern: "foo", options: options, selectFirstResult: true)

        XCTAssertTrue(engine.replace(at: 0, with: "Q"))
        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()
        XCTAssertEqual(view.string, "foo one\nfoo two\nfoo three\n")

        // The remaining results were shifted for the replace; the undo moved
        // the text back. A replace must not edit whatever now sits there.
        _ = engine.replace(at: 0, with: "Q")
        let text = view.string
        XCTAssertTrue(
            text == "foo one\nfoo two\nfoo three\n" || text == "foo one\nQ two\nfoo three\n",
            "replace edited text that was not a match: \(text.debugDescription)"
        )
    }

    // MARK: - Empty regex matches

    func testRegexMatchesOfTheEmptyStringAreFound() async {
        let view = makeView("one\ntwo\nthree\n")
        let engine = SearchReplaceEngine()
        engine.attach(to: view)
        var options = SearchOptions()
        options.flashResult = false
        options.useRegularExpression = true

        let counts = await [
            engine.findAll(pattern: "^", options: options, selectFirstResult: false).count,
            engine.findAll(pattern: "$", options: options, selectFirstResult: false).count,
            engine.findAll(pattern: "\\b", options: options, selectFirstResult: false).count
        ]

        XCTAssertEqual(counts, [1, 2, 6])
    }
}
#endif
