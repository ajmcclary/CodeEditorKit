import Foundation

// MARK: - Shared Swift Highlighting Utilities

/// Shared utilities for Swift syntax highlighting that work across all platforms
/// including iOS where SwiftSyntax is not available
package enum SwiftHighlightingUtilities {
    // MARK: - Keywords

    package static let keywords: Set<String> = [
        "let", "var", "func", "class", "struct", "if", "else", "for", "while",
        "return", "import", "public", "private", "internal", "enum", "protocol",
        "extension", "case", "default", "switch", "do", "try", "catch", "throw",
        "throws", "async", "await", "actor", "init", "deinit", "override",
        "final", "static", "lazy", "weak", "unowned", "mutating", "nonmutating",
        "convenience", "required", "optional", "dynamic", "inout", "associatedtype",
        "typealias", "where", "self", "Self", "super", "nil", "true", "false",
        "break", "continue"
    ]

    // MARK: - Basic Highlighting Methods

    package static func performBasicSwiftHighlighting(source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []

        // Add keywords
        tokens.append(contentsOf: highlightKeywords(in: source))

        // Add strings
        tokens.append(contentsOf: highlightStrings(in: source))

        // Add comments
        tokens.append(contentsOf: highlightComments(in: source))

        // Add numbers
        tokens.append(contentsOf: highlightNumbers(in: source))

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    package static func highlightKeywords(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []

        for keyword in keywords {
            var searchStartIndex = source.startIndex

            while searchStartIndex < source.endIndex {
                guard let range = source.range(of: keyword, range: searchStartIndex..<source.endIndex) else { break }

                // Convert to NSRange for compatibility with existing highlighting system
                let nsRange = NSRange(range, in: source)

                // Check if it's a whole word (basic boundary check)
                let isWholeWord = checkWordBoundary(in: source, range: nsRange)

                if isWholeWord {
                    tokens.append(HighlightedToken(
                        range: nsRange,
                        type: .keyword,
                        text: keyword
                    ))
                }

                searchStartIndex = range.upperBound
            }
        }

        return tokens
    }

    package static func highlightStrings(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        let utf16 = source.utf16
        var index = utf16.startIndex

        while index < utf16.endIndex {
            let char = utf16[index]

            // Check for string literals
            if char == UnicodeScalar("\"").value {
                let startIndex = index
                index = utf16.index(after: index)

                // Find the end of the string
                var foundEnd = false
                while index < utf16.endIndex {
                    let currentChar = utf16[index]

                    if currentChar == UnicodeScalar("\"").value {
                        index = utf16.index(after: index)
                        foundEnd = true
                        break
                    } else if currentChar == UnicodeScalar("\\").value {
                        // Skip escaped character
                        index = utf16.index(after: index)
                        if index < utf16.endIndex {
                            index = utf16.index(after: index)
                        }
                    } else {
                        index = utf16.index(after: index)
                    }
                }

                if foundEnd {
                    let startOffset = utf16.distance(from: utf16.startIndex, to: startIndex)
                    let endOffset = utf16.distance(from: utf16.startIndex, to: index)
                    let nsRange = NSRange(location: startOffset, length: endOffset - startOffset)

                    tokens.append(HighlightedToken(
                        range: nsRange,
                        type: .string,
                        text: String(source[source.index(source.startIndex, offsetBy: startOffset)..<source.index(source.startIndex, offsetBy: endOffset)])
                    ))
                }
            } else {
                index = utf16.index(after: index)
            }
        }

        return tokens
    }

    package static func highlightComments(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        let lines = source.components(separatedBy: .newlines)
        var currentOffset = 0

        for line in lines {
            // Single-line comments
            if let range = line.range(of: "//") {
                let lineStartInSource = source.index(source.startIndex, offsetBy: currentOffset)
                let commentStartInLine = line.distance(from: line.startIndex, to: range.lowerBound)
                let commentStartInSource = source.index(lineStartInSource, offsetBy: commentStartInLine)
                let commentEndInSource = source.index(lineStartInSource, offsetBy: line.count)

                let nsRange = NSRange(commentStartInSource..<commentEndInSource, in: source)
                tokens.append(HighlightedToken(
                    range: nsRange,
                    type: .comment,
                    text: String(source[commentStartInSource..<commentEndInSource])
                ))
            }

            currentOffset += line.count + 1 // +1 for newline
        }

        // Multi-line comments
        var searchStartIndex = source.startIndex
        while searchStartIndex < source.endIndex {
            guard let startRange = source.range(of: "/*", range: searchStartIndex..<source.endIndex) else { break }
            guard let endRange = source.range(of: "*/", range: startRange.upperBound..<source.endIndex) else { break }

            let commentRange = startRange.lowerBound..<endRange.upperBound
            let nsRange = NSRange(commentRange, in: source)

            tokens.append(HighlightedToken(
                range: nsRange,
                type: .comment,
                text: String(source[commentRange])
            ))

            searchStartIndex = endRange.upperBound
        }

        return tokens
    }

    package static func highlightNumbers(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []

        // Simple number pattern matching
        let numberPattern = #"\b\d+\.?\d*\b"#
        guard let regex = try? NSRegularExpression(pattern: numberPattern) else { return tokens }

        let matches = regex.matches(in: source, range: NSRange(location: 0, length: source.utf16.count))

        for match in matches {
            guard let stringRange = Range(match.range, in: source) else { continue }
            let text = String(source[stringRange])
            tokens.append(HighlightedToken(
                range: match.range,
                type: .number,
                text: text
            ))
        }

        return tokens
    }

    package static func checkWordBoundary(in string: String, range: NSRange) -> Bool {
        let chars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let utf16 = string.utf16

        // Check character before
        if range.location > 0 {
            let beforeIndex = utf16.index(utf16.startIndex, offsetBy: range.location - 1)
            let beforeChar = utf16[beforeIndex]
            if let scalar = UnicodeScalar(beforeChar), chars.contains(scalar) {
                return false
            }
        }

        // Check character after
        let endLocation = range.location + range.length
        if endLocation < utf16.count {
            let afterIndex = utf16.index(utf16.startIndex, offsetBy: endLocation)
            let afterChar = utf16[afterIndex]
            if let scalar = UnicodeScalar(afterChar), chars.contains(scalar) {
                return false
            }
        }

        return true
    }
}
