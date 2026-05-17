@testable import CodeEditorPlugin
@testable import CodeEditorTheming
import CustomDump
import Foundation
import Testing

@Suite("Theme encode/decode roundtrip")
struct ThemeRoundtripTests {
    @Test("encode + decode of every bundled variant returns an equal Theme")
    func bundledRoundtripEqual() throws {
        let family = try #require(ThemeFamily.bundled("zed-trek"))
        for theme in family.themes {
            let encoded = try JSONEncoder().encode(theme)
            let decoder = JSONDecoder()
            decoder.userInfo[.themeWarnings] = WarningCollector()
            let decoded = try decoder.decode(Theme.self, from: encoded)
            expectNoDifference(decoded, theme)
        }
    }
}
