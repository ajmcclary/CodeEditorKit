import CodeEditorPlugin
import Foundation
import Observation
import SwiftUI

/// Multi-tab in-memory document store for the sample app. Owns the
/// canonical `[TabModel]` consumed by `EditorTabStrip` and a per-tab
/// text dictionary. No persistence — `⌘S` is a no-op in the demo.
@MainActor
@Observable
final class DocumentStore {
    /// Tabs in display order. `EditorTabStrip` binds to a derived
    /// binding into this array.
    var tabs: [TabModel]

    /// Active tab; nil when `tabs.isEmpty`.
    var activeTabID: TabModel.ID?

    /// Per-tab text contents, keyed by `TabModel.id`.
    private var texts: [TabModel.ID: String]

    /// Counter for `Untitled-N.swift` naming.
    private var untitledCounter: Int

    /// Boot state: one empty `Untitled-1.swift` tab, active.
    init() {
        let first = TabModel(name: "Untitled-1.swift", language: .swift)
        self.tabs = [first]
        self.activeTabID = first.id
        self.texts = [first.id: ""]
        self.untitledCounter = 1
    }

    // MARK: - Tab lifecycle

    /// Append a new `Untitled-N.swift` tab and activate it.
    func newTab() {
        untitledCounter += 1
        let tab = TabModel(name: "Untitled-\(untitledCounter).swift", language: .swift)
        tabs.append(tab)
        texts[tab.id] = ""
        activeTabID = tab.id
    }

    /// Close a tab. If the closed tab was active, activate the previous
    /// tab in the list, or `nil` when the list becomes empty.
    func close(_ id: TabModel.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        texts.removeValue(forKey: id)
        if activeTabID == id {
            activeTabID = index > 0 ? tabs[index - 1].id : tabs.first?.id
        }
    }

    /// Close every tab.
    func closeAll() {
        tabs.removeAll()
        texts.removeAll()
        activeTabID = nil
    }

    /// Activate a tab by id. No-op if `id` isn't in `tabs`.
    func setActive(_ id: TabModel.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    // MARK: - Per-tab content access

    /// Text binding for a given tab id. Reads return the empty string
    /// for unknown ids. Writes mark the tab dirty when the new value
    /// differs from the previous.
    func textBinding(for id: TabModel.ID) -> Binding<String> {
        Binding(
            get: { self.texts[id] ?? "" },
            set: { newValue in
                let oldValue = self.texts[id] ?? ""
                self.texts[id] = newValue
                if oldValue != newValue,
                   let index = self.tabs.firstIndex(where: { $0.id == id }),
                   !self.tabs[index].isDirty {
                    self.tabs[index].isDirty = true
                }
            }
        )
    }

    /// Set the language of a tab in-place. No-op for unknown ids.
    func setLanguage(_ language: Language, of id: TabModel.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].language = language
    }

    /// Convenience: the language of the active tab, or nil.
    var activeLanguage: Language? {
        guard let activeTabID,
              let tab = tabs.first(where: { $0.id == activeTabID })
        else { return nil }
        return tab.language
    }
}
