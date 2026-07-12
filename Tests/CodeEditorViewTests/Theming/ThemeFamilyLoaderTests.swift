import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

@Suite("ThemeFamily loader")
struct ThemeFamilyLoaderTests {
    @Test("init(jsonData:) throws on parse error")
    func initJsonDataThrowsOnParseError() {
        #expect(throws: DecodingError.self) {
            _ = try ThemeFamily(jsonData: Data("not json".utf8))
        }
    }

    @Test("loaded(jsonData:) returns warnings for malformed colors")
    func loadedReturnsWarnings() throws {
        let json = ##"""
        {
          "name": "Test", "themes": [
            {
              "appearance": "dark", "name": "Test Dark",
              "style": {
                "background": "not-a-color",
                "editor.background": "#010204",
                "editor.foreground": "#DFE7F1",
                "players": [{ "cursor": "#7EC8DE", "selection": "#7EC8DE26" }],
                "accents": [], "syntax": {}
              }
            }
          ]
        }
        """##
        let (family, warnings) = try ThemeFamily.loaded(jsonData: Data(json.utf8))
        #expect(family.themes.count == 1)
        #expect(warnings.contains { $0.kind == .malformedColor })
    }

    @Test("init(contentsOf:) reads from a file URL")
    func initContentsOfReadsFromFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("theme-test-\(UUID().uuidString).json")
        let json = ##"""
        {
          "name": "FromFile", "themes": [{
            "appearance": "dark", "name": "FromFile Dark",
            "style": {
              "background": "#020204",
              "editor.background": "#010204",
              "editor.foreground": "#DFE7F1",
              "players": [{ "cursor": "#7EC8DE", "selection": "#7EC8DE26" }],
              "accents": [], "syntax": {}
            }
          }]
        }
        """##
        try Data(json.utf8).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }
        let family = try ThemeFamily(contentsOf: temp)
        #expect(family.name == "FromFile")
    }

    @Test("init(contentsOf:) on missing file throws")
    func initContentsOfMissingFileThrows() {
        let missing = URL(fileURLWithPath: "/tmp/definitely-not-here-\(UUID().uuidString).json")
        #expect(throws: (any Error).self) {
            _ = try ThemeFamily(contentsOf: missing)
        }
    }
}
