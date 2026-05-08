#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorCommandPaletteSnapshots: XCTestCase {
    func testEmptyQueryDark() {
        snap(theme: .dark, variant: .empty, name: "empty-dark")
    }

    func testEmptyQueryLight() {
        snap(theme: .light, variant: .empty, name: "empty-light")
    }

    func testWithQueryDark() {
        snap(theme: .dark, variant: .withQuery, name: "with-query-dark")
    }

    func testWithQueryLight() {
        snap(theme: .light, variant: .withQuery, name: "with-query-light")
    }

    func testNoResultsDark() {
        snap(theme: .dark, variant: .noResults, name: "no-results-dark")
    }

    func testNoResultsLight() {
        snap(theme: .light, variant: .noResults, name: "no-results-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    private enum Variant {
        case empty
        case withQuery
        case noResults
    }

    private static let items: [CommandPaletteItem] = [
        .init(title: "Open File…", kind: .action, shortcut: "⌘O"),
        .init(title: "Open Workspace", kind: .action, shortcut: nil),
        .init(title: "Save", kind: .action, shortcut: "⌘S"),
        .init(title: "Toggle Sidebar", kind: .action, shortcut: "⌘B"),
        .init(title: "Editor: Font Size", kind: .setting, shortcut: nil)
    ]

    private func snap(theme: ThemeChoice, variant: Variant, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let initialQuery: String
        switch variant {
        case .empty:
            initialQuery = ""

        case .withQuery:
            initialQuery = "open"

        case .noResults:
            initialQuery = "xyzzy"
        }
        let view = SnapshotSupport.framed(
            EditorCommandPalettePreviewHarness(
                items: Self.items,
                initialQuery: initialQuery
            ),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.popoverSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "EditorCommandPaletteSnapshots"
        )
    }
}

@MainActor
private struct EditorCommandPalettePreviewHarness: View {
    let items: [CommandPaletteItem]
    let initialQuery: String

    var body: some View {
        let visible = CommandPaletteFilter.filter(items: items, query: initialQuery)
        DefaultEditorCommandPaletteStyle().makeBody(
            configuration: EditorCommandPaletteStyleConfiguration(
                prompt: "Type a command…",
                query: .constant(initialQuery),
                visibleItems: visible,
                highlightedID: visible.first?.id,
                onHighlight: { _ in },
                onSelect: { _ in }
            )
        )
        .padding(16)
    }
}
#endif
