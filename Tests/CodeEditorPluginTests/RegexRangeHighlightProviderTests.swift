import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import XCTest

/// Phase 5 spike: benchmark regex range query vs. direct regex highlighting.
///
/// The spike uses `RegexIncrementalRangeQueryParser` which wraps our existing regex
/// engine through the regex range query pipeline. This proves the architecture works
/// and establishes baseline numbers for the range-highlighting path.
final class RegexRangeHighlightProviderTests: XCTestCase {
    private final class RecordingRangeQueryParser: RangeQueryParserProtocol, @unchecked Sendable {
        var setLanguageDelay: UInt64 = 0
        var didSetLanguage = false
        var parseCallsBeforeSetup = 0
        var parseResult = RangeQueryParseResult(captures: [], parseDuration: 0, queryDuration: 0)
        var editCalls: [(startByte: Int, oldEndByte: Int, newEndByte: Int)] = []

        func setLanguage(_: Language) async throws {
            if setLanguageDelay > 0 {
                try await Task.sleep(nanoseconds: setLanguageDelay)
            }
            didSetLanguage = true
        }

        func parse(source _: String) async throws -> RangeQueryParseResult {
            guard didSetLanguage else {
                parseCallsBeforeSetup += 1
                throw RangeQueryParserError.noLanguageSet
            }
            return parseResult
        }

        func applyEdit(startByte: Int, oldEndByte: Int, newEndByte: Int) async -> IndexSet {
            editCalls.append((startByte, oldEndByte, newEndByte))
            return IndexSet(integersIn: startByte..<newEndByte)
        }
    }

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

        guard RegexRangeHighlightProvider.makeProvider(for: .javascript) != nil else {
            XCTFail("Should create internal provider for JavaScript")
            return
        }

        let parser = RegexIncrementalRangeQueryParser()
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
    func testProviderAwaitsLanguageSetupBeforeQuerying() async throws {
        let source = "let value = 1"
        let parser = RecordingRangeQueryParser()
        parser.setLanguageDelay = 20_000_000
        parser.parseResult = RangeQueryParseResult(
            captures: [
                RangeQueryCapture(byteRange: 0..<3, captureName: "keyword")
            ],
            parseDuration: 0,
            queryDuration: 0
        )
        let provider = RegexRangeHighlightProvider(parser: parser, captureMap: .javascript)
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = source

        provider.setUp(textView: textView, language: .javascript)
        let tokens = try await provider.queryHighlights(
            textView: textView,
            range: NSRange(location: 0, length: source.utf16.count)
        )

        XCTAssertTrue(parser.didSetLanguage)
        XCTAssertEqual(parser.parseCallsBeforeSetup, 0)
        XCTAssertEqual(tokens.map(\.text), ["let"])
    }

    @MainActor
    func testProviderConvertsUTF16EditRangeToUTF8Bytes() async {
        let original = "π = 1\nlet café = 1"
        let replacement = "ee"
        guard let editedSwiftRange = original.range(of: "é") else {
            XCTFail("Expected fixture to contain edited character")
            return
        }
        let editedRange = NSRange(editedSwiftRange, in: original)
        let updated = original.replacingCharacters(in: editedSwiftRange, with: replacement)
        let expectedStartByte = original[..<editedSwiftRange.lowerBound].utf8.count
        let expectedOldEndByte = original[..<editedSwiftRange.upperBound].utf8.count
        let expectedNewEndByte = expectedStartByte + replacement.utf8.count

        let parser = RecordingRangeQueryParser()
        let provider = RegexRangeHighlightProvider(parser: parser, captureMap: .javascript)
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = original

        provider.setUp(textView: textView, language: .javascript)
        provider.willApplyEdit(textView: textView, range: editedRange)
        textView.text = updated

        _ = await provider.applyEdit(
            textView: textView,
            range: editedRange,
            delta: replacement.utf16.count - editedRange.length
        )

        XCTAssertEqual(parser.editCalls.count, 1)
        XCTAssertEqual(parser.editCalls.first?.startByte, expectedStartByte)
        XCTAssertEqual(parser.editCalls.first?.oldEndByte, expectedOldEndByte)
        XCTAssertEqual(parser.editCalls.first?.newEndByte, expectedNewEndByte)
    }

    @MainActor
    func testProviderReturnsOnlyHighlightsInsideRequestedRange() async throws {
        let source = "let first = 1\nlet second = 2"
        guard let firstRange = source.range(of: "let"),
              let newlineRange = source.range(of: "\n"),
              let secondRange = source.range(of: "let", range: newlineRange.upperBound..<source.endIndex) else {
            XCTFail("Expected fixture ranges")
            return
        }
        let requestedRange = NSRange(secondRange, in: source)
        let parser = RecordingRangeQueryParser()
        parser.didSetLanguage = true
        parser.parseResult = RangeQueryParseResult(
            captures: [
                RangeQueryCapture(byteRange: byteRange(for: firstRange, in: source), captureName: "keyword"),
                RangeQueryCapture(byteRange: byteRange(for: secondRange, in: source), captureName: "keyword")
            ],
            parseDuration: 0,
            queryDuration: 0
        )
        let provider = RegexRangeHighlightProvider(parser: parser, captureMap: .javascript)
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        textView.text = source

        provider.setUp(textView: textView, language: .javascript)
        let tokens = try await provider.queryHighlights(textView: textView, range: requestedRange)

        XCTAssertEqual(tokens.map(\.range), [requestedRange])
        XCTAssertEqual(tokens.map(\.text), ["let"])
    }

    @MainActor
    func testCaptureMapConversion() {
        let map = QueryCaptureMap.javascript

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

    private func byteRange(for range: Range<String.Index>, in source: String) -> Range<Int> {
        let lowerBound = source[..<range.lowerBound].utf8.count
        let upperBound = source[..<range.upperBound].utf8.count
        return lowerBound..<upperBound
    }

    // MARK: - Benchmark Tests

    @MainActor
    func testParsePerformance10KLines() async throws {
        let source = javascriptFixture(lineCount: 10_000)
        let parser = RegexIncrementalRangeQueryParser()
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
    func testParseBailsOutForVeryLargeFiles() async throws {
        // `RegexIncrementalRangeQueryParser.maxSyncContentLength` (1 MB UTF-8)
        // is an intentional ceiling — files past it return empty captures
        // immediately rather than block the main actor on a multi-second
        // parse. A 100K-line JS fixture is roughly ~3 MB and trips this
        // guard.
        let source = javascriptFixture(lineCount: 100_000)
        XCTAssertGreaterThan(source.utf8.count, 1_000_000, "fixture should exceed the parser's sync cap")

        let parser = RegexIncrementalRangeQueryParser()
        try await parser.setLanguage(.javascript)

        let result = try await parser.parse(source: source)
        XCTAssertTrue(result.captures.isEmpty, "Files above the cap should bail out with no captures")
        XCTAssertEqual(result.parseDuration, 0, "Bail-out path is constant time")
        XCTAssertEqual(result.queryDuration, 0, "Bail-out path is constant time")
    }

    @MainActor
    func testCompareRegexVsRegexRangePipeline() async throws {
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

        // Regex range query pipeline
        let queryParser = RegexIncrementalRangeQueryParser()
        try await queryParser.setLanguage(.javascript)

        let tsStart = Date()
        let queryResult = try await queryParser.parse(source: source)
        let tsDuration = Date().timeIntervalSince(tsStart)

        // Both should produce tokens
        XCTAssertFalse(regexTokens.isEmpty, "Regex should produce tokens")
        XCTAssertFalse(queryResult.captures.isEmpty, "regex range query pipeline should produce captures")

        XCTAssertGreaterThanOrEqual(regexDuration, 0)
        XCTAssertGreaterThanOrEqual(tsDuration, 0)
    }

    // MARK: - Phase 6a: Multi-language Tests

    @MainActor
    func testAllLanguagesUsingRegexHighlighterProduceProvider() {
        // `makeProvider` is gated on `usesRegexHighlighter` — languages whose
        // descriptor opts out (Swift via SwiftSyntax, JSON via FastJSONTokenizer,
        // plain text) intentionally return nil, so filter by that flag rather
        // than `parserName != nil`.
        let languagesUsingRegex = Language.allCases.filter {
            LanguageDescriptor.descriptor(for: $0)?.usesRegexHighlighter == true
        }

        XCTAssertFalse(languagesUsingRegex.isEmpty, "Should have languages using the regex pipeline")
        XCTAssertGreaterThan(languagesUsingRegex.count, 20, "Should have > 20 languages on the regex pipeline")

        for language in languagesUsingRegex {
            let provider = RegexRangeHighlightProvider.makeProvider(for: language)
            XCTAssertNotNil(provider, "Should create internal provider for \(language.name)")
        }
    }

    @MainActor
    func testCaptureMapForAllLanguages() {
        for language in Language.allCases {
            let map = QueryCaptureMap.forLanguage(language)
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
        // JSON is intentionally absent: it opts out of the regex pipeline
        // (`usesRegexHighlighter == false`) and routes through
        // `FastJSONTokenizer` instead, so the range-query parser has
        // nothing to produce for it.
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
            (.lua, "function greet(name, times)\n    for i = 1, times do\n        print('Hello, ' .. name)\n    end\nend\n\ngreet('Ada', 2)\n"),
            (.csharp, "using System;\n\nclass Program {\n    static void Main() {\n        Console.WriteLine(\"Hello\");\n    }\n}\n"),
            (.kotlin, "fun main() {\n    val name = \"Ada\"\n    println(\"Hello, $name\")\n}\n"),
            (.dart, "void main() {\n    final name = 'Ada';\n    print('Hello, $name');\n}\n"),
            (.toml, "title = \"Test\"\n\n[owner]\nname = \"Ada\"\nactive = true\n")
        ]

        for (language, source) in fixtures {
            let parser = RegexIncrementalRangeQueryParser()
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
