import CodeEditorCommon
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Testing

@Suite("SourcePosition")
struct SourcePositionTests {
    @Test func equatableByLineAndCharacter() {
        let first = SourcePosition(line: 3, character: 5)
        let second = SourcePosition(line: 3, character: 5)
        let third = SourcePosition(line: 3, character: 6)
        #expect(first == second)
        #expect(first != third)
    }

    @Test func hashableMatchesEquality() {
        let first = SourcePosition(line: 1, character: 2)
        let second = SourcePosition(line: 1, character: 2)
        var set: Set<SourcePosition> = []
        set.insert(first)
        #expect(set.contains(second))
    }

    @Test func zeroIsValid() {
        let position = SourcePosition(line: 0, character: 0)
        #expect(position.line == 0)
        #expect(position.character == 0)
    }
}
