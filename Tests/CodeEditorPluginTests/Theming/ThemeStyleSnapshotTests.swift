@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import CustomDump
import DesignKitThemes
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
