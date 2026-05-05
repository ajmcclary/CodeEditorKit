import CodeEditorDesignTokens
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("Sub-struct flat-init constructors")
struct SubStructFlatInitTests {
    @Test("IconLevels populates from flat")
    func iconLevels() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "icon": Tokens.Color(hex: 0xAA_AA_AA),
            "icon.muted": Tokens.Color(hex: 0xBB_BB_BB),
            "icon.placeholder": Tokens.Color(hex: 0xCC_CC_CC),
            "icon.disabled": Tokens.Color(hex: 0xDD_DD_DD),
            "icon.accent": Tokens.Color(hex: 0xEE_EE_EE)
        ]
        let icons = IconLevels(flat: flat, warnings: collector, path: "style")
        #expect(icons.base == Tokens.Color(hex: 0xAA_AA_AA))
        #expect(icons.accent == Tokens.Color(hex: 0xEE_EE_EE))
        #expect(collector.warnings.isEmpty)
    }

    @Test("BorderColors populates 6 keys")
    func borderColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "border": Tokens.Color(hex: 0x11_11_11),
            "border.disabled": Tokens.Color(hex: 0x22_22_22),
            "border.focused": Tokens.Color(hex: 0x33_33_33),
            "border.selected": Tokens.Color(hex: 0x44_44_44),
            "border.transparent": Tokens.Color(hex: 0x55_55_55),
            "border.variant": Tokens.Color(hex: 0x66_66_66)
        ]
        let borders = BorderColors(flat: flat, warnings: collector, path: "style")
        #expect(borders.base == Tokens.Color(hex: 0x11_11_11))
        #expect(borders.variant == Tokens.Color(hex: 0x66_66_66))
    }

    @Test("ScrollbarColors populates 5 dotted keys")
    func scrollbarColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "scrollbar.track.background": Tokens.Color(hex: 0x11_11_11),
            "scrollbar.track.border": Tokens.Color(hex: 0x22_22_22),
            "scrollbar.thumb.background": Tokens.Color(hex: 0x33_33_33),
            "scrollbar.thumb.border": Tokens.Color(hex: 0x44_44_44),
            "scrollbar.thumb.hover_background": Tokens.Color(hex: 0x55_55_55)
        ]
        let scrollbar = ScrollbarColors(flat: flat, warnings: collector, path: "style")
        #expect(scrollbar.trackBackground == Tokens.Color(hex: 0x11_11_11))
        #expect(scrollbar.thumbHoverBackground == Tokens.Color(hex: 0x55_55_55))
    }

    @Test("SearchColors populates")
    func searchColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "search.match_background": Tokens.Color(hex: 0xAB_CD_EF)
        ]
        let search = SearchColors(flat: flat, warnings: collector, path: "style")
        #expect(search.matchBackground == Tokens.Color(hex: 0xAB_CD_EF))
    }

    @Test("PredictiveColors populates 3 keys")
    func predictiveColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "predictive": Tokens.Color(hex: 0x11_11_11),
            "predictive.background": Tokens.Color(hex: 0x22_22_22),
            "predictive.border": Tokens.Color(hex: 0x33_33_33)
        ]
        let predictive = PredictiveColors(flat: flat, warnings: collector, path: "style")
        #expect(predictive.base == Tokens.Color(hex: 0x11_11_11))
        #expect(predictive.border == Tokens.Color(hex: 0x33_33_33))
    }

    @Test("HintColors populates 3 keys")
    func hintColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "hint": Tokens.Color(hex: 0x11_11_11),
            "hint.background": Tokens.Color(hex: 0x22_22_22),
            "hint.border": Tokens.Color(hex: 0x33_33_33)
        ]
        let hint = HintColors(flat: flat, warnings: collector, path: "style")
        #expect(hint.base == Tokens.Color(hex: 0x11_11_11))
        #expect(hint.border == Tokens.Color(hex: 0x33_33_33))
    }

    @Test("StatusPalette populates 5 kinds × 3 keys")
    func statusPalette() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "info": Tokens.Color(hex: 0x11_11_11),
            "info.background": Tokens.Color(hex: 0x12_12_12),
            "info.border": Tokens.Color(hex: 0x13_13_13),
            "success": Tokens.Color(hex: 0x21_11_11),
            "success.background": Tokens.Color(hex: 0x22_12_12),
            "success.border": Tokens.Color(hex: 0x23_13_13),
            "warning": Tokens.Color(hex: 0x31_11_11),
            "warning.background": Tokens.Color(hex: 0x32_12_12),
            "warning.border": Tokens.Color(hex: 0x33_13_13),
            "error": Tokens.Color(hex: 0x41_11_11),
            "error.background": Tokens.Color(hex: 0x42_12_12),
            "error.border": Tokens.Color(hex: 0x43_13_13),
            "conflict": Tokens.Color(hex: 0x51_11_11),
            "conflict.background": Tokens.Color(hex: 0x52_12_12),
            "conflict.border": Tokens.Color(hex: 0x53_13_13)
        ]
        let status = StatusPalette(flat: flat, warnings: collector, path: "style")
        #expect(status.info.base == Tokens.Color(hex: 0x11_11_11))
        #expect(status.error.background == Tokens.Color(hex: 0x42_12_12))
        #expect(status.conflict.border == Tokens.Color(hex: 0x53_13_13))
    }

    @Test("VCSPalette populates 7 kinds × 3 keys")
    func vcsPalette() {
        let collector = WarningCollector()
        var flat: [String: Tokens.Color] = [:]
        let kinds = ["created", "modified", "deleted", "renamed", "ignored", "hidden", "unreachable"]
        for (idx, kind) in kinds.enumerated() {
            flat[kind] = Tokens.Color(hex: UInt32(idx + 1) * 0x01_01_01)
            flat["\(kind).background"] = Tokens.Color(hex: UInt32(idx + 1) * 0x02_02_02)
            flat["\(kind).border"] = Tokens.Color(hex: UInt32(idx + 1) * 0x03_03_03)
        }
        let vcs = VCSPalette(flat: flat, warnings: collector, path: "style")
        #expect(vcs.created.base == Tokens.Color(hex: 0x01_01_01))
        #expect(vcs.deleted.border == Tokens.Color(hex: 0x09_09_09))
    }

    @Test("EditorColors populates 16 keys")
    func editorColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "editor.background": Tokens.Color(hex: 0x01_02_04),
            "editor.foreground": Tokens.Color(hex: 0xDF_E7_F1),
            "editor.gutter.background": Tokens.Color(hex: 0x05_07_0D),
            "editor.active_line.background": Tokens.Color(hex: 0x12_12_12),
            "editor.highlighted_line.background": Tokens.Color(hex: 0x13_13_13),
            "editor.active_line_number": Tokens.Color(hex: 0x7E_C8_DE),
            "editor.line_number": Tokens.Color(hex: 0x5D_6B_7F),
            "editor.invisible": Tokens.Color(hex: 0x1B_24_33),
            "editor.indent_guide": Tokens.Color(hex: 0x12_18_26),
            "editor.indent_guide_active": Tokens.Color(hex: 0x7E_C8_DE),
            "editor.wrap_guide": Tokens.Color(hex: 0x12_18_26),
            "editor.active_wrap_guide": Tokens.Color(hex: 0xB5_A7_FF),
            "editor.subheader.background": Tokens.Color(hex: 0x05_07_0D),
            "editor.document_highlight.read_background": Tokens.Color(hex: 0x14_14_14),
            "editor.document_highlight.write_background": Tokens.Color(hex: 0x15_15_15),
            "editor.document_highlight.bracket_background": Tokens.Color(hex: 0x16_16_16)
        ]
        let editor = EditorColors(flat: flat, warnings: collector, path: "style")
        #expect(editor.background == Tokens.Color(hex: 0x01_02_04))
        #expect(editor.foreground == Tokens.Color(hex: 0xDF_E7_F1))
        #expect(editor.documentHighlightBracket == Tokens.Color(hex: 0x16_16_16))
    }

    @Test("ChromeColors populates 16 keys")
    func chromeColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "title_bar.background": Tokens.Color(hex: 0x11_11_11),
            "title_bar.inactive_background": Tokens.Color(hex: 0x12_12_12),
            "tab_bar.background": Tokens.Color(hex: 0x13_13_13),
            "tab.active_background": Tokens.Color(hex: 0x14_14_14),
            "tab.inactive_background": Tokens.Color(hex: 0x15_15_15),
            "status_bar.background": Tokens.Color(hex: 0x16_16_16),
            "toolbar.background": Tokens.Color(hex: 0x17_17_17),
            "surface.background": Tokens.Color(hex: 0x18_18_18),
            "elevated_surface.background": Tokens.Color(hex: 0x19_19_19),
            "panel.background": Tokens.Color(hex: 0x1A_1A_1A),
            "panel.focused_border": Tokens.Color(hex: 0x1B_1B_1B),
            "panel.indent_guide": Tokens.Color(hex: 0x1C_1C_1C),
            "panel.indent_guide_active": Tokens.Color(hex: 0x1D_1D_1D),
            "panel.indent_guide_hover": Tokens.Color(hex: 0x1E_1E_1E),
            "pane.focused_border": Tokens.Color(hex: 0x1F_1F_1F),
            "pane_group.border": Tokens.Color(hex: 0x20_20_20)
        ]
        let chrome = ChromeColors(flat: flat, warnings: collector, path: "style")
        #expect(chrome.titleBarBackground == Tokens.Color(hex: 0x11_11_11))
        #expect(chrome.paneGroupBorder == Tokens.Color(hex: 0x20_20_20))
    }

    @Test("ElementStates populates element.* and ghost_element.*")
    func elementStates() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "element.background": Tokens.Color(hex: 0x11_11_11),
            "element.hover": Tokens.Color(hex: 0x22_22_22),
            "element.active": Tokens.Color(hex: 0x33_33_33),
            "element.selected": Tokens.Color(hex: 0x44_44_44),
            "element.disabled": Tokens.Color(hex: 0x55_55_55),
            "ghost_element.background": Tokens.Color(hex: 0x66_11_11),
            "ghost_element.hover": Tokens.Color(hex: 0x66_22_22),
            "ghost_element.active": Tokens.Color(hex: 0x66_33_33),
            "ghost_element.selected": Tokens.Color(hex: 0x66_44_44),
            "ghost_element.disabled": Tokens.Color(hex: 0x66_55_55)
        ]
        let elements = ElementStates(flat: flat, warnings: collector, path: "style")
        #expect(elements.element.background == Tokens.Color(hex: 0x11_11_11))
        #expect(elements.ghostElement.disabled == Tokens.Color(hex: 0x66_55_55))
    }
}
