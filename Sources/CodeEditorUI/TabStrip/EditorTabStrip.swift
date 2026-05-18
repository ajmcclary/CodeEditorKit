import CodeEditorLanguages
import CodeEditorPlugin
import CodeEditorSwiftUI
import SwiftUI

/// File-tab strip. Reads its style from `\.editorTabStripStyle` (default
/// is `DefaultEditorTabStripStyle`); hosts override via
/// `.editorTabStripStyle(_:)`.
///
/// Tabs and active selection are passed via `Binding`s — typically
/// `Binding<[TabModel]>(get: { state.tabs }, set: { state.tabs = $0 })`,
/// but any host model that produces those bindings works.
public struct EditorTabStrip: View {
    @Environment(\.editorTabStripStyle) private var style

    @Binding private var tabs: [TabModel]
    @Binding private var activeTabID: TabModel.ID?
    private let onClose: ((TabModel.ID) -> Void)?

    /// Creates a tab strip.
    /// - Parameters:
    ///   - tabs: bound array of tabs; mutate to reorder/insert/remove.
    ///   - activeTabID: bound active-tab id; mutate to switch foreground.
    ///   - onClose: extra close hook fired in addition to default
    ///     "remove from `tabs`" behavior. nil means "default behavior only."
    public init(
        tabs: Binding<[TabModel]>,
        activeTabID: Binding<TabModel.ID?>,
        onClose: ((TabModel.ID) -> Void)? = nil
    ) {
        self._tabs = tabs
        self._activeTabID = activeTabID
        self.onClose = onClose
    }

    public var body: some View {
        let configuration = EditorTabStripStyleConfiguration(
            tabs: tabs,
            activeTabID: activeTabID,
            setActive: { id in activeTabID = id },
            close: { id in
                onClose?(id)
                if let index = tabs.firstIndex(where: { $0.id == id }) {
                    tabs.remove(at: index)
                    if activeTabID == id { activeTabID = tabs.first?.id }
                }
            }
        )
        AnyView(style.makeBody(configuration: configuration))
    }
}
