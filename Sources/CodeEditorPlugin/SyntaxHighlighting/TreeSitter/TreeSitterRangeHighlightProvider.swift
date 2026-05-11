import Foundation

// MARK: - Tree-sitter Parser Protocol

/// Pluggable parser interface for Tree-sitter integration.
///
/// During the Phase 5 spike, a regex-backed implementation proves the
/// pipeline works. A real C Tree-sitter parser replaces it in Phase 6
/// without changing the provider's architecture.
internal protocol TreeSitterParserProtocol: AnyObject, Sendable {
    /// Set the language for this parser (load grammar, queries, etc.).
    func setLanguage(_ language: Language) async throws

    /// Parse source text and return a parse result.
    func parse(source: String) async throws -> TreeSitterParseResult

    /// Apply an edit to the existing parse tree (incremental parsing).
    /// Returns the invalidated byte ranges.
    func applyEdit(
        startByte: Int,
        oldEndByte: Int,
        newEndByte: Int
    ) async -> IndexSet
}

// MARK: - Parse Result

/// Result of parsing a document with Tree-sitter.
internal struct TreeSitterParseResult: Sendable {
    /// All capture ranges produced by querying the parse tree.
    let captures: [TreeSitterCapture]

    /// Total parse time in seconds (for benchmarking).
    let parseDuration: TimeInterval

    /// Total query time in seconds.
    let queryDuration: TimeInterval
}

/// A single capture from a Tree-sitter query: a byte range + capture name.
internal struct TreeSitterCapture: Sendable {
    let byteRange: Range<Int>
    let captureName: String
}

// MARK: - Regex-backed Parser (Spike)

/// Regex-backed Tree-sitter parser used during the Phase 5 spike.
///
/// Uses our existing `RegexSyntaxHighlighter` to produce tokens,
/// then converts them into `TreeSitterCapture` results. This proves
/// the `RangeHighlightProviding` pipeline works end-to-end. The real
/// C Tree-sitter parser replaces this in Phase 6.
internal final class RegexBackedTreeSitterParser: TreeSitterParserProtocol, @unchecked Sendable {
    private let regexHighlighter = RegexSyntaxHighlighter()
    private var languageDefinition: RegexLanguageDefinition?
    private var captureMap: TreeSitterCaptureMap = .javascript

    func setLanguage(_ language: Language) async throws {
        guard let definition = regexHighlighter.languageDefinition(for: language) else {
            throw TreeSitterError.languageNotSupported(language)
        }
        languageDefinition = definition
        captureMap = captureMapForLanguage(language)
    }

    func parse(source: String) async throws -> TreeSitterParseResult {
        guard let languageDefinition else {
            throw TreeSitterError.noLanguageSet
        }

        let parseStart = Date()
        let tokens = regexHighlighter.highlight(source: source, language: languageDefinition)
        let parseDuration = Date().timeIntervalSince(parseStart)

        let queryStart = Date()
        let captures = tokens.compactMap { token -> TreeSitterCapture? in
            // Convert NSRange to byte range
            guard let stringRange = Range(token.range, in: source) else { return nil }
            let utf8View = source.utf8
            let byteStart = source[..<stringRange.lowerBound].utf8.count
            let byteEnd = byteStart + source[stringRange].utf8.count
            return TreeSitterCapture(
                byteRange: byteStart..<byteEnd,
                captureName: captureName(for: token.type)
            )
        }
        let queryDuration = Date().timeIntervalSince(queryStart)

        return TreeSitterParseResult(
            captures: captures,
            parseDuration: parseDuration,
            queryDuration: queryDuration
        )
    }

    func applyEdit(startByte _: Int, oldEndByte _: Int, newEndByte _: Int) async -> IndexSet {
        // Regex parser doesn't support incremental editing — invalidate
        // the entire document for now.
        IndexSet(integersIn: 0..<Int.max)
    }

    // MARK: - Helpers

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

    private func captureMapForLanguage(_ language: Language) -> TreeSitterCaptureMap {
        TreeSitterCaptureMap.forLanguage(language)
    }
}

// MARK: - Range Highlight Provider

/// Tree-sitter-backed highlight provider that conforms to
/// `RangeHighlightProviding` and plugs into `RangeBasedHighlightingController`.
///
/// During the Phase 5 spike, uses `RegexBackedTreeSitterParser`;
/// in Phase 6 this is replaced with a real C Tree-sitter parser.
@MainActor
internal final class TreeSitterRangeHighlightProvider: RangeHighlightProviding {
    private let parser: any TreeSitterParserProtocol
    private let captureMap: TreeSitterCaptureMap
    private var currentLanguage: Language = .plainText
    private var documentVersion = 0
    private let logger = CrossPlatformLogger.logger(
        subsystem: "CodeEditorPlugin",
        category: "TreeSitterProvider"
    )

    init(parser: any TreeSitterParserProtocol, captureMap: TreeSitterCaptureMap) {
        self.parser = parser
        self.captureMap = captureMap
    }

    // MARK: - RangeHighlightProviding

    func setUp(textView _: CodeEditorView, language: Language) {
        currentLanguage = language
        documentVersion = 0
        Task {
            do {
                try await parser.setLanguage(language)
                logger.debug("Tree-sitter language set to \(language.name)")
            } catch {
                logger.error("Tree-sitter failed to set language: \(error)")
            }
        }
    }

    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet {
        documentVersion &+= 1

        #if canImport(AppKit)
        guard let source = textView.textStorage?.string else { return IndexSet() }
        #else
        let source = textView.textStorage.string
        #endif

        // Convert NSRange (UTF-16) to byte offsets for Tree-sitter
        let utf16View = source.utf16
        let byteStart = source.utf8.distance(
            from: source.utf8.startIndex,
            to: source.utf8.index(source.utf8.startIndex, offsetBy: range.location)
        )
        let oldByteEnd = byteStart + range.length
        let newByteEnd = byteStart + range.length + delta

        return await parser.applyEdit(
            startByte: byteStart,
            oldEndByte: oldByteEnd,
            newEndByte: newByteEnd
        )
    }

    func queryHighlights(textView: CodeEditorView, range _: NSRange) async throws -> [HighlightedToken] {
        #if canImport(AppKit)
        guard let source = textView.textStorage?.string, !source.isEmpty else { return [] }
        #else
        let source = textView.textStorage.string
        guard !source.isEmpty else { return [] }
        #endif

        let result = try await parser.parse(source: source)

        // Convert captures to HighlightedToken array
        var tokens: [HighlightedToken] = []
        tokens.reserveCapacity(result.captures.count)

        for capture in result.captures {
            let tokenType = captureMap.tokenType(for: capture.captureName)
            guard tokenType != .whitespace else { continue }

            // Convert byte range back to NSRange (UTF-16)
            let utf8View = source.utf8
            let byteStartIndex = utf8View.index(utf8View.startIndex, offsetBy: capture.byteRange.lowerBound)
            let byteEndIndex = utf8View.index(utf8View.startIndex, offsetBy: capture.byteRange.upperBound)
            let stringRange = byteStartIndex..<byteEndIndex

            let nsRange = NSRange(stringRange, in: source)
            let text = String(source[stringRange])

            tokens.append(HighlightedToken(range: nsRange, type: tokenType, text: text))
        }

        return tokens
    }
}

// MARK: - Provider Factory

extension TreeSitterRangeHighlightProvider {
    /// Creates a provider for the given language using the spike regex-backed parser.
    ///
    /// In Phase 6 this switches to a real C Tree-sitter parser. Currently
    /// supports all 26 languages via `RegexBackedTreeSitterParser`.
    static func makeSpikeProvider(for language: Language) -> TreeSitterRangeHighlightProvider? {
        // Only create a provider for languages with a Tree-sitter grammar name
        // (Swift uses SwiftSyntax; plainText has no highlighting)
        guard LanguageDescriptor.descriptor(for: language)?.treeSitterName != nil else {
            return nil
        }

        let captureMap = TreeSitterCaptureMap.forLanguage(language)
        let parser = RegexBackedTreeSitterParser()
        return TreeSitterRangeHighlightProvider(parser: parser, captureMap: captureMap)
    }
}

// MARK: - Errors

internal enum TreeSitterError: Error {
    case languageNotSupported(Language)
    case noLanguageSet
    case parseFailed(String)
}
