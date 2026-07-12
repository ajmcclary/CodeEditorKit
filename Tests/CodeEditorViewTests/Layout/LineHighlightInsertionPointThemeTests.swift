import CodeEditorDesignTokens
@testable import CodeEditorLayout
import CodeEditorPlatform
import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("LineHighlight + InsertionPoint theme")
struct LineHighlightInsertionPointThemeTests {
    @Test("LineHighlightView fill = style.editor.activeLineBackground after apply")
    @MainActor
    func lineHighlightColorFromTheme() {
        let view = LineHighlightView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = PlatformColor(tokens: theme.style.editor.activeLineBackground)
        #expect(view.themedFillColor == expected)
        #expect(view.highlightColor == expected)
    }

    @Test("LineHighlightView equality-gated apply is no-op on second identical call")
    @MainActor
    func lineHighlightEqualityGate() {
        let view = LineHighlightView()
        view.apply(theme: .lcarsDark)
        let firstStored = view.appliedTheme
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == firstStored)
    }

    @Test("InsertionPointView caret = style.players[0].cursor after apply")
    @MainActor
    func caretColorFromTheme() {
        let view = InsertionPointView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = PlatformColor(tokens: theme.style.players[0].cursor)
        #expect(view.themedCaretColor == expected)
    }

    @Test("InsertionPointView equality-gated apply is no-op on second identical call")
    @MainActor
    func insertionPointEqualityGate() {
        let view = InsertionPointView()
        view.apply(theme: .lcarsDark)
        let firstStored = view.appliedTheme
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == firstStored)
    }
}
