import Testing
@testable import CodeEditorDesignTokens

@Suite("Tokens.Typography")
struct TypographyTests {

    @Test("font stacks lead with Apple system fonts")
    func fontStacks() {
        #expect(Tokens.Typography.fontSansStack.first == "-apple-system")
        #expect(Tokens.Typography.fontDisplayStack.first == "-apple-system")
        #expect(Tokens.Typography.fontMonoStack.first == "ui-monospace")
        #expect(Tokens.Typography.fontRoundedStack.first == "ui-rounded")
    }

    @Test("type scale matches CSS source")
    func sizes() {
        #expect(Tokens.Typography.Size.displayXL == 80)
        #expect(Tokens.Typography.Size.titleXL == 34)
        #expect(Tokens.Typography.Size.titleLG == 28)
        #expect(Tokens.Typography.Size.bodyLG == 17)
        #expect(Tokens.Typography.Size.captionLG == 12)
        #expect(Tokens.Typography.Size.captionMD == 11)
    }

    @Test("type scale is monotonically decreasing through the headline ramp")
    func sizeMonotonicity() {
        let ramp = [
            Tokens.Typography.Size.displayXL,
            Tokens.Typography.Size.displayLG,
            Tokens.Typography.Size.displayMD,
            Tokens.Typography.Size.displaySM,
            Tokens.Typography.Size.titleXL,
            Tokens.Typography.Size.titleLG,
            Tokens.Typography.Size.titleMD,
            Tokens.Typography.Size.titleSM
        ]
        for i in 1..<ramp.count {
            #expect(ramp[i] < ramp[i - 1], "ramp[\(i)]=\(ramp[i]) should be < ramp[\(i-1)]=\(ramp[i-1])")
        }
    }

    @Test("weights match Apple semantic values")
    func weights() {
        #expect(Tokens.Typography.Weight.regular == 400)
        #expect(Tokens.Typography.Weight.medium == 500)
        #expect(Tokens.Typography.Weight.semibold == 600)
        #expect(Tokens.Typography.Weight.bold == 700)
    }

    @Test("line heights")
    func lineHeights() {
        #expect(Tokens.Typography.LineHeight.tight == 1.0)
        #expect(Tokens.Typography.LineHeight.normal == 1.2)
        #expect(Tokens.Typography.LineHeight.relaxed == 1.5)
    }
}
