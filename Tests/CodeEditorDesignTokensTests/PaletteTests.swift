@testable import CodeEditorDesignTokens
import Testing

@Suite("Tokens.Palette base values")
struct PaletteBaseTests {
    @Test("Apple systemBlue accent (dark)")
    func accentDark() {
        #expect(Tokens.Palette.Accent.dark == Tokens.Color(hex: 0x0A84FF))
    }

    @Test("Apple systemBlue accent (light)")
    func accentLight() {
        #expect(Tokens.Palette.Accent.light == Tokens.Color(hex: 0x007AFF))
    }

    @Test("accent contrast is white")
    func accentContrast() {
        #expect(Tokens.Palette.Accent.contrast == Tokens.Color(hex: 0xFFFFFF))
    }

    @Test("status palette (dark)")
    func statusDark() {
        #expect(Tokens.Palette.Status.successDark == Tokens.Color(hex: 0x30D158))
        #expect(Tokens.Palette.Status.warningDark == Tokens.Color(hex: 0xFF9F0A))
        #expect(Tokens.Palette.Status.errorDark == Tokens.Color(hex: 0xFF453A))
        #expect(Tokens.Palette.Status.infoDark == Tokens.Color(hex: 0x0A84FF))
        #expect(Tokens.Palette.Status.cautionDark == Tokens.Color(hex: 0xFFD60A))
    }

    @Test("status palette (light)")
    func statusLight() {
        #expect(Tokens.Palette.Status.successLight == Tokens.Color(hex: 0x34C759))
        #expect(Tokens.Palette.Status.warningLight == Tokens.Color(hex: 0xFF9500))
        #expect(Tokens.Palette.Status.errorLight == Tokens.Color(hex: 0xFF3B30))
        #expect(Tokens.Palette.Status.infoLight == Tokens.Color(hex: 0x007AFF))
    }

    @Test("ANSI terminal palette")
    func ansi() {
        #expect(Tokens.Palette.ANSI.black == Tokens.Color(hex: 0x1E1E1E))
        #expect(Tokens.Palette.ANSI.red == Tokens.Color(hex: 0xF44747))
        #expect(Tokens.Palette.ANSI.green == Tokens.Color(hex: 0x6A9955))
        #expect(Tokens.Palette.ANSI.yellow == Tokens.Color(hex: 0xD7BA7D))
        #expect(Tokens.Palette.ANSI.blue == Tokens.Color(hex: 0x569CD6))
        #expect(Tokens.Palette.ANSI.magenta == Tokens.Color(hex: 0xC39BD3))
        #expect(Tokens.Palette.ANSI.cyan == Tokens.Color(hex: 0x4DD0E1))
        #expect(Tokens.Palette.ANSI.white == Tokens.Color(hex: 0xD4D4D4))
    }
}

@Suite("Tokens.Palette derived accent variants")
struct PaletteDerivedTests {
    @Test("dark hover is darker than dark base")
    func darkHoverDarker() {
        let base = Tokens.Palette.Accent.dark
        let hover = Tokens.Palette.Accent.hoverDark
        #expect(Int(hover.red) <= Int(base.red))
        #expect(Int(hover.green) <= Int(base.green))
        #expect(Int(hover.blue) <= Int(base.blue))
        #expect(hover != base)
    }

    @Test("dark pressed is darker than dark hover")
    func darkPressedDarkerThanHover() {
        let hover = Tokens.Palette.Accent.hoverDark
        let pressed = Tokens.Palette.Accent.pressedDark
        #expect(Int(pressed.red) <= Int(hover.red))
        #expect(Int(pressed.green) <= Int(hover.green))
        #expect(Int(pressed.blue) <= Int(hover.blue))
    }

    @Test("derived dark variants match precomputed values")
    func darkPrecomputed() {
        #expect(Tokens.Palette.Accent.hoverDark == Tokens.Color(hex: 0x0977E6))
        #expect(Tokens.Palette.Accent.pressedDark == Tokens.Color(hex: 0x086ACC))
    }

    @Test("derived light variants match precomputed values")
    func lightPrecomputed() {
        #expect(Tokens.Palette.Accent.hoverLight == Tokens.Color(hex: 0x006EE6))
        #expect(Tokens.Palette.Accent.pressedLight == Tokens.Color(hex: 0x0062CC))
    }

    @Test("dark tints share base hex with monotonically increasing alpha")
    func darkTintsAlpha() {
        let base = Tokens.Palette.Accent.dark
        let tint10 = Tokens.Palette.Accent.tint10Dark
        let tint15 = Tokens.Palette.Accent.tint15Dark
        let tint20 = Tokens.Palette.Accent.tint20Dark
        let tint25 = Tokens.Palette.Accent.tint25Dark
        for tint in [tint10, tint15, tint20, tint25] {
            #expect(tint.red == base.red)
            #expect(tint.green == base.green)
            #expect(tint.blue == base.blue)
        }
        #expect(abs(tint10.alpha - 0.10) < 1e-9)
        #expect(abs(tint15.alpha - 0.15) < 1e-9)
        #expect(abs(tint20.alpha - 0.20) < 1e-9)
        #expect(abs(tint25.alpha - 0.25) < 1e-9)
    }

    @Test("light tints share base hex with monotonically increasing alpha")
    func lightTintsAlpha() {
        let base = Tokens.Palette.Accent.light
        let tints = [
            Tokens.Palette.Accent.tint10Light,
            Tokens.Palette.Accent.tint15Light,
            Tokens.Palette.Accent.tint20Light,
            Tokens.Palette.Accent.tint25Light
        ]
        for tint in tints {
            #expect(tint.red == base.red)
            #expect(tint.green == base.green)
            #expect(tint.blue == base.blue)
        }
        let alphas = tints.map(\.alpha)
        for idx in 1..<alphas.count {
            #expect(alphas[idx] > alphas[idx - 1])
        }
    }
}
