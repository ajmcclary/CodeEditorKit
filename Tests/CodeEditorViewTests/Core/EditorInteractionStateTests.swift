import CodeEditorCommon
@testable import CodeEditorView
import Foundation
import Testing

@Suite("EditorInteractionState JSON round-trip")
struct EditorInteractionStateTests {
    @Test("empty state encodes and decodes")
    func emptyState() throws {
        let state = EditorInteractionState()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EditorInteractionState.self, from: data)
        #expect(decoded.cursorPositions == nil)
        #expect(decoded.scrollPosition == nil)
        #expect(decoded.findText == nil)
    }

    @Test("full state encodes and decodes correctly")
    func fullState() throws {
        let state = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 42, column: 7)],
            scrollPosition: CGPoint(x: 0, y: 500),
            findText: "hello",
            replaceText: "world",
            findPanelVisible: true,
            collapsedFoldIDs: ["fold-1", "fold-2"]
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EditorInteractionState.self, from: data)

        #expect(decoded.cursorPositions?.count == 1)
        #expect(decoded.cursorPositions?[0].line == 42)
        #expect(decoded.cursorPositions?[0].column == 7)
        #expect(decoded.scrollPosition?.y == 500)
        #expect(decoded.findText == "hello")
        #expect(decoded.replaceText == "world")
        #expect(decoded.findPanelVisible == true)
        #expect(decoded.collapsedFoldIDs?.count == 2)
    }

    @Test("partial state encodes NULL fields as absent in JSON")
    func partialStateNulls() throws {
        let state = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 1, column: 1)],
            findPanelVisible: false
        )
        let data = try JSONEncoder().encode(state)
        let json = String(data: data, encoding: .utf8) ?? ""
        // scrollPosition should not appear in JSON
        #expect(!json.contains("scrollPosition"))
    }

    @Test("Equatable conformance")
    func equatable() {
        let state1 = EditorInteractionState(cursorPositions: [EditorCursorPosition(line: 1, column: 1)])
        let state2 = EditorInteractionState(cursorPositions: [EditorCursorPosition(line: 1, column: 1)])
        let state3 = EditorInteractionState(cursorPositions: [EditorCursorPosition(line: 2, column: 1)])
        #expect(state1 == state2)
        #expect(state1 != state3)
    }

    @Test("Hashable conformance")
    func hashable() {
        let state1 = EditorInteractionState(cursorPositions: [EditorCursorPosition(line: 1, column: 1)])
        let state2 = EditorInteractionState(cursorPositions: [EditorCursorPosition(line: 1, column: 1)])
        #expect(state1.hashValue == state2.hashValue)
    }
}

@Suite("EditorCursorPosition")
struct EditorCursorPositionTests {
    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        let pos = EditorCursorPosition(line: 10, column: 5)
        let data = try JSONEncoder().encode(pos)
        let decoded = try JSONDecoder().decode(EditorCursorPosition.self, from: data)
        #expect(decoded.line == 10)
        #expect(decoded.column == 5)
    }
}
