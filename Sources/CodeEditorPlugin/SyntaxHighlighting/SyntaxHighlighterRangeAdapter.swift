import Foundation

/// Adapts existing `SyntaxHighlighter` instances to the `RangeHighlightProviding`
/// protocol so they can participate in range-based highlighting without rewriting
/// every language provider.
@MainActor
internal final class SyntaxHighlighterRangeAdapter: RangeHighlightProviding {
    private let highlighter: any SyntaxHighlighter
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "RangeAdapter")

    init(highlighter: any SyntaxHighlighter) {
        self.highlighter = highlighter
    }

    func setUp(textView _: CodeEditorView, language _: Language) {}

    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet {
        // Non-incremental highlighters invalidate the visible chunk
        guard highlighter.supportsIncrementalHighlighting else {
            let visibleRange: NSRange = textView.visibleRange()
            let invalidStart = max(0, range.location - visibleRange.length / 2)
            #if canImport(AppKit)
            let storageLength = textView.textStorage?.length ?? 0
            #else
            let storageLength = textView.textStorage.length
            #endif
            let invalidEnd = min(storageLength, range.location + range.length + visibleRange.length / 2)
            return IndexSet(integersIn: invalidStart..<invalidEnd)
        }

        // Incremental highlighters return precise invalidation
        #if canImport(AppKit)
        let source = textView.textStorage?.string ?? ""
        #else
        let source = textView.textStorage.string
        #endif
        _ = highlighter.highlightIncremental(source: source, changeRange: range)
        return IndexSet(integersIn: range.location..<(range.location + range.length + delta))
    }

    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        #if canImport(AppKit)
        let source = textView.textStorage?.string ?? ""
        #else
        let source = textView.textStorage.string
        #endif
        guard !source.isEmpty else { return [] }

        let sourceLength = TextRangeUtilities.utf16Length(of: source)
        let clampedRange = TextRangeUtilities.clampRange(range, toTextLength: sourceLength)
        guard clampedRange.length > 0 else { return [] }

        guard let chunkText = TextRangeUtilities.substring(inUTF16Range: clampedRange, from: source) else {
            return []
        }

        let tokens = highlighter.highlight(source: chunkText)

        // Shift token ranges to be relative to the full document
        return tokens.map { token in
            HighlightedToken(
                range: NSRange(
                    location: token.range.location + clampedRange.location,
                    length: token.range.length
                ),
                type: token.type,
                text: token.text
            )
        }
    }
}
