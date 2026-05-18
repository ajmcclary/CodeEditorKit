import CodeEditorDesignTokens
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

@Suite("TextLevels")
struct TextLevelsTests {
    @Test("populates known suffixes from flat dictionary")
    func populatesFromFlat() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "text": Tokens.Color(hex: 0x11_11_11),
            "text.muted": Tokens.Color(hex: 0x22_22_22),
            "text.placeholder": Tokens.Color(hex: 0x33_33_33),
            "text.disabled": Tokens.Color(hex: 0x44_44_44),
            "text.accent": Tokens.Color(hex: 0x55_55_55)
        ]
        let levels = TextLevels(
            flat: flat, warnings: collector, path: "style", appearance: .dark
        )
        #expect(levels.base == Tokens.Color(hex: 0x11_11_11))
        #expect(levels.muted == Tokens.Color(hex: 0x22_22_22))
        #expect(levels.placeholder == Tokens.Color(hex: 0x33_33_33))
        #expect(levels.disabled == Tokens.Color(hex: 0x44_44_44))
        #expect(levels.accent == Tokens.Color(hex: 0x55_55_55))
        #expect(levels.extras.isEmpty)
        #expect(collector.warnings.isEmpty)
    }

    @Test("missing keys fall back and warn")
    func missingKeysFallBackAndWarn() {
        let collector = WarningCollector()
        let levels = TextLevels(
            flat: ["text": Tokens.Color(hex: 0x11_11_11)],
            warnings: collector,
            path: "style",
            appearance: .dark
        )
        #expect(levels.base == Tokens.Color(hex: 0x11_11_11))
        #expect(levels.muted == ThemeFallbackPalette.textMuted(.dark))
        #expect(collector.warnings.count == 4)
        let keyPaths = Set(collector.warnings.map(\.keyPath))
        #expect(keyPaths == ["text.muted", "text.placeholder", "text.disabled", "text.accent"])
    }

    @Test("unknown text.* keys land in extras")
    func unknownKeysBecomeExtras() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "text": Tokens.Color(hex: 0x11_11_11),
            "text.muted": Tokens.Color(hex: 0x22_22_22),
            "text.placeholder": Tokens.Color(hex: 0x33_33_33),
            "text.disabled": Tokens.Color(hex: 0x44_44_44),
            "text.accent": Tokens.Color(hex: 0x55_55_55),
            "text.brand": Tokens.Color(hex: 0xAA_AA_AA)
        ]
        let levels = TextLevels(
            flat: flat, warnings: collector, path: "style", appearance: .dark
        )
        #expect(levels.extras == ["text.brand": Tokens.Color(hex: 0xAA_AA_AA)])
    }

    @Test("flatten round-trips a populated TextLevels")
    func flattenEmitsAllKeys() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "text": Tokens.Color(hex: 0x11_11_11),
            "text.muted": Tokens.Color(hex: 0x22_22_22),
            "text.placeholder": Tokens.Color(hex: 0x33_33_33),
            "text.disabled": Tokens.Color(hex: 0x44_44_44),
            "text.accent": Tokens.Color(hex: 0x55_55_55),
            "text.brand": Tokens.Color(hex: 0xAA_AA_AA)
        ]
        let levels = TextLevels(
            flat: flat, warnings: collector, path: "style", appearance: .dark
        )
        var out: [String: Tokens.Color] = [:]
        levels.flatten(into: &out)
        #expect(out["text"] == flat["text"])
        #expect(out["text.muted"] == flat["text.muted"])
        #expect(out["text.brand"] == flat["text.brand"])
    }
}
