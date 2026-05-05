import CodeEditorPlugin
import SwiftUI

/// Style protocol for `EditorTabStrip`, à la `ButtonStyle`.
///
/// Implementers receive the strip's data + actions in `Configuration`
/// and return a body view. Library ships `.default` and `.compact`;
/// hosts install custom styles via `.editorTabStripStyle(_:)`.
public protocol EditorTabStripStyle {
    /// View type returned from `makeBody(configuration:)`.
    associatedtype Body: View

    /// Render the strip for the given configuration. SwiftUI calls this
    /// from MainActor; implementers may freely use MainActor-isolated APIs.
    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body

    /// Convenience alias for the configuration handed to `makeBody`.
    typealias Configuration = EditorTabStripStyleConfiguration
}

/// Data + actions handed to an `EditorTabStripStyle` to render with.
public struct EditorTabStripStyleConfiguration {
    /// Current tabs in the strip.
    public let tabs: [TabModel]
    /// Active tab's ID; nil when no tab is active.
    public let activeTabID: TabModel.ID?
    /// Activate a tab by ID.
    public let setActive: (TabModel.ID) -> Void
    /// Close a tab by ID.
    public let close: (TabModel.ID) -> Void

    /// Memberwise builder for tests/custom styles.
    public init(
        tabs: [TabModel],
        activeTabID: TabModel.ID?,
        setActive: @escaping (TabModel.ID) -> Void,
        close: @escaping (TabModel.ID) -> Void
    ) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.setActive = setActive
        self.close = close
    }
}

/// Default tab strip style — comfortable height, scroll-on-overflow,
/// dirty dot replaces close button on dirty tabs.
public struct DefaultEditorTabStripStyle: EditorTabStripStyle {
    /// Creates the default style.
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(configuration.tabs) { tab in
                    EditorTab(
                        tab: tab,
                        isActive: tab.id == configuration.activeTabID,
                        onSelect: { configuration.setActive(tab.id) },
                        onClose: { configuration.close(tab.id) }
                    )
                    Divider()
                        .frame(height: 16)
                        .opacity(0.3)
                }
            }
        }
        .frame(height: 36)
        .platformGlassSurface(.tabBar)
    }
}

/// Compact tab strip style — shorter height, no dividers.
public struct CompactEditorTabStripStyle: EditorTabStripStyle {
    /// Creates the compact style.
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(configuration.tabs) { tab in
                    EditorTab(
                        tab: tab,
                        isActive: tab.id == configuration.activeTabID,
                        onSelect: { configuration.setActive(tab.id) },
                        onClose: { configuration.close(tab.id) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 28)
        .platformGlassSurface(.tabBar)
    }
}

extension EditorTabStripStyle where Self == DefaultEditorTabStripStyle {
    /// Default tab strip style.
    public static var `default`: Self { .init() }
}

extension EditorTabStripStyle where Self == CompactEditorTabStripStyle {
    /// Compact tab strip style.
    public static var compact: Self { .init() }
}

// MARK: - Style installation

private struct EditorTabStripStyleEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: any EditorTabStripStyle = DefaultEditorTabStripStyle()
}

extension EnvironmentValues {
    var editorTabStripStyle: any EditorTabStripStyle {
        get { self[EditorTabStripStyleEnvironmentKey.self] }
        set { self[EditorTabStripStyleEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Install a tab strip style for any `EditorTabStrip` in this view's
    /// scope.
    public func editorTabStripStyle<S: EditorTabStripStyle>(_ style: S) -> some View {
        environment(\.editorTabStripStyle, style)
    }
}
