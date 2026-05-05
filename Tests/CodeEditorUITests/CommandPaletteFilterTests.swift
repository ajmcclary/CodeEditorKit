@testable import CodeEditorUI
import Foundation
import Testing

@Suite("Command palette query filter")
struct CommandPaletteFilterTests {
    private let items: [CommandPaletteItem] = [
        .init(title: "Open File…", kind: .action, shortcut: "⌘O"),
        .init(title: "Open Workspace", kind: .action, shortcut: nil),
        .init(title: "Save", kind: .action, shortcut: "⌘S"),
        .init(title: "Toggle Sidebar", kind: .action, shortcut: "⌘B"),
        .init(title: "Editor: Font Size", kind: .setting, shortcut: nil)
    ]

    @Test("Empty query returns all items in order")
    func emptyQuery() {
        let result = CommandPaletteFilter.filter(items: items, query: "")
        #expect(result.map(\.title) == items.map(\.title))
    }

    @Test("Substring match is case-insensitive")
    func substringMatch() {
        let result = CommandPaletteFilter.filter(items: items, query: "open")
        #expect(result.map(\.title) == ["Open File…", "Open Workspace"])
    }

    @Test("Whitespace-only query returns all")
    func whitespaceQuery() {
        let result = CommandPaletteFilter.filter(items: items, query: "   ")
        #expect(result.count == items.count)
    }

    @Test("No match returns empty")
    func noMatch() {
        let result = CommandPaletteFilter.filter(items: items, query: "xyzzy")
        #expect(result.isEmpty)
    }
}
