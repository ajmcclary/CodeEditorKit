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
/// Every delta edit (`SemanticTokensEdit`) refers to the original array, so
/// edits are applied from the highest `start` down, whatever order the
/// server sent them in.
///
/// Thread safety: writes happen on `@MainActor` (LSP response handlers);
/// reads from `RangeHighlightProviding.queryHighlights` are also on
/// `@MainActor` so no lock is needed.
@MainActor
package final class LSPSemanticTokenStorage {
    // MARK: - Decoded token

    package struct DecodedToken: Sendable {
        package let line: Int          // 0-based absolute line
        package let startChar: Int     // 0-based UTF-16 character on that line
        package let length: Int        // UTF-16 code units
        package let tokenType: Int     // index into legend
        package let tokenModifiers: Int // bitmask
    }

    // MARK: - Stored state

    private var data: [UInt32] = []
    package private(set) var legend: SemanticTokensLegend?
    package private(set) var resultId: String?

    // MARK: - Initial state

    package init() {}

    package var isEmpty: Bool { data.isEmpty }

    // MARK: - Full update

    package func applyFull(_ tokens: SemanticTokens) {
        data = tokens.data
        resultId = tokens.resultId
    }

    /// Records the server's legend, which names each token-type index.
    package func setLegend(_ legend: SemanticTokensLegend?) {
        self.legend = legend
    }

    // MARK: - Delta update

    /// Applies a `SemanticTokensDelta`. Edits are applied by descending
    /// `start` so each still indexes the original array.
    package func applyDelta(_ delta: SemanticTokensDelta) {
        resultId = delta.resultId

        for edit in delta.edits.sorted(by: { $0.start > $1.start }) {
            let startIdx = Int(edit.start)
            let deleteCount = Int(edit.deleteCount)
            let insertData = edit.data

            // Validate bounds — start and deleteCount index into the
            // raw UInt32 array, NOT into tokens (5 ints per token).
            guard startIdx <= data.count else { continue }
            let clampedDelete = min(deleteCount, data.count - startIdx)

            let endIdx = startIdx + clampedDelete
            data.replaceSubrange(startIdx..<min(endIdx, data.count), with: insertData)
        }
    }

    // MARK: - Decoding

    /// Decodes tokens intersecting the given line range into absolute
    /// `DecodedToken` values.
    package func tokens(in lineRange: ClosedRange<Int>) -> [DecodedToken] {
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

    /// Returns the character indices invalidated by a delta. Edit `start`
    /// values index the token array, not the document, so mapping them to
    /// characters would need the decoded tokens; the whole document is
    /// reported instead.
    package func invalidatedIndices(for _: SemanticTokensDelta, documentLength: Int) -> IndexSet {
        IndexSet(integersIn: 0..<max(0, documentLength))
    }

    // MARK: - Reset

    package func reset() {
        data.removeAll()
        resultId = nil
    }
}
