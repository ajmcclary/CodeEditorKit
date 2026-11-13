import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
import Foundation
import XCTest

/// Document text must never reach a recursive parser without a depth guard.
/// Foundation's JSON parser recurses once per nesting level; on a Swift
/// concurrency thread (a small stack) a JSON file with ~500 nested objects
/// overflowed it inside the JSON symbol provider. Every case here runs the
/// way the editor runs it, off the main actor on a cooperative thread.
final class DeepNestingParserTests: XCTestCase {
    private static let depths = [500, 5_000, 100_000]

    private func symbolsOffMain(_ text: String) async -> [DocumentSymbol] {
        await Task.detached { await JSONSymbolProvider().detectSymbols(in: text) }.value
    }

    func testDeeplyNestedJSONObjectsDoNotCrash() async {
        for depth in Self.depths {
            let text = String(repeating: #"{"k":"#, count: depth) + "1" + String(repeating: "}", count: depth)
            _ = await symbolsOffMain(text)
        }
    }

    func testDeeplyNestedJSONArraysDoNotCrash() async {
        for depth in Self.depths {
            let text = String(repeating: "[", count: depth) + "1" + String(repeating: "]", count: depth)
            _ = await symbolsOffMain(text)
        }
    }

    func testDeeplyNestedMixedJSONDoesNotCrash() async {
        for depth in Self.depths {
            let open = String(repeating: #"{"a":[{"b":"#, count: depth / 2)
            let close = String(repeating: "}]}", count: depth / 2)
            _ = await symbolsOffMain(open + "1" + close)
        }
    }

    /// Brackets inside strings are not nesting: a shallow document full of
    /// them is still parsed (not sent to the line-by-line fallback).
    func testBracketsInsideStringsDoNotCountAsNesting() async {
        let text = #"{"open": ""# + String(repeating: "{[", count: 10_000) + #"", "esc": "\"{", "n": {"m": 1}}"#
        let names = await symbolsOffMain(text).map(\.name)
        XCTAssertEqual(Set(names), ["open", "esc", "n", "m"])
    }

    func testJSONNestingDepthScan() {
        XCTAssertEqual(JSONSymbolProvider.maximumNestingDepth(of: #"{"a": [1, {"b": "]]}}"}]}"#), 3)
        XCTAssertEqual(JSONSymbolProvider.maximumNestingDepth(of: #"["\\", ["\""]]"#), 2)
        XCTAssertEqual(JSONSymbolProvider.maximumNestingDepth(of: "1"), 0)
    }

    // MARK: - SwiftSyntax

    private func highlightOffMain(_ source: String) async -> [HighlightedToken] {
        await Task.detached { SwiftSyntaxHighlighter().highlight(source: source) }.value
    }

    func testDeeplyNestedSwiftDoesNotCrashTheHighlighter() async {
        let shapes: [(String, String, String)] = [
            ("parentheses", "(", ")"),
            ("brackets", "[", "]"),
            ("closures", "{ ", " }"),
            ("if blocks", "if x { ", " }"),
            ("arrays of tuples", "[(", ")]"),
            ("tuples of arrays", "([", "])")
        ]
        for (name, open, close) in shapes {
            for depth in [2_000, 100_000] {
                let source = "let v = " + String(repeating: open, count: depth) + "1" + String(repeating: close, count: depth) + "\n"
                let tokens = await highlightOffMain(source)
                XCTAssertFalse(tokens.isEmpty, "\(name) at \(depth) produced no tokens")
            }
        }
    }

    /// Nesting up to the limits still gets the parser, on a stack that holds
    /// it: 64 levels overflowed a concurrency thread in a debug build.
    func testSwiftNestedToTheLimitsIsParsedWithoutCrashing() async {
        let limit = SwiftSyntaxHighlighter.maximumBracketNesting
        let squareLimit = SwiftSyntaxHighlighter.maximumSquareBracketNesting
        let shapes: [(String, String, Int)] = [
            ("(", ")", limit),
            ("{ ", " }", limit),
            ("if x { ", " }", limit),
            ("[(", ")]", squareLimit)
        ]
        for (open, close, depth) in shapes {
            let source = "let v = " + String(repeating: open, count: depth) + "1" + String(repeating: close, count: depth) + "\n"
            XCTAssertTrue(SwiftSyntaxHighlighter.isWithinParserLimits(source), open)
            let tokens = await highlightOffMain(source)
            XCTAssertFalse(tokens.isEmpty, open)
        }
    }

    /// Brackets inside an interpolation are code and count; brackets in
    /// comments and in a string's text do not.
    func testSwiftNestingScan() {
        func depths(_ source: String) -> [Int] {
            let measured = SwiftSyntaxHighlighter.nestingDepths(of: source)
            return [measured.brackets, measured.squareBrackets]
        }
        XCTAssertEqual(depths("f([{ x }])"), [3, 1])
        XCTAssertEqual(depths(#"let s = "[[[[""#), [0, 0])
        XCTAssertEqual(depths("// [[[[\nx"), [0, 0])
        XCTAssertEqual(depths("/* /* [[ */ [[ */ x"), [0, 0])
        XCTAssertEqual(depths("let s = \"\"\"\n[[[\n\"\"\"\n"), [0, 0])
        XCTAssertEqual(depths(#"let s = "\([[[1]]])""#), [4, 3])
        XCTAssertEqual(depths(##"let s = #"\"# + [[1]]"##), [2, 2])
        XCTAssertEqual(depths(##"let s = #"\#([1])"#"##), [2, 1])
        XCTAssertEqual(depths(#"let s = "\"[" + [1]"#), [1, 1])
        XCTAssertEqual(depths("let s = \"open\n[[1]]"), [2, 2])
        XCTAssertEqual(depths("]]) [x]"), [1, 1])
    }

    /// Hiding the nesting inside a string interpolation does not get it past
    /// the guard.
    func testSwiftNestingHiddenInAnInterpolationIsCounted() async {
        let depth = 2_000
        let source = #"let s = "\("# + String(repeating: "[", count: depth) + "1" + String(repeating: "]", count: depth) + #")""# + "\n"
        XCTAssertFalse(SwiftSyntaxHighlighter.isWithinParserLimits(source))
        _ = await highlightOffMain(source)
    }
}
