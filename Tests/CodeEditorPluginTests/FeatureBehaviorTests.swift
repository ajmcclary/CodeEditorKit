@testable import CodeEditorPlugin
import XCTest

@MainActor
final class FeatureBehaviorTests: CleanupTestCase {
    func testSearchReplaceFindsAndReplacesAllMatches() async {
        let editor = createCodeEditorView()
        editor.text = """
        let foo = 1
        foo += 1
        print(foo)
        """

        var options = SearchOptions()
        options.highlightResults = false
        options.flashResult = false

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)

        let results = await engine.findAll(pattern: "foo", options: options)
        XCTAssertEqual(results.map(\.lineNumber), [1, 2, 3])
        XCTAssertEqual(engine.searchStatistics.totalMatches, 3)

        let replacementCount = await engine.replaceAll(pattern: "foo", with: "bar", options: options)
        XCTAssertEqual(replacementCount, 3)
        let editedText = editor.text ?? ""
        XCTAssertFalse(editedText.contains("foo"))
        XCTAssertTrue(editedText.contains("print(bar)"))
    }

    func testCodeFoldingDetectsAndTogglesSwiftRegions() async throws {
        let editor = createCodeEditorView()
        editor.language = .swift
        editor.text = """
        struct Example {
            func message() -> String {
                let value = "Hello"
                return value
            }
        }
        """

        let engine = CodeFoldingEngine()
        engine.configuration.minimumLineCount = 1
        engine.configuration.hidesFoldedContent = false
        engine.attach(to: editor)
        engine.updateFoldableRegions()

        let region = try await waitForFoldableRegion(in: engine)
        XCTAssertEqual(engine.folds(in: region.range).first?.range, region.range)

        XCTAssertTrue(engine.fold(region))
        XCTAssertTrue(engine.foldedRegions.contains(region.id))
        XCTAssertEqual(engine.folds(in: region.range).first?.isCollapsed, true)
        XCTAssertFalse(engine.fold(region))

        XCTAssertTrue(engine.unfold(region))
        XCTAssertFalse(engine.foldedRegions.contains(region.id))
        XCTAssertEqual(engine.folds(in: region.range).first?.isCollapsed, false)

        editor.textEditEventHub.publish(TextEditEvent(
            editedRange: NSRange(location: 0, length: 0),
            changeInLength: 2,
            documentLength: TextRangeUtilities.utf16Length(of: editor.text ?? "") + 2,
            editedCharacters: true
        ))
        let shiftedFold = engine.folds(in: NSRange(location: 0, length: NSMaxRange(region.range) + 2))
            .first { $0.id == region.id.uuidString }
        XCTAssertEqual(shiftedFold?.range.location, region.range.location + 2)
    }

    private func waitForFoldableRegion(in engine: CodeFoldingEngine) async throws -> FoldableRegion {
        for _ in 0..<20 {
            if let region = engine.foldableRegions.first {
                return region
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTFail("Expected at least one foldable region")
        throw CancellationError()
    }
}
