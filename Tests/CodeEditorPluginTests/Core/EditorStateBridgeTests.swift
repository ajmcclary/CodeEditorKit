@testable import CodeEditorPlugin
import CodeEditorTextModel
@testable import CodeEditorView
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("EditorStateBridge derivations")
struct EditorStateBridgeTests {
    @Test("deriveSelection maps NSRange to 1-based Ln/Col on a multi-line string")
    func deriveSelectionMaps() {
        let text = "alpha\nbeta\ngamma"
        let bIndex = text.distance(from: text.startIndex, to: text.firstIndex(of: "b") ?? text.startIndex)
        let range = NSRange(location: bIndex + 1, length: 0)
        let result = EditorStateBridge.deriveSelection(from: range, in: text)
        #expect(result.line == 2)
        #expect(result.column == 2)
        #expect(result.selectionLength == 0)
    }

    @Test("deriveSelection preserves selection length")
    func deriveSelectionLength() {
        let text = "hello"
        let range = NSRange(location: 1, length: 3)
        let result = EditorStateBridge.deriveSelection(from: range, in: text)
        #expect(result.line == 1)
        #expect(result.column == 2)
        #expect(result.selectionLength == 3)
    }

    @Test("deriveSelection clamps out-of-range locations safely")
    func deriveSelectionClamps() {
        let text = "abc"
        let range = NSRange(location: 999, length: 0)
        let result = EditorStateBridge.deriveSelection(from: range, in: text)
        #expect(result.line == 1)
        #expect(result.column == 4)
    }

    @Test("lineCount returns 0 for empty text and N+1 for N newlines")
    func lineCountBasics() {
        #expect(EditorStateBridge.lineCount(of: "") == 0)
        #expect(EditorStateBridge.lineCount(of: "abc") == 1)
        #expect(EditorStateBridge.lineCount(of: "abc\ndef") == 2)
        #expect(EditorStateBridge.lineCount(of: "abc\ndef\n") == 3)
    }
}

@Suite("EditorStateBridge cache-aware selection derivation")
@MainActor
struct EditorStateBridgeCacheAwareTests {
    @Test("deriveSelection with LineGeometryStore matches simple path on small text")
    func cacheMatchesSimple() {
        let text = "alpha\nbeta\ngamma"
        let textStorage = NSTextStorage(string: text)
        let store = LineGeometryStore()
        store.build(from: textStorage)
        let range = NSRange(location: 7, length: 0) // "b" in beta
        let simple = EditorStateBridge.deriveSelection(from: range, in: text)
        let cached = EditorStateBridge.deriveSelection(from: range, in: text, lineGeometryStore: store)
        #expect(simple.line == cached.line)
        #expect(simple.column == cached.column)
        #expect(simple.selectionLength == cached.selectionLength)
    }

    @Test("deriveSelection with LineGeometryStore handles large text correctly")
    func cacheLargeText() {
        let lines = (0..<2_000).map { "line \($0)" }
        let text = lines.joined(separator: "\n")
        let textStorage = NSTextStorage(string: text)
        let store = LineGeometryStore()
        store.build(from: textStorage)

        // Position at line 1500, column 1
        let line1500Offset = lines[0..<1_500].reduce(0) { $0 + $1.count + 1 }
        let range = NSRange(location: line1500Offset, length: 0)

        let result = EditorStateBridge.deriveSelection(from: range, in: text, lineGeometryStore: store)
        #expect(result.line == 1_501)
        #expect(result.column == 1)
    }

    @Test("deriveSelection with LineGeometryStore returns 1-based column")
    func cacheColumnOneBased() {
        let text = "abc\ndef\nghi"
        let textStorage = NSTextStorage(string: text)
        let store = LineGeometryStore()
        store.build(from: textStorage)

        // Position at 'd' on second line
        let range = NSRange(location: 4, length: 0)
        let result = EditorStateBridge.deriveSelection(from: range, in: text, lineGeometryStore: store)
        #expect(result.line == 2)
        #expect(result.column == 1)
    }

    @Test("deriveSelection with LineGeometryStore reports character columns for emoji")
    func cacheColumnUsesCharactersNotUTF16CodeUnits() {
        let text = "😀x\nnext"
        let textStorage = NSTextStorage(string: text)
        let store = LineGeometryStore()
        store.build(from: textStorage)

        let range = NSRange(location: 2, length: 0)
        let result = EditorStateBridge.deriveSelection(from: range, in: text, lineGeometryStore: store)

        #expect(result.line == 1)
        #expect(result.column == 2)
    }
}
