import CodeEditorDesignTokens
import CodeEditorPlatform
@testable import CodeEditorPlugin
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("MinimapView theme")
struct MinimapViewThemeTests {
    @Test("Minimap background = style.editor.background after apply")
    @MainActor
    func minimapBackground() {
        let view = MinimapView(frame: .zero)
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = PlatformColor(tokens: theme.style.editor.background)
        #expect(view.themedBackgroundColor == expected)
    }

    @Test("Minimap viewport indicator = style.scrollbar.thumbBackground")
    @MainActor
    func minimapViewportIndicator() {
        let view = MinimapView(frame: .zero)
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = PlatformColor(tokens: theme.style.scrollbar.thumbBackground)
        #expect(view.themedViewportIndicatorColor == expected)
    }

    @Test("Minimap track = style.scrollbar.trackBackground")
    @MainActor
    func minimapViewportTrack() {
        let view = MinimapView(frame: .zero)
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = PlatformColor(tokens: theme.style.scrollbar.trackBackground)
        #expect(view.themedTrackColor == expected)
    }

    @Test("apply(theme:) is equality-gated")
    @MainActor
    func minimapEqualityGate() {
        let view = MinimapView(frame: .zero)
        view.apply(theme: .lcarsDark)
        let firstStored = view.appliedTheme
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == firstStored)
    }
}
