import Foundation

// MARK: - LineRangeIndex

/// Line- and word-oriented queries over a Swift string. Wraps `NSString`
/// line enumeration so UTF-16 correctness for emoji, composed characters,
/// and surrogate pairs is consistent across the editor.
internal enum LineRangeIndex {
    // MARK: - Line Ranges

    /// Returns the line range containing a UTF-16 offset.
    package static func lineRange(containingUTF16Offset offset: Int, in text: String) -> NSRange {
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let clampedLocation = max(0, min(offset, nsText.length))
        return nsText.lineRange(for: NSRange(location: clampedLocation, length: 0))
    }

    /// Returns the line text containing a UTF-16 offset without trailing newline characters.
    package static func lineText(containingUTF16Offset offset: Int, in text: String) -> String {
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        let range = lineRange(containingUTF16Offset: offset, in: text)
        guard NSMaxRange(range) <= nsText.length else { return "" }
        return nsText.substring(with: range).trimmingCharacters(in: .newlines)
    }

    /// All UTF-16 line ranges in the string, including line terminators.
    package static func lineRanges(in string: String) -> [NSRange] {
        // swiftlint:disable:next legacy_objc_type
        let nsText = string as NSString
        guard nsText.length > 0 else { return [] }

        var ranges: [NSRange] = []
        var location = 0
        while location < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
            ranges.append(lineRange)
            let nextLocation = NSMaxRange(lineRange)
            guard nextLocation > location else { break }
            location = nextLocation
        }
        return ranges
    }

    /// Zero-based line number for a UTF-16 offset.
    package static func lineNumber(for offset: Int, in string: String) -> Int {
        let clampedOffset = max(0, min(offset, UTF16RangeConverter.utf16Length(of: string)))
        guard clampedOffset > 0 else { return 0 }

        let prefix = UTF16RangeConverter.substring(upToUTF16Offset: clampedOffset, in: string)
        return prefix.reduce(into: 0) { count, character in
            if character == "\n" {
                count += 1
            }
        }
    }

    /// UTF-16 offset of the start of a zero-based line, or `nil` if out of bounds.
    static func startOfLine(_ lineNumber: Int, in string: String) -> Int? {
        let ranges = lineRanges(in: string)
        guard lineNumber >= 0, lineNumber < ranges.count else { return nil }
        return ranges[lineNumber].location
    }

    /// Character offset of a line in a pre-split `[String]` of lines.
    package static func locationForLine(_ lineIndex: Int, in lines: [String]) -> Int {
        var location = 0
        for index in 0..<lineIndex {
            location += UTF16RangeConverter.utf16Length(of: lines[index]) + 1 // +1 for newline
        }
        return location
    }

    // MARK: - Word / Identifier Ranges

    /// Identifier-like word range at a UTF-16 offset.
    package static func wordRange(at offset: Int, in string: String) -> NSRange? {
        let clampedOffset = max(0, min(offset, UTF16RangeConverter.utf16Length(of: string)))
        guard let insertionRange = Range(NSRange(location: clampedOffset, length: 0), in: string) else {
            return nil
        }

        var start = insertionRange.lowerBound
        while start > string.startIndex {
            let previous = string.index(before: start)
            guard isIdentifierCharacter(string[previous]) else { break }
            start = previous
        }

        var end = insertionRange.lowerBound
        while end < string.endIndex, isIdentifierCharacter(string[end]) {
            end = string.index(after: end)
        }

        guard start < end else { return nil }
        return NSRange(start..<end, in: string)
    }

    /// Current identifier prefix ending at a UTF-16 offset.
    package static func identifierPrefix(endingAtUTF16Offset offset: Int, in text: String) -> String {
        let prefix = UTF16RangeConverter.substring(upToUTF16Offset: offset, in: text)
        var characters: [Character] = []

        for character in prefix.reversed() {
            guard isIdentifierCharacter(character) else { break }
            characters.append(character)
        }

        return String(characters.reversed())
    }

    /// UTF-16 range for the current identifier ending at an offset.
    package static func identifierRange(endingAtUTF16Offset offset: Int, in text: String) -> NSRange? {
        let clampedOffset = max(0, min(offset, UTF16RangeConverter.utf16Length(of: text)))
        let prefix = identifierPrefix(endingAtUTF16Offset: clampedOffset, in: text)
        guard !prefix.isEmpty else { return nil }

        let length = UTF16RangeConverter.utf16Length(of: prefix)
        return NSRange(location: clampedOffset - length, length: length)
    }

    /// Whether a character is an identifier constituent for editor features.
    package static func isIdentifierCharacter(_ character: Character) -> Bool {
        let identifierCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return character.unicodeScalars.allSatisfy { identifierCharacters.contains($0) }
    }
}
