import DesignKitThemes
import Testing

/// Contract with DesignKit 3: the generated theme pair is what this editor
/// renders. If a value here changes, DesignKit's generator mapping changed.
@Suite("DesignKit 3 contract")
struct DesignKitMigrationContractTests {
    @Test("default theme is the generated dark theme")
    func defaultThemeValues() {
        let theme = Theme.default
        #expect(theme == .dark && theme.name == "Dark")
        #expect(theme.style.editor.background.hexString == "#1E1E1E")
        #expect(theme.style.editor.foreground.hexString == "#FFFFFFD9")
        #expect(theme.style.borders.focused.hexString == "#0A99FF")
        #expect(theme.style.accents.first?.hexString == "#0A99FF")
    }

    @Test("syntax resolution covers the six-way mapping and the hierarchy walk")
    func syntaxResolution() {
        let theme = Theme.dark
        #expect(theme.resolveSyntaxColor(for: "keyword").hexString == "#569CD6")
        #expect(theme.resolveSyntaxColor(for: "keyword.unknown.leaf").hexString == "#569CD6")
        #expect(theme.resolveSyntaxColor(for: "string.special").hexString == "#70A25A")
        #expect(theme.resolveSyntaxColor(for: "punctuation.bracket") == theme.style.text.base)
        #expect(theme.resolveSyntaxColor(for: "nonexistent.role") == theme.style.editor.foreground)
    }

    @Test("editor surface roles used by CodeEditorView+Theme exist and are sane")
    func editorSurfaceRoles() {
        let theme = Theme.default
        #expect(!theme.style.players.isEmpty)   // players[0] cursor/selection
        _ = theme.style.players[0].cursor
        _ = theme.style.players[0].selection
        #expect(theme.glass.glass.opacity > 0)  // glass surface inputs
        _ = theme.glass.shadows.popover
    }

    @Test("catalog surface consumed by the sample app")
    func catalogSurface() {
        #expect(Theme.all == [.dark, .light])
        #expect(Theme.theme(for: .light) == .light)
    }
}
