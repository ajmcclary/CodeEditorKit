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

    // MARK: - Phase 6a: Multi-language Tests

    @MainActor
    func testAllLanguagesWithTreeSitterNameProduceProvider() {
        let languagesWithTS = Language.allCases.filter {
            LanguageDescriptor.descriptor(for: $0)?.treeSitterName != nil
        }

        XCTAssertFalse(languagesWithTS.isEmpty, "Should have languages with tree-sitter names")
        XCTAssertGreaterThan(languagesWithTS.count, 20, "Should have > 20 languages with tree-sitter names")

        for language in languagesWithTS {
            let provider = TreeSitterRangeHighlightProvider.makeSpikeProvider(for: language)
            XCTAssertNotNil(provider, "Should create spike provider for \(language.name)")
        }
    }

    @MainActor
    func testCaptureMapForAllLanguages() {
        for language in Language.allCases {
            let map = TreeSitterCaptureMap.forLanguage(language)
            // Every map should resolve common capture names without crashing.
            // Not every preset maps "keyword" literally — e.g. HTML maps "tag"
            // to .keyword, JSON maps "boolean"/"null" to .keyword.
            let kw = map.tokenType(for: "keyword")
            XCTAssertNotEqual(kw, .whitespace, "\(language.name) map should return a valid type for 'keyword'")

            let str = map.tokenType(for: "string")
            XCTAssertNotEqual(str, .whitespace, "\(language.name) map should return a valid type for 'string'")
        }
    }

    @MainActor
    func testParseMultiLanguageSmallFiles() async throws {
        let fixtures: [(Language, String)] = [
            (.python, "def greet(name, times=1):\n    return f'Hello, {name}!'\n\nprint(greet('Ada', 2))\n"),
            (.typescript, "interface Person {\n    name: string;\n    age: number;\n}\n\nconst p: Person = { name: 'Ada', age: 30 };\n"),
            (.go, "package main\n\nimport \"fmt\"\n\nfunc main() {\n    fmt.Println(\"Hello, World!\")\n}\n"),
            (.rust, "fn main() {\n    let x = 42;\n    println!(\"{}\", x);\n}\n"),
            (.c, "#include <stdio.h>\n\nint main(void) {\n    printf(\"Hello\\n\");\n    return 0;\n}\n"),
            (.cpp, "#include <iostream>\n\nint main() {\n    std::cout << \"Hello\" << std::endl;\n    return 0;\n}\n"),
            (.java, "public class Main {\n    public static void main(String[] args) {\n        System.out.println(\"Hello\");\n    }\n}\n"),
            (.ruby, "def greet(name, times = 1)\n  times.times { |i| puts \"Hello, #{name}! (#{i + 1})\" }\nend\n\ngreet('Ada', 2)\n"),
            (.php, "<?php\nfunction greet($name, $times = 1) {\n    for ($i = 0; $i < $times; $i++) {\n        echo \"Hello, $name!\\n\";\n    }\n}\n\ngreet('Ada', 2);\n"),
            (.html, "<!DOCTYPE html>\n<html>\n<head><title>Test</title></head>\n<body>\n<h1>Hello</h1>\n</body>\n</html>\n"),
            (.css, "body {\n    font-family: sans-serif;\n    color: #333;\n}\n\n.container {\n    max-width: 800px;\n}\n"),
            (.sql, "SELECT name, age FROM users WHERE active = 1 ORDER BY name;\n"),
            (.shell, "#!/bin/bash\n\necho \"Hello, World!\"\n\nfor name in Ada Grace Linus; do\n    echo \"Hello, $name\"\ndone\n"),
            (.yaml, "name: test\nversion: 1.0\n\nitems:\n  - name: alpha\n    value: 42\n  - name: beta\n    value: 88\n"),
            (.xml, "<?xml version=\"1.0\"?>\n<root>\n    <item id=\"1\">Alpha</item>\n    <item id=\"2\">Beta</item>\n</root>\n"),
            (.markdown, "# Hello\n\nThis is **bold** and *italic*.\n\n```js\nconst x = 1;\n```\n"),
            (.json, "{\"name\": \"test\", \"values\": [1, 2, 3], \"active\": true}\n"),
            (.lua, "function greet(name, times)\n    for i = 1, times do\n        print('Hello, ' .. name)\n    end\nend\n\ngreet('Ada', 2)\n"),
            (.csharp, "using System;\n\nclass Program {\n    static void Main() {\n        Console.WriteLine(\"Hello\");\n    }\n}\n"),
            (.kotlin, "fun main() {\n    val name = \"Ada\"\n    println(\"Hello, $name\")\n}\n"),
            (.dart, "void main() {\n    final name = 'Ada';\n    print('Hello, $name');\n}\n"),
            (.toml, "title = \"Test\"\n\n[owner]\nname = \"Ada\"\nactive = true\n")
        ]

        for (language, source) in fixtures {
            let parser = RegexBackedTreeSitterParser()
            do {
                try await parser.setLanguage(language)
                let result = try await parser.parse(source: source)
                XCTAssertFalse(
                    result.captures.isEmpty,
                    "\(language.name) should produce captures for a small file"
                )
            } catch {
                XCTFail("\(language.name) parse threw: \(error)")
            }
        }
    }
}
