@testable import CodeEditorLSP
import Testing

@Suite("LSP semantic token storage")
struct LSPSemanticTokenStorageTests {
    @Test("delta edits use raw UInt32 array indexes")
    @MainActor
    func deltaEditsUseRawArrayIndexes() {
        let storage = LSPSemanticTokenStorage()
        storage.applyFull(SemanticTokens(
            data: [
                0, 0, 3, 1, 0,
                0, 4, 2, 2, 0
            ],
            resultId: "before"
        ))

        storage.applyDelta(SemanticTokensDelta(
            edits: [
                SemanticTokensEdit(
                    start: 5,
                    deleteCount: 5,
                    data: [0, 4, 4, 3, 0]
                )
            ],
            resultId: "after"
        ))

        let tokens = storage.tokens(in: 0...0)
        #expect(tokens.map(\.tokenType) == [1, 3])
        #expect(tokens.map(\.length) == [3, 4])
        #expect(storage.resultId == "after")
    }

    @Test("delta edits apply against the original array whatever their order")
    @MainActor
    func deltaEditsInAscendingOrder() {
        let storage = LSPSemanticTokenStorage()
        storage.applyFull(SemanticTokens(
            data: [
                0, 0, 1, 1, 0,
                0, 2, 1, 2, 0,
                0, 2, 1, 3, 0
            ],
            resultId: "before"
        ))
        // Both edits refer to the original array; the server sent the
        // higher one first.
        storage.applyDelta(SemanticTokensDelta(
            edits: [
                SemanticTokensEdit(start: 13, deleteCount: 1, data: [9]),
                SemanticTokensEdit(start: 0, deleteCount: 5, data: [])
            ],
            resultId: "after"
        ))
        #expect(storage.tokens(in: 0...0).map(\.tokenType) == [2, 9])
    }

    @Test("line starts follow the LSP line model")
    func lineStarts() {
        #expect(LSPTextPosition.lineStartOffsets(in: "a\r\nb\rc\nd") == [0, 3, 5, 7])
        #expect(LSPTextPosition.line(containingUTF16Offset: 4, lineStarts: [0, 3, 5, 7]) == 1)
        #expect(LSPTextPosition.line(containingUTF16Offset: 7, lineStarts: [0, 3, 5, 7]) == 3)
    }
}
