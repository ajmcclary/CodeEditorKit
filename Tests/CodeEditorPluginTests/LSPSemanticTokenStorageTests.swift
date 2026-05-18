import CodeEditorLSP
@testable import CodeEditorPlugin
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
}
