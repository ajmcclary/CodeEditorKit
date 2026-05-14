import Foundation

// MARK: - Range Query Parser Protocol

/// Pluggable parser interface for range-scoped syntax highlighting.
internal protocol RangeQueryParserProtocol: AnyObject, Sendable {
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
internal struct RangeQueryParseResult: Sendable {
    /// All capture ranges produced by the parser.
    let captures: [RangeQueryCapture]

    /// Total parse time in seconds (for benchmarking).
    let parseDuration: TimeInterval

    /// Total query time in seconds.
    let queryDuration: TimeInterval
}

/// A single query capture: a byte range + capture name.
internal struct RangeQueryCapture: Sendable {
    let byteRange: Range<Int>
    let captureName: String
}

// MARK: - Range Highlight Provider

/// Regex-backed highlight provider that conforms to `RangeHighlightProviding`
/// and plugs into `RangeBasedHighlightingController`.
@MainActor
internal final class RegexRangeHighlightProvider: RangeHighlightProviding {
    private struct PreEditSnapshot {
        let source: String
        let range: NSRange
    }

    private let parser: any RangeQueryParserProtocol
    private let captureMap: QueryCaptureMap
    private var currentLanguage: Language = .plainText
    private var documentVersion = 0
    private var setupTask: Task<Void, Error>?
    private var preEditSnapshots: [PreEditSnapshot] = []
    private var cachedSource: String?
    private var cachedResult: RangeQueryParseResult?
    private let logger = CrossPlatformLogger.logger(
        subsystem: "CodeEditorPlugin",
        category: "RegexRangeProvider"
    )

    init(parser: any RangeQueryParserProtocol, captureMap: QueryCaptureMap) {
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
            logger.error("Regex range provider setup failed before edit: \(error)")
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

    private func parseResult(for source: String) async throws -> RangeQueryParseResult {
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
        textView.textKitBridge.documentString
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

extension RegexRangeHighlightProvider {
    /// Creates a provider for the given language.
    static func makeProvider(for language: Language) -> RegexRangeHighlightProvider? {
        guard LanguageDescriptor.descriptor(for: language)?.usesRegexHighlighter == true else {
            return nil
        }

        let captureMap = QueryCaptureMap.forLanguage(language)
        let parser = RegexIncrementalRangeQueryParser()
        return RegexRangeHighlightProvider(parser: parser, captureMap: captureMap)
    }
}

// MARK: - Errors

internal enum RangeQueryParserError: Error {
    case languageNotSupported(Language)
    case noLanguageSet
    case parseFailed(String)
}
