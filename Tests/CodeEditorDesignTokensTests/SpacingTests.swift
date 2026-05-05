@testable import CodeEditorDesignTokens
import Testing

@Suite("Tokens.Spacing")
struct SpacingTests {
    @Test("scale matches CSS source")
    func values() {
        #expect(Tokens.Spacing.xxxs == 2)
        #expect(Tokens.Spacing.xxs == 4)
        #expect(Tokens.Spacing.xs == 6)
        #expect(Tokens.Spacing.sm == 8)
        #expect(Tokens.Spacing.smMd == 10)
        #expect(Tokens.Spacing.md == 12)
        #expect(Tokens.Spacing.lg == 16)
        #expect(Tokens.Spacing.xl == 20)
        #expect(Tokens.Spacing.xxl == 24)
        #expect(Tokens.Spacing.xxxl == 32)
    }

    @Test("scale is strictly monotonic")
    func monotonic() {
        let scale = [
            Tokens.Spacing.xxxs, Tokens.Spacing.xxs, Tokens.Spacing.xs,
            Tokens.Spacing.sm, Tokens.Spacing.smMd, Tokens.Spacing.md,
            Tokens.Spacing.lg, Tokens.Spacing.xl, Tokens.Spacing.xxl,
            Tokens.Spacing.xxxl
        ]
        for idx in 1..<scale.count {
            #expect(scale[idx] > scale[idx - 1])
        }
    }

    @Test("aliases delegate to scale values")
    func aliases() {
        #expect(Tokens.Spacing.cardPadding == Tokens.Spacing.lg)
        #expect(Tokens.Spacing.section == Tokens.Spacing.xl)
        #expect(Tokens.Spacing.content == Tokens.Spacing.xxl)
    }
}
