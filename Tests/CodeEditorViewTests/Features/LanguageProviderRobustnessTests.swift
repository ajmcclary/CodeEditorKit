import CodeEditorLanguages
import Foundation
import XCTest

/// The heuristic folding and symbol providers run on every document the
/// editor attaches to. These tests pin that they do not trap, stay linear on
/// large input, and report UTF-16 ranges that hold for CRLF and non-BMP text.
@MainActor
final class LanguageProviderRobustnessTests: XCTestCase {
    private func utf16Range(of needle: String, in source: String) -> NSRange {
        guard let range = source.range(of: needle) else { return NSRange(location: NSNotFound, length: 0) }
        return NSRange(range, in: source)
    }

    /// CPU seconds of the process while `body` runs (it may hop threads):
    /// a loaded machine does not inflate it.
    private func elapsed(_ body: () async -> Void) async -> TimeInterval {
        await CPUTime.inProcess(body).seconds
    }

    // MARK: - CSS symbols

    func testSingleLineMediaRuleYieldsItsCondition() async {
        let source = "@media (max-width: 600px) {\n  a { color: red; }\n}\n@supports (display: grid) {\n}\n@media print\n"
        let symbols = await CSSSymbolProvider().detectSymbols(in: source)
        let names = symbols.map(\.name)
        XCTAssertTrue(names.contains("@media (max-width: 600px)"), "\(names)")
        XCTAssertTrue(names.contains("@supports (display: grid)"), "\(names)")
        XCTAssertTrue(names.contains("@media print"), "\(names)")
    }

    // MARK: - XML folding

    private func xmlDocument(items: Int, lineEnding: String) -> String {
        var lines = ["<root>"]
        for index in 0..<items {
            lines.append("  <item id=\"\(index)\">")
            lines.append("    <name>n\(index)</name>")
            lines.append("  </item>")
        }
        lines.append("</root>")
        return lines.joined(separator: lineEnding)
    }

    func testXMLFoldingIsTheSameForLFAndCRLF() async {
        let lf = await XMLFoldingProvider().detectFoldableRegions(in: xmlDocument(items: 20, lineEnding: "\n"))
        let crlf = await XMLFoldingProvider().detectFoldableRegions(in: xmlDocument(items: 20, lineEnding: "\r\n"))
        // root + 20 items + 20 names
        XCTAssertEqual(lf.count, 41)
        XCTAssertEqual(crlf.count, 41)
    }

    func testXMLFoldRangesAreUTF16AndNestSameNameTags() async {
        let source = "<a>😀\n<a>x</a>\n</a>"
        let regions = await XMLFoldingProvider().detectFoldableRegions(in: source)
        let ranges = regions.map(\.range)
        let utf16Length = source.utf16.count
        XCTAssertEqual(ranges, [
            NSRange(location: 0, length: utf16Length),
            utf16Range(of: "<a>x</a>", in: source)
        ])
    }

    func testXMLFoldingIsLinearOnLargeDocuments() async {
        let source = xmlDocument(items: 2_000, lineEnding: "\n") // ~90 KB
        var count = 0
        let seconds = await elapsed {
            count = await XMLFoldingProvider().detectFoldableRegions(in: source).count
        }
        XCTAssertEqual(count, 4_001)
        XCTAssertLessThan(seconds, 10, "XML folding took \(seconds)s")
    }

    // MARK: - XML symbols

    func testXMLSymbolsOnAMinifiedLineAreLinearAndUTF16() async {
        let tags = String(repeating: "<i>😀</i>", count: 20_000)
        let source = "<root>\(tags)</root>"
        var symbols: [DocumentSymbol] = []
        let seconds = await elapsed {
            symbols = await XMLSymbolProvider().detectSymbols(in: source)
        }
        XCTAssertLessThan(seconds, 10, "XML symbols took \(seconds)s")
        XCTAssertEqual(symbols.count, 20_001)
        // Each `<i>😀</i>` is 9 UTF-16 units; `<root>` is 6.
        XCTAssertEqual(symbols.dropFirst().first?.range.location, 6)
        XCTAssertEqual(symbols.dropFirst(2).first?.range.location, 15)
    }

    // MARK: - Brace folding

    func testBraceFoldingClassifiesFromTheOpeningLine() async {
        let source = """
        // Licence header: https://example.com
        class Foo {
            func bar() {
                if true {
                }
            }
        }
        """
        let regions = await BraceFoldingProvider().detectFoldableRegions(in: source)
        let types = Dictionary(uniqueKeysWithValues: regions.map { ($0.title, $0.type) })
        XCTAssertEqual(types["class Foo"], .class)
        XCTAssertEqual(types["func bar()"], .function)
        XCTAssertEqual(types["if true"], .block)
    }

    func testBraceFoldRangesAreUTF16() async {
        let source = "let s = \"😀\"\nfunc a() {\n}\n"
        let regions = await BraceFoldingProvider().detectFoldableRegions(in: source)
        let brace = utf16Range(of: "{\n}", in: source)
        XCTAssertEqual(regions.first?.range, brace)
        XCTAssertEqual(regions.first?.title, "func a()")
    }

    func testBraceFoldingIsLinearOnLargeDocuments() async {
        let block = "func f() {\n    if x {\n        y()\n    }\n}\n"
        let source = String(repeating: block, count: 10_000) // ~450 KB, 50k lines
        var count = 0
        let seconds = await elapsed {
            count = await BraceFoldingProvider().detectFoldableRegions(in: source).count
        }
        XCTAssertEqual(count, 20_000)
        XCTAssertLessThan(seconds, 10, "Brace folding took \(seconds)s")
    }

    /// Minified JSON / JavaScript / CSS: one 200 KB line. Detection must be
    /// linear in the document and keep each region's title short.
    func testBraceFoldingIsLinearOnOneLongLine() async {
        let unit = #"{"key": [1, 2, {"inner": "v"}], "other": true},"#
        let source = "[" + String(repeating: unit, count: 200_000 / unit.utf16.count) + "{}]"
        XCTAssertGreaterThan(source.utf16.count, 199_000)
        var regions: [FoldableRegion] = []
        let seconds = await elapsed {
            regions = await BraceFoldingProvider().detectFoldableRegions(in: source)
        }
        // Each region was the whole line prefix before: 105 s, 892 MB (-O).
        XCTAssertLessThan(seconds, 2, "Brace folding took \(seconds)s on one 200 KB line")
        XCTAssertLessThanOrEqual(regions.map(\.title.utf16.count).max() ?? 0, 200)
    }

    /// Every folding provider on one long line, shaped for its language.
    func testFoldingProvidersAreLinearOnOneLongLine() async {
        let line = { (unit: String) in String(repeating: unit, count: 200_000 / unit.utf16.count) }
        let cases: [(String, any CodeFoldingProvider, String)] = [
            ("indentation", IndentationFoldingProvider(), line("a b c d ")),
            ("markdown", MarkdownFoldingProvider(), "# " + line("word ")),
            ("xml", XMLFoldingProvider(), line("<a><b>t</b></a>")),
            ("ruby", RubyFoldingProvider(), line("def f; end; ")),
            ("shell", ShellFoldingProvider(), line("if x; then y; fi; ")),
            ("sql", SQLFoldingProvider(), line("BEGIN SELECT 1; END; ")),
            ("lua", LuaFoldingProvider(), line("function f() end ")),
            ("toml", TomlFoldingProvider(), "[t]" + line("a = 1 ")),
            ("dockerfile", DockerfileFoldingProvider(), "RUN " + line("x && "))
        ]
        for (name, provider, source) in cases {
            var regions: [FoldableRegion] = []
            let seconds = await elapsed {
                regions = await provider.detectFoldableRegions(in: source)
            }
            XCTAssertLessThan(seconds, 2, "\(name) folding took \(seconds)s on one 200 KB line")
            XCTAssertLessThanOrEqual(regions.map(\.title.utf16.count).max() ?? 0, 200, name)
        }
    }

    // MARK: - JSON / Markdown / indentation / Lua

    func testJSONKeyLocationsAreUTF16() async {
        let source = "{\"emoji\": \"😀😀\", \"after\": 1}"
        let symbols = await JSONSymbolProvider().detectSymbols(in: source)
        let after = symbols.first { $0.name == "after" }
        XCTAssertEqual(after?.range.location, utf16Range(of: "\"after\":", in: source).location)
    }

    /// Nested keys come out in pre-order, each key before the keys of its
    /// value, and nesting depth costs no stack (the walk is iterative). The
    /// depth stays within `maximumParsedNesting`: deeper documents never
    /// reach `JSONSerialization` (see `DeepNestingParserTests`).
    func testJSONSymbolsOfNestedObjectsComeOutInPreOrder() async {
        let depth = JSONSymbolProvider.maximumParsedNesting
        let source = String(repeating: "{\"k\": ", count: depth) + "1" + String(repeating: "}", count: depth)
        let symbols = await JSONSymbolProvider().detectSymbols(in: source)
        XCTAssertEqual(symbols.count, depth)
        XCTAssertEqual(symbols.first?.kind, .object)
        XCTAssertEqual(symbols.last?.kind, .number)

        let mixed = #"{"a": {"b": 1}, "c": [{"d": true}, [{"e": 2}]]}"#
        let names = await JSONSymbolProvider().detectSymbols(in: mixed).map(\.name)
        XCTAssertEqual(Set(names), ["a", "b", "c", "d"])
        if let keyA = names.firstIndex(of: "a"), let keyB = names.firstIndex(of: "b") { XCTAssertEqual(keyB, keyA + 1) }
        if let keyC = names.firstIndex(of: "c"), let keyD = names.firstIndex(of: "d") { XCTAssertEqual(keyD, keyC + 1) }
    }

    func testMarkdownSectionsEndAtTheUTF16End() async {
        let source = "# One 😀\ntext 😀\n# Two\nmore 😀"
        let regions = await MarkdownFoldingProvider().detectFoldableRegions(in: source)
        let two = utf16Range(of: "# Two", in: source).location
        XCTAssertEqual(regions.map(\.range), [
            NSRange(location: 0, length: two - 1),
            NSRange(location: two, length: source.utf16.count - two)
        ])
    }

    func testIndentationFoldEndsAtTheUTF16LineEnd() async {
        let source = "def f():\n    a = 1\n    return '😀'\nx = 1"
        let regions = await IndentationFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.first?.range, NSRange(location: 0, length: utf16Range(of: "\nx = 1", in: source).location))
    }

    func testLuaFoldsInACRLFFileWithLineComments() async {
        let source = "-- header\r\nfunction greet(name)\r\n  -- say hi\r\n  print(name)\r\nend\r\n"
        let regions = await LuaFoldingProvider().detectFoldableRegions(in: source)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions.first?.title, "function greet")
    }
}
