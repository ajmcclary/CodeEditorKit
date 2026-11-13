@testable import CodeEditorCompletion
@testable import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
import Foundation
import XCTest

final class RegexHighlighterCostTests: XCTestCase {
    /// CPU seconds on this thread: a loaded machine does not inflate it.
    private func seconds(_ body: () -> Void) -> TimeInterval {
        CPUTime.onThread(body).seconds
    }

    func testHighlightersShareCompiledLanguageDefinitions() throws {
        let first = RegexSyntaxHighlighter()
        let second = RegexSyntaxHighlighter()
        let firstRule = try XCTUnwrap(first.languageDefinition(for: .javascript)?.rules.first)
        let secondRule = try XCTUnwrap(second.languageDefinition(for: .javascript)?.rules.first)
        XCTAssertIdentical(firstRule.pattern, secondRule.pattern, "every instance recompiled ~300 patterns")
    }

    func testALongDigitRunFollowedByALetterIsLinear() throws {
        let highlighter = RegexSyntaxHighlighter()
        let definition = try XCTUnwrap(highlighter.languageDefinition(for: .javascript))
        let source = "x = " + String(repeating: "1", count: 40_000) + "a;"
        let elapsed = seconds { _ = highlighter.highlight(source: source, language: definition) }
        XCTAssertLessThan(elapsed, 10, "number rule took \(elapsed)s")

        let numbers = highlighter.highlight(source: "a = 1.5 + 2. + 3", language: definition)
            .filter { $0.type == .number }
            .map(\.text)
        XCTAssertEqual(numbers, ["1.5", "2", "3"])
    }

    func testMemberTargetExtractionIsBoundedOnLongWordRuns() {
        let text = String(repeating: "a", count: 20_000) + " b."
        var target: String?
        let elapsed = seconds { target = CompletionParsingHelpers.extractTargetForDotNotation(from: text) }
        XCTAssertEqual(target, "b")
        XCTAssertLessThan(elapsed, 10, "target extraction took \(elapsed)s")

        let longRun = String(repeating: "a", count: 20_000)
        let runElapsed = seconds { _ = CompletionParsingHelpers.extractTargetForDotNotation(from: longRun) }
        XCTAssertLessThan(runElapsed, 10, "target extraction took \(runElapsed)s")
    }
}
