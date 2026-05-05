@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import SwiftUI
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@Suite("Tokens.Color bridges")
struct ColorBridgesTests {

    @Test("SwiftUI.Color preserves sRGB components")
    func swiftUIColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF)
        let color = Color(tokens: token)
        let expected = Color(
            .sRGB,
            red: Double(token.red) / 255,
            green: Double(token.green) / 255,
            blue: Double(token.blue) / 255,
            opacity: token.alpha
        )
        #expect(color == expected)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Test("NSColor(tokens:) preserves sRGB components")
    func nsColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF)
        let nsColor = NSColor(tokens: token)
        let inSRGB = nsColor.usingColorSpace(.sRGB)
        #expect(inSRGB != nil)
        if let c = inSRGB {
            #expect(abs(c.redComponent - 0x0A / 255.0) < 0.005)
            #expect(abs(c.greenComponent - 0x84 / 255.0) < 0.005)
            #expect(abs(c.blueComponent - 0xFF / 255.0) < 0.005)
            #expect(abs(c.alphaComponent - 1.0) < 0.005)
        }
    }
    #endif

    #if canImport(UIKit)
    @Test("UIColor(tokens:) preserves sRGB components")
    func uiColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF, alpha: 0.5)
        let uiColor = UIColor(tokens: token)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 0x0A / 255.0) < 0.005)
        #expect(abs(g - 0x84 / 255.0) < 0.005)
        #expect(abs(b - 0xFF / 255.0) < 0.005)
        #expect(abs(a - 0.5) < 0.005)
    }
    #endif
}
