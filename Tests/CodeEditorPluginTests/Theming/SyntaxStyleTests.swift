import CodeEditorDesignTokens
@testable import CodeEditorPlugin
import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

@Suite("SyntaxStyle")
struct SyntaxStyleTests {
    @Test("decodes color + font_weight + font_style")
    func decodesAllFields() throws {
        let json = ##"{"color":"#7ec8de","font_weight":700,"font_style":"italic"}"##
        let style = try JSONDecoder().decode(SyntaxStyle.self, from: Data(json.utf8))
        #expect(style.color == Tokens.Color(hex: 0x7E_C8_DE))
        #expect(style.fontWeight == 700)
        #expect(style.fontStyle == .italic)
        #expect(style.backgroundColor == nil)
    }

    @Test("decodes emphasis-style entry with no color")
    func decodesEmphasisStyleOnly() throws {
        let json = ##"{"font_style":"italic"}"##
        let style = try JSONDecoder().decode(SyntaxStyle.self, from: Data(json.utf8))
        #expect(style.color == nil)
        #expect(style.fontStyle == .italic)
        #expect(style.fontWeight == nil)
    }

    @Test("decodes weight 100 through 900")
    func acceptsAnyValidWeight() throws {
        for weight in stride(from: 100, through: 900, by: 100) {
            let json = ##"{"color":"#000000","font_weight":\##(weight)}"##
            let style = try JSONDecoder().decode(SyntaxStyle.self, from: Data(json.utf8))
            #expect(style.fontWeight == weight)
        }
    }

    @Test("Player decodes cursor + selection + optional background")
    func playerDecodes() throws {
        let json = ##"{"cursor":"#7ec8de","selection":"#7ec8de26","background":"#7ec8de33"}"##
        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))
        #expect(player.cursor == Tokens.Color(hex: 0x7E_C8_DE))
        #expect(player.background?.alpha != nil)
    }

    @Test("Player decodes without background")
    func playerDecodesWithoutBackground() throws {
        let json = ##"{"cursor":"#7ec8de","selection":"#7ec8de26"}"##
        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))
        #expect(player.background == nil)
    }

    @Test("TerminalColors decodes selectively")
    func terminalDecodes() throws {
        let json = ##"{"foreground":"#dfe7f1","ansi":{"red":"#ff7373"}}"##
        let term = try JSONDecoder().decode(TerminalColors.self, from: Data(json.utf8))
        #expect(term.foreground == Tokens.Color(hex: 0xDF_E7_F1))
        #expect(term.ansi?.red == Tokens.Color(hex: 0xFF_73_73))
        #expect(term.background == nil)
    }
}
