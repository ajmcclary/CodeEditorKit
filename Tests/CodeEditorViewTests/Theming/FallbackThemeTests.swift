import DesignKitTokens
import DesignKitThemes
@testable import CodeEditorView
import Foundation
import Testing

@Suite("Theme.fallback and ThemeFamily.theme(named:)")
struct FallbackThemeTests {
    @Test("dark fallback has usable values")
    func darkFallbackUsable() {
        let theme = Theme.fallback(appearance: .dark)
        #expect(theme.appearance == .dark)
        #expect(theme.style.editor.background.alpha == 1)
        #expect(theme.style.editor.background != Tokens.Color(hex: 0x00_00_00, alpha: 0))
        #expect(theme.style.editor.foreground != theme.style.editor.background)
    }

    @Test("light fallback has usable values")
    func lightFallbackUsable() {
        let theme = Theme.fallback(appearance: .light)
        #expect(theme.appearance == .light)
        #expect(theme.style.editor.background != theme.style.editor.foreground)
    }

    @Test("ThemeFamily.theme(named:) hits and misses correctly")
    func familyVariantLookup() {
        let dark = Theme.fallback(appearance: .dark)
        let light = Theme.fallback(appearance: .light)
        let family = ThemeFamily(name: "Test Family", themes: [dark, light])
        #expect(family.theme(named: dark.name)?.appearance == .dark)
        #expect(family.theme(named: light.name)?.appearance == .light)
        #expect(family.theme(named: "Bogus") == nil)
    }
}
