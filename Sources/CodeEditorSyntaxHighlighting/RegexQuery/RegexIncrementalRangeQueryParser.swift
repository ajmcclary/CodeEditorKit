import CodeEditorLanguages
import Foundation

// MARK: - Regex Incremental Range Query Parser

/// A parser implementation conforming to `RangeQueryParserProtocol`.
///
/// **Current backend**: `RegexSyntaxHighlighter` with bounded incremental
/// invalidation around edits.
///
/// Parser state is isolated behind an actor so queries and edits can
/// proceed concurrently without data races.
package final class RegexIncrementalRangeQueryParser: RangeQueryParserProtocol, @unchecked Sendable {
    // MARK: - Actor-isolated state

    private actor State {
        var language: Language?
        /// Snapshot of the last-parsed source, used for incremental edit
        /// byte-range computation.
        var lastSource: String = ""

        func setLanguage(_ newLanguage: Language) {
            language = newLanguage
        }

        func recordSource(_ source: String) {
            lastSource = source
        }

        /// Converts a UTF-16 `NSRange` into a UTF-8 byte range using the
        /// stored source snapshot.
        func byteRange(forUTF16Range range: NSRange) -> Range<Int>? {
            guard let stringRange = Range(range, in: lastSource) else { return nil }
            let lower = lastSource[..<stringRange.lowerBound].utf8.count
            let upper = lastSource[..<stringRange.upperBound].utf8.count
            return lower..<upper
        }

        /// Converts a UTF-8 byte range into a UTF-16 `NSRange`.
        func utf16Range(forByteRange byteRange: Range<Int>) -> NSRange? {
            guard byteRange.lowerBound >= 0,
                  byteRange.upperBound >= byteRange.lowerBound,
                  byteRange.upperBound <= lastSource.utf8.count else { return nil }

            let utf8 = lastSource.utf8
            guard let lower8 = utf8.index(utf8.startIndex, offsetBy: byteRange.lowerBound, limitedBy: utf8.endIndex),
                  let upper8 = utf8.index(utf8.startIndex, offsetBy: byteRange.upperBound, limitedBy: utf8.endIndex),
                  let lowerIdx = String.Index(lower8, within: lastSource),
                  let upperIdx = String.Index(upper8, within: lastSource) else { return nil }

            let utf16 = lastSource.utf16
            let start = utf16.distance(from: utf16.startIndex, to: lowerIdx)
            let end = utf16.distance(from: utf16.startIndex, to: upperIdx)
            return NSRange(location: start, length: end - start)
        }
    }

    // MARK: - Constants

    private let maxSyncContentLength = 1_000_000
    private let contextChars = 4_096

    // MARK: - Dependencies

    private let state = State()
    private let regexHighlighter = RegexSyntaxHighlighter()

    // MARK: - RangeQueryParserProtocol

    package init() {}

    package func setLanguage(_ language: Language) async throws {
        await state.setLanguage(language)
    }

    package func parse(source: String) async throws -> RangeQueryParseResult {
        let parseStart = Date()

        guard let language = await state.language else {
            throw RangeQueryParserError.noLanguageSet
        }

        // For very large files, skip parsing (return empty captures).
        if source.utf8.count > maxSyncContentLength {
            return RangeQueryParseResult(
                captures: [],
                parseDuration: 0,
                queryDuration: 0
            )
        }

        await state.recordSource(source)

        // Produce captures via the regex highlighter.
        let tokens = highlightTokens(for: language, source: source)
        let parseDuration = Date().timeIntervalSince(parseStart)

        let queryStart = Date()
        var captures: [RangeQueryCapture] = []
        captures.reserveCapacity(tokens.count)

        for token in tokens {
            guard let stringRange = Range(token.range, in: source) else { continue }
            let byteStart = source[..<stringRange.lowerBound].utf8.count
            let byteEnd = source[..<stringRange.upperBound].utf8.count
            captures.append(
                RangeQueryCapture(
                    byteRange: byteStart..<byteEnd,
                    captureName: captureName(for: token.type)
                )
            )
        }
        let queryDuration = Date().timeIntervalSince(queryStart)

        return RangeQueryParseResult(
            captures: captures,
            parseDuration: parseDuration,
            queryDuration: queryDuration
        )
    }

    package func applyEdit(
        startByte: Int,
        oldEndByte _: Int,
        newEndByte: Int
    ) async -> IndexSet {
        // Compute the invalidated byte range with surrounding context.
        // Bounded invalidation is significantly better than the spike's
        // full-document invalidation.
        let contextStart = max(0, startByte - contextChars)
        let contextEnd = newEndByte + contextChars
        let invalidByteRange = contextStart..<max(contextStart, contextEnd)

        guard let invalidCharRange = await state.utf16Range(forByteRange: invalidByteRange) else {
            // Fall back to full invalidation when mapping is unavailable.
            return IndexSet(integersIn: 0..<Int.max)
        }

        let lower = invalidCharRange.location
        let upper = invalidCharRange.location + invalidCharRange.length
        guard lower < upper else {
            return IndexSet(integersIn: 0..<Int.max)
        }
        return IndexSet(integersIn: lower..<upper)
    }

    // MARK: - Internal highlighting

    private func highlightTokens(for language: Language, source: String) -> [HighlightedToken] {
        guard let definition = regexHighlighter.languageDefinition(for: language) else {
            return []
        }
        return regexHighlighter.highlight(source: source, language: definition)
    }

    private func captureName(for tokenType: TokenType) -> String {
        switch tokenType {
        case .keyword: return "keyword"
        case .string: return "string"
        case .number: return "number"
        case .comment: return "comment"
        case .function: return "function"
        case .type: return "type"
        case .property: return "property"
        case .operator: return "operator"
        case .punctuation: return "punctuation"
        case .identifier: return "variable"
        case .preprocessor: return "keyword"
        case .whitespace: return "whitespace"
        case .unknown: return "unknown"
        }
    }
}
