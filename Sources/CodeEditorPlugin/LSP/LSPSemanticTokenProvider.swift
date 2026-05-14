import Foundation

// MARK: - LSP Semantic Token Provider

/// A `RangeHighlightProviding` adapter that feeds LSP semantic tokens
/// into the range-store highlighting pipeline at priority -1 (higher
/// than syntax token priority 0, so semantic tokens override syntax).
///
/// ## Refresh ordering (critical)
///
/// The provider does **not** call the server inside `applyEdit` — doing
/// so would race the server before it has processed the `didChange`
/// notification. Instead it subscribes to `LSPContentCoordinator.onBatchFlushed`
/// (Phase 4) and requests updated tokens only after the server has
/// acknowledged the document change.
///
/// ## Token type mapping
///
/// LSP token type indices (from the server's `SemanticTokensLegend`) are
/// resolved to `TokenType` via a standard mapping table. Unrecognized
/// types map to `.identifier`.
@MainActor
final class LSPSemanticTokenProvider: RangeHighlightProviding {
    // MARK: - Token type mapping

    /// Standard LSP token type names → `TokenType`. Index in this array
    /// corresponds to the server's `SemanticTokensLegend.tokenTypes`.
    private static let lspTokenTypes: [TokenType] = [
        .type,          // 0: namespace
        .type,          // 1: type
        .type,          // 2: class
        .type,          // 3: enum
        .type,          // 4: interface
        .type,          // 5: struct
        .type,          // 6: typeParameter
        .identifier,    // 7: parameter
        .identifier,    // 8: variable
        .property,      // 9: property
        .property,      // 10: enumMember
        .identifier,    // 11: event
        .function,      // 12: function
        .function,      // 13: method
        .function,      // 14: macro
        .keyword,       // 15: keyword
        .keyword,       // 16: modifier
        .comment,       // 17: comment
        .string,        // 18: string
        .number,        // 19: number
        .string,        // 20: regexp
        .operator,      // 21: operator
        .function      // 22: decorator
    ]

    // MARK: - State

    private let storage = LSPSemanticTokenStorage()
    private let lspManager: LSPManager
    private let filePath: String
    private var textView: CodeEditorView?
    private var isSetup = false

    /// Called when full or delta token responses update local storage.
    /// The controller uses this to invalidate and repaint visible ranges.
    var onTokensUpdated: (@MainActor (IndexSet) -> Void)?

    // MARK: - Initialization

    init(lspManager: LSPManager, filePath: String) {
        self.lspManager = lspManager
        self.filePath = filePath
    }

    // MARK: - RangeHighlightProviding

    func setUp(textView: CodeEditorView, language: Language) {
        self.textView = textView
        isSetup = true

        // Request initial full semantic tokens.
        let uri = "file://\(filePath)"
        Task { [weak self] in
            guard let self else { return }
            do {
                let client = self.lspManager.client(
                    for: language.lspIdentifier
                )
                let tokens = try await client?.requestSemanticTokens(uri: uri)
                if let tokens {
                    self.storage.applyFull(tokens)
                    self.notifyTokensUpdated()
                }
            } catch {
                // Non-fatal — server may not support semantic tokens.
                let logger = CrossPlatformLogger.logger(
                    subsystem: "com.codeeditor.lsp",
                    category: "SemanticTokens"
                )
                logger.debug("Semantic tokens unavailable: \(error.localizedDescription)")
            }
        }
    }

    func willApplyEdit(textView _: CodeEditorView, range _: NSRange) {
        // No-op: the server manages its own state.
    }

    func willApplyEdit(textView _: CodeEditorView, source _: String, range _: NSRange) {
        // No-op.
    }

    func applyEdit(textView: CodeEditorView, range _: NSRange, delta _: Int) async -> IndexSet {
        // Do NOT request tokens from the server here — the server hasn't
        // received the didChange yet. Refresh is triggered from the
        // post-batch hook instead. Return the full document as invalidated
        // so the visible range is re-queried after refresh.
        let length = textView.textKitBridge.documentLength
        return IndexSet(integersIn: 0..<max(1, length))
    }

    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        guard isSetup, !storage.isEmpty else { return [] }

        // Convert the character range to a line range.
        let source = textView.textKitBridge.documentString
        guard !source.isEmpty else { return [] }
        let lineRange = lineNumbers(in: source, for: range)

        let decoded = storage.tokens(in: lineRange)
        guard !decoded.isEmpty else { return [] }

        var tokens: [HighlightedToken] = []
        tokens.reserveCapacity(decoded.count)

        for dt in decoded {
            let tokenType = Self.tokenType(for: dt.tokenType)
            guard tokenType != .whitespace else { continue }

            // Compute the UTF-16 range from (line, startChar, length).
            guard let utf16Range = utf16Range(
                line: dt.line,
                startChar: dt.startChar,
                length: dt.length,
                in: source
            ) else { continue }

            // Intersect with the query range.
            let intersection = NSIntersectionRange(utf16Range, range)
            guard intersection.length > 0 else { continue }

            guard
                let startIdx = source.utf16.index(
                    source.utf16.startIndex,
                    offsetBy: intersection.location,
                    limitedBy: source.utf16.endIndex
                ),
                let endIdx = source.utf16.index(
                    startIdx,
                    offsetBy: intersection.length,
                    limitedBy: source.utf16.endIndex
                ),
                let stringStart = String.Index(startIdx, within: source),
                let stringEnd = String.Index(endIdx, within: source)
            else { continue }
            let text = String(source[stringStart..<stringEnd])
            tokens.append(HighlightedToken(range: intersection, type: tokenType, text: text))
        }

        return tokens
    }

    // MARK: - Post-batch refresh

    /// Should be called from `LSPContentCoordinator.onBatchFlushed`.
    /// Requests updated semantic tokens from the server and invalidates
    /// affected ranges.
    func refreshAfterBatch(textView _: CodeEditorView) {
        guard isSetup else { return }

        let uri = "file://\(filePath)"
        let fileExtension = URL(fileURLWithPath: filePath).pathExtension
        let langId = lspManager.languageId(for: fileExtension) ?? ""

        Task { [weak self] in
            guard let self else { return }
            do {
                let client = self.lspManager.client(for: langId)
                if let resultId = self.storage.resultId {
                    // Server supports deltas.
                    let delta = try await client?.requestSemanticTokensDelta(
                        uri: uri,
                        previousResultId: resultId
                    )
                    if let delta {
                        self.storage.applyDelta(delta)
                        self.notifyTokensUpdated()
                    }
                } else {
                    // Full refresh.
                    let tokens = try await client?.requestSemanticTokens(uri: uri)
                    if let tokens {
                        self.storage.applyFull(tokens)
                        self.notifyTokensUpdated()
                    }
                }
            } catch {
                // Non-fatal.
            }
        }
    }

    // MARK: - Helpers

    private static func tokenType(for lspIndex: Int) -> TokenType {
        guard lspIndex >= 0, lspIndex < lspTokenTypes.count else {
            return .identifier
        }
        return lspTokenTypes[lspIndex]
    }

    private func notifyTokensUpdated() {
        let length = textView?.textKitBridge.documentLength ?? 0
        guard length > 0 else { return }
        onTokensUpdated?(IndexSet(integersIn: 0..<length))
    }

    /// Converts a (0-based line, 0-based character, length) triplet
    /// to a UTF-16 `NSRange`.
    private func utf16Range(
        line: Int,
        startChar: Int,
        length: Int,
        in source: String
    ) -> NSRange? {
        let utf16 = source.utf16
        let totalLength = utf16.count

        // Find the start of the requested line by counting newlines.
        var lineStart = 0
        var currentLine = 0
        var pos = 0
        var idx = utf16.startIndex

        while currentLine < line, idx < utf16.endIndex {
            if utf16[idx] == 0x0A { // U+000A LINE FEED
                currentLine &+= 1
                lineStart = pos &+ 1
            }
            utf16.formIndex(after: &idx)
            pos &+= 1
        }

        let offset = lineStart + startChar
        guard offset < totalLength else { return nil }

        let clampedLength = min(length, totalLength - offset)
        guard clampedLength > 0 else { return nil }

        return NSRange(location: offset, length: clampedLength)
    }

    /// Returns the 0-based line range intersecting the given character range.
    private func lineNumbers(
        in source: String,
        for range: NSRange
    ) -> ClosedRange<Int> {
        let utf16 = source.utf16
        let totalLength = utf16.count
        let startLine = lineNumber(at: range.location, utf16: utf16)
        let endPos = min(range.location + range.length, totalLength)
        let endLine = endPos > range.location
            ? lineNumber(at: endPos, utf16: utf16)
            : startLine
        return startLine...endLine
    }

    private func lineNumber(at offset: Int, utf16: String.UTF16View) -> Int {
        var line = 0
        var pos = 0
        var idx = utf16.startIndex
        while pos < offset, idx < utf16.endIndex {
            if utf16[idx] == 0x0A { // U+000A LINE FEED
                line &+= 1
            }
            utf16.formIndex(after: &idx)
            pos &+= 1
        }
        return line
    }
}
