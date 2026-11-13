@testable import CodeEditorLSP
import Foundation
import Testing

/// Regression: `LSPCompletionProvider.convertLSPRangeToNSRange` used to
/// accumulate `String.count` (grapheme-cluster count) when summing prior
/// lines, where the LSP spec defines `Position.character` as a UTF-16 code
/// unit offset. Result: completion edits landed at wrong offsets in any
/// file whose prior lines contained non-BMP characters such as emoji
/// (REVIEW.md LSP/Critical).
@Suite("LSPCompletionProvider range conversion")
struct LSPCompletionRangeConversionTests {
    @Test("Multi-line range with non-BMP prior line uses UTF-16 line lengths")
    func multiLineRangeWithEmojiInPriorLine() {
        // text: "😀\nline1"
        // UTF-16: 😀=2, \n=1, l=1, i=1, n=1, e=1, 1=1  -> total 8 units.
        // LSP line=1 char=0 must map to UTF-16 offset 3 (start of "line1").
        // LSP line=1 char=5 must map to UTF-16 offset 8 (end of "line1").
        // With the old grapheme-count bug both came out 1 too low.
        let text = "😀\nline1"
        let range = LSPRange(
            start: Position(line: 1, character: 0),
            end: Position(line: 1, character: 5)
        )
        let nsRange = LSPCompletionProvider.convertLSPRangeToNSRange(range, in: text)
        #expect(nsRange == NSRange(location: 3, length: 5))
    }

    @Test("Single-line ranges are unaffected (no prior-line accumulation)")
    func singleLineRangeIsUnchanged() {
        let text = "hello world"
        let range = LSPRange(
            start: Position(line: 0, character: 6),
            end: Position(line: 0, character: 11)
        )
        let nsRange = LSPCompletionProvider.convertLSPRangeToNSRange(range, in: text)
        #expect(nsRange == NSRange(location: 6, length: 5))
    }

    @Test("Range entirely within a line containing a leading emoji")
    func rangeAfterEmojiOnSameLine() {
        // text: "abc\n😀tail"
        // UTF-16 of line 1: 😀=2, t=1, a=1, i=1, l=1 -> length 6.
        // LSP line=1 char=2 -> right after the emoji on line 1.
        // Prior-line accumulation: line 0 utf16=3, +1 newline -> 4.
        // Expected NSRange: (4 + 2, end - start) = (6, 4) covering "tail".
        let text = "abc\n😀tail"
        let range = LSPRange(
            start: Position(line: 1, character: 2),
            end: Position(line: 1, character: 6)
        )
        let nsRange = LSPCompletionProvider.convertLSPRangeToNSRange(range, in: text)
        #expect(nsRange == NSRange(location: 6, length: 4))
    }

    @Test("Out-of-bounds end position clamps to document UTF-16 length")
    func endClampsToDocumentLength() {
        let text = "abc"
        let range = LSPRange(
            start: Position(line: 0, character: 1),
            end: Position(line: 0, character: 99)
        )
        let nsRange = LSPCompletionProvider.convertLSPRangeToNSRange(range, in: text)
        #expect(nsRange == NSRange(location: 1, length: 2))
    }

    @Test("CRLF counts as one line terminator in both directions")
    func crlfIsOneTerminator() {
        let text = (0..<10).map { "line\($0)" }.joined(separator: "\r\n")
        let lineNine = text.utf16.count - "line9".utf16.count
        #expect(LSPTextPosition.position(forUTF16Offset: lineNine + 2, in: text) == Position(line: 9, character: 2))

        let range = LSPRange(start: Position(line: 9, character: 0), end: Position(line: 9, character: 5))
        #expect(LSPCompletionProvider.convertLSPRangeToNSRange(range, in: text) == NSRange(location: lineNine, length: 5))
    }

    @Test("Only LF, CRLF and CR end a line")
    func onlyLSPTerminatorsEndALine() {
        let text = "a\u{2028}b\u{000C}c\rd\ne"
        #expect(LSPTextPosition.position(forUTF16Offset: 5, in: text) == Position(line: 0, character: 5))
        #expect(LSPTextPosition.position(forUTF16Offset: 6, in: text) == Position(line: 1, character: 0))
        #expect(LSPTextPosition.position(forUTF16Offset: 8, in: text) == Position(line: 2, character: 0))
        #expect(LSPTextPosition.utf16Offset(for: Position(line: 2, character: 0), in: text) == 8)
        #expect(LSPTextPosition.utf16Offset(for: Position(line: 1, character: 0), in: text) == 6)
    }

    @Test("An offset inside CRLF is the end of its line; positions round-trip")
    func roundTrip() {
        let text = "ab\r\ncd\re\n\nf"
        #expect(LSPTextPosition.position(forUTF16Offset: 3, in: text) == Position(line: 0, character: 2))
        for offset in [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11] {
            let position = LSPTextPosition.position(forUTF16Offset: offset, in: text)
            #expect(LSPTextPosition.utf16Offset(for: position, in: text) == offset, "offset \(offset) -> \(position)")
        }
    }
}
