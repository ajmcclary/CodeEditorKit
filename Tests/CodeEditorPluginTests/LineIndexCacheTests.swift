@testable import CodeEditorPlugin
import XCTest

final class LineIndexCacheTests: XCTestCase {
    private var cache: LineIndexCache?

    // MARK: - Basic Tests

    override func setUp() {
        super.setUp()
        cache = LineIndexCache()
    }

    override func tearDown() {
        cache = nil
        super.tearDown()
    }

    // Helper to ensure cache is available
    private func requireCache() -> LineIndexCache {
        guard let cache else {
            XCTFail("Cache is not initialized")
            return LineIndexCache() // Return a dummy instance to allow tests to continue
        }
        return cache
    }

    func testLineNumberCalculation() {
        let text = """
        Line 1
        Line 2
        Line 3
        Line 4
        """

        // Test first line
        let cache = requireCache()
        let firstLineNumber = cache.lineNumber(at: 0, in: text)
        XCTAssertEqual(firstLineNumber, 1)
        XCTAssertEqual(cache.lineNumber(at: 5, in: text), 1) // Middle of "Line 1"

        // Test second line
        XCTAssertEqual(cache.lineNumber(at: 7, in: text), 2) // Start of "Line 2"
        XCTAssertEqual(cache.lineNumber(at: 12, in: text), 2) // Middle of "Line 2"

        // Test last line
        guard let lastLineStart = text.lastIndex(of: "4") else {
            XCTFail("Failed to find '4' in text")
            return
        }
        let offset = text.distance(from: text.startIndex, to: lastLineStart)
        XCTAssertEqual(cache.lineNumber(at: offset, in: text), 4)
    }

    func testLineRangeCalculation() {
        let text = """
        Line 1
        Line 2
        Line 3
        """

        // Test first line range
        let range1 = requireCache().lineRangeNSRange(for: 1, in: text)
        XCTAssertNotNil(range1)
        XCTAssertEqual(range1?.location, 0)
        XCTAssertEqual(range1?.length, 7) // "Line 1\n"

        // Test middle line range
        let range2 = requireCache().lineRangeNSRange(for: 2, in: text)
        XCTAssertNotNil(range2)
        XCTAssertEqual(range2?.location, 7)
        XCTAssertEqual(range2?.length, 7) // "Line 2\n"

        // Test last line range (no trailing newline)
        let range3 = requireCache().lineRangeNSRange(for: 3, in: text)
        XCTAssertNotNil(range3)
        XCTAssertEqual(range3?.location, 14)
        XCTAssertEqual(range3?.length, 6) // "Line 3"
    }

    func testLineCount() {
        XCTAssertEqual(requireCache().lineCount(in: ""), 1) // Empty string has 1 line
        XCTAssertEqual(requireCache().lineCount(in: "Hello"), 1)
        XCTAssertEqual(requireCache().lineCount(in: "Hello\nWorld"), 2)
        XCTAssertEqual(requireCache().lineCount(in: "Line 1\nLine 2\nLine 3"), 3)
        XCTAssertEqual(requireCache().lineCount(in: "Line 1\nLine 2\nLine 3\n"), 4) // Trailing newline adds a line
    }

    func testEmptyText() {
        let text = ""

        XCTAssertEqual(requireCache().lineNumber(at: 0, in: text), 1)
        XCTAssertEqual(requireCache().lineCount(in: text), 1)

        let range = requireCache().lineRangeNSRange(for: 1, in: text)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.location, 0)
        XCTAssertEqual(range?.length, 0)
    }

    func testInvalidLineNumbers() {
        let text = "Line 1\nLine 2"

        XCTAssertNil(requireCache().lineRangeNSRange(for: 0, in: text)) // Line numbers are 1-based
        XCTAssertNil(requireCache().lineRangeNSRange(for: 3, in: text)) // Beyond line count
        XCTAssertNil(requireCache().lineRangeNSRange(for: -1, in: text)) // Negative
    }

    // MARK: - Performance Tests

    func testPerformanceWithLargeFile() {
        // Create a large file with 10,000 lines
        let largeText = (1...10_000).map { "Line \($0) with some content" }.joined(separator: "\n")

        measure(options: Self.standardMeasureOptions) {
            // Test multiple operations to ensure cache is working
            _ = requireCache().lineCount(in: largeText)
            _ = requireCache().lineNumber(at: largeText.count / 2, in: largeText)
            _ = requireCache().lineRangeNSRange(for: 5_000, in: largeText)
            _ = requireCache().lineNumber(at: largeText.count - 100, in: largeText)
        }
    }

    func testCacheInvalidation() {
        let text1 = "Line 1\nLine 2"
        let text2 = "Different\nText\nHere"

        // First access builds cache for text1
        XCTAssertEqual(requireCache().lineCount(in: text1), 2)

        // Access with different text should rebuild cache
        XCTAssertEqual(requireCache().lineCount(in: text2), 3)

        // Verify cache was updated by checking line ranges
        let range = requireCache().lineRangeNSRange(for: 3, in: text2)
        XCTAssertNotNil(range)
        if let range, let stringRange = Range(range, in: text2) {
            let substring = text2[stringRange]
            XCTAssertEqual(substring, "Here")
        } else {
            XCTFail("Failed to create range for line 3")
        }
    }

    // MARK: - Visible Line Info Tests

    func testVisibleLineInfo() {
        let text = """
        Line 1
        Line 2
        Line 3
        Line 4
        Line 5
        """

        // Test visible range in the middle
        let visibleRange = NSRange(location: 7, length: 14) // "Line 2\nLine 3\n"
        let visibleLines = requireCache().visibleLineInfo(in: text, visibleRange: visibleRange)

        XCTAssertEqual(visibleLines.count, 2)
        XCTAssertEqual(visibleLines[0].lineNumber, 2)
        XCTAssertEqual(visibleLines[1].lineNumber, 3)
    }

    // MARK: - String.Index Tests

    func testLineNumberWithStringIndex() {
        let text = "Hello\nWorld\nTest"

        // Test at start
        let startIndex = text.startIndex
        XCTAssertEqual(requireCache().lineNumber(at: startIndex, in: text), 1)

        // Test at "World"
        if let worldIndex = text.firstIndex(of: "W") {
            XCTAssertEqual(requireCache().lineNumber(at: worldIndex, in: text), 2)
        }

        // Test at "Test"
        if let testIndex = text.firstIndex(of: "T") {
            XCTAssertEqual(requireCache().lineNumber(at: testIndex, in: text), 3)
        }
    }

    func testLineRangeWithStringIndex() {
        let text = "First\nSecond\nThird"

        // Test line 2 range returns correct String.Index range
        if let range = requireCache().lineRange(for: 2, in: text) {
            let substring = String(text[range])
            XCTAssertEqual(substring, "Second\n")
        }

        // Test last line (no trailing newline)
        if let range = requireCache().lineRange(for: 3, in: text) {
            let substring = String(text[range])
            XCTAssertEqual(substring, "Third")
        }
    }
}
