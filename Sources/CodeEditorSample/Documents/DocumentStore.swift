import CodeEditorPlugin
import Foundation
import Observation
import SwiftUI

/// Multi-tab in-memory document store for the sample app. Owns the
/// canonical `[TabModel]` consumed by `EditorTabStrip`, a per-tab text
/// dictionary, and a per-tab `EditorInteractionState` so the cursor
/// position survives tab switches. No persistence — `⌘S` is a no-op in
/// the demo.
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

    /// Per-tab interaction state (cursor positions, scroll, etc.). Empty
    /// state for an unknown id is generated on demand.
    private var interactionStates: [TabModel.ID: EditorInteractionState]

    /// Counter for `Untitled-N.swift` naming.
    private var untitledCounter: Int

    /// Boot state: one `Untitled-1.swift` tab seeded with a small Swift
    /// snippet so the syntax highlighter and theme have something to
    /// render on first launch.
    init() {
        let first = TabModel(name: "Untitled-1.swift", language: .swift)
        self.tabs = [first]
        self.activeTabID = first.id
        self.texts = [first.id: SampleCodeCatalog.text(for: .swift)]
        self.interactionStates = [:]
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
        interactionStates.removeValue(forKey: id)
        if activeTabID == id {
            activeTabID = index > 0 ? tabs[index - 1].id : tabs.first?.id
        }
    }

    /// Close every tab.
    func closeAll() {
        tabs.removeAll()
        texts.removeAll()
        interactionStates.removeAll()
        activeTabID = nil
    }

    /// Activate a tab by id. No-op if `id` isn't in `tabs`.
    func setActive(_ id: TabModel.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    /// Open a file from disk into a new tab and activate it. If a tab is
    /// already open for the same URL, activates that tab instead. Returns
    /// the tab id, or nil when the file cannot be read.
    ///
    /// Sample-internal: used by the LSP definition-jump path to surface
    /// cross-file Swift navigation results. The opened tab carries the
    /// source URL on `TabModel.url`; persistence (write-back) is out of
    /// scope for this iteration.
    @discardableResult
    func openFile(url: URL) -> TabModel.ID? {
        if let existing = tabs.first(where: { $0.url == url }) {
            activeTabID = existing.id
            return existing.id
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let language = LanguageDetectionService().detectLanguage(fromExtension: url.pathExtension)
        let tab = TabModel(
            name: url.lastPathComponent,
            url: url,
            language: language
        )
        tabs.append(tab)
        texts[tab.id] = text
        activeTabID = tab.id
        return tab.id
    }

    // MARK: - Per-tab content access

    /// Text binding for a given tab id. Reads return the empty string
    /// for unknown ids. Writes update the text only — the dirty bit is
    /// driven from `.onTextChange { markDirty(_:newText:) }` so the
    /// binding setter stays a pure write.
    func textBinding(for id: TabModel.ID) -> Binding<String> {
        Binding(
            get: { self.texts[id] ?? "" },
            set: { newValue in self.texts[id] = newValue }
        )
    }

    /// Marks `id` dirty if `newText` differs from the previously stored
    /// content. Called from the editor's `.onTextChange { … }` modifier
    /// after the SwiftUI binding has already absorbed the write.
    func markDirty(_ id: TabModel.ID, newText: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }),
              !tabs[index].isDirty,
              texts[id] != nil else { return }
        // `texts[id]` is the new value (writes ran first via the binding
        // setter). We treat any change at all as dirty.
        if !newText.isEmpty || tabs[index].name.hasPrefix("Untitled") {
            tabs[index].isDirty = true
        }
    }

    /// Per-tab interaction-state binding. Reads return the stored value
    /// (or a fresh default), writes update the per-tab slot. Used to
    /// preserve cursor positions across tab switches.
    func interactionBinding(for id: TabModel.ID) -> Binding<EditorInteractionState> {
        Binding(
            get: { self.interactionStates[id] ?? EditorInteractionState() },
            set: { self.interactionStates[id] = $0 }
        )
    }

    /// Set the language of a tab without touching its contents. Use this
    /// when the user picks a language from the sidebar — they expect
    /// their edits to survive the switch.
    func setLanguage(_ language: Language, of id: TabModel.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].language = language
        tabs[index].name = Self.renamedTab(tabs[index].name, for: language)
    }

    /// Replace the active tab's text with the canonical sample snippet
    /// for `language` and switch the tab's language to match. Destructive
    /// — wipes the dirty bit and clears any prior content. Use this for
    /// "Sample: X" command-palette entries, not for plain language picks.
    func resetToSample(_ language: Language, of id: TabModel.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].language = language
        tabs[index].name = Self.renamedTab(tabs[index].name, for: language)
        tabs[index].isDirty = false
        texts[id] = SampleCodeCatalog.text(for: language)
        interactionStates[id] = EditorInteractionState()
    }

    /// Replace the file extension on a tab name with the language's
    /// primary extension. `MyFile.swift` + `.python` → `MyFile.py`;
    /// `Untitled` + `.go` → `Untitled.go`.
    private static func renamedTab(_ name: String, for language: Language) -> String {
        let basename: String = {
            // Strip the trailing extension (everything after the last dot),
            // unless the name has no dot or starts with one (`.gitignore`).
            if let dot = name.lastIndex(of: "."), dot != name.startIndex {
                return String(name[..<dot])
            }
            return name
        }()
        let ext = language.fileExtensions.first ?? "txt"
        return "\(basename).\(ext)"
    }

    /// Convenience: the language of the active tab, or nil.
    var activeLanguage: Language? {
        guard let activeTabID,
              let tab = tabs.first(where: { $0.id == activeTabID })
        else { return nil }
        return tab.language
    }
}
