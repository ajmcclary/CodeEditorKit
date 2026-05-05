import CodeEditorPlugin
import CodeEditorUI
import Foundation
import SwiftUI

/// Live builder for the command-palette item set. Returns a parallel
/// dispatch closure so the host can run the action when the user
/// confirms a row.
enum CommandPaletteCatalog {
    @MainActor
    static func build(
        theme: Binding<Theme>,
        configuration: Binding<EditorConfiguration>,
        documents: DocumentStore,
        settingsVisible: Binding<Bool>,
        inspectorVisible: Binding<Bool>
    ) -> (items: [CommandPaletteItem], dispatch: (CommandPaletteItem) -> Void) {
        var items: [CommandPaletteItem] = []
        var actions: [CommandPaletteItem.ID: () -> Void] = [:]

        for chosen in ThemeCatalog.all {
            let item = CommandPaletteItem(title: "Theme: \(chosen.name)", kind: .setting)
            actions[item.id] = { theme.wrappedValue = chosen }
            items.append(item)
        }

        for language in LanguageCatalog.all {
            let item = CommandPaletteItem(title: "Language: \(language.name)", kind: .setting)
            actions[item.id] = {
                guard let id = documents.activeTabID else { return }
                documents.setLanguage(language, of: id)
            }
            items.append(item)
        }

        for preset in PresetCatalog.all {
            let item = CommandPaletteItem(title: "Preset: \(preset.name)", kind: .setting)
            actions[item.id] = { configuration.wrappedValue = preset.configuration }
            items.append(item)
        }

        let newTab = CommandPaletteItem(title: "New Tab", kind: .action, shortcut: "⌘T")
        actions[newTab.id] = { documents.newTab() }
        items.append(newTab)

        let closeTab = CommandPaletteItem(title: "Close Tab", kind: .action, shortcut: "⌘W")
        actions[closeTab.id] = {
            if let id = documents.activeTabID { documents.close(id) }
        }
        items.append(closeTab)

        let closeAll = CommandPaletteItem(title: "Close All Tabs", kind: .action)
        actions[closeAll.id] = { documents.closeAll() }
        items.append(closeAll)

        let toggleSettings = CommandPaletteItem(title: "Toggle Settings Sidebar", kind: .action)
        actions[toggleSettings.id] = { settingsVisible.wrappedValue.toggle() }
        items.append(toggleSettings)

        let toggleInspector = CommandPaletteItem(title: "Toggle Inspector", kind: .action)
        actions[toggleInspector.id] = { inspectorVisible.wrappedValue.toggle() }
        items.append(toggleInspector)

        return (items, { picked in actions[picked.id]?() })
    }
}
