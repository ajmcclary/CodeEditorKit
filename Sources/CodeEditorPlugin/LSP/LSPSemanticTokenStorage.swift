import Foundation

// MARK: - Semantic Token Storage

/// Stores compressed LSP semantic-token data and applies delta edits.
///
/// Semantic tokens are transmitted as a flat `[UInt32]` array where
/// every group of 5 integers represents one token:
/// - `data[i]`     = deltaLine (relative to previous token)
/// - `data[i+1]`   = deltaStartChar (relative to previous, or 0 for same line)
/// - `data[i+2]`   = length (UTF-16 code units)
/// - `data[i+3]`   = tokenType (index into `SemanticTokensLegend.tokenTypes`)
/// - `data[i+4]`   = tokenModifiers (bitmask into `SemanticTokensLegend.tokenModifiers`)
///
/// Delta edits (`SemanticTokensEdit`) are applied in **reverse order**
/// (last edit first) to preserve earlier edit indices.
///
/// Thread safety: writes happen on `@MainActor` (LSP response handlers);
/// reads from `RangeHighlightProviding.queryHighlights` are also on
/// `@MainActor` so no lock is needed.
@MainActor
final class LSPSemanticTokenStorage {
    // MARK: - Decoded token

    struct DecodedToken: Sendable {
        let line: Int          // 0-based absolute line
        let startChar: Int     // 0-based UTF-16 character on that line
        let length: Int        // UTF-16 code units
        let tokenType: Int     // index into legend
        let tokenModifiers: Int // bitmask
    }

    // MARK: - Stored state

    private var data: [UInt32] = []
    private(set) var legend: SemanticTokensLegend?
    private(set) var resultId: String?

    // MARK: - Initial state

    var isEmpty: Bool { data.isEmpty }

    // MARK: - Full update

    func applyFull(_ tokens: SemanticTokens) {
        data = tokens.data
        resultId = tokens.resultId
    }

    // MARK: - Delta update

    /// Applies a `SemanticTokensDelta`, processing edits in reverse order
    /// so that earlier edits remain at their correct indices.
    func applyDelta(_ delta: SemanticTokensDelta) {
        resultId = delta.resultId

        for edit in delta.edits.reversed() {
            let start = Int(edit.start)
            let deleteCount = Int(edit.deleteCount)
            let insertData = edit.data

            // Validate bounds
            guard start <= data.count else { continue }
            let clampedDelete = min(deleteCount, data.count - start)

            // Replace: remove `clampedDelete` tokens (×5 ints each) then insert new data
            let startIdx = start * 5
            let endIdx = startIdx + clampedDelete * 5
            data.replaceSubrange(startIdx..<min(endIdx, data.count), with: insertData)
        }
    }

    // MARK: - Decoding

    /// Decodes tokens intersecting the given line range into absolute
    /// `DecodedToken` values.
    func tokens(in lineRange: ClosedRange<Int>) -> [DecodedToken] {
        guard !data.isEmpty else { return [] }

        var result: [DecodedToken] = []
        var currentLine = 0
        var currentChar = 0
        var idx = 0

        while idx + 4 < data.count {
            let deltaLine = Int(data[idx])
            let deltaChar = Int(data[idx + 1])
            let length = Int(data[idx + 2])
            let tokenType = Int(data[idx + 3])
            let modifiers = Int(data[idx + 4])
            idx += 5

            if deltaLine > 0 {
                currentLine += deltaLine
                currentChar = deltaChar
            } else {
                currentChar += deltaChar
            }

            let tokenLine = currentLine
            if tokenLine > lineRange.upperBound { break }
            if tokenLine >= lineRange.lowerBound {
                result.append(
                    DecodedToken(
                        line: tokenLine,
                        startChar: currentChar,
                        length: length,
                        tokenType: tokenType,
                        tokenModifiers: modifiers
                    )
                )
            }
        }

        return result
    }

    // MARK: - Invalidation

    /// Returns an `IndexSet` of character indices invalidated after
    /// applying a delta, based on the edit boundaries.
    func invalidatedIndices(for delta: SemanticTokensDelta, documentLength: Int) -> IndexSet {
        var indices = IndexSet()
        for edit in delta.edits {
            let start = Int(edit.start)
            // Conservative: invalidate from edit point to end of document.
            // A more precise calculation would convert token positions to
            // character ranges, but this is simple and correct.
            indices.insert(integersIn: start..<max(start, documentLength))
        }
        return indices
    }

    // MARK: - Reset

    func reset() {
        data.removeAll()
        resultId = nil
    }
}
