import CodeEditorDesignTokens
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("apply(theme:) propagation")
struct ApplyThemePropagationTests {
    @Test("CodeEditorContainerView stores the applied theme")
    @MainActor
    func storesAppliedTheme() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        #expect(container.appliedTheme == nil)
        container.apply(theme: .lcarsDark)
        #expect(container.appliedTheme == Theme.lcarsDark)
    }

    @Test("apply(theme:) is equality-gated — re-apply with same theme is a no-op")
    @MainActor
    func equalityGated() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.apply(theme: .lcarsDark)
        let firstStored = container.appliedTheme
        container.apply(theme: .lcarsDark)
        #expect(container.appliedTheme == firstStored)
    }

    @Test("Different themes update the stored value")
    @MainActor
    func differentThemesUpdate() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.apply(theme: .lcarsDark)
        let fallback = Theme.fallback(appearance: .light)
        container.apply(theme: fallback)
        #expect(container.appliedTheme == fallback)
        #expect(container.appliedTheme != Theme.lcarsDark)
    }
}
