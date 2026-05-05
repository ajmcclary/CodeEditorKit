@testable import CodeEditorPlugin
import CustomDump
import Foundation
import SnapshotTesting
import Testing

@Suite("Theme structure snapshots")
struct ThemeStyleSnapshotTests {
    @Test("LCARS Dark style structure (CustomDump)")
    func lcarsDarkStyleSnapshot() {
        let theme = Theme.lcarsDark
        assertSnapshot(of: theme.style, as: .dump)
    }
}
