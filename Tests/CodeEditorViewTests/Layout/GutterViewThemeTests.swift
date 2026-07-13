import DesignKitTokens
import CodeEditorPlatform
import DesignKitThemes
@testable import CodeEditorView
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("GutterView theme")
struct GutterViewThemeTests {
    @Test("Gutter background = theme.style.editor.gutterBackground after apply")
    @MainActor
    func gutterBackgroundFromTheme() {
        let view = GutterView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = PlatformColor(tokens: theme.style.editor.gutterBackground)
        #expect(view.themedBackgroundColor == expected)
    }

    @Test("Renderer inactive number color = style.editor.lineNumber")
    @MainActor
    func rendererInactiveNumberColor() {
        let renderer = GutterViewRenderer()
        let theme = Theme.lcarsDark
        renderer.apply(theme: theme)
        #expect(renderer.themedLineNumberColor == PlatformColor(tokens: theme.style.editor.lineNumber))
    }

    @Test("Renderer active number color = style.editor.activeLineNumber")
    @MainActor
    func rendererActiveNumberColor() {
        let renderer = GutterViewRenderer()
        let theme = Theme.lcarsDark
        renderer.apply(theme: theme)
        #expect(renderer.themedActiveLineNumberColor == PlatformColor(tokens: theme.style.editor.activeLineNumber))
    }

    @Test("apply(theme:) is equality-gated — re-apply same theme is a no-op")
    @MainActor
    func applyEqualityGated() {
        let view = GutterView()
        view.apply(theme: .lcarsDark)
        let firstStored = view.appliedTheme
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == firstStored)
    }
}
