@testable import CodeEditorPlugin
import XCTest

/// Phase 5 spike: benchmark Tree-sitter (regex-backed) vs. direct regex highlighting.
///
/// The spike uses `RegexBackedTreeSitterParser` which wraps our existing regex
/// engine through the Tree-sitter pipeline. This proves the architecture works
/// and establishes baseline numbers before the real C Tree-sitter integration
/// in Phase 6.
final class TreeSitterBenchmarkTests: XCTestCase {
    // MARK: - Fixtures

    private func javascriptFixture(lineCount: Int) -> String {
        var lines: [String] = []
        lines.append("// Generated JavaScript benchmark fixture (\(lineCount) lines)")
        lines.append("")
        lines.append("function factorial(n) {")
        lines.append("    if (n <= 1) return 1;")
        lines.append("    return n * factorial(n - 1);")
        lines.append("}")
        lines.append("")

        // Repeat a block to reach the desired line count
        let block = [
            "class DataProcessor {",
            "    constructor(data) {",
            "        this.data = data;",
            "        this.results = [];",
            "    }",
            "",
            "    process() {",
            "        const start = Date.now();",
            "        for (const item of this.data) {",
            "            const transformed = this.transform(item);",
            "            this.results.push(transformed);",
            "        }",
            "        const elapsed = Date.now() - start;",
            "        return { results: this.results, elapsed };",
            "    }",
            "",
            "    transform(item) {",
            "        return {",
            "            id: item.id,",
            "            name: item.name.toUpperCase(),",
            "            value: item.value * 1.5,",
            "            active: item.value > 100",
            "        };",
            "    }",
            "}",
            "",
            "const processor = new DataProcessor([",
            "    { id: 1, name: 'alpha', value: 42 },",
            "    { id: 2, name: 'beta',  value: 200 },",
            "    { id: 3, name: 'gamma', value: 88 },",
            "]);",
            "",
            "console.log(processor.process());"
        ]

        while lines.count < lineCount {
            lines.append(contentsOf: block)
        }

        return lines.prefix(lineCount).joined(separator: "\n")
    }

    // MARK: - Correctness Tests

    @MainActor
    func testSpikeProviderProducesTokens() async throws {
        let source = javascriptFixture(lineCount: 80)

        guard let provider = TreeSitterRangeHighlightProvider.makeSpikeProvider(for: .javascript) else {
            XCTFail("Should create spike provider for JavaScript")
            return
        }

        let parser = RegexBackedTreeSitterParser()
        try await parser.setLanguage(.javascript)

        let result = try await parser.parse(source: source)

        XCTAssertFalse(result.captures.isEmpty, "Should produce captures for JavaScript source")
        XCTAssertGreaterThan(result.captures.count, 10, "Should produce at least 10 captures")

        // Verify we get a mix of token types
        let captureNames = Set(result.captures.map(\.captureName))
        XCTAssertTrue(captureNames.contains("keyword"), "Should have keyword captures")
        XCTAssertTrue(captureNames.contains("string"), "Should have string captures")
    }

    @MainActor
    func testCaptureMapConversion() {
        let map = TreeSitterCaptureMap.javascript

        // Direct matches
        XCTAssertEqual(map.tokenType(for: "keyword"), .keyword)
        XCTAssertEqual(map.tokenType(for: "string"), .string)
        XCTAssertEqual(map.tokenType(for: "comment"), .comment)

        // Scoped names (e.g. "keyword.return" → "keyword")
        XCTAssertEqual(map.tokenType(for: "keyword.return"), .keyword)
        XCTAssertEqual(map.tokenType(for: "function.method"), .function)

        // Unknown captures
        XCTAssertEqual(map.tokenType(for: "nonexistent"), .unknown)
    }

    // MARK: - Benchmark Tests

    @MainActor
    func testParsePerformance10KLines() async throws {
        let source = javascriptFixture(lineCount: 10_000)
        let parser = RegexBackedTreeSitterParser()
        try await parser.setLanguage(.javascript)

        measure(options: Self.standardMeasureOptions) {
            Task { @MainActor in
                _ = try? await parser.parse(source: source)
            }
        }

        // Parse once outside measure to get timing data
        let result = try await parser.parse(source: source)
        XCTAssertLessThan(result.parseDuration, 0.5, "10K-line parse should complete in < 500 ms")
        XCTAssertGreaterThan(result.captures.count, 100, "10K-line JS should produce > 100 captures")
    }

    @MainActor
    func testParsePerformance100KLines() async throws {
        let source = javascriptFixture(lineCount: 100_000)
        let parser = RegexBackedTreeSitterParser()
        try await parser.setLanguage(.javascript)

        let result = try await parser.parse(source: source)
        XCTAssertLessThan(result.parseDuration, 5.0, "100K-line parse should complete in < 5 s")
        XCTAssertGreaterThan(result.captures.count, 1_000, "100K-line JS should produce > 1000 captures")
    }

    @MainActor
    func testCompareRegexVsTreeSitterPipeline() async throws {
        let source = javascriptFixture(lineCount: 5_000)

        // Direct regex path
        let regexHighlighter = RegexSyntaxHighlighter()
        guard let jsDef = regexHighlighter.languageDefinition(for: .javascript) else {
            XCTFail("Should find JS definition")
            return
        }
        let regexHL = RegexSyntaxHighlighter(customLanguage: jsDef)

        let regexStart = Date()
        let regexTokens = regexHL.highlight(source: source)
        let regexDuration = Date().timeIntervalSince(regexStart)

        // Tree-sitter pipeline (regex-backed in spike)
        let tsParser = RegexBackedTreeSitterParser()
        try await tsParser.setLanguage(.javascript)

        let tsStart = Date()
        let tsResult = try await tsParser.parse(source: source)
        let tsDuration = Date().timeIntervalSince(tsStart)

        // Both should produce tokens
        XCTAssertFalse(regexTokens.isEmpty, "Regex should produce tokens")
        XCTAssertFalse(tsResult.captures.isEmpty, "Tree-sitter pipeline should produce captures")

        // Log comparison for manual review
        print("=== Phase 5 Benchmark: 5K-line JavaScript ===")
        print("Regex direct:   \(regexTokens.count) tokens in \(String(format: "%.3f", regexDuration * 1_000)) ms")
        print("TS pipeline:    \(tsResult.captures.count) captures in \(String(format: "%.3f", tsDuration * 1_000)) ms")
        print("Parse time:     \(String(format: "%.3f", tsResult.parseDuration * 1_000)) ms")
        print("Query time:     \(String(format: "%.3f", tsResult.queryDuration * 1_000)) ms")
    }
}
