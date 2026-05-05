@testable import CodeEditorPlugin
import Foundation
import Testing

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
