@testable import CodeEditorDesignTokens
import Testing

@Suite("Tokens.Elevation")
struct ElevationTests {
    @Test("card shadow differs by scheme, blur/offset match CSS")
    func cardShadow() {
        #expect(Tokens.Elevation.card(.dark).blur == 12)
        #expect(Tokens.Elevation.card(.dark).y == 4)
        #expect(Tokens.Elevation.card(.dark).color != Tokens.Elevation.card(.light).color)
        #expect(Tokens.Elevation.window(.dark).y == 24)
        #expect(Tokens.Elevation.window(.dark).blur == 80)
        #expect(Tokens.Elevation.popover(.light).blur == 32)
    }

    @Test("focus ring is accent at 28% alpha, 3pt wide")
    func focusRing() {
        #expect(Tokens.Elevation.focusRingWidth == 3)
        let ring = Tokens.Elevation.focusRing(accent: Tokens.Color(hex: 0xFF_99_33))
        #expect(ring.red == 0xFF && ring.green == 0x99 && ring.blue == 0x33)
        #expect(abs(ring.alpha - 0.28) < 0.0001)
    }
}
