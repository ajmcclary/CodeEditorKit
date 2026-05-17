import CodeEditorLanguages
import Foundation

// MARK: - Range Query Parser Protocol

/// Pluggable parser interface for range-scoped syntax highlighting.
package protocol RangeQueryParserProtocol: AnyObject, Sendable {
    /// Set the language for this parser.
    func setLanguage(_ language: Language) async throws

    /// Parse source text and return a parse result.
    func parse(source: String) async throws -> RangeQueryParseResult

    /// Apply an edit to the existing parser state.
    /// Returns the invalidated byte ranges.
    func applyEdit(
        startByte: Int,
        oldEndByte: Int,
        newEndByte: Int
    ) async -> IndexSet
}

// MARK: - Parse Result

/// Result of parsing a document for range-scoped highlighting.
package struct RangeQueryParseResult: Sendable {
    /// All capture ranges produced by the parser.
    package let captures: [RangeQueryCapture]

    /// Total parse time in seconds (for benchmarking).
    package let parseDuration: TimeInterval

    /// Total query time in seconds.
    package let queryDuration: TimeInterval

    package init(captures: [RangeQueryCapture], parseDuration: TimeInterval, queryDuration: TimeInterval) {
        self.captures = captures
        self.parseDuration = parseDuration
        self.queryDuration = queryDuration
    }
}

/// A single query capture: a byte range + capture name.
package struct RangeQueryCapture: Sendable {
    package let byteRange: Range<Int>
    package let captureName: String

    package init(byteRange: Range<Int>, captureName: String) {
        self.byteRange = byteRange
        self.captureName = captureName
    }
}

// MARK: - Errors

package enum RangeQueryParserError: Error {
    case languageNotSupported(Language)
    case noLanguageSet
    case parseFailed(String)
}
