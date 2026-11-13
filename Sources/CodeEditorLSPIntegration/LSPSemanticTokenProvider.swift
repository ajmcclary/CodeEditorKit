import CodeEditorCommon
import CodeEditorHighlightingCore
import CodeEditorLSP
import CodeEditorSyntaxHighlighting
import Foundation

// MARK: - LSP Semantic Token Provider

/// A value-oriented ``HighlightRangeProviding`` adapter that feeds LSP semantic
/// tokens into the editor's range-store highlighting pipeline at priority -1
/// (higher than syntax token priority 0, so semantic tokens override syntax).
///
/// The provider consumes immutable ``HighlightDocumentSnapshot`` values — it
/// never touches the editor view — so it lives entirely in the
/// `CodeEditorLSPIntegration` product, out of `CodeEditorView`.
///
/// ## Refresh ordering (critical)
///
/// The provider does **not** call the server inside ``invalidate(for:in:)`` —
/// doing so would race the server before it has processed the `didChange`
/// notification. Instead it is refreshed via ``refreshAfterBatch()``, driven
/// from `LSPContentCoordinator.onBatchFlushed`, only after the server has
/// acknowledged the document change.
///
/// ## Token type mapping
///
/// LSP token type indices are resolved through the server's
/// `SemanticTokensLegend` (from `initialize`) to a type name, and the name
/// to a `TokenType`; without a legend the standard LSP order is assumed.
/// Unrecognized types map to `.identifier`.
@MainActor
final class LSPSemanticTokenProvider: HighlightRangeProviding {
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

    /// LSP token type names → `TokenType` (the standard names above, by name).
    private static let tokenTypesByName: [String: TokenType] = [
        "namespace": .type, "type": .type, "class": .type, "enum": .type,
        "interface": .type, "struct": .type, "typeParameter": .type,
        "parameter": .identifier, "variable": .identifier, "property": .property,
        "enumMember": .property, "event": .identifier, "function": .function,
        "method": .function, "macro": .function, "keyword": .keyword,
        "modifier": .keyword, "comment": .comment, "string": .string,
        "number": .number, "regexp": .string, "operator": .operator,
        "decorator": .function
    ]

    // MARK: - State

    private let storage = LSPSemanticTokenStorage()
    private let lspManager: LSPManager
    private let filePath: String
    private var lastDocumentLength = 0
    private var isSetup = false

    /// Called when full or delta token responses update local storage.
    /// The controller uses this to invalidate and repaint visible ranges.
    var onTokensUpdated: (@MainActor (IndexSet) -> Void)?

    // MARK: - Initialization

    init(lspManager: LSPManager, filePath: String) {
        self.lspManager = lspManager
        self.filePath = filePath
    }

    // MARK: - HighlightRangeProviding

    func prepare(for document: HighlightDocumentSnapshot) async {
        lastDocumentLength = document.utf16Length
        isSetup = true

        // Request initial full semantic tokens.
        let uri = LSPDocumentURI.uri(forFilePath: filePath)
        do {
            let client = lspManager.client(for: document.languageID)
            storage.setLegend(client?.serverCapabilities?.semanticTokensLegend)
            let tokens = try await client?.requestSemanticTokens(uri: uri)
            if let tokens {
                storage.applyFull(tokens)
                notifyTokensUpdated()
            }
        } catch {
            // Non-fatal — server may not support semantic tokens.
            let logger = CodeEditorLog.lsp(category: "SemanticTokens")
            logger.debug("Semantic tokens unavailable: \(error.localizedDescription)")
        }
    }

    func invalidate(
        for _: HighlightTextEdit,
        in document: HighlightDocumentSnapshot
    ) async -> HighlightInvalidation {
        // Do NOT request tokens from the server here — the server hasn't
        // received the didChange yet. Refresh is triggered from the
        // post-batch hook instead. Report the whole document as invalidated
        // so the visible range is re-queried after refresh.
        lastDocumentLength = document.utf16Length
        return .everything(length: max(1, document.utf16Length))
    }

    func highlights(
        in range: HighlightRange,
        of document: HighlightDocumentSnapshot
    ) async throws -> [HighlightToken] {
        lastDocumentLength = document.utf16Length
        guard isSetup, !storage.isEmpty else { return [] }

        let source = document.text
        guard !source.isEmpty else { return [] }
        let queryRange = range.nsRange
        // Line starts once per query; each token used to rescan the
        // document from the start.
        let lineStarts = LSPTextPosition.lineStartOffsets(in: source)
        let totalLength = source.utf16.count
        let lineRange = lineNumbers(for: queryRange, lineStarts: lineStarts, totalLength: totalLength)

        let decoded = storage.tokens(in: lineRange)
        guard !decoded.isEmpty else { return [] }

        var tokens: [HighlightToken] = []
        tokens.reserveCapacity(decoded.count)

        for dt in decoded {
            let tokenType = Self.tokenType(for: dt.tokenType, legend: storage.legend)
            guard tokenType != .whitespace else { continue }

            // Compute the UTF-16 range from (line, startChar, length).
            guard let utf16Range = Self.utf16Range(
                line: dt.line,
                startChar: dt.startChar,
                length: dt.length,
                lineStarts: lineStarts,
                totalLength: totalLength
            ) else { continue }

            // Intersect with the query range.
            let intersection = NSIntersectionRange(utf16Range, queryRange)
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
            tokens.append(
                HighlightToken(
                    range: HighlightRange(intersection),
                    tokenType: tokenType.rawValue,
                    text: text
                )
            )
        }

        return tokens
    }

    // MARK: - Post-batch refresh

    /// Should be called from `LSPContentCoordinator.onBatchFlushed`.
    /// Requests updated semantic tokens from the server and invalidates
    /// affected ranges.
    func refreshAfterBatch() {
        guard isSetup else { return }

        let uri = LSPDocumentURI.uri(forFilePath: filePath)
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

    static func tokenType(for lspIndex: Int, legend: SemanticTokensLegend?) -> TokenType {
        if let legend {
            guard lspIndex >= 0, lspIndex < legend.tokenTypes.count else { return .identifier }
            return tokenTypesByName[legend.tokenTypes[lspIndex]] ?? .identifier
        }
        guard lspIndex >= 0, lspIndex < lspTokenTypes.count else {
            return .identifier
        }
        return lspTokenTypes[lspIndex]
    }

    private func notifyTokensUpdated() {
        guard lastDocumentLength > 0 else { return }
        onTokensUpdated?(IndexSet(integersIn: 0..<lastDocumentLength))
    }

    /// Converts a (0-based line, 0-based character, length) triplet
    /// to a UTF-16 `NSRange`.
    private static func utf16Range(
        line: Int,
        startChar: Int,
        length: Int,
        lineStarts: [Int],
        totalLength: Int
    ) -> NSRange? {
        guard line >= 0, line < lineStarts.count else { return nil }
        let offset = lineStarts[line] + startChar
        guard offset < totalLength else { return nil }

        let clampedLength = min(length, totalLength - offset)
        guard clampedLength > 0 else { return nil }

        return NSRange(location: offset, length: clampedLength)
    }

    /// Returns the 0-based line range intersecting the given character range.
    private func lineNumbers(
        for range: NSRange,
        lineStarts: [Int],
        totalLength: Int
    ) -> ClosedRange<Int> {
        let startLine = LSPTextPosition.line(containingUTF16Offset: range.location, lineStarts: lineStarts)
        let endPos = min(range.location + range.length, totalLength)
        let endLine = endPos > range.location
            ? LSPTextPosition.line(containingUTF16Offset: endPos, lineStarts: lineStarts)
            : startLine
        return startLine...endLine
    }
}
