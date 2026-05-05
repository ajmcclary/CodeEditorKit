@testable import CodeEditorDesignTokens
import Testing

@Suite("Tokens.Shape")
struct ShapeTests {
    @Test("radii match CSS source")
    func radii() {
        #expect(Tokens.Shape.radiusXS == 4)
        #expect(Tokens.Shape.radiusSM == 6)
        #expect(Tokens.Shape.radiusMD == 10)
        #expect(Tokens.Shape.radiusLG == 12)
        #expect(Tokens.Shape.radiusXL == 16)
        #expect(Tokens.Shape.radiusXXL == 20)
        #expect(Tokens.Shape.radiusChip == 8)
        #expect(Tokens.Shape.radiusWindow == 40)
        #expect(Tokens.Shape.radiusFull == 9_999)
    }

    @Test("strokes match CSS source")
    func strokes() {
        #expect(Tokens.Shape.strokeHairline == 0.5)
        #expect(Tokens.Shape.strokeThin == 1)
        #expect(Tokens.Shape.strokeMedLight == 1.5)
        #expect(Tokens.Shape.strokeMedium == 2)
        #expect(Tokens.Shape.strokeThick == 3)
        #expect(Tokens.Shape.strokeRing == 8)
    }

    @Test("strokes are strictly monotonic")
    func strokeMonotonic() {
        let scale = [
            Tokens.Shape.strokeHairline, Tokens.Shape.strokeThin,
            Tokens.Shape.strokeMedLight, Tokens.Shape.strokeMedium,
            Tokens.Shape.strokeThick, Tokens.Shape.strokeRing
        ]
        for idx in 1..<scale.count {
            #expect(scale[idx] > scale[idx - 1])
        }
    }

    @Test("radiusFull is the largest radius")
    func radiusFullIsLargest() {
        #expect(Tokens.Shape.radiusFull > Tokens.Shape.radiusWindow)
        #expect(Tokens.Shape.radiusWindow > Tokens.Shape.radiusXXL)
    }
}
