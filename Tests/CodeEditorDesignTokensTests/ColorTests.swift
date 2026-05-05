@testable import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Tokens.Color")
struct ColorTests {
    @Test("hex literal init builds expected components")
    func hexLiteralInit() {
        let color = Tokens.Color(hex: 0x0A84FF)
        #expect(color.red == 0x0A)
        #expect(color.green == 0x84)
        #expect(color.blue == 0xFF)
        #expect(color.alpha == 1.0)
    }

    @Test("hex literal init with alpha")
    func hexLiteralInitWithAlpha() {
        let color = Tokens.Color(hex: 0xFFFFFF, alpha: 0.5)
        #expect(color.red == 0xFF)
        #expect(color.green == 0xFF)
        #expect(color.blue == 0xFF)
        #expect(abs(color.alpha - 0.5) < 1e-9)
    }

    @Test("hexString init parses with leading hash")
    func hexStringInitWithHash() throws {
        let color = try #require(Tokens.Color(hexString: "#0A84FF"))
        #expect(color == Tokens.Color(hex: 0x0A84FF))
    }

    @Test("hexString init parses without leading hash")
    func hexStringInitWithoutHash() throws {
        let color = try #require(Tokens.Color(hexString: "0A84FF"))
        #expect(color == Tokens.Color(hex: 0x0A84FF))
    }

    @Test("hexString init parses 8-digit (RGBA)")
    func hexStringInit8Digit() throws {
        let color = try #require(Tokens.Color(hexString: "#0A84FF80"))
        #expect(color.red == 0x0A)
        #expect(color.green == 0x84)
        #expect(color.blue == 0xFF)
        #expect(abs(color.alpha - Double(0x80) / 255.0) < 1e-9)
    }

    @Test("hexString init returns nil for invalid input")
    func hexStringInitRejectsInvalid() {
        #expect(Tokens.Color(hexString: "not-a-color") == nil)
        #expect(Tokens.Color(hexString: "#XYZ") == nil)
        #expect(Tokens.Color(hexString: "#12345") == nil)
    }

    @Test("hexString roundtrips with full alpha")
    func hexStringRoundtripFullAlpha() {
        let color = Tokens.Color(hex: 0x0A84FF)
        #expect(color.hexString == "#0A84FF")
    }

    @Test("hexString roundtrips with partial alpha")
    func hexStringRoundtripPartialAlpha() {
        let color = Tokens.Color(hex: 0x0A84FF, alpha: Double(0x80) / 255.0)
        #expect(color.hexString == "#0A84FF80")
    }

    @Test("Codable roundtrips")
    func codableRoundtrip() throws {
        let original = Tokens.Color(hex: 0x0A84FF, alpha: 0.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Tokens.Color.self, from: data)
        #expect(decoded == original)
    }

    @Test("equality treats colors with same components as equal")
    func equality() {
        #expect(Tokens.Color(hex: 0x123456) == Tokens.Color(red: 0x12, green: 0x34, blue: 0x56))
        #expect(Tokens.Color(hex: 0x123456) != Tokens.Color(hex: 0x123457))
    }
}
