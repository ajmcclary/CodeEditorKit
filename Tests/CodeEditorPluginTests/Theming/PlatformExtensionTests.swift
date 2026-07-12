import CodeEditorDesignTokens
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

@Suite("PlatformExtension")
struct PlatformExtensionTests {
    @Test("decodes from explicit platform object")
    func decodesExplicitPlatformObject() throws {
        let json = ##"""
        {
          "glass": { "tint": "#7EC8DE", "opacity": 0.12 },
          "shadows": { "popover": { "color": "#000000", "blur": 24, "x": 0, "y": 12 } },
          "field": { "fill": "#101010", "border": "#202020", "focused_border": "#0A84FF" }
        }
        """##
        let decoder = JSONDecoder()
        decoder.userInfo[.themeWarnings] = WarningCollector()
        let platform = try decoder.decode(PlatformExtension.self, from: Data(json.utf8))
        #expect(platform.glass.tint == Tokens.Color(hex: 0x7E_C8_DE))
        #expect(abs(platform.glass.opacity - 0.12) < 1e-9)
        #expect(platform.shadows.popover.blur == 24)
        #expect(platform.field.focusedBorder == Tokens.Color(hex: 0x0A_84_FF))
    }

    @Test("unknown platform key lands in extras and warns")
    func unknownKeyInExtras() throws {
        let json = ##"""
        {
          "glass": { "tint": "#7EC8DE", "opacity": 0.12 },
          "shadows": { "popover": { "color": "#000000", "blur": 1, "x": 0, "y": 1 } },
          "field": { "fill": "#101010", "border": "#202020", "focused_border": "#0A84FF" },
          "weird_key": "#FF0000"
        }
        """##
        let decoder = JSONDecoder()
        let collector = WarningCollector()
        decoder.userInfo[.themeWarnings] = collector
        let platform = try decoder.decode(PlatformExtension.self, from: Data(json.utf8))
        #expect(platform.extras["weird_key"] == Tokens.Color(hex: 0xFF_00_00))
        #expect(collector.warnings.contains { $0.kind == .unknownPlatformKey })
    }

    @Test("explicit platform.on_accent / on_danger decode")
    func decodesOnRoles() throws {
        let json = ##"""
        {
          "glass": { "tint": "#FF9933", "opacity": 0.12 },
          "shadows": { "popover": { "color": "#0000004D", "blur": 36, "x": 0, "y": 10 } },
          "field": { "fill": "#151A24", "border": "#2A2030", "focused_border": "#FF9933" },
          "on_accent": "#05060A", "on_danger": "#05060A"
        }
        """##
        let decoder = JSONDecoder()
        decoder.userInfo[.themeWarnings] = WarningCollector()
        let platform = try decoder.decode(PlatformExtension.self, from: Data(json.utf8))
        #expect(platform.onAccent == Tokens.Color(hex: 0x05_06_0A))
        #expect(platform.onDanger == Tokens.Color(hex: 0x05_06_0A))
        #expect(platform.glass.tint == Tokens.Color(hex: 0xFF_99_33))
    }

    @Test("derived() supplies on-role fallbacks per appearance")
    func derivedFallback() {
        let dark = Theme.fallback(appearance: .dark)
        #expect(dark.platform.onAccent == Tokens.Color(hex: 0x05_06_0A))
        let light = Theme.fallback(appearance: .light)
        #expect(light.platform.onAccent == Tokens.Color(hex: 0xFF_FF_FF))
    }

    @Test("Theme exposes role accessors")
    func themeRoleAccessors() {
        let theme = Theme.fallback(appearance: .dark)
        #expect(theme.onAccent == theme.platform.onAccent)
        #expect(theme.onDanger == theme.platform.onDanger)
        #expect(theme.glassTint == theme.platform.glass.tint)
    }
}
