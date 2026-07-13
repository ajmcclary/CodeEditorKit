import DesignKitTokens
import DesignKitThemes
@testable import CodeEditorView
import Foundation
import Testing

@Suite("ThemeStyle top-level decoder")
struct ThemeStyleDecoderTests {
    private static let lcarsDarkStyleJson = ##"""
    {
      "background": "#020204",
      "background.appearance": "opaque",
      "surface.background": "#07090F",
      "elevated_surface.background": "#10121C",
      "editor.background": "#010204",
      "editor.foreground": "#DFE7F1",
      "editor.gutter.background": "#05070D",
      "editor.active_line.background": "#7EC8DE12",
      "editor.highlighted_line.background": "#B5A7FF1F",
      "editor.active_line_number": "#7EC8DE",
      "editor.line_number": "#5D6B7F",
      "editor.invisible": "#1B2433",
      "editor.indent_guide": "#121826",
      "editor.indent_guide_active": "#7EC8DE",
      "editor.wrap_guide": "#121826",
      "editor.active_wrap_guide": "#B5A7FF",
      "editor.subheader.background": "#05070D",
      "editor.document_highlight.read_background": "#7EC8DE24",
      "editor.document_highlight.write_background": "#B5A7FF26",
      "editor.document_highlight.bracket_background": "#7EC8DE33",
      "title_bar.background": "#080B12",
      "title_bar.inactive_background": "#05070D",
      "tab_bar.background": "#020204",
      "tab.active_background": "#10121C",
      "tab.inactive_background": "#05070D",
      "status_bar.background": "#080B12",
      "toolbar.background": "#080B12",
      "panel.background": "#080B12",
      "panel.focused_border": "#C7E9F1",
      "panel.indent_guide": "#121826",
      "panel.indent_guide_active": "#7EC8DE",
      "panel.indent_guide_hover": "#B5A7FF",
      "pane.focused_border": "#7EC8DE",
      "pane_group.border": "#121826",
      "border": "#1A2232",
      "border.disabled": "#10121C",
      "border.focused": "#7EC8DE",
      "border.selected": "#B5A7FF",
      "border.transparent": "#7EC8DE00",
      "border.variant": "#121826",
      "text": "#DFE7F1",
      "text.muted": "#8B99AB",
      "text.placeholder": "#68778C",
      "text.disabled": "#4F5D70",
      "text.accent": "#C7E9F1",
      "icon": "#C5D1DF",
      "icon.muted": "#768699",
      "icon.placeholder": "#5D6B7F",
      "icon.disabled": "#364253",
      "icon.accent": "#7EC8DE",
      "element.background": "#10121C",
      "element.hover": "#151C2B",
      "element.active": "#1B273A",
      "element.selected": "#252041",
      "element.disabled": "#080B12",
      "ghost_element.background": "#00000000",
      "ghost_element.hover": "#7EC8DE18",
      "ghost_element.active": "#7EC8DE2B",
      "ghost_element.selected": "#B5A7FF33",
      "ghost_element.disabled": "#10121C88",
      "drop_target.background": "#B5A7FF2E",
      "scrollbar.track.background": "#020204",
      "scrollbar.track.border": "#121826",
      "scrollbar.thumb.background": "#7EC8DE99",
      "scrollbar.thumb.border": "#B5A7FF",
      "scrollbar.thumb.hover_background": "#C7E9F1AA",
      "search.match_background": "#B5A7FF66",
      "predictive": "#8B99AB",
      "predictive.background": "#7EC8DE1D",
      "predictive.border": "#257EA7",
      "hint": "#7EC8DE",
      "hint.background": "#102838",
      "hint.border": "#257EA7",
      "info": "#7EC8DE",
      "info.background": "#102838",
      "info.border": "#257EA7",
      "success": "#4EE6A6",
      "success.background": "#0F2A21",
      "success.border": "#2F9F68",
      "warning": "#FF9933",
      "warning.background": "#33210D",
      "warning.border": "#FF9933",
      "error": "#FF7373",
      "error.background": "#341519",
      "error.border": "#EF5A5A",
      "conflict": "#FF9933",
      "conflict.background": "#33210D",
      "conflict.border": "#FF9933",
      "created": "#4EE6A6",
      "created.background": "#0F2A21",
      "created.border": "#2F9F68",
      "modified": "#7EC8DE",
      "modified.background": "#102838",
      "modified.border": "#257EA7",
      "deleted": "#FF7373",
      "deleted.background": "#341519",
      "deleted.border": "#EF5A5A",
      "renamed": "#B5A7FF",
      "renamed.background": "#211D36",
      "renamed.border": "#7566D8",
      "ignored": "#4F5D70",
      "ignored.background": "#05070D",
      "ignored.border": "#121826",
      "hidden": "#364253",
      "hidden.background": "#05070D",
      "hidden.border": "#10121C",
      "unreachable": "#68727C",
      "unreachable.background": "#10121C",
      "unreachable.border": "#1A2232",
      "link_text.hover": "#C7E9F1",
      "players": [
        { "background": "#7EC8DE33", "cursor": "#7EC8DE", "selection": "#7EC8DE26" }
      ],
      "accents": [ "#7EC8DE", "#C7E9F1", "#B5A7FF" ],
      "syntax": {
        "keyword": { "color": "#C7E9F1", "font_weight": 800 },
        "string":  { "color": "#7EC8DE" }
      }
    }
    """##

    @Test("routes flat dotted keys into the right sub-structs")
    func routesFlatKeys() throws {
        let decoder = JSONDecoder()
        let collector = WarningCollector()
        decoder.userInfo[.themeWarnings] = collector
        let style = try decoder.decode(ThemeStyle.self, from: Data(Self.lcarsDarkStyleJson.utf8))

        #expect(style.background == Tokens.Color(hex: 0x02_02_04))
        #expect(style.backgroundAppearance == "opaque")
        #expect(style.editor.background == Tokens.Color(hex: 0x01_02_04))
        #expect(style.text.muted == Tokens.Color(hex: 0x8B_99_AB))
        #expect(style.elements.element.background == Tokens.Color(hex: 0x10_12_1C))
        #expect(style.status.warning.base == Tokens.Color(hex: 0xFF_99_33))
        #expect(style.vcs.deleted.background == Tokens.Color(hex: 0x34_15_19))
        #expect(style.dropTarget.alpha < 0.5)
        #expect(style.players.count == 1)
        #expect(style.accents.count == 3)
        #expect(style.syntax["keyword"]?.fontWeight == 800)
        #expect(collector.warnings.isEmpty)
    }

    @Test("encoder produces a flat-keyed object that decodes back equally")
    func encoderRoundtrips() throws {
        let decoder1 = JSONDecoder()
        decoder1.userInfo[.themeWarnings] = WarningCollector()
        let style1 = try decoder1.decode(ThemeStyle.self, from: Data(Self.lcarsDarkStyleJson.utf8))
        let encoded = try JSONEncoder().encode(style1)
        let decoder2 = JSONDecoder()
        decoder2.userInfo[.themeWarnings] = WarningCollector()
        let style2 = try decoder2.decode(ThemeStyle.self, from: encoded)
        #expect(style1.editor.background == style2.editor.background)
        #expect(style1.text.muted == style2.text.muted)
        #expect(style1.players == style2.players)
        #expect(style1.accents == style2.accents)
    }

    @Test("PlatformExtension.derived synthesizes from a populated style")
    func platformDerived() throws {
        let decoder = JSONDecoder()
        decoder.userInfo[.themeWarnings] = WarningCollector()
        let style = try decoder.decode(ThemeStyle.self, from: Data(Self.lcarsDarkStyleJson.utf8))
        let platform = PlatformExtension.derived(from: style, appearance: .dark)
        #expect(platform.glass.tint != Tokens.Color(hex: 0x00_00_00, alpha: 0))
        #expect(platform.glass.opacity > 0)
        #expect(platform.shadows.popover.blur > 0)
    }
}
