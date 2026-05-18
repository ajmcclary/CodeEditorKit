import CodeEditorDesignTokens
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Foundation
import SwiftUI
import Testing

#if canImport(AppKit)
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

    #if canImport(AppKit)
    @Test("NSColor(tokens:) preserves sRGB components")
    func nsColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF)
        let nsColor = NSColor(tokens: token)
        let inSRGB = nsColor.usingColorSpace(.sRGB)
        #expect(inSRGB != nil)
        if let inSRGB {
            #expect(abs(inSRGB.redComponent - 0x0A / 255.0) < 0.005)
            #expect(abs(inSRGB.greenComponent - 0x84 / 255.0) < 0.005)
            #expect(abs(inSRGB.blueComponent - 0xFF / 255.0) < 0.005)
            #expect(abs(inSRGB.alphaComponent - 1.0) < 0.005)
        }
    }
    #endif

    #if canImport(UIKit)
    @Test("UIColor(tokens:) preserves sRGB components")
    func uiColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF, alpha: 0.5)
        let uiColor = UIColor(tokens: token)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(abs(red - 0x0A / 255.0) < 0.005)
        #expect(abs(green - 0x84 / 255.0) < 0.005)
        #expect(abs(blue - 0xFF / 255.0) < 0.005)
        #expect(abs(alpha - 0.5) < 0.005)
    }
    #endif
}
