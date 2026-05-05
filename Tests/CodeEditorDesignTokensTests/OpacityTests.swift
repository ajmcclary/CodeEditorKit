import Testing
@testable import CodeEditorDesignTokens

@Suite("Tokens.Opacity")
struct OpacityTests {

    @Test("values match CSS source")
    func values() {
        #expect(Tokens.Opacity.faint == 0.03)
        #expect(Tokens.Opacity.dim == 0.04)
        #expect(Tokens.Opacity.subtle == 0.05)
        #expect(Tokens.Opacity.mist == 0.06)
        #expect(Tokens.Opacity.soft == 0.08)
        #expect(Tokens.Opacity.tint == 0.10)
        #expect(Tokens.Opacity.glassFill == 0.12)
        #expect(Tokens.Opacity.glassBorder == 0.14)
        #expect(Tokens.Opacity.glassHighlight == 0.15)
        #expect(Tokens.Opacity.light == 0.20)
        #expect(Tokens.Opacity.disabled == 0.30)
        #expect(Tokens.Opacity.medium == 0.50)
        #expect(Tokens.Opacity.strong == 0.70)
        #expect(Tokens.Opacity.heavy == 0.80)
        #expect(Tokens.Opacity.near == 0.85)
    }

    @Test("scale is strictly monotonic")
    func monotonic() {
        let scale: [Double] = [
            Tokens.Opacity.faint, Tokens.Opacity.dim, Tokens.Opacity.subtle,
            Tokens.Opacity.mist, Tokens.Opacity.soft, Tokens.Opacity.tint,
            Tokens.Opacity.glassFill, Tokens.Opacity.glassBorder, Tokens.Opacity.glassHighlight,
            Tokens.Opacity.light, Tokens.Opacity.disabled, Tokens.Opacity.medium,
            Tokens.Opacity.strong, Tokens.Opacity.heavy, Tokens.Opacity.near
        ]
        for i in 1..<scale.count {
            #expect(scale[i] > scale[i - 1])
        }
    }
}
