@testable import CodeEditorPlugin
import Foundation
import XCTest

/// Regression coverage for the `processFolding` filter that gated fold
/// regions on `region.range.length >= configuration.minimumLineCount`.
/// `NSRange.length` is UTF-16 length, not line span, so single-line
/// regions slipped through the threshold as long as they contained
/// enough UTF-16 code units. The fix introduces
/// `CodeFoldingEngine.lineSpan(of:in:)` and compares its result to
/// `minimumLineCount`; these tests pin both the helper's matrix and
/// the engine's end-to-end filter.
@MainActor
final class CodeFoldingEngineLineSpanTests: CleanupTestCase {
    // MARK: - LineSpan helper — direct matrix

    func testLineSpanForSingleLineRange() {
        let text = "let value = 1"
        let span = CodeFoldingEngine.lineSpan(
            of: NSRange(location: 0, length: text.utf16.count),
            in: text
        )
        XCTAssertEqual(span, 1, "A range with no newlines spans exactly one line")
    }

    func testLineSpanForTwoLineRange() {
        let text = "{\n}"
        let span = CodeFoldingEngine.lineSpan(
            of: NSRange(location: 0, length: text.utf16.count),
            in: text
        )
        XCTAssertEqual(span, 2, "A range with one newline spans two lines")
    }

    func testLineSpanForThreeLineRange() {
        let text = "{\n  body\n}"
        let span = CodeFoldingEngine.lineSpan(
            of: NSRange(location: 0, length: text.utf16.count),
            in: text
        )
        XCTAssertEqual(span, 3, "A range with two newlines spans three lines")
    }

    func testLineSpanForZeroLengthRange() {
        let text = "{\n  body\n}"
        let span = CodeFoldingEngine.lineSpan(
            of: NSRange(location: 4, length: 0),
            in: text
        )
        XCTAssertEqual(span, 1, "A zero-length range collapses to a single-line span")
    }

    func testLineSpanClampsRangeBeyondDocument() {
        let text = "abc"
        let span = CodeFoldingEngine.lineSpan(
            of: NSRange(location: 100, length: 50),
            in: text
        )
        XCTAssertEqual(span, 1, "Out-of-bounds ranges must not crash and must report a sane span")
    }

    func testLineSpanIgnoresUTF16ContentLength() {
        // The original bug: an NSRange of UTF-16 length 3 on a single
        // line would pass `length >= minimumLineCount=3`. lineSpan
        // must report 1 regardless.
        let text = "abc"
        let span = CodeFoldingEngine.lineSpan(
            of: NSRange(location: 0, length: 3),
            in: text
        )
        XCTAssertEqual(span, 1, "Three UTF-16 characters on one line must not be reported as three lines")
    }

    // MARK: - Engine-level filter
    //
    // Integration tests use the default `BraceFoldingProvider` for Swift,
    // applied to a struct/func snippet known to produce two regions:
    // the outer struct (six lines) and the inner function (four lines).
    // `minimumLineCount` is varied to exercise the lineSpan-based
    // filter. Under the BUGGY `length >= minimumLineCount` filter both
    // regions' UTF-16 lengths trivially exceed any plausible
    // threshold — the regression-detecting assertions live in the high
    // `minimumLineCount` test below.

    private static let nestedSwiftSnippet = """
    struct Example {
        func message() -> String {
            let value = "Hello"
            return value
        }
    }
    """

    func testEngineAcceptsRegionsWhenMinimumLineCountMatchesSpan() async throws {
        let editor = createCodeEditorView()
        editor.language = .swift
        editor.text = Self.nestedSwiftSnippet

        let engine = CodeFoldingEngine()
        // Inner func spans four lines, outer struct spans six. Both
        // pass at minimumLineCount=4.
        engine.configuration.minimumLineCount = 4
        engine.configuration.hidesFoldedContent = false
        engine.attach(to: editor)
        engine.updateFoldableRegions()

        let region = try await waitForFoldableRegion(in: engine)
        let span = CodeFoldingEngine.lineSpan(of: region.range, in: editor.text ?? "")
        XCTAssertGreaterThanOrEqual(
            span,
            4,
            "Accepted region must actually span at least minimumLineCount lines. actual span=\(span), range=\(NSStringFromRange(region.range))"
        )
    }

    func testEngineRejectsRegionsWhenMinimumLineCountExceedsEverySpan() async throws {
        let editor = createCodeEditorView()
        editor.language = .swift
        editor.text = Self.nestedSwiftSnippet

        let engine = CodeFoldingEngine()
        // Outer struct spans six lines; setting the threshold to 7
        // rejects both the outer struct and the inner function. Under
        // the BUGGY `length >= minimumLineCount` filter both regions
        // pass the threshold trivially (length is ~50+ UTF-16 units
        // for each), so foldableRegions would be non-empty.
        engine.configuration.minimumLineCount = 7
        engine.configuration.hidesFoldedContent = false
        engine.attach(to: editor)
        engine.updateFoldableRegions()

        // Two debounced passes' worth — by this point detection has
        // definitely run and produced (or rejected) regions.
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertTrue(
            engine.foldableRegions.isEmpty,
            "minimumLineCount=7 must reject every region in a snippet whose widest span is six lines — M2 regression check against the UTF-16 vs line-count confusion"
        )
    }

    // MARK: - Helpers

    private func waitForFoldableRegion(in engine: CodeFoldingEngine) async throws -> FoldableRegion {
        for _ in 0..<100 {
            if let region = engine.foldableRegions.first {
                return region
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Expected at least one foldable region after the debounce window — isProcessing=\(engine.isProcessing), foldableRegions.count=\(engine.foldableRegions.count)")
        throw CancellationError()
    }
}
