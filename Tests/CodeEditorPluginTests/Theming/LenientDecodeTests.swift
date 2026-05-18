import CodeEditorDesignTokens
@testable import CodeEditorPlugin
import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

@Suite("Lenient decode")
struct LenientDecodeTests {
    private func minimalThemeJson(
        extraStyleKeys: [String: String] = [:],
        removed: Set<String> = []
    ) -> Data {
        var styleKeys: [String: String] = [
            "background": "#020204",
            "editor.background": "#010204",
            "editor.foreground": "#DFE7F1",
            "editor.gutter.background": "#05070D",
            "text": "#DFE7F1",
            "text.muted": "#8B99AB",
            "text.placeholder": "#68778C",
            "text.disabled": "#4F5D70",
            "text.accent": "#C7E9F1"
        ]
        for (key, value) in extraStyleKeys { styleKeys[key] = value }
        for key in removed { styleKeys.removeValue(forKey: key) }
        let pairs = styleKeys.map { ##""\##($0.key)":"\##($0.value)""## }.joined(separator: ",")
        let json = """
        {"name":"T","themes":[{"appearance":"dark","name":"T Dark","style":{
        \(pairs),"players":[{"cursor":"#7EC8DE","selection":"#7EC8DE26"}],"accents":[],"syntax":{}
        }}]}
        """
        return Data(json.utf8)
    }

    @Test("missing editor.gutter.background falls back and warns")
    func missingGutterFallsBack() throws {
        let data = minimalThemeJson(removed: ["editor.gutter.background"])
        let (_, warnings) = try ThemeFamily.loaded(jsonData: data)
        #expect(warnings.contains {
            $0.keyPath == "editor.gutter.background" && $0.kind == .missingKey
        })
    }

    @Test("malformed hex falls back and warns")
    func malformedHexWarns() throws {
        let data = minimalThemeJson(extraStyleKeys: ["text.muted": "not-a-color"])
        let (_, warnings) = try ThemeFamily.loaded(jsonData: data)
        #expect(warnings.contains { $0.kind == .malformedColor && $0.detail == "not-a-color" })
    }

    @Test("absent platform key derives defaults")
    func absentPlatformDerives() throws {
        let data = minimalThemeJson()
        let (family, _) = try ThemeFamily.loaded(jsonData: data)
        let theme = try #require(family.themes.first)
        #expect(theme.platform.glass.opacity > 0)
        #expect(theme.platform.shadows.popover.blur > 0)
    }

    @Test("emphasis-only syntax entry decodes with no color")
    func emphasisOnlySyntaxEntry() throws {
        let json = ##"""
        {"name":"T","themes":[{"appearance":"dark","name":"T Dark","style":{
        "background":"#020204","editor.background":"#010204","editor.foreground":"#DFE7F1",
        "players":[{"cursor":"#7EC8DE","selection":"#7EC8DE26"}],"accents":[],
        "syntax":{"emphasis":{"font_style":"italic"}}}}]}
        """##
        let (family, _) = try ThemeFamily.loaded(jsonData: Data(json.utf8))
        let theme = try #require(family.themes.first)
        #expect(theme.style.syntax["emphasis"]?.color == nil)
        #expect(theme.style.syntax["emphasis"]?.fontStyle == .italic)
    }
}
