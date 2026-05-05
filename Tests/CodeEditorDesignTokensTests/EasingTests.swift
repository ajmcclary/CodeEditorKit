@testable import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Tokens.Easing")
struct EasingTests {
    @Test("init stores control points")
    func storesControlPoints() {
        let easing = Tokens.Easing(0.16, 1.00, 0.30, 1.00)
        #expect(easing.x1 == 0.16)
        #expect(easing.y1 == 1.00)
        #expect(easing.x2 == 0.30)
        #expect(easing.y2 == 1.00)
    }

    @Test("equality")
    func equality() {
        let lhs = Tokens.Easing(0, 0, 1, 1)
        let rhs = Tokens.Easing(0, 0, 1, 1)
        #expect(lhs == rhs)
        #expect(Tokens.Easing(0, 0, 1, 1) != Tokens.Easing(0, 0, 1, 0.99))
    }

    @Test("Codable roundtrips")
    func codableRoundtrip() throws {
        let original = Tokens.Easing(0.22, 1.00, 0.36, 1.00)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Tokens.Easing.self, from: data)
        #expect(decoded == original)
    }
}
