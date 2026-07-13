import DesignKitThemes
import Testing

/// Value-equivalence contract for the DesignKit migration: these exact
/// values were previously decoded from zed-trek.json at runtime. If any
/// fails, DesignKit's transcription diverged from what this editor shipped.
@Suite("DesignKit migration contract")
struct DesignKitMigrationContractTests {
    @Test("default theme is LCARS Dark with the shipped values")
    func defaultThemeValues() {
        let theme = Theme.default
        #expect(theme.name == "LCARS Dark")
        #expect(theme.appearance == .dark)
        #expect(theme.style.background.hexString == "#05060A")
        #expect(theme.style.editor.background.hexString == "#080A0F")
        #expect(theme.style.editor.foreground.hexString == "#F2E7D8")
        #expect(theme.style.text.accent.hexString == "#FFCC66")
        #expect(theme.style.borders.focused.hexString == "#FF9933")
        #expect(theme.style.chrome.panelBackground.hexString == "#0C111B")
        #expect(theme.style.chrome.statusBarBackground.hexString == "#0D1018")
        #expect(theme.style.accents.first?.hexString == "#FF9933")
    }

    @Test("syntax resolution matches the shipped hierarchy behavior")
    func syntaxResolution() {
        let theme = Theme.lcarsDark
        #expect(theme.resolveSyntaxColor(for: "keyword").hexString == "#FF9933")
        // Hierarchical fallback still walks dotted segments.
        #expect(theme.resolveSyntaxColor(for: "keyword.some.unknown.leaf").hexString == "#FF9933")
        // Unknown roots land on editor.foreground.
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
        #expect(Theme.all.count == 24)
        #expect(Theme.Family.allCases.count == 12)
        #expect(Theme.all.contains { $0.name == "LCARS Dark" })
    }
}
