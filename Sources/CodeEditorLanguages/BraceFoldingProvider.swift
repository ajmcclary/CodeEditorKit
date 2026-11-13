import CodeEditorTextModel
import Foundation

// MARK: - Brace Folding Provider

/// Brace-based folding provider for C-style languages
package struct BraceFoldingProvider: CodeFoldingProvider {
    package init() {}

    package func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        // Simple brace matching over the UTF-16 view: every offset below is a
        // UTF-16 offset, and each region is classified from the text of its
        // opening brace's own line, so the cost is linear in the document.
        let units = Array(text.utf16)
        var braceStack: [Int] = []

        for (index, unit) in units.enumerated() {
            switch unit {
            case Self.openBrace:
                braceStack.append(index)

            case Self.closeBrace:
                if let openIndex = braceStack.popLast() {
                    let range = NSRange(location: openIndex, length: index - openIndex + 1)
                    let linePrefix = Self.linePrefix(endingAt: openIndex, in: units)
                    let type = determineFoldingType(linePrefix: linePrefix)

                    regions.append(FoldableRegion(
                        range: range,
                        title: linePrefix.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: type
                    ))
                }

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

    /// The text from the start of the line containing `location` up to (not
    /// including) `location`.
    private static func linePrefix(endingAt location: Int, in units: [UInt16]) -> String {
        var start = location
        while start > 0, units[start - 1] != newline, units[start - 1] != carriageReturn {
            start -= 1
        }
        return String(decoding: units[start..<location], as: UTF16.self)
    }

    /// Classifies a region from the code before its opening brace on the same
    /// line (`class Foo {`, `func bar() {`, `// {`).
    private func determineFoldingType(linePrefix: String) -> FoldingType {
        let trimmed = linePrefix.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
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
