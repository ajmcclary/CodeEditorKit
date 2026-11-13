import Foundation

/// Converts between UTF-16 offsets and LSP `Position`s using the LSP line
/// model: lines end at `\n`, `\r\n` (one terminator) or a lone `\r`, and
/// `character` counts UTF-16 code units from the start of the line.
///
/// `components(separatedBy: .newlines)` is not that model: it splits `\r\n`
/// twice and also splits on U+000B, U+000C, U+0085, U+2028 and U+2029.
package enum LSPTextPosition {
    private static let lineFeed: UInt16 = 0x0A
    private static let carriageReturn: UInt16 = 0x0D

    /// The position of UTF-16 offset `offset` (clamped to the text). An
    /// offset between the `\r` and `\n` of a `\r\n` maps to the end of
    /// that line.
    package static func position(forUTF16Offset offset: Int, in text: String) -> Position {
        let units = Array(text.utf16)
        let target = max(0, min(offset, units.count))
        var line = 0
        var lineStart = 0
        var index = 0

        while index < target {
            let unit = units[index]
            index += 1
            if unit == lineFeed {
                line += 1
                lineStart = index
            } else if unit == carriageReturn {
                let isCRLF = index < units.count && units[index] == lineFeed
                if isCRLF {
                    if index == target {
                        // Inside the terminator: still the end of this line.
                        return Position(line: line, character: index - 1 - lineStart)
                    }
                    index += 1
                }
                line += 1
                lineStart = index
            }
        }
        return Position(line: line, character: target - lineStart)
    }

    /// The UTF-16 offset of `position`. A line past the end maps to the end
    /// of the text, and a `character` past the end of its line maps to the
    /// end of that line (excluding the terminator), as the spec requires.
    package static func utf16Offset(for position: Position, in text: String) -> Int {
        let units = Array(text.utf16)
        var line = 0
        var index = 0
        let targetLine = max(0, position.line)

        while line < targetLine {
            guard index < units.count else { return units.count }
            let unit = units[index]
            index += 1
            if unit == lineFeed {
                line += 1
            } else if unit == carriageReturn {
                if index < units.count, units[index] == lineFeed {
                    index += 1
                }
                line += 1
            }
        }

        var lineEnd = index
        while lineEnd < units.count, units[lineEnd] != lineFeed, units[lineEnd] != carriageReturn {
            lineEnd += 1
        }
        return index + min(max(0, position.character), lineEnd - index)
    }

    /// The UTF-16 range of `range`.
    package static func utf16Range(for range: LSPRange, in text: String) -> NSRange {
        let start = utf16Offset(for: range.start, in: text)
        let end = max(start, utf16Offset(for: range.end, in: text))
        return NSRange(location: start, length: end - start)
    }
}
