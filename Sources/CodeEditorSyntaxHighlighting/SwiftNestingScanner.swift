import Foundation

/// Measures how deeply Swift source nests brackets without parsing it, so
/// `SwiftSyntaxHighlighter` can refuse sources SwiftParser cannot handle in
/// bounded time and stack.
///
/// A single linear pass over UTF-8 bytes. Comments (`//`, nested `/* */`)
/// and string literals (single-line, multi-line, raw `#"…"#` with their
/// escapes) are skipped, but the code inside a string interpolation `\(…)`
/// is counted: the parser parses it, so hiding brackets in an interpolation
/// must not hide them from the scan. A single-line string ends at a newline
/// even when unterminated, as it does for the parser. Unbalanced closers are
/// ignored; anything the scan misreads errs towards counting more.
struct SwiftNestingScanner {
    private enum Context {
        /// Code; `interpolationBase` is the bracket-stack height at which the
        /// interpolation's own `(` sits, or `nil` at the top level.
        case code(interpolationBase: Int?)
        case string(hashes: Int, multiline: Bool)
    }

    private let bytes: UnsafeBufferPointer<UInt8>
    private var index = 0
    private var contexts: [Context] = [.code(interpolationBase: nil)]
    private var openBrackets: [UInt8] = []
    private var openSquareBrackets = 0
    private var deepest = 0
    private var deepestSquare = 0

    init(bytes: UnsafeBufferPointer<UInt8>) {
        self.bytes = bytes
    }

    /// The deepest bracket nesting and the most `[` open at once. Returns as
    /// soon as either exceeds its limit.
    mutating func scan(stoppingAbove limits: (brackets: Int, squareBrackets: Int)) -> (brackets: Int, squareBrackets: Int) {
        while index < bytes.count {
            switch contexts[contexts.count - 1] {
            case let .code(interpolationBase):
                scanCode(interpolationBase: interpolationBase)

            case let .string(hashes, multiline):
                scanString(hashes: hashes, multiline: multiline)
            }
            if deepest > limits.brackets || deepestSquare > limits.squareBrackets { break }
        }
        return (deepest, deepestSquare)
    }

    private func byte(at offset: Int) -> UInt8? {
        offset < bytes.count ? bytes[offset] : nil
    }

    private mutating func open(_ bracket: UInt8) {
        openBrackets.append(bracket)
        deepest = max(deepest, openBrackets.count)
        if bracket == UInt8(ascii: "[") {
            openSquareBrackets += 1
            deepestSquare = max(deepestSquare, openSquareBrackets)
        }
    }

    private mutating func close() {
        guard let bracket = openBrackets.popLast() else { return }
        if bracket == UInt8(ascii: "[") { openSquareBrackets -= 1 }
    }

    private func hashCount(from offset: Int) -> Int {
        var count = 0
        while byte(at: offset + count) == UInt8(ascii: "#") { count += 1 }
        return count
    }

    private mutating func scanCode(interpolationBase: Int?) {
        let current = bytes[index]
        switch current {
        case UInt8(ascii: "/") where byte(at: index + 1) == UInt8(ascii: "/"):
            while index < bytes.count, bytes[index] != UInt8(ascii: "\n") { index += 1 }

        case UInt8(ascii: "/") where byte(at: index + 1) == UInt8(ascii: "*"):
            skipBlockComment()

        case UInt8(ascii: "#"), UInt8(ascii: "\""):
            let hashes = hashCount(from: index)
            guard byte(at: index + hashes) == UInt8(ascii: "\"") else {
                index += max(hashes, 1)
                return
            }
            let quote = index + hashes
            let multiline = byte(at: quote + 1) == UInt8(ascii: "\"") && byte(at: quote + 2) == UInt8(ascii: "\"")
            index = quote + (multiline ? 3 : 1)
            contexts.append(.string(hashes: hashes, multiline: multiline))

        case UInt8(ascii: "("), UInt8(ascii: "["), UInt8(ascii: "{"):
            open(current)
            index += 1

        case UInt8(ascii: ")") where interpolationBase.map { openBrackets.count == $0 + 1 } == true:
            // The interpolation's own `)`: back into the string.
            close()
            contexts.removeLast()
            index += 1

        case UInt8(ascii: ")"), UInt8(ascii: "]"), UInt8(ascii: "}"):
            if let interpolationBase, openBrackets.count <= interpolationBase + 1 {
                // Never let a stray closer pop the interpolation's `(`.
                index += 1
                return
            }
            close()
            index += 1

        default:
            index += 1
        }
    }

    private mutating func skipBlockComment() {
        var depth = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "/"), byte(at: index + 1) == UInt8(ascii: "*") {
                depth += 1
                index += 2
            } else if bytes[index] == UInt8(ascii: "*"), byte(at: index + 1) == UInt8(ascii: "/") {
                depth -= 1
                index += 2
                if depth == 0 { return }
            } else {
                index += 1
            }
        }
    }

    private mutating func scanString(hashes: Int, multiline: Bool) {
        let current = bytes[index]
        switch current {
        case UInt8(ascii: "\\"):
            guard hashCount(from: index + 1) >= hashes else {
                index += 1
                return
            }
            let afterDelimiter = index + 1 + hashes
            if byte(at: afterDelimiter) == UInt8(ascii: "(") {
                contexts.append(.code(interpolationBase: openBrackets.count))
                open(UInt8(ascii: "("))
                index = afterDelimiter + 1
            } else {
                // An escape: skip the escaped byte too.
                index = afterDelimiter + 1
            }

        case UInt8(ascii: "\""):
            let quotes = multiline ? 3 : 1
            let closesQuotes = (0..<quotes).allSatisfy { byte(at: index + $0) == UInt8(ascii: "\"") }
            if closesQuotes, hashCount(from: index + quotes) >= hashes {
                index += quotes + hashes
                contexts.removeLast()
            } else {
                index += 1
            }

        case UInt8(ascii: "\n") where !multiline:
            contexts.removeLast()
            index += 1

        default:
            index += 1
        }
    }
}
