import Foundation

/// Lua folding: stack-based `function`/`do`/`if`/`for`/`while`/`repeat`
/// matching. Tokenisation runs on a cleaned copy of the source where
/// `--` line comments, `--[=*[ ... ]=*]` block comments, and `[=*[ ... ]=*]`
/// long strings are blanked so their contents cannot supply phantom
/// keywords. Short strings (`"..."`/`'...'`) are blanked on each line too.
struct LuaFoldingProvider: CodeFoldingProvider {
    private struct Opener {
        let keyword: String
        let lineIndex: Int
        let type: FoldingType
        let title: String
    }

    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        let cleaned = clean(text)
        let cleanedLines = cleaned.components(separatedBy: "\n")
        let originalLines = text.components(separatedBy: "\n")

        var lineLocations = [Int]()
        lineLocations.reserveCapacity(originalLines.count)
        var cursor = 0
        for line in originalLines {
            lineLocations.append(cursor)
            cursor += TextRangeUtilities.utf16Length(of: line) + 1
        }

        var stack: [Opener] = []
        var regions: [FoldableRegion] = []

        for (lineIndex, cleanedLine) in cleanedLines.enumerated() {
            let keywords = foldKeywords(in: cleanedLine)
            var pendingForWhile = 0

            for keyword in keywords {
                switch keyword {
                case "function":
                    stack.append(Opener(
                        keyword: "function",
                        lineIndex: lineIndex,
                        type: .function,
                        title: functionTitle(in: originalLines[lineIndex])
                    ))

                case "if":
                    stack.append(Opener(keyword: "if", lineIndex: lineIndex, type: .block, title: "if"))

                case "for":
                    stack.append(Opener(keyword: "for", lineIndex: lineIndex, type: .block, title: "for"))
                    pendingForWhile += 1

                case "while":
                    stack.append(Opener(keyword: "while", lineIndex: lineIndex, type: .block, title: "while"))
                    pendingForWhile += 1

                case "repeat":
                    stack.append(Opener(keyword: "repeat", lineIndex: lineIndex, type: .block, title: "repeat"))

                case "do":
                    if pendingForWhile > 0 {
                        pendingForWhile -= 1
                    } else {
                        stack.append(Opener(keyword: "do", lineIndex: lineIndex, type: .block, title: "do"))
                    }

                case "end":
                    if let opener = stack.popLast() {
                        emit(opener: opener, closerLine: lineIndex, originalLines: originalLines, lineLocations: lineLocations, into: &regions)
                    }

                case "until":
                    if let top = stack.last, top.keyword == "repeat" {
                        stack.removeLast()
                        emit(opener: top, closerLine: lineIndex, originalLines: originalLines, lineLocations: lineLocations, into: &regions)
                    }

                default:
                    continue
                }
            }
        }

        return regions
    }

    // MARK: - Keyword tokenisation

    private static let recognisedKeywords: Set<String> = [
        "function", "if", "for", "while", "repeat", "do", "end", "until"
    ]

    private func foldKeywords(in line: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in line {
            if ch.isLetter || ch.isNumber || ch == "_" {
                current.append(ch)
            } else {
                if Self.recognisedKeywords.contains(current) {
                    result.append(current)
                }
                current.removeAll(keepingCapacity: true)
            }
        }
        if Self.recognisedKeywords.contains(current) {
            result.append(current)
        }
        return result
    }

    private func functionTitle(in originalLine: String) -> String {
        let trimmed = originalLine.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: #"function\s+([A-Za-z_][A-Za-z0-9_.:]*)"#, options: .regularExpression) {
            let match = String(trimmed[range])
            let name = match.components(separatedBy: .whitespaces).last ?? ""
            if !name.isEmpty { return "function \(name)" }
        }
        return "function"
    }

    // MARK: - Region assembly

    private func emit(
        opener: Opener,
        closerLine: Int,
        originalLines: [String],
        lineLocations: [Int],
        into regions: inout [FoldableRegion]
    ) {
        guard closerLine > opener.lineIndex else { return }
        let start = lineLocations[opener.lineIndex]
        let endLocation = lineLocations[closerLine]
        let endLineLength = TextRangeUtilities.utf16Length(of: originalLines[closerLine])
        let length = (endLocation + endLineLength) - start
        regions.append(FoldableRegion(
            range: NSRange(location: start, length: length),
            title: opener.title,
            type: opener.type
        ))
    }

    // MARK: - Comment / string blanking

    /// Replaces the contents of Lua comments and strings with spaces while
    /// preserving newlines and total length, so downstream keyword scans cannot
    /// pick up phantom keywords from `--[[ end ]]` etc.
    private func clean(_ text: String) -> String {
        enum State {
            case code
            case lineComment
            case blockComment(level: Int)
            case longString(level: Int)
            case shortString(quote: Character)
        }

        var state: State = .code
        var result = ""
        result.reserveCapacity(text.count)
        let chars = Array(text)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            switch state {
            case .code:
                // `--` may open a block comment (`--[=*[`) or a line comment.
                if char == "-", index + 1 < chars.count, chars[index + 1] == "-" {
                    let afterDashes = index + 2
                    if afterDashes < chars.count, chars[afterDashes] == "[",
                       let (level, openEnd) = matchLongBracketOpen(at: afterDashes, in: chars) {
                        state = .blockComment(level: level)
                        for _ in index...openEnd { result.append(" ") }
                        index = openEnd + 1
                    } else {
                        state = .lineComment
                        result.append(" ")
                        result.append(" ")
                        index += 2
                    }
                    continue
                }

                // Bare `[=*[` opens a long string.
                if char == "[", let (level, openEnd) = matchLongBracketOpen(at: index, in: chars) {
                    state = .longString(level: level)
                    for _ in index...openEnd { result.append(" ") }
                    index = openEnd + 1
                    continue
                }

                if char == "\"" || char == "'" {
                    state = .shortString(quote: char)
                    result.append(" ")
                    index += 1
                    continue
                }

                result.append(char)
                index += 1

            case .lineComment:
                if char == "\n" {
                    state = .code
                    result.append("\n")
                } else {
                    result.append(" ")
                }
                index += 1

            case let .blockComment(level):
                if char == "]", let closeEnd = matchLongBracketClose(at: index, in: chars, level: level) {
                    state = .code
                    for _ in index...closeEnd { result.append(" ") }
                    index = closeEnd + 1
                    continue
                }
                result.append(char == "\n" ? "\n" : " ")
                index += 1

            case let .longString(level):
                if char == "]", let closeEnd = matchLongBracketClose(at: index, in: chars, level: level) {
                    state = .code
                    for _ in index...closeEnd { result.append(" ") }
                    index = closeEnd + 1
                    continue
                }
                result.append(char == "\n" ? "\n" : " ")
                index += 1

            case let .shortString(quote):
                if char == "\\", index + 1 < chars.count {
                    result.append(" ")
                    result.append(" ")
                    index += 2
                    continue
                }
                if char == quote {
                    state = .code
                    result.append(" ")
                    index += 1
                    continue
                }
                if char == "\n" {
                    // Unterminated short string — bail back to code so subsequent
                    // lines aren't permanently blanked.
                    state = .code
                    result.append("\n")
                    index += 1
                    continue
                }
                result.append(" ")
                index += 1
            }
        }

        return result
    }

    /// Detects `[=*[` at `start`. Returns `(level, indexOfFinalOpenBracket)`
    /// or nil if the position is not a long-bracket opener.
    private func matchLongBracketOpen(at start: Int, in chars: [Character]) -> (level: Int, end: Int)? {
        guard start < chars.count, chars[start] == "[" else { return nil }
        var cursor = start + 1
        var level = 0
        while cursor < chars.count, chars[cursor] == "=" {
            level += 1
            cursor += 1
        }
        guard cursor < chars.count, chars[cursor] == "[" else { return nil }
        return (level, cursor)
    }

    /// Detects `]=*]` of `level` equals signs at `start`. Returns the index of
    /// the final closing bracket, or nil if the position is not a matching close.
    private func matchLongBracketClose(at start: Int, in chars: [Character], level: Int) -> Int? {
        guard start < chars.count, chars[start] == "]" else { return nil }
        var cursor = start + 1
        var equals = 0
        while cursor < chars.count, chars[cursor] == "=" {
            equals += 1
            cursor += 1
        }
        guard equals == level, cursor < chars.count, chars[cursor] == "]" else { return nil }
        return cursor
    }
}
