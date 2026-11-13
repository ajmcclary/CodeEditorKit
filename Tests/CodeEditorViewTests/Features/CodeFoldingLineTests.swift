#if canImport(AppKit)
import AppKit
import CodeEditorConfiguration
import CodeEditorLanguages
@testable import CodeEditorView
import XCTest

/// Folding through the view's public, 1-based line API: the line a chevron is
/// asked about, the region a click folds, detection after typing, and what a
/// fold/unfold round trip leaves in the text storage.
@MainActor
final class CodeFoldingLineTests: XCTestCase {
    private static let nested = """
    struct A {
      func f() {
        a
        b
        c
      }

      func g() {
        a
        b
        c
      }
    }

    """

    private func makeEditor(_ text: String) -> CodeEditorView {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        var config = EditorConfiguration()
        config.display.isCodeFoldingEnabled = true
        config.display.areFoldingControlsVisible = true
        view.configuration = config
        view.language = .swift
        view.string = text
        return view
    }

    private func waitForRegions(
        in view: CodeEditorView,
        count: Int? = nil,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let regions = view.codeFoldingEngine.foldableRegions
            if let count, regions.count == count { return }
            if count == nil, !regions.isEmpty { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("regions=\(view.codeFoldingEngine.foldableRegions.count), wanted \(String(describing: count))")
    }

    private func hiddenUnits(in view: CodeEditorView) -> Int {
        guard let storage = view.textContentStorage?.textStorage else { return 0 }
        var hidden = 0
        storage.enumerateAttribute(.font, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if let font = value as? NSFont, font.pointSize < 1 { hidden += range.length }
        }
        return hidden
    }

    // MARK: - Line base and region choice

    func testChevronLinesAreTheLinesRegionsStartOn() async throws {
        let view = makeEditor(Self.nested)
        try await waitForRegions(in: view, count: 3)

        let foldable = (1...13).filter { view.isFoldable(at: $0) }

        XCTAssertEqual(foldable, [1, 2, 8])
    }

    func testTogglingAFunctionsLineFoldsOnlyThatFunction() async throws {
        let view = makeEditor(Self.nested)
        try await waitForRegions(in: view, count: 3)

        XCTAssertTrue(view.toggleFold(at: 2))

        let hidden = hiddenUnits(in: view)
        XCTAssertGreaterThan(hidden, 0)
        XCTAssertLessThan(hidden, 30, "folded \(hidden) units; one function body is ~25")
        XCTAssertTrue(view.isFolded(at: 2))
        XCTAssertFalse(view.isFolded(at: 8))
    }

    func testCRLFDocumentsHaveFoldableRegionsOnTheRightLines() async throws {
        let view = makeEditor(Self.nested.replacingOccurrences(of: "\n", with: "\r\n"))
        try await waitForRegions(in: view, count: 3)

        XCTAssertEqual((1...13).filter { view.isFoldable(at: $0) }, [1, 2, 8])
    }

    // MARK: - Cost of a gutter redraw

    func testOneScreenOfGutterQueriesIsCheap() async throws {
        let function = "  func f() {\n    a\n    b\n    c\n  }\n"
        let view = makeEditor("struct A {\n" + String(repeating: function, count: 1_000) + "}\n")
        try await waitForRegions(in: view, count: 1_001, timeout: 20)

        let start = Date()
        var foldable = 0
        for line in 2_000..<2_050 {
            if view.isFoldable(at: line) { foldable += 1 }
            _ = view.isFolded(at: line)
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(foldable, 10)
        // Each query used to copy and walk the document once per region (~28 s).
        XCTAssertLessThan(elapsed, 1, "50 gutter lines took \(elapsed) s")
    }

    // MARK: - Detection after edits

    func testAShortDocumentGetsRegions() async throws {
        let view = makeEditor("func f() {\n  a\n  b\n}\n")

        try await waitForRegions(in: view, count: 1)
        XCTAssertTrue(view.isFoldable(at: 1))
    }

    func testAFunctionTypedByHandBecomesFoldable() async throws {
        let view = makeEditor(Self.nested)
        try await waitForRegions(in: view, count: 3)

        view.setSelectedRange(NSRange(location: Self.nested.utf16.count, length: 0))
        for character in "func h() {\n  x\n  y\n}\n" {
            view.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0))
        }

        try await waitForRegions(in: view, count: 4)
        XCTAssertTrue(view.isFoldable(at: 14))
    }

    func testALargeEditAboveAFoldKeepsTheFoldVisibleAsFolded() async throws {
        let view = makeEditor(Self.nested)
        try await waitForRegions(in: view, count: 3)
        XCTAssertTrue(view.toggleFold(at: 8))
        let hiddenBefore = hiddenUnits(in: view)
        XCTAssertGreaterThan(hiddenBefore, 0)

        let comment = "// " + String(repeating: "x", count: 150) + "\n"
        view.textContentStorage?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: 0), with: comment)
        try await Task.sleep(nanoseconds: 700_000_000)

        let hiddenAfter = hiddenUnits(in: view)
        // Either the fold survived (gutter says folded, text hidden) or it was
        // dropped (nothing hidden); never hidden text under an expanded chevron.
        if view.isFolded(at: 9) {
            XCTAssertEqual(hiddenAfter, hiddenBefore)
        } else {
            XCTAssertEqual(hiddenAfter, 0)
        }
        XCTAssertTrue(view.isFolded(at: 9), "the fold should follow its region")
    }

    func testFoldAllAndUnfoldAllCoverEveryRegion() async throws {
        let view = makeEditor(Self.nested)
        try await waitForRegions(in: view, count: 3)

        view.foldAll()
        XCTAssertEqual(view.codeFoldingEngine.foldedRegions.count, 3)
        let regions = view.codeFoldingEngine.foldableRegions
        XCTAssertTrue(view.codeFoldingEngine.folds(in: NSRange(location: 0, length: Self.nested.utf16.count))
            .filter { fold in regions.contains { $0.id.uuidString == fold.id } }
            .allSatisfy(\.isCollapsed))

        view.unfoldAll()
        XCTAssertTrue(view.codeFoldingEngine.foldedRegions.isEmpty)
        XCTAssertEqual(hiddenUnits(in: view), 0)
    }

    // MARK: - Unfold restores layout attributes

    func testUnfoldingRestoresTheParagraphStyleAndForeground() async throws {
        let view = makeEditor(Self.nested)
        try await waitForRegions(in: view, count: 3)
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        let probe = try XCTUnwrap(Self.nested.utf16.firstIndex(of: 0x62)).utf16Offset(in: Self.nested)
        let styleBefore = storage.attribute(.paragraphStyle, at: probe, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(styleBefore)

        XCTAssertTrue(view.toggleFold(at: 2))
        XCTAssertTrue(view.toggleFold(at: 2))

        let styleAfter = storage.attribute(.paragraphStyle, at: probe, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(styleAfter, styleBefore)
        XCTAssertNotNil(storage.attribute(.foregroundColor, at: probe, effectiveRange: nil))
        XCTAssertEqual(hiddenUnits(in: view), 0)
    }
}
#endif
