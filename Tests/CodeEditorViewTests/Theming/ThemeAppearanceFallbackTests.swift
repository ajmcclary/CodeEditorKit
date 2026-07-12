import CodeEditorDesignTokens
@testable import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

/// Regression: every leaf palette decoder used to hard-code
/// `let appearance: Theme.Appearance = .dark`, so light themes missing any
/// key silently picked up dark fallback colors (REVIEW.md Theming/Critical).
@Suite("Theme appearance-aware fallbacks")
struct ThemeAppearanceFallbackTests {
    @Test("Theme.fallback(.light) text palette uses light substitutes")
    func lightFallbackUsesLightTextFallbacks() {
        let theme = Theme.fallback(appearance: .light)
        #expect(theme.style.text.muted == ThemeFallbackPalette.textMuted(.light))
        #expect(theme.style.text.muted != ThemeFallbackPalette.textMuted(.dark))
        #expect(theme.style.text.placeholder == ThemeFallbackPalette.textPlaceholder(.light))
        #expect(theme.style.text.disabled == ThemeFallbackPalette.textDisabled(.light))
    }

    @Test("Theme.fallback(.light) icon and border palettes use light substitutes")
    func lightFallbackUsesLightIconAndBorderFallbacks() {
        let theme = Theme.fallback(appearance: .light)
        #expect(theme.style.icon.muted == ThemeFallbackPalette.iconMuted(.light))
        #expect(theme.style.icon.muted != ThemeFallbackPalette.iconMuted(.dark))
        #expect(theme.style.borders.base == ThemeFallbackPalette.border(.light))
        #expect(theme.style.borders.base != ThemeFallbackPalette.border(.dark))
    }

    @Test("Decoded light theme with missing leaf keys uses light fallbacks")
    func decodedLightThemeUsesLightFallbacks() throws {
        // Minimal valid Zed v0.2.0 family with appearance=light and a sparse
        // style. text.muted is absent; the decoder must substitute light.
        let json = #"""
        {
          "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
          "name": "AppearanceFallbackProbe",
          "author": "test",
          "themes": [
            {
              "name": "Probe Light",
              "appearance": "light",
              "style": {
                "background": "#ffffffff",
                "text": "#111111ff"
              }
            }
          ]
        }
        """#
        let data = Data(json.utf8)
        let family = try ThemeFamily(jsonData: data)
        let theme = try #require(family.theme(named: "Probe Light"))
        #expect(theme.appearance == .light)
        #expect(theme.style.text.muted == ThemeFallbackPalette.textMuted(.light))
        #expect(theme.style.text.muted != ThemeFallbackPalette.textMuted(.dark))
    }
}
