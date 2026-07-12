@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import Foundation
import XCTest

/// Regression: `Languages/Data/SqlLanguageDescriptor.swift` declares its
/// keyword / type / function lists in uppercase, but the keyword pattern
/// `RegexSyntaxHighlighter+LanguagesExtensions.wordPattern(for:)` builds is
/// case-sensitive. Lowercase SQL — the common case in real codebases —
/// gets zero keyword highlighting (REVIEW.md SyntaxHighlighting/Critical).
final class SqlCaseInsensitiveKeywordTests: XCTestCase {
    /// Helper: parse `source` as SQL and return the substrings that received
    /// the given `captureName`.
    @MainActor
    private func capturedSubstrings(
        for source: String, captureName: String
    ) async throws -> [String] {
        let parser = RegexIncrementalRangeQueryParser()
        try await parser.setLanguage(.sql)
        let result = try await parser.parse(source: source)
        let bytes = Array(source.utf8)
        return result.captures
            .filter { $0.captureName == captureName }
            .compactMap { capture in
                let slice = bytes[capture.byteRange]
                return String(data: Data(slice), encoding: .utf8)
            }
    }

    @MainActor
    func testLowercaseSelectFromWhereAreHighlightedAsKeywords() async throws {
        let source = "select id from users where active = 1"
        let keywords = try await capturedSubstrings(for: source, captureName: "keyword")
        // The exact set "select"/"from"/"where" must all be present; the
        // legacy uppercase-only pattern produced none of them.
        XCTAssertTrue(keywords.contains("select"), "expected `select` to be highlighted as keyword, got \(keywords)")
        XCTAssertTrue(keywords.contains("from"), "expected `from` to be highlighted as keyword, got \(keywords)")
        XCTAssertTrue(keywords.contains("where"), "expected `where` to be highlighted as keyword, got \(keywords)")
    }

    @MainActor
    func testUppercaseSqlStillWorks() async throws {
        let source = "SELECT id FROM users WHERE active = 1"
        let keywords = try await capturedSubstrings(for: source, captureName: "keyword")
        XCTAssertTrue(keywords.contains("SELECT"), "expected `SELECT` (uppercase) to still highlight, got \(keywords)")
        XCTAssertTrue(keywords.contains("FROM"), "expected `FROM` (uppercase) to still highlight, got \(keywords)")
        XCTAssertTrue(keywords.contains("WHERE"), "expected `WHERE` (uppercase) to still highlight, got \(keywords)")
    }

    @MainActor
    func testLowercaseTypesAreCapturedAsType() async throws {
        // `int` and `varchar` are in `SqlLanguageDescriptor.types`. The
        // generic function-call rule cannot fire here (no `(` follows), so
        // the only way these get a `type` capture is the type word-pattern
        // matching case-insensitively.
        let source = "create table t (id int, name varchar)"
        let types = try await capturedSubstrings(for: source, captureName: "type")
        XCTAssertTrue(types.contains("int"), "expected lowercase `int` to be highlighted as type, got \(types)")
        XCTAssertTrue(types.contains("varchar"), "expected lowercase `varchar` to be highlighted as type, got \(types)")
    }
}
