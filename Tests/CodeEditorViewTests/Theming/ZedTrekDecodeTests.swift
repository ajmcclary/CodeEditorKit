import CodeEditorDesignTokens
@testable import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

@Suite("Zed Trek bundled decode")
struct ZedTrekDecodeTests {
    @Test("ThemeFamily.bundled(\"zed-trek\") loads 22 themes")
    func bundledFamilyLoads() throws {
        let family = try #require(ThemeFamily.bundled("zed-trek"))
        #expect(family.themes.count == 22)
    }

    @Test("ThemeFamily.bundled returns nil for unknown name")
    func bundledFamilyMiss() {
        #expect(ThemeFamily.bundled("nonexistent") == nil)
    }

    @Test("Theme.bundled(family:variant:) hits and misses correctly")
    func bundledThemeVariantHitMiss() {
        #expect(Theme.bundled(family: "zed-trek", variant: "LCARS Dark") != nil)
        #expect(Theme.bundled(family: "zed-trek", variant: "Bogus") == nil)
        #expect(Theme.bundled(family: "x", variant: "y") == nil)
    }

    @Test("Theme.lcarsDark resolves from the bundle")
    func lcarsDarkResolves() {
        let theme = Theme.lcarsDark
        #expect(theme.name == "LCARS Dark")
        #expect(theme.appearance == .dark)
    }

    @Test("All 22 Zed Trek variants decode without warnings")
    func allVariantsDecodeCleanly() throws {
        guard let url = Bundle.module.url(forResource: "zed-trek", withExtension: "json") else {
            Issue.record("zed-trek.json not bundled")
            return
        }
        let data = try Data(contentsOf: url)
        let (family, warnings) = try ThemeFamily.loaded(jsonData: data)
        #expect(family.themes.count == 22)
        #expect(
            warnings.isEmpty,
            "Bundled themes should decode cleanly; got \(warnings.count) warnings: \(warnings.prefix(5))"
        )
    }

    @Test("All 22 expected variant names are present")
    func variantNamesMatch() throws {
        let family = try #require(ThemeFamily.bundled("zed-trek"))
        let expected: Set<String> = [
            "Black Alert Dark", "Black Alert Light",
            "Borg Cube Dark", "Borg Cube Light",
            "Command Dark", "Command Light",
            "Federation Dark", "Federation Light",
            "LCARS Dark", "LCARS Light",
            "LCARS High Contrast Dark", "LCARS High Contrast Light",
            "Mission Control Dark", "Mission Control Light",
            "Ready Room Dark", "Ready Room Light",
            "Red Alert Dark", "Red Alert Light",
            "Sick Bay Dark", "Sick Bay Light",
            "Yellow Alert Dark", "Yellow Alert Light"
        ]
        #expect(Set(family.themes.map(\.name)) == expected)
    }

    @Test("hardened CSS signature values are present")
    func signatureValues() throws {
        let family = try #require(ThemeFamily.bundled("zed-trek"))
        let lcarsDark = try #require(family.theme(named: "LCARS Dark"))
        #expect(lcarsDark.style.chrome.surfaceBackground == Tokens.Color(hex: 0x16_1F_33))
        #expect(lcarsDark.platform.onAccent == Tokens.Color(hex: 0x05_06_0A))
        #expect(lcarsDark.style.syntax["comment"]?.color == Tokens.Color(hex: 0x93_9B_A9))

        let hcDark = try #require(family.theme(named: "LCARS High Contrast Dark"))
        #expect(hcDark.style.background == Tokens.Color(hex: 0x05_06_0A))
        #expect(hcDark.style.accents.first == Tokens.Color(hex: 0xFF_99_33))
        #expect(hcDark.style.status.error.base == Tokens.Color(hex: 0xF3_7F_7F))
        #expect(hcDark.style.text.placeholder == Tokens.Color(hex: 0x99_A1_AD))

        let hcLight = try #require(family.theme(named: "LCARS High Contrast Light"))
        #expect(hcLight.style.background == Tokens.Color(hex: 0xFB_F7_F1))
    }
}
