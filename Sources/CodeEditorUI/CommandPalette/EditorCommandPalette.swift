import CodeEditorSwiftUI
import DesignKitTokens
import SwiftUI

/// Opinionated command-palette view. Pass `Binding<Bool>` to control
/// presentation, `[CommandPaletteItem]` for the static command set, and
/// an `onSelect` callback for the picked item.
///
/// Hosts wire the keyboard shortcut themselves (e.g., `.keyboardShortcut`
/// on a button or window-toolbar item) — the palette stays neutral on
/// `⌘P` vs `⌘⇧P`. Internal handling responds to `Esc` (dismiss),
/// `↑/↓` (move highlight), `Return` (select highlighted).
public struct EditorCommandPalette: View {
    @Environment(\.editorCommandPaletteStyle) private var style

    @Binding private var isPresented: Bool
    @State private var query: String = ""
    @State private var highlightedID: CommandPaletteItem.ID?

    private let items: [CommandPaletteItem]
    private let onSelect: (CommandPaletteItem) -> Void
    private let prompt: String

    /// Creates a command palette.
    /// - Parameters:
    ///   - isPresented: bound visibility flag — host toggles to show/hide.
    ///   - items: full command set; the palette filters by query at render.
    ///   - onSelect: invoked when the user confirms an item.
    ///   - prompt: placeholder text for the search field.
    public init(
        isPresented: Binding<Bool>,
        items: [CommandPaletteItem],
        onSelect: @escaping (CommandPaletteItem) -> Void,
        prompt: String = "Type a command…"
    ) {
        self._isPresented = isPresented
        self.items = items
        self.onSelect = onSelect
        self.prompt = prompt
    }

    public var body: some View {
        if isPresented {
            paletteBody
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .background(KeyboardCommands(
                    onEscape: { isPresented = false; query = "" },
                    onArrowUp: { moveHighlight(by: -1) },
                    onArrowDown: { moveHighlight(by: +1) },
                    onReturn: confirmHighlighted
                ))
        } else {
            EmptyView()
        }
    }

    private var paletteBody: some View {
        let visible = CommandPaletteFilter.filter(items: items, query: query)
        let resolved = highlightedID ?? visible.first?.id
        return AnyView(
            style.makeBody(
                configuration: EditorCommandPaletteStyleConfiguration(
                    prompt: prompt,
                    query: $query,
                    visibleItems: visible,
                    highlightedID: resolved,
                    onHighlight: { id in highlightedID = id },
                    onSelect: { item in
                        isPresented = false
                        query = ""
                        onSelect(item)
                    }
                )
            )
        )
    }

    private func moveHighlight(by delta: Int) {
        let visible = CommandPaletteFilter.filter(items: items, query: query)
        guard !visible.isEmpty else { return }
        let currentID = highlightedID ?? visible.first?.id
        guard let currentIndex = visible.firstIndex(where: { $0.id == currentID }) else {
            highlightedID = visible.first?.id
            return
        }
        let nextIndex = clamped(currentIndex + delta, to: 0...(visible.count - 1))
        highlightedID = visible[nextIndex].id
    }

    private func confirmHighlighted() {
        let visible = CommandPaletteFilter.filter(items: items, query: query)
        let id = highlightedID ?? visible.first?.id
        guard let id, let item = visible.first(where: { $0.id == id }) else { return }
        isPresented = false
        query = ""
        onSelect(item)
    }
}

// MARK: - Helpers

private func clamped<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
    min(max(value, range.lowerBound), range.upperBound)
}

private struct KeyboardCommands: View {
    let onEscape: () -> Void
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onReturn: () -> Void

    var body: some View {
        Color.clear
            .focusable()
            .onKeyPress(.escape) { onEscape(); return .handled }
            .onKeyPress(.upArrow) { onArrowUp(); return .handled }
            .onKeyPress(.downArrow) { onArrowDown(); return .handled }
            .onKeyPress(.return) { onReturn(); return .handled }
    }
}
