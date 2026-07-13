@testable import CodeEditorLayout
import DesignKitThemes
import Testing

@MainActor
@Suite("Completion cell theme state")
struct CompletionCellThemeStateTests {
    @Test("theme state reports only effective changes")
    func equalityGate() {
        var state = CompletionCellThemeState(fallback: .default)
        let firstApply = state.apply(theme: .default)
        let secondApply = state.apply(theme: .default)
        #expect(firstApply)
        #expect(secondApply == false)
    }
}
