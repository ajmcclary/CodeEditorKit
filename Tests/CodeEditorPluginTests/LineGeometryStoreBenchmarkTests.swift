@testable import CodeEditorPlugin
import Foundation
import XCTest

// MARK: - LineGeometryStore Benchmark & Correctness Tests
//
// Phase 0 of the LineGeometryStore implementation strategy.
// These tests establish the correctness baseline that the new store must meet
// and the performance baseline it must beat.
//
// Categories:
//   1. ASCII correctness (offset ↔ line round-trips)
//   2. Emoji / composed-character correctness (UTF-16 vs Swift Character)
//   3. Line-ending variants (LF, CRLF, CR, mixed, trailing-newline)
//   4. NSRange round-trip tests (every offset maps correctly)
//   5. Performance benchmarks (build, lookup, insert, delete at scale)
//   6. Fuzz harness (random edit sequences vs known-correct rebuild)

@MainActor
final class LineGeometryStoreBenchmarkTests: XCTestCase {
    // MARK: - Helpers

    /// Build offsets using NSString for known-correct UTF-16 positions.
    /// This is the reference implementation that the LineGeometryStore must match.
    ///
    /// Uses `getLineStart(_:end:contentsEnd:for:)` so we can distinguish a
    /// line that ends with a terminator (contentsEnd < lineEnd, producing a
    /// trailing empty line) from the final line without a terminator
    /// (contentsEnd == lineEnd, no trailing empty line).
    private func referenceLineOffsets(for text: String) -> [Int] {
        let nsString = text as NSString
        var offsets: [Int] = [0]
        var index = 0
        let length = nsString.length
        while index < length {
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            nsString.getLineStart(&lineStart, end: &lineEnd,
                                  contentsEnd: &contentsEnd,
                                  for: NSRange(location: index, length: 0))
            index = lineEnd
            let isTerminatedLine = contentsEnd < lineEnd
            if index < length || (index == length && isTerminatedLine) {
                offsets.append(index)
            }
            if index >= length { break }
        }
        return offsets
    }

    /// Build the reference line count from NSString.
    private func referenceLineCount(for text: String) -> Int {
        referenceLineOffsets(for: text).count
    }

    // MARK: - 1. ASCII Correctness

    func testASCIISingleLine() {
        let text = "Hello, World!"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 1)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(referenceLineCount(for: text), 1)
    }

    func testASCIIMultiLineLF() {
        let text = "Line 1\nLine 2\nLine 3"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[0], 0)   // "Line 1\n"
        XCTAssertEqual(offsets[1], 7)   // "Line 2\n"
        XCTAssertEqual(offsets[2], 14)  // "Line 3"

        // Verify line count
        XCTAssertEqual(referenceLineCount(for: text), 3)

        // Verify line ranges
        let nsString = text as NSString
        let line0Range = nsString.lineRange(for: NSRange(location: 0, length: 0))
        XCTAssertEqual(line0Range.location, 0)
        XCTAssertEqual(line0Range.length, 7) // "Line 1\n"

        let line1Range = nsString.lineRange(for: NSRange(location: 7, length: 0))
        XCTAssertEqual(line1Range.location, 7)
        XCTAssertEqual(line1Range.length, 7) // "Line 2\n"

        let line2Range = nsString.lineRange(for: NSRange(location: 14, length: 0))
        XCTAssertEqual(line2Range.location, 14)
        XCTAssertEqual(line2Range.length, 6) // "Line 3" (no trailing newline)
    }

    func testASCIIEmptyText() {
        let text = ""
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 1)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(referenceLineCount(for: text), 1)
    }

    func testASCIIOffsetToLineRoundTrip() {
        let text = "a\nbb\nccc\ndddd\neeeee"
        let nsString = text as NSString

        // Walk every offset and verify that the line index at that offset
        // maps back to a line containing that offset.
        for offset in 0..<nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: offset, length: 0))
            XCTAssertTrue(NSLocationInRange(offset, lineRange),
                          "Offset \(offset) not in its own line range \(lineRange)")
        }
    }

    func testASCIILineToOffsetRoundTrip() {
        let text = "a\nbb\nccc\ndddd\neeeee"
        let nsString = text as NSString

        var lineIndex = 0
        var cursor = 0
        while cursor < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: cursor, length: 0))
            // The start of line 'lineIndex' should be cursor
            XCTAssertEqual(lineRange.location, cursor,
                           "Line \(lineIndex) starts at \(lineRange.location), expected \(cursor)")
            cursor = NSMaxRange(lineRange)
            lineIndex += 1
        }
        XCTAssertEqual(lineIndex, 5)
    }

    func testASCIILineNumberAtOffset() {
        let text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        let nsString = text as NSString

        // offset 0 → line 0
        var lineRange = nsString.lineRange(for: NSRange(location: 0, length: 0))
        XCTAssertEqual(lineRange.location, 0)

        // offset 7 → line 1
        lineRange = nsString.lineRange(for: NSRange(location: 7, length: 0))
        XCTAssertEqual(lineRange.location, 7)

        // offset 14 → line 2
        lineRange = nsString.lineRange(for: NSRange(location: 14, length: 0))
        XCTAssertEqual(lineRange.location, 14)

        // offset 21 → line 3
        lineRange = nsString.lineRange(for: NSRange(location: 21, length: 0))
        XCTAssertEqual(lineRange.location, 21)

        // offset 28 → line 4
        lineRange = nsString.lineRange(for: NSRange(location: 28, length: 0))
        XCTAssertEqual(lineRange.location, 28)
    }

    // MARK: - 2. Emoji & Composed Character Correctness

    func testSingleScalarEmoji() {
        // 😀 = U+1F600 (4 UTF-8 bytes, 2 UTF-16 code units)
        let text = "😀"
        let nsString = text as NSString

        XCTAssertEqual(nsString.length, 2, "😀 should be 2 UTF-16 code units")
        XCTAssertEqual(text.count, 1, "😀 should be 1 Swift Character")

        let offsets = referenceLineOffsets(for: text)
        XCTAssertEqual(offsets.count, 1)
        XCTAssertEqual(offsets[0], 0)
    }

    func testZWJSequenceEmoji() {
        // 👨‍👩‍👧‍👦 = man + ZWJ + woman + ZWJ + girl + ZWJ + boy
        // 1 Swift Character, 11 UTF-16 code units
        let text = "👨‍👩‍👧‍👦"
        let nsString = text as NSString

        XCTAssertEqual(nsString.length, 11, "👨‍👩‍👧‍👦 should be 11 UTF-16 code units")
        XCTAssertEqual(text.count, 1, "👨‍👩‍👧‍👦 should be 1 Swift Character")

        let offsets = referenceLineOffsets(for: text)
        XCTAssertEqual(offsets.count, 1)
        XCTAssertEqual(offsets[0], 0)
    }

    func testComposedCharacterEAcute() {
        // é as precomposed: U+00E9 (1 UTF-16 code unit, 1 Character)
        let precomposed = "\u{00E9}"
        let nsPrecomposed = precomposed as NSString
        XCTAssertEqual(nsPrecomposed.length, 1)
        XCTAssertEqual(precomposed.count, 1)

        // é as e + combining acute: U+0065 U+0301 (2 UTF-16 code units, 1 Character)
        let decomposed = "e\u{0301}"
        let nsDecomposed = decomposed as NSString
        XCTAssertEqual(nsDecomposed.length, 2)
        XCTAssertEqual(decomposed.count, 1)

        // Both should produce the same line offsets
        let offsets1 = referenceLineOffsets(for: precomposed)
        let offsets2 = referenceLineOffsets(for: decomposed)
        XCTAssertEqual(offsets1.count, 1)
        XCTAssertEqual(offsets2.count, 1)
    }

    func testEmojiInMultiLineText() {
        // "a😀b\nc👨‍👩‍👧‍👦d\nefé"
        let text = "a😀b\nc👨‍👩‍👧‍👦d\nef\u{00E9}"
        let nsString = text as NSString

        // UTF-16 lengths:
        // "a😀b\n"  = 1 + 2 + 1 + 1 = 5
        // "c👨‍👩‍👧‍👦d\n" = 1 + 11 + 1 + 1 = 14
        // "efé"     = 1 + 1 + 1 = 3

        let offsets = referenceLineOffsets(for: text)
        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(offsets[1], 5)
        XCTAssertEqual(offsets[2], 19)

        // Verify every offset round-trips
        for offset in 0..<nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: offset, length: 0))
            XCTAssertTrue(NSLocationInRange(offset, lineRange),
                          "Offset \(offset) not in its own line range \(lineRange) for emoji text")
        }
    }

    func testCharacterVsUTF16OffsetDivergence() {
        // This test demonstrates the bug described in ANALYSIS.md §5.1.1:
        // Swift Character iteration yields different offsets than NSString UTF-16.

        let text = "a😀b\nc👨‍👩‍👧‍👦d"

        // Swift Character iteration (what LineIndexCache.buildCache does)
        var charOffsets: [Int] = [0]
        var currentCharOffset = 0
        for char in text {
            currentCharOffset += 1
            if char == "\n" {
                charOffsets.append(currentCharOffset)
            }
        }
        // "a😀b\nc👨‍👩‍👧‍👦d" has 6 Swift Characters: a, 😀, b, \n, c, 👨‍👩‍👧‍👦, d
        // Character offsets: [0, 4] (newline at character index 4)

        // NSString UTF-16 offsets (correct)
        let utf16Offsets = referenceLineOffsets(for: text)
        // "a😀b\nc👨‍👩‍👧‍👦d" in UTF-16: a(1) 😀(2) b(1) \n(1) = 5, then c(1) 👨‍👩‍👧‍👦(11) d(1) = 13
        // UTF-16 offsets: [0, 5]

        // They SHOULD differ — this is the bug.
        XCTAssertNotEqual(charOffsets, utf16Offsets,
                          "Character offsets [\(charOffsets)] MUST differ from UTF-16 offsets [\(utf16Offsets)] for emoji text")
        XCTAssertEqual(utf16Offsets, [0, 5],
                       "Correct UTF-16 offsets should be [0, 5]")
        XCTAssertEqual(charOffsets, [0, 4],
                       "Character offsets should be [0, 4] — this is the bug in LineIndexCache")
    }

    // MARK: - 3. Line-Ending Variants

    func testLFLineEndings() {
        let text = "line1\nline2\nline3"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(offsets[1], 6)  // "line1\n"
        XCTAssertEqual(offsets[2], 12) // "line2\n"

        // Verify line ranges include the newline
        let nsString = text as NSString
        let line0 = nsString.lineRange(for: NSRange(location: 0, length: 0))
        XCTAssertEqual(line0.length, 6) // "line1\n"
    }

    func testCRLFLineEndings() {
        let text = "line1\r\nline2\r\nline3"
        let nsString = text as NSString

        let offsets = referenceLineOffsets(for: text)
        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(offsets[1], 7)  // "line1\r\n" = 7 UTF-16 units
        XCTAssertEqual(offsets[2], 14) // "line2\r\n" = 7 UTF-16 units

        // Verify line ranges include both \r and \n
        let line0 = nsString.lineRange(for: NSRange(location: 0, length: 0))
        XCTAssertEqual(line0.length, 7)
    }

    func testCRLineEndings() {
        let text = "line1\rline2\rline3"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(offsets[1], 6)  // "line1\r"
        XCTAssertEqual(offsets[2], 12) // "line2\r"
    }

    func testMixedLineEndings() {
        let text = "LF\nCRLF\r\nCR\rLF\n"
        let nsString = text as NSString
        let offsets = referenceLineOffsets(for: text)

        // NSString treats CR, LF, and CRLF as line separators.
        // "LF\n" = 3, "CRLF\r\n" = 6, "CR\r" = 3, "LF\n" = 3, "" (trailing empty) = 0
        // Total: 5 lines (trailing newline produces an empty last line)
        XCTAssertEqual(offsets.count, 5)
        XCTAssertEqual(offsets, [0, 3, 9, 12, 15])

        // Verify every offset round-trips
        for offset in 0..<nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: offset, length: 0))
            XCTAssertTrue(NSLocationInRange(offset, lineRange),
                          "Offset \(offset) not in line range \(lineRange) for mixed endings")
        }
    }

    func testTrailingNewlinePresent() {
        let text = "line1\nline2\n"
        let offsets = referenceLineOffsets(for: text)

        // NSString reports 3 lines for trailing-newline text
        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[0], 0)  // "line1\n"
        XCTAssertEqual(offsets[1], 6)  // "line2\n"
        XCTAssertEqual(offsets[2], 12) // "" (empty last line)

        XCTAssertEqual(referenceLineCount(for: text), 3)
    }

    func testTrailingNewlineAbsent() {
        let text = "line1\nline2"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 2)
        XCTAssertEqual(referenceLineCount(for: text), 2)
    }

    func testMultipleBlankLines() {
        let text = "a\n\n\nb"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 4)
        XCTAssertEqual(offsets[0], 0) // "a\n"
        XCTAssertEqual(offsets[1], 2) // "\n"
        XCTAssertEqual(offsets[2], 3) // "\n"
        XCTAssertEqual(offsets[3], 4) // "b"

        // Every offset should be in a valid line
        let nsString = text as NSString
        for offset in 0..<nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: offset, length: 0))
            XCTAssertTrue(lineRange.length >= 1 || (offset == nsString.length - 1 && text.hasSuffix("\n") == false),
                          "Offset \(offset) has empty line range \(lineRange)")
        }
    }

    // MARK: - 4. NSRange Round-Trip Tests

    func testNSRangeRoundTripEveryOffset() {
        // Test that for every offset in the text, the line range contains that offset.
        let text = """
        import Foundation

        /// Documentation comment
        public func hello() -> String {
            let greeting = "Hello, World!"
            return greeting
        }
        """

        let nsString = text as NSString
        for offset in 0..<nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: offset, length: 0))
            XCTAssertTrue(NSLocationInRange(offset, lineRange),
                          "Round-trip failed: offset \(offset) not in \(lineRange)")
        }
    }

    func testNSRangeLineStartOffsetsAreConsistent() {
        let text = """
        A
        BB
        CCC
        DDDD
        EEEEE
        """
        let nsString = text as NSString

        var lineStarts: [Int] = []
        var cursor = 0
        while cursor < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: cursor, length: 0))
            lineStarts.append(lineRange.location)
            cursor = NSMaxRange(lineRange)
        }

        XCTAssertEqual(lineStarts, [0, 2, 5, 9, 14])
    }

    func testNSRangeLineAtIndex() {
        // Build a known line-offset array and verify it against NSString
        let text = String(repeating: "line\n", count: 100) + "final"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 101)
        XCTAssertEqual(offsets[0], 0)
        for i in 0..<100 {
            XCTAssertEqual(offsets[i], i * 5) // "line\n" = 5 UTF-16 units
        }
    }

    // MARK: - 5. Performance Benchmarks

    func testBuildPerformance10kLines() {
        let text = (1...10_000).map { "Line \($0) with some filler content to make lines longer\n" }.joined()

        measure(options: Self.ultraFastMeasureOptions) {
            autoreleasepool {
                _ = referenceLineOffsets(for: text)
            }
        }
    }

    func testBuildPerformance100kLines() {
        let text = (1...100_000).map { "L\($0)\n" }.joined()

        measure(options: Self.ultraFastMeasureOptions) {
            autoreleasepool {
                _ = referenceLineOffsets(for: text)
            }
        }
    }

    func testOffsetToLineLookup10kQueries() {
        let text = (1...10_000).map { "Line \($0) with some content\n" }.joined()
        let nsString = text as NSString
        let midPoint = nsString.length / 2

        measure(options: Self.ultraFastMeasureOptions) {
            autoreleasepool {
                // Binary-search-style lookups across the document
                for offset in stride(from: 0, to: nsString.length, by: nsString.length / 100) {
                    _ = nsString.lineRange(for: NSRange(location: offset, length: 0))
                }
                _ = nsString.lineRange(for: NSRange(location: midPoint, length: 0))
            }
        }
    }

    func testLineCountPerformance1MLines() {
        let text = String(repeating: "x\n", count: 1_000_000)

        measure(options: Self.ultraFastMeasureOptions) {
            autoreleasepool {
                _ = referenceLineCount(for: text)
            }
        }
    }

    // MARK: - 6. Fuzz Test Harness

    /// Generate a random edit: pick a random range in the document and
    /// replace it with random ASCII text (which may contain newlines).
    private func randomEdit(for text: String) -> (range: NSRange, replacement: String)? {
        let nsString = text as NSString
        guard nsString.length > 0 else { return nil }

        let loc = Int.random(in: 0..<nsString.length)
        let maxLen = min(50, nsString.length - loc)
        let len = Int.random(in: 0...maxLen)
        let range = NSRange(location: loc, length: len)

        // Generate random replacement (0-20 chars, may include newlines)
        let replacementLen = Int.random(in: 0...20)
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t"
        let replacement = String((0..<replacementLen).map { _ in chars.randomElement()! })

        return (range, replacement)
    }

    /// Apply an edit to a string and return the new string.
    private func apply(edit: (range: NSRange, replacement: String), to text: String) -> String {
        let nsString = text as NSString
        return nsString.replacingCharacters(in: edit.range, with: edit.replacement)
    }

    func testFuzzIncrementalEditCorrectness() {
        // Start with a known document, apply 200 random edits,
        // and verify that after each edit, a full rebuild of line offsets
        // matches the expected state.

        var text = """
        import Foundation

        /// A sample Swift file for fuzz testing.
        public struct FuzzTest {
            var value: Int = 0

            mutating func increment() {
                value += 1
            }

            func description() -> String {
                return "Value: \\(value)"
            }
        }
        """

        for iteration in 0..<200 {
            guard let edit = randomEdit(for: text) else { continue }
            text = apply(edit: edit, to: text)

            // Full rebuild from scratch (reference)
            let referenceOffsets = referenceLineOffsets(for: text)

            // Basic sanity: first offset is always 0
            XCTAssertEqual(referenceOffsets.first, 0,
                           "Iteration \(iteration): first offset should be 0, got \(referenceOffsets.first ?? -1)")

            // Basic sanity: offsets are strictly increasing
            for i in 1..<referenceOffsets.count {
                XCTAssertLessThan(referenceOffsets[i - 1], referenceOffsets[i],
                                  "Iteration \(iteration): offsets not increasing at index \(i): \(referenceOffsets[i - 1]) >= \(referenceOffsets[i])")
            }

            // Every offset in the document belongs to exactly one line
            let nsString = text as NSString
            for offset in 0..<max(1, nsString.length) {
                let lineRange = nsString.lineRange(for: NSRange(location: min(offset, nsString.length - 1), length: 0))
                XCTAssertTrue(lineRange.length > 0 || nsString.length == 0,
                              "Iteration \(iteration): offset \(offset) has empty line range")
            }
        }
    }

    func testFuzzLineCountAfterRandomEdits() {
        var text = "start\n"
        for i in 0..<100 {
            guard let edit = randomEdit(for: text) else { continue }
            text = apply(edit: edit, to: text)

            let offsets = referenceLineOffsets(for: text)
            let lineCount = offsets.count
            let nsString = text as NSString

            // Verify every offset maps to a valid line that contains it
            for offset in offsets where offset < nsString.length {
                let lineRange = nsString.lineRange(for: NSRange(location: offset, length: 0))
                XCTAssertTrue(NSLocationInRange(offset, lineRange),
                              "Iteration \(i): offset \(offset) not in its own line range \(lineRange)")
            }

            // Verify offsets are strictly increasing
            for j in 1..<offsets.count {
                XCTAssertLessThan(offsets[j - 1], offsets[j],
                                  "Iteration \(i): offsets not increasing")
            }

            // Line count must be at least 1
            XCTAssertGreaterThanOrEqual(lineCount, 1,
                                        "Iteration \(i): line count should be >= 1")
        }
    }

    // MARK: - 7. Edge Cases

    func testSingleNewlineOnly() {
        let text = "\n"
        let offsets = referenceLineOffsets(for: text)
        XCTAssertEqual(offsets.count, 2)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(offsets[1], 1)
    }

    func testOnlyNewlines() {
        let text = "\n\n\n"
        let offsets = referenceLineOffsets(for: text)
        XCTAssertEqual(offsets.count, 4)
    }

    func testVeryLongLine() {
        let longLine = String(repeating: "x", count: 100_000)
        let text = longLine + "\n" + "short"
        let offsets = referenceLineOffsets(for: text)

        XCTAssertEqual(offsets.count, 2)
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(offsets[1], 100_001) // 100,000 'x' + '\n'

        // First line range should span the entire long line
        let nsString = text as NSString
        let line0 = nsString.lineRange(for: NSRange(location: 0, length: 0))
        XCTAssertEqual(line0.location, 0)
        XCTAssertEqual(line0.length, 100_001)
    }

    func testVeryManyShortLines() {
        let text = String(repeating: "x\n", count: 50_000)
        let offsets = referenceLineOffsets(for: text)

        // 50,000 lines of "x\n" + the trailing empty line = 50,001
        XCTAssertEqual(offsets.count, 50_001)
        // Verify the first few and last few
        XCTAssertEqual(offsets[0], 0)
        XCTAssertEqual(offsets[1], 2)
        XCTAssertEqual(offsets[2], 4)
        XCTAssertEqual(offsets[49_999], 99_998)
        XCTAssertEqual(offsets[50_000], 100_000)
    }

    // MARK: - 8. LineGeometryStore Integration Tests

    /// Helper: build a `LineGeometryStore` from a plain String.
    private func makeStore(for text: String) -> LineGeometryStore {
        let storage = NSTextStorage(string: text)
        let store = LineGeometryStore()
        store.build(from: storage)
        return store
    }

    /// Verify that the store's offsets match the reference implementation
    /// for a given text. Returns the reference offsets for further assertions.
    @discardableResult
    private func assertStoreMatchesReference(
        for text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [Int] {
        let referenceOffsets = referenceLineOffsets(for: text)
        let store = makeStore(for: text)

        // Line count must match
        XCTAssertEqual(store.lineCount, referenceOffsets.count,
                       "Line count mismatch", file: file, line: line)

        // Total UTF-16 length must match NSString length
        let nsString = text as NSString
        XCTAssertEqual(store.totalUtf16Length, nsString.length,
                       "Total UTF-16 length mismatch", file: file, line: line)

        // Every reference offset must map to the correct line index
        for (lineIndex, expectedOffset) in referenceOffsets.enumerated() {
            let actualOffset = store.utf16Offset(forLineIndex: lineIndex)
            XCTAssertEqual(actualOffset, expectedOffset,
                           "Line \(lineIndex): expected offset \(expectedOffset), got \(actualOffset)",
                           file: file, line: line)
        }

        // Every offset in the document must round-trip through the store
        for offset in 0..<nsString.length {
            let lineIdx = store.lineIndex(forUtf16Offset: offset)
            let lineStart = store.utf16Offset(forLineIndex: lineIdx)
            let lineEnd = lineIdx + 1 < store.lineCount
                ? store.utf16Offset(forLineIndex: lineIdx + 1)
                : nsString.length
            XCTAssertTrue(offset >= lineStart && offset < lineEnd,
                          "Offset \(offset) not in line [\(lineStart), \(lineEnd))",
                          file: file, line: line)
        }

        // Tree must be valid
        XCTAssertTrue(store.validateTree(), "Red-black tree invariants violated",
                      file: file, line: line)

        return referenceOffsets
    }

    func testStoreMatchesReferenceASCIISingleLine() {
        assertStoreMatchesReference(for: "Hello, World!")
    }

    func testStoreMatchesReferenceASCIIMultiLine() {
        assertStoreMatchesReference(for: "Line 1\nLine 2\nLine 3")
    }

    func testStoreMatchesReferenceEmpty() {
        assertStoreMatchesReference(for: "")
    }

    func testStoreMatchesReferenceEmoji() {
        assertStoreMatchesReference(for: "a😀b\nc👨‍👩‍👧‍👦d\nef\u{00E9}")
    }

    func testStoreMatchesReferenceCRLF() {
        assertStoreMatchesReference(for: "line1\r\nline2\r\nline3")
    }

    func testStoreMatchesReferenceCR() {
        assertStoreMatchesReference(for: "line1\rline2\rline3")
    }

    func testStoreMatchesReferenceMixedEndings() {
        assertStoreMatchesReference(for: "LF\nCRLF\r\nCR\rLF\n")
    }

    func testStoreMatchesReferenceTrailingNewline() {
        assertStoreMatchesReference(for: "line1\nline2\n")
    }

    func testStoreMatchesReferenceNoTrailingNewline() {
        assertStoreMatchesReference(for: "line1\nline2")
    }

    func testStoreMatchesReferenceMultipleBlankLines() {
        assertStoreMatchesReference(for: "a\n\n\nb")
    }

    func testStoreMatchesReferenceSingleNewline() {
        assertStoreMatchesReference(for: "\n")
    }

    func testStoreMatchesReferenceSwiftFile() {
        let text = """
        import Foundation

        /// A sample file.
        public struct Test {
            var value: Int = 0
        }
        """
        assertStoreMatchesReference(for: text)
    }

    func testStoreLineGeometryAccess() {
        let text = "line1\nline2\nline3"
        let store = makeStore(for: text)

        // Access individual line geometries
        let geom0 = store.lineGeometry(at: 0)
        XCTAssertNotNil(geom0)
        XCTAssertEqual(geom0?.utf16Offset, 0)
        XCTAssertEqual(geom0?.utf16Length, 6) // "line1\n"
        XCTAssertEqual(geom0?.lineEndingLength, 1)

        let geom1 = store.lineGeometry(at: 1)
        XCTAssertNotNil(geom1)
        XCTAssertEqual(geom1?.utf16Offset, 6)
        XCTAssertEqual(geom1?.utf16Length, 6)

        let geom2 = store.lineGeometry(at: 2)
        XCTAssertNotNil(geom2)
        XCTAssertEqual(geom2?.utf16Offset, 12)
        XCTAssertEqual(geom2?.utf16Length, 5) // "line3" — no newline
        XCTAssertEqual(geom2?.lineEndingLength, 0)

        // Out of bounds
        XCTAssertNil(store.lineGeometry(at: -1))
        XCTAssertNil(store.lineGeometry(at: 3))
    }

    func testStoreGeometryRangeIteration() {
        let text = "a\nbb\nccc\ndddd\neeeee"
        let store = makeStore(for: text)

        // Get lines in a UTF-16 range
        let range = NSRange(location: 2, length: 10) // covers "bb\nccc\ndd"
        let geometries = store.lineGeometries(in: range)
        XCTAssertEqual(geometries.count, 3) // lines 1, 2, 3
        XCTAssertEqual(geometries[0].utf16Offset, 2) // "bb\n"
        XCTAssertEqual(geometries[1].utf16Offset, 5) // "ccc\n"
        XCTAssertEqual(geometries[2].utf16Offset, 9) // "dddd\n"
    }

    func testStoreHeightTracking() {
        let text = "line1\nline2\nline3"
        let store = makeStore(for: text)

        // Default estimated height
        let defaultHeight: CGFloat = 17.0

        // Each unmeasured line should have effectiveHeight == estimatedHeight
        for idx in 0..<store.lineCount {
            let geom = store.lineGeometry(at: idx)
            XCTAssertEqual(geom?.effectiveHeight, defaultHeight)
            XCTAssertNil(geom?.measuredHeight)
        }

        // Total height should be lineCount * estimatedHeight
        XCTAssertEqual(store.totalHeight, CGFloat(store.lineCount) * defaultHeight)

        // Update a measured height
        store.updateMeasuredHeight(24.0, forLineAt: 1)
        let updatedGeom = store.lineGeometry(at: 1)
        XCTAssertEqual(updatedGeom?.measuredHeight, 24.0)
        XCTAssertEqual(updatedGeom?.effectiveHeight, 24.0)

        // Total height should reflect the change
        XCTAssertEqual(store.totalHeight, defaultHeight + 24.0 + defaultHeight)
    }

    func testStoreFoldState() {
        let text = "line1\nline2\nline3\nline4"
        let store = makeStore(for: text)
        let defaultHeight: CGFloat = 17.0

        // Initial total height
        XCTAssertEqual(store.totalHeight, CGFloat(store.lineCount) * defaultHeight)

        // Fold line 1
        store.setFolded(true, forLineAt: 1)
        XCTAssertTrue(store.lineGeometry(at: 1)?.isFolded ?? false)
        XCTAssertEqual(store.lineGeometry(at: 1)?.effectiveHeight, 0)

        // Total height should decrease by one line height
        XCTAssertEqual(store.totalHeight, CGFloat(store.lineCount - 1) * defaultHeight)

        // Unfold
        store.setFolded(false, forLineAt: 1)
        XCTAssertEqual(store.totalHeight, CGFloat(store.lineCount) * defaultHeight)
    }

    func testStoreYPositionLookup() {
        let text = "line1\nline2\nline3"
        let store = makeStore(for: text)
        let h: CGFloat = 17.0

        // Y-position of each line
        XCTAssertEqual(store.yPosition(forLineIndex: 0), 0)
        XCTAssertEqual(store.yPosition(forLineIndex: 1), h)
        XCTAssertEqual(store.yPosition(forLineIndex: 2), h * 2)

        // Line index from y-position
        XCTAssertEqual(store.lineIndex(forYPosition: 0), 0)
        XCTAssertEqual(store.lineIndex(forYPosition: h - 1), 0)
        XCTAssertEqual(store.lineIndex(forYPosition: h), 1)
        XCTAssertEqual(store.lineIndex(forYPosition: h * 2 - 1), 1)
        XCTAssertEqual(store.lineIndex(forYPosition: h * 2), 2)
    }

    func testStoreAllLineGeometries() {
        let text = "a\nb\nc"
        let store = makeStore(for: text)

        let all = store.allLineGeometries
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].utf16Offset, 0)
        XCTAssertEqual(all[1].utf16Offset, 2)
        XCTAssertEqual(all[2].utf16Offset, 4)
    }

    func testStoreRebuildAfterReset() {
        let store = LineGeometryStore()
        store.build(from: NSTextStorage(string: "first"))
        XCTAssertEqual(store.lineCount, 1)

        store.reset()
        XCTAssertEqual(store.lineCount, 0)

        store.build(from: NSTextStorage(string: "second\nthird"))
        XCTAssertEqual(store.lineCount, 2)
        XCTAssertEqual(store.utf16Offset(forLineIndex: 0), 0)
        XCTAssertEqual(store.utf16Offset(forLineIndex: 1), 7)
    }

    // MARK: - 9. Edit Handler Tests

    /// Simulate a text edit by directly calling `textStorageDidApplyEdit`
    /// on the handler. Verifies the store is rebuilt correctly.
    func testEditHandlerRebuildsAfterCharacterEdit() {
        let textView = CodeEditorView(frame: .zero)
        textView.text = "line1\nline2\nline3"

        // Remove the handler created during setupTextView to test in isolation
        textView.lineGeometryEditHandler?.detach()
        textView.lineGeometryEditHandler = nil

        // Build the store initially
        textView.lineGeometryStore.build(from: textView.textStorage!)
        XCTAssertEqual(textView.lineGeometryStore.lineCount, 3)

        // Create the handler (normally done in setupTextView)
        let handler = LineGeometryEditHandler(
            geometryStore: textView.lineGeometryStore,
            textView: textView
        )

        // Simulate a text edit: insert "extra\n" at the beginning
        let storage = textView.textStorage!
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "extra\n")

        // Fire the edit event
        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 0),
            changeInLength: 6,
            documentLength: storage.length,
            editedCharacters: true
        )
        handler.textStorageDidApplyEdit(event)

        // Store should now reflect the new text
        XCTAssertEqual(textView.lineGeometryStore.lineCount, 4)
        assertStoreMatchesReference(for: storage.string)

        handler.detach()
    }

    func testEditHandlerNoOpOnAttributeOnlyEdit() {
        let textView = CodeEditorView(frame: .zero)
        textView.text = "line1\nline2"

        textView.lineGeometryEditHandler?.detach()
        textView.lineGeometryEditHandler = nil

        textView.lineGeometryStore.build(from: textView.textStorage!)
        XCTAssertEqual(textView.lineGeometryStore.lineCount, 2)

        let handler = LineGeometryEditHandler(
            geometryStore: textView.lineGeometryStore,
            textView: textView
        )

        // Fire an attribute-only edit event
        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 0),
            changeInLength: 0,
            documentLength: textView.textStorage!.length,
            editedCharacters: false
        )
        handler.textStorageDidApplyEdit(event)

        // Store should be unchanged
        XCTAssertEqual(textView.lineGeometryStore.lineCount, 2)

        handler.detach()
    }

    func testEditHandlerMultipleSequentialEdits() {
        let textView = CodeEditorView(frame: .zero)
        textView.text = "a\nb\nc"

        textView.lineGeometryEditHandler?.detach()
        textView.lineGeometryEditHandler = nil

        textView.lineGeometryStore.build(from: textView.textStorage!)
        let handler = LineGeometryEditHandler(
            geometryStore: textView.lineGeometryStore,
            textView: textView
        )

        // Edit 1: insert "X" at position 0
        let storage = textView.textStorage!
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "X")
        handler.textStorageDidApplyEdit(TextEditEvent(
            editedRange: NSRange(location: 0, length: 0),
            changeInLength: 1,
            documentLength: storage.length,
            editedCharacters: true
        ))
        assertStoreMatchesReference(for: storage.string)

        // Edit 2: delete the newline after "b"
        // "Xa\nb\nc" → find the \n after "b"
        let nsString = storage.string as NSString
        let bLineRange = nsString.lineRange(for: NSRange(location: 4, length: 0))
        let newlineLoc = NSMaxRange(bLineRange) - 1
        storage.replaceCharacters(in: NSRange(location: newlineLoc, length: 1), with: "")
        handler.textStorageDidApplyEdit(TextEditEvent(
            editedRange: NSRange(location: newlineLoc, length: 1),
            changeInLength: -1,
            documentLength: storage.length,
            editedCharacters: true
        ))
        assertStoreMatchesReference(for: storage.string)

        // Edit 3: replace all content
        storage.replaceCharacters(
            in: NSRange(location: 0, length: storage.length),
            with: "new\ncontent\nhere"
        )
        handler.textStorageDidApplyEdit(TextEditEvent(
            editedRange: NSRange(location: 0, length: storage.length - 14),
            changeInLength: 14 - (storage.length - 14),
            documentLength: storage.length,
            editedCharacters: true
        ))
        assertStoreMatchesReference(for: storage.string)

        handler.detach()
    }

    func testEditHandlerDetachStopsObserving() {
        let textView = CodeEditorView(frame: .zero)
        textView.text = "test"

        // Detach the handler created during setupTextView() so we can
        // test detach behavior in isolation.
        textView.lineGeometryEditHandler?.detach()
        textView.lineGeometryEditHandler = nil

        textView.lineGeometryStore.build(from: textView.textStorage!)
        let handler = LineGeometryEditHandler(
            geometryStore: textView.lineGeometryStore,
            textView: textView
        )

        // Detach the handler
        handler.detach()

        // Modify text — handler should NOT rebuild
        textView.textStorage?.replaceCharacters(in: NSRange(location: 0, length: 4), with: "changed")
        // The store should still reflect the old text (length 4 = "test")
        XCTAssertEqual(textView.lineGeometryStore.totalUtf16Length, 4)
    }

    func testEditHandlerRegisteredViaSetup() {
        // Verify that a properly set up CodeEditorView has the handler
        let textView = CodeEditorView(frame: .zero)
        textView.text = "line1\nline2"

        // setupTextView is called during init
        XCTAssertNotNil(textView.lineGeometryEditHandler,
                        "Handler should be created during setupTextView()")

        // After setting text, the store should reflect it (handler rebuilds on edit)
        // The initial text set doesn't go through TextEditEventHub, so we build manually
        textView.lineGeometryStore.build(from: textView.textStorage!)
        XCTAssertEqual(textView.lineGeometryStore.lineCount, 2)
    }
}
