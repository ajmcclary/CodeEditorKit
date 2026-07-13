import CodeEditorSwiftUI
import DesignKitTokens
import SwiftUI

/// Style protocol for `EditorCommandPalette`, à la `ButtonStyle`.
public protocol EditorCommandPaletteStyle {
    /// View type returned from `makeBody(configuration:)`.
    associatedtype Body: View

    /// Render the palette for the given configuration. SwiftUI calls
    /// this from MainActor.
    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body

    /// Convenience alias for the configuration handed to `makeBody`.
    typealias Configuration = EditorCommandPaletteStyleConfiguration
}

/// Data + actions handed to an `EditorCommandPaletteStyle` to render with.
public struct EditorCommandPaletteStyleConfiguration {
    /// Placeholder text shown in the search field.
    public let prompt: String
    /// Bound query string the field edits.
    public let query: Binding<String>
    /// Items currently visible (post-filter).
    public let visibleItems: [CommandPaletteItem]
    /// Currently keyboard-focused item, or nil if none.
    public let highlightedID: CommandPaletteItem.ID?
    /// Update the highlighted item.
    public let onHighlight: (CommandPaletteItem.ID) -> Void
    /// Confirm the selection.
    public let onSelect: (CommandPaletteItem) -> Void

    /// Memberwise builder.
    public init(
        prompt: String,
        query: Binding<String>,
        visibleItems: [CommandPaletteItem],
        highlightedID: CommandPaletteItem.ID?,
        onHighlight: @escaping (CommandPaletteItem.ID) -> Void,
        onSelect: @escaping (CommandPaletteItem) -> Void
    ) {
        self.prompt = prompt
        self.query = query
        self.visibleItems = visibleItems
        self.highlightedID = highlightedID
        self.onHighlight = onHighlight
        self.onSelect = onSelect
    }
}

/// Default palette style — frosted-glass card with search field on top
/// and a scrolling list of `EditorCommandPaletteRow`s.
public struct DefaultEditorCommandPaletteStyle: EditorCommandPaletteStyle {
    /// Creates the default style.
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            searchField(prompt: configuration.prompt, query: configuration.query)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider().opacity(0.4)

            if configuration.visibleItems.isEmpty {
                emptyState(prompt: configuration.prompt)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(configuration.visibleItems) { item in
                            Button {
                                configuration.onSelect(item)
                            } label: {
                                EditorCommandPaletteRow(
                                    item: item,
                                    isHighlighted: item.id == configuration.highlightedID
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in
                                if isHovering {
                                    configuration.onHighlight(item.id)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .platformGlassSurface(.popover)
        .clipShape(.rect(cornerRadius: 12))
        .frame(maxWidth: 480)
    }

    @ViewBuilder
    private func searchField(prompt: String, query: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").imageScale(.medium)
            TextField(prompt, text: query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
    }

    @ViewBuilder
    private func emptyState(prompt: String) -> some View {
        VStack(spacing: 6) {
            Text("No commands match")
                .font(.system(size: 12, weight: .medium))
            Text(prompt)
                .font(.system(size: 11))
                .opacity(0.6)
        }
    }
}

extension EditorCommandPaletteStyle where Self == DefaultEditorCommandPaletteStyle {
    /// Default command-palette style.
    public static var `default`: Self { .init() }
}

// MARK: - Style installation

private struct EditorCommandPaletteStyleEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: any EditorCommandPaletteStyle = DefaultEditorCommandPaletteStyle()
}

extension EnvironmentValues {
    var editorCommandPaletteStyle: any EditorCommandPaletteStyle {
        get { self[EditorCommandPaletteStyleEnvironmentKey.self] }
        set { self[EditorCommandPaletteStyleEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Install a command palette style for `EditorCommandPalette` in this
    /// view's scope.
    public func editorCommandPaletteStyle<S: EditorCommandPaletteStyle>(_ style: S) -> some View {
        environment(\.editorCommandPaletteStyle, style)
    }
}
