import CodeEditorTextModel
import Foundation

// MARK: - Brace Folding Provider

/// Brace-based folding provider for C-style languages
package struct BraceFoldingProvider: CodeFoldingProvider {
    package init() {}

    /// The longest stretch of a line before an opening brace that a region's
    /// title and classification look at (UTF-16 units). `class Foo {` needs a
    /// few dozen; minified code puts the whole document on one line.
    static let titleWindow = 120

    package func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        // One pass over the UTF-16 view: every offset below is a UTF-16
        // offset. Each brace remembers where its line starts, so a region's
        // title and type come from a bounded window before the brace — never
        // a walk back to the line start or a copy of the line, which made a
        // single long line (minified JSON, JavaScript, CSS) quadratic.
        let units = Array(text.utf16)
        var braceStack: [(index: Int, lineStart: Int, line: Int)] = []
        var lineStart = 0
        var line = 0

        for (index, unit) in units.enumerated() {
            switch unit {
            case Self.newline:
                line += 1
                lineStart = index + 1

            case Self.carriageReturn:
                // CRLF counts once (at its LF); a lone CR ends a line.
                if index + 1 >= units.count || units[index + 1] != Self.newline {
                    line += 1
                }
                lineStart = index + 1

            case Self.openBrace:
                braceStack.append((index, lineStart, line))

            case Self.closeBrace:
                // A region that opens and closes on one line hides nothing.
                guard let open = braceStack.popLast(), open.line != line else { break }
                let windowStart = max(open.lineStart, open.index - Self.titleWindow)
                let linePrefix = String(decoding: units[windowStart..<open.index], as: UTF16.self)
                let type = determineFoldingType(
                    linePrefix: linePrefix,
                    lineIsComment: Self.lineStartsWithComment(at: open.lineStart, before: open.index, in: units)
                )
                regions.append(FoldableRegion(
                    range: NSRange(location: open.index, length: index - open.index + 1),
                    title: linePrefix.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: type
                ))

            default:
                break
            }
        }
        return regions
    }

    private static let newline = UInt16(UInt8(ascii: "\n"))
    private static let carriageReturn = UInt16(UInt8(ascii: "\r"))
    private static let openBrace = UInt16(UInt8(ascii: "{"))
    private static let closeBrace = UInt16(UInt8(ascii: "}"))
    private static let slash = UInt16(UInt8(ascii: "/"))
    private static let star = UInt16(UInt8(ascii: "*"))
    private static let space = UInt16(UInt8(ascii: " "))
    private static let tab = UInt16(UInt8(ascii: "\t"))

    /// Whether the line's first non-blank characters (before `end`) are `//`
    /// or `/*`. Looks past at most `titleWindow` blanks.
    private static func lineStartsWithComment(at lineStart: Int, before end: Int, in units: [UInt16]) -> Bool {
        var cursor = lineStart
        let limit = min(end, lineStart + titleWindow)
        while cursor < limit, units[cursor] == space || units[cursor] == tab {
            cursor += 1
        }
        guard cursor + 1 < end, units[cursor] == slash else { return false }
        return units[cursor + 1] == slash || units[cursor + 1] == star
    }

    /// Classifies a region from the code before its opening brace on the same
    /// line (`class Foo {`, `func bar() {`, `// {`).
    private func determineFoldingType(linePrefix: String, lineIsComment: Bool) -> FoldingType {
        let trimmed = linePrefix.trimmingCharacters(in: .whitespaces)
        if lineIsComment || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
            return .comment
        }
        let words = Set(trimmed.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.map(String.init))
        if !words.isDisjoint(with: ["class", "struct"]) {
            return .class
        }
        if !words.isDisjoint(with: ["func", "function"]) {
            return .function
        }
        return .block
    }
}
