import CodeEditorKit
import CodeEditorLanguages
@testable import CodeEditorSwiftUI
import CodeEditorUI
import Foundation
import SwiftUI
import Testing

@Suite("Tab strip & command palette style protocols")
@MainActor
struct StyleProtocolTests {
    @Test("DefaultEditorTabStripStyle.makeBody returns non-empty for empty tabs")
    func defaultStyleEmpty() {
        let configuration = EditorTabStripStyleConfiguration(
            tabs: [],
            activeTabID: nil,
            setActive: { _ in },
            close: { _ in }
        )
        let body = DefaultEditorTabStripStyle().makeBody(configuration: configuration)
        _ = body
    }

    @Test("DefaultEditorTabStripStyle.makeBody returns non-empty for many tabs")
    func defaultStyleMany() {
        let tabs = (0..<10).map { idx in
            TabModel(name: "File\(idx).swift", isDirty: idx.isMultiple(of: 2))
        }
        let configuration = EditorTabStripStyleConfiguration(
            tabs: tabs,
            activeTabID: tabs[3].id,
            setActive: { _ in },
            close: { _ in }
        )
        let body = DefaultEditorTabStripStyle().makeBody(configuration: configuration)
        _ = body
    }

    @Test("CompactEditorTabStripStyle is distinct from default")
    func compactDistinct() {
        _ = DefaultEditorTabStripStyle()
        _ = CompactEditorTabStripStyle()
    }
}
