@testable import CodeEditorKit
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import CustomDump
import DesignKitThemes
import Foundation
import SnapshotTesting
import Testing

@Suite("Theme structure snapshots")
struct ThemeStyleSnapshotTests {
    @Test("dark theme style structure (CustomDump)")
    func darkStyleSnapshot() {
        let theme = Theme.dark
        assertSnapshot(of: theme.style, as: .dump)
    }
}
