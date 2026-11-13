import AppKit
@testable import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
import Foundation
import XCTest

final class RegexIncrementalRangeQueryParserTests: XCTestCase {
    func testCaptureByteRangesAreUTF8Offsets() async throws {
        let parser = RegexIncrementalRangeQueryParser()
        try await parser.setLanguage(.javascript)
        let source = "let é = \"ü\"\nlet b = 1"
        let result = try await parser.parse(source: source)
        let utf8 = Array(source.utf8)
        let texts = result.captures.compactMap { String(bytes: utf8[$0.byteRange], encoding: .utf8) }
        XCTAssertTrue(texts.contains("\"ü\""), "\(texts)")
        XCTAssertEqual(texts.filter { $0 == "let" }.count, 2, "\(texts)")
    }

    func testParseIsLinearOnABridgedString() async throws {
        let parser = RegexIncrementalRangeQueryParser()
        try await parser.setLanguage(.javascript)
        let line = "let value = 42; // café\n"
        // The editor's text comes from `NSTextStorage.string`, a bridged string.
        let source = NSTextStorage(string: String(repeating: line, count: 20_000)).string // ~460 KB
        let start = Date()
        let result = try await parser.parse(source: source)
        let seconds = Date().timeIntervalSince(start)
        XCTAssertFalse(result.captures.isEmpty)
        XCTAssertLessThan(seconds, 10, "parse took \(seconds)s")
    }
}
