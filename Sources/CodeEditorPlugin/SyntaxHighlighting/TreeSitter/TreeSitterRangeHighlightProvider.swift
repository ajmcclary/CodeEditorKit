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
    private struct PreEditSnapshot {
        let source: String
        let range: NSRange
    }

    private let parser: any TreeSitterParserProtocol
    private let captureMap: TreeSitterCaptureMap
    private var currentLanguage: Language = .plainText
    private var documentVersion = 0
    private var setupTask: Task<Void, Error>?
    private var preEditSnapshots: [PreEditSnapshot] = []
    private var cachedSource: String?
    private var cachedResult: TreeSitterParseResult?
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
        preEditSnapshots.removeAll()
        cachedSource = nil
        cachedResult = nil
        setupTask?.cancel()

        let parser = self.parser
        setupTask = Task {
            try await parser.setLanguage(language)
        }
    }

    func willApplyEdit(textView: CodeEditorView, range: NSRange) {
        recordPreEditSnapshot(source: Self.sourceString(from: textView), range: range)
    }

    func willApplyEdit(textView _: CodeEditorView, source: String, range: NSRange) {
        recordPreEditSnapshot(source: source, range: range)
    }

    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet {
        documentVersion &+= 1
        cachedSource = nil
        cachedResult = nil

        do {
            try await awaitSetup()
        } catch {
            logger.error("Tree-sitter setup failed before edit: \(error)")
            return IndexSet()
        }

        let source = Self.sourceString(from: textView)
        let sourceLength = TextRangeUtilities.utf16Length(of: source)
        let fullInvalidation = IndexSet(integersIn: 0..<sourceLength)

        guard let snapshotIndex = preEditSnapshots.firstIndex(where: { $0.range == range }) else {
            logger.warning("Missing pre-edit source snapshot; invalidating full document")
            return fullInvalidation
        }
        let snapshot = preEditSnapshots.remove(at: snapshotIndex)

        let newLength = max(0, range.length + delta)
        let newRange = NSRange(location: range.location, length: newLength)
        guard let oldByteRange = Self.byteRange(forUTF16Range: range, in: snapshot.source),
              let newByteRange = Self.byteRange(forUTF16Range: newRange, in: source) else {
            logger.warning("Unable to translate UTF-16 edit range to UTF-8 bytes; invalidating full document")
            return fullInvalidation
        }

        return await parser.applyEdit(
            startByte: oldByteRange.lowerBound,
            oldEndByte: oldByteRange.upperBound,
            newEndByte: newByteRange.upperBound
        )
    }

    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        try await awaitSetup()

        let source = Self.sourceString(from: textView)
        guard !source.isEmpty else { return [] }

        let sourceLength = TextRangeUtilities.utf16Length(of: source)
        let clampedRange = TextRangeUtilities.clampRange(range, toTextLength: sourceLength)
        guard clampedRange.length > 0 else { return [] }

        let result = try await parseResult(for: source)

        // Convert captures to HighlightedToken array
        var tokens: [HighlightedToken] = []
        tokens.reserveCapacity(result.captures.count)

        for capture in result.captures {
            let tokenType = captureMap.tokenType(for: capture.captureName)
            guard tokenType != .whitespace else { continue }

            // Convert byte range back to NSRange (UTF-16)
            guard let stringRange = Self.stringRange(forByteRange: capture.byteRange, in: source) else {
                continue
            }

            let nsRange = NSRange(stringRange, in: source)
            let intersection = NSIntersectionRange(nsRange, clampedRange)
            guard intersection.length > 0,
                  let text = TextRangeUtilities.substring(inUTF16Range: intersection, from: source) else {
                continue
            }

            tokens.append(HighlightedToken(range: intersection, type: tokenType, text: text))
        }

        return tokens
    }

    private func awaitSetup() async throws {
        if let setupTask {
            try await setupTask.value
        }
    }

    private func parseResult(for source: String) async throws -> TreeSitterParseResult {
        if cachedSource == source, let cachedResult {
            return cachedResult
        }

        let result = try await parser.parse(source: source)
        cachedSource = source
        cachedResult = result
        return result
    }

    private func recordPreEditSnapshot(source: String, range: NSRange) {
        preEditSnapshots.append(PreEditSnapshot(source: source, range: range))
        let maximumRetainedSnapshots = 32
        if preEditSnapshots.count > maximumRetainedSnapshots {
            preEditSnapshots.removeFirst(preEditSnapshots.count - maximumRetainedSnapshots)
        }
    }

    private static func sourceString(from textView: CodeEditorView) -> String {
        #if canImport(AppKit)
        textView.textStorage?.string ?? ""
        #else
        textView.textStorage.string
        #endif
    }

    private static func byteRange(forUTF16Range range: NSRange, in source: String) -> Range<Int>? {
        guard let stringRange = Range(range, in: source) else { return nil }
        let lowerBound = source[..<stringRange.lowerBound].utf8.count
        let upperBound = source[..<stringRange.upperBound].utf8.count
        return lowerBound..<upperBound
    }

    private static func stringRange(forByteRange byteRange: Range<Int>, in source: String) -> Range<String.Index>? {
        guard byteRange.lowerBound >= 0,
              byteRange.upperBound >= byteRange.lowerBound,
              byteRange.upperBound <= source.utf8.count else {
            return nil
        }

        let utf8View = source.utf8
        guard let lowerByteIndex = utf8View.index(
            utf8View.startIndex,
            offsetBy: byteRange.lowerBound,
            limitedBy: utf8View.endIndex
        ),
            let upperByteIndex = utf8View.index(
                utf8View.startIndex,
                offsetBy: byteRange.upperBound,
                limitedBy: utf8View.endIndex
            ),
            let lowerIndex = String.Index(lowerByteIndex, within: source),
            let upperIndex = String.Index(upperByteIndex, within: source) else {
            return nil
        }

        return lowerIndex..<upperIndex
    }
}

// MARK: - Provider Factory

extension TreeSitterRangeHighlightProvider {
    /// Creates a provider for the given language.
    ///
    /// Uses `TreeSitterParser` (with bounded incremental invalidation)
    /// instead of the spike's `RegexBackedTreeSitterParser`. The parser
    /// backend is still regex-backed until a companion package provides real
    /// C grammar loading.
    static func makeProvider(for language: Language) -> TreeSitterRangeHighlightProvider? {
        guard LanguageDescriptor.descriptor(for: language)?.treeSitterName != nil else {
            return nil
        }

        let captureMap = TreeSitterCaptureMap.forLanguage(language)
        let parser = TreeSitterParser()
        return TreeSitterRangeHighlightProvider(parser: parser, captureMap: captureMap)
    }
}

// MARK: - Errors

internal enum TreeSitterError: Error {
    case languageNotSupported(Language)
    case noLanguageSet
    case parseFailed(String)
}
