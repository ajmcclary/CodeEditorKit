@testable import CodeEditorPlugin
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@Suite("SwiftSyntaxHighlighter UTF-8 to UTF-16 range conversion")
struct SwiftSyntaxHighlighterTests {
    // MARK: - Multi-byte character tests

    @Test("emoji in comment before a keyword produces correct UTF-16 ranges")
    func emojiBeforeKeyword() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "// \u{1F600}\nlet x = 1"
        let tokens = highlighter.highlight(source: source)

        // Verify at least one token exists and all ranges are valid
        #expect(!tokens.isEmpty)
        let utf16Count = source.utf16.count
        for token in tokens {
            #expect(token.range.location >= 0)
            let max = token.range.location + token.range.length
            #expect(max <= utf16Count, "Token range \(token.range) exceeds UTF-16 count \(utf16Count)")
        }
    }

    @Test("emoji identifier before a keyword shifts token ranges correctly")
    func emojiIdentifierBeforeKeyword() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "let \u{1F600} = 1; let x = 2"
        let tokens = highlighter.highlight(source: source)

        // Find the SECOND "let" (the one before "x")
        let letTokens = tokens.filter { $0.text.trimmingCharacters(in: .whitespaces) == "let" }
        #expect(letTokens.count == 2, "Expected 2 let tokens, got \(letTokens.count)")
        if letTokens.count >= 2 {
            // "let 😀 = 1; " = 3+1+2+1+1+1+1+1+1+1 = 13 UTF-16
            let secondLet = letTokens[1]
            #expect(secondLet.range.location > 4,
                     "Second 'let' should be after emoji, got location \(secondLet.range.location)")
        }
    }

    @Test("CJK character before Swift token produces correct UTF-16 ranges")
    func cjkBeforeToken() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "let \u{4E16} = 1; let x = 2"
        let tokens = highlighter.highlight(source: source)

        let letTokens = tokens.filter { $0.text.trimmingCharacters(in: .whitespaces) == "let" }
        #expect(letTokens.count >= 2, "Expected at least 2 let tokens, got \(letTokens.count)")
        if letTokens.count >= 2 {
            // The second "let" is after the CJK identifier
            #expect(letTokens[1].range.location > 4)
        }
    }

    @Test("accented character before keyword produces correct UTF-16 ranges")
    func accentedBeforeKeyword() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "let \u{00E9} = 1; let x = 2"
        let tokens = highlighter.highlight(source: source)

        let letTokens = tokens.filter { $0.text.trimmingCharacters(in: .whitespaces) == "let" }
        #expect(letTokens.count >= 2, "Expected at least 2 let tokens, got \(letTokens.count)")
        if letTokens.count >= 2 {
            // The second "let" should start after the accented-char identifier
            #expect(letTokens[1].range.location > 4)
        }
    }

    @Test("mixed multi-byte characters produce valid NSRanges")
    func mixedMultiByte() {
        let highlighter = SwiftSyntaxHighlighter()
        // emoji in comment, accented in string, CJK as identifier
        let source = "// \u{1F600}\nlet \u{4E16} = \"\u{00E9}\"; let y = 42"
        let tokens = highlighter.highlight(source: source)

        #expect(!tokens.isEmpty)
        let utf16Count = source.utf16.count
        for token in tokens {
            #expect(token.range.location >= 0)
            let max = token.range.location + token.range.length
            #expect(max <= utf16Count, "Token range \(token.range) exceeds UTF-16 count \(utf16Count)")
        }
    }

    @Test("all token ranges are within the source string's UTF-16 bounds")
    func rangesWithinBounds() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "let x = \u{1F600}\nfunc \u{4E16}\u{00E9}() {}"
        let tokens = highlighter.highlight(source: source)
        let utf16Count = source.utf16.count

        for token in tokens {
            let max = token.range.location + token.range.length
            #expect(token.range.location >= 0,
                     "Token '\(token.text)' has negative location: \(token.range.location)")
            #expect(max <= utf16Count,
                     "Token '\(token.text)' range \(token.range) exceeds UTF-16 count \(utf16Count)")
            // Verify the text matches the source at that range
            let startIndex = source.utf16.index(source.utf16.startIndex, offsetBy: token.range.location)
            let endIndex = source.utf16.index(startIndex, offsetBy: token.range.length)
            let sourceText = String(source.utf16[startIndex..<endIndex]) ?? ""
            let trimmedSource = sourceText.trimmingCharacters(in: .whitespaces)
            let trimmedToken = token.text.trimmingCharacters(in: .whitespaces)
            #expect(trimmedSource == trimmedToken,
                     "Token '\(token.text)' text mismatch at range \(token.range) with source '\(sourceText)'")
        }
    }

    @Test("line comment trivia with emoji produces valid UTF-16 ranges")
    func lineCommentWithMultiBytePrefix() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "// \u{1F600} comment\nlet x = 1"
        let tokens = highlighter.highlight(source: source)

        #expect(!tokens.isEmpty)
        let utf16Count = source.utf16.count
        for token in tokens {
            #expect(token.range.location >= 0)
            let max = token.range.location + token.range.length
            #expect(max <= utf16Count, "Token range \(token.range) exceeds length \(utf16Count)")
        }
    }

    @Test("block comment trivia with emoji produces valid UTF-16 ranges")
    func blockCommentWithMultiBytePrefix() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "/* \u{1F600} block */\nlet x = 1"
        let tokens = highlighter.highlight(source: source)

        #expect(!tokens.isEmpty)
        let utf16Count = source.utf16.count
        for token in tokens {
            #expect(token.range.location >= 0)
            let max = token.range.location + token.range.length
            #expect(max <= utf16Count, "Token range \(token.range) exceeds length \(utf16Count)")
        }
    }

    // MARK: - Regression tests

    @Test("simple ASCII source still produces correct ranges")
    func asciiSource() {
        let highlighter = SwiftSyntaxHighlighter()
        let source = "func hello(){}"
        let tokens = highlighter.highlight(source: source)

        #expect(!tokens.isEmpty)
        let funcTokens = tokens.filter { $0.text.trimmingCharacters(in: .whitespaces) == "func" }
        #expect(!funcTokens.isEmpty, "Should find 'func' keyword")
        if let funcToken = funcTokens.first {
            #expect(funcToken.range.location == 0)
        }
    }

    @Test("empty source produces no tokens")
    func emptySource() {
        let highlighter = SwiftSyntaxHighlighter()
        let tokens = highlighter.highlight(source: "")
        #expect(tokens.isEmpty)
    }
}
