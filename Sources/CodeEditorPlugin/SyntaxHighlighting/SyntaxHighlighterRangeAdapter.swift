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
            let storageLength = textView.textStorage?.length ?? 0
            let invalidEnd = min(storageLength, range.location + range.length + visibleRange.length / 2)
            return IndexSet(integersIn: invalidStart..<invalidEnd)
        }

        // Incremental highlighters return precise invalidation
        let source = textView.textStorage?.string ?? ""
        _ = highlighter.highlightIncremental(source: source, changeRange: range)
        return IndexSet(integersIn: range.location..<(range.location + range.length + delta))
    }

    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        let source = textView.textStorage?.string ?? ""
        guard !source.isEmpty else { return [] }

        // Clamp range to valid bounds
        let clampedLocation = max(0, min(range.location, source.utf16.count))
        let maxLength = source.utf16.count - clampedLocation
        let clampedLength = max(0, min(range.length, maxLength))
        let clampedRange = NSRange(location: clampedLocation, length: clampedLength)

        guard clampedRange.length > 0 else { return [] }

        // Extract chunk text
        guard let swiftRange = Range(clampedRange, in: source) else { return [] }
        let chunkText = String(source[swiftRange])

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
