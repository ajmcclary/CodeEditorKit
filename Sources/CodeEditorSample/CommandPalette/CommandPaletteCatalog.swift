import CodeEditorPlugin
import CodeEditorUI
import Foundation
import SwiftUI

/// Live builder for the command-palette item set. Returns a parallel
/// dispatch closure so the host can run the action when the user
/// confirms a row.
enum CommandPaletteCatalog {
    // swiftlint:disable:next function_body_length
    @MainActor
    static func build(
        appState: AppState,
        workspaceVisible: Binding<Bool>,
        inspectorVisible: Binding<Bool>
    ) -> (items: [CommandPaletteItem], dispatch: (CommandPaletteItem) -> Void) {
        var items: [CommandPaletteItem] = []
        var actions: [CommandPaletteItem.ID: () -> Void] = [:]

        for chosen in ThemeCatalog.all {
            let item = CommandPaletteItem(title: "Theme: \(chosen.name)", kind: .setting)
            actions[item.id] = { appState.theme = chosen }
            items.append(item)
        }

        for language in LanguageCatalog.all {
            // "Language: X" preserves the buffer — switches highlighter only.
            let setLanguage = CommandPaletteItem(title: "Language: \(language.name)", kind: .setting)
            actions[setLanguage.id] = {
                guard let id = appState.documents.activeID else { return }
                appState.documents.setLanguageRenaming(language, of: id)
            }
            items.append(setLanguage)

            // "Sample: X" is destructive — replaces the buffer with the
            // canonical demo snippet for that language.
            let resetSample = CommandPaletteItem(title: "Sample: \(language.name)", kind: .setting)
            actions[resetSample.id] = {
                guard let id = appState.documents.activeID else { return }
                appState.documents.resetToSample(language, of: id)
            }
            items.append(resetSample)
        }

        for preset in PresetCatalog.all {
            // "Preset: X" merges display/behavior/layout onto the current
            // configuration, preserving the user's tuned performance knobs.
            let apply = CommandPaletteItem(title: "Preset: \(preset.name)", kind: .setting)
            actions[apply.id] = {
                appState.configuration = PresetCatalog.apply(preset, onto: appState.configuration)
            }
            items.append(apply)

            // "Reset to preset: X" is the destructive wholesale-replace
            // variant — kept separate so the merge above stays safe to
            // explore without clobbering the user's tuning.
            let reset = CommandPaletteItem(title: "Reset to preset: \(preset.name)", kind: .setting)
            actions[reset.id] = { appState.configuration = preset.configuration }
            items.append(reset)
        }

        appendDocumentActions(into: &items, actions: &actions, appState: appState)
        appendSidebarActions(
            into: &items,
            actions: &actions,
            workspaceVisible: workspaceVisible,
            inspectorVisible: inspectorVisible
        )
        appendFindActions(into: &items, actions: &actions, appState: appState)
        appendNavigationActions(into: &items, actions: &actions, appState: appState)
        appendFoldingActions(into: &items, actions: &actions, appState: appState)
        appendAnnotationActions(into: &items, actions: &actions, appState: appState)

        return (items, { picked in actions[picked.id]?() })
    }

    // MARK: - Section helpers

    @MainActor
    private static func appendDocumentActions(
        into items: inout [CommandPaletteItem],
        actions: inout [CommandPaletteItem.ID: () -> Void],
        appState: AppState
    ) {
        let newTab = CommandPaletteItem(title: "New Tab", kind: .action, shortcut: "⌘T")
        actions[newTab.id] = { appState.documents.newTab() }
        items.append(newTab)

        let closeTab = CommandPaletteItem(title: "Close Tab", kind: .action, shortcut: "⌘W")
        actions[closeTab.id] = {
            if let id = appState.documents.activeID { appState.documents.close(id) }
        }
        items.append(closeTab)

        let closeAll = CommandPaletteItem(title: "Close All Tabs", kind: .action)
        actions[closeAll.id] = { appState.documents.closeAll() }
        items.append(closeAll)
    }

    @MainActor
    private static func appendSidebarActions(
        into items: inout [CommandPaletteItem],
        actions: inout [CommandPaletteItem.ID: () -> Void],
        workspaceVisible: Binding<Bool>,
        inspectorVisible: Binding<Bool>
    ) {
        let toggleWorkspace = CommandPaletteItem(title: "Toggle Workspace Sidebar", kind: .action)
        actions[toggleWorkspace.id] = { workspaceVisible.wrappedValue.toggle() }
        items.append(toggleWorkspace)

        let toggleInspector = CommandPaletteItem(title: "Toggle Inspector", kind: .action)
        actions[toggleInspector.id] = { inspectorVisible.wrappedValue.toggle() }
        items.append(toggleInspector)
    }

    @MainActor
    private static func appendFindActions(
        into items: inout [CommandPaletteItem],
        actions: inout [CommandPaletteItem.ID: () -> Void],
        appState: AppState
    ) {
        // Single entry covers both Find and Replace — the overlay exposes
        // both rows, so two palette entries that both just toggle it on
        // were redundant.
        let openOverlay = CommandPaletteItem(title: "Find / Replace…", kind: .action, shortcut: "⌘F")
        actions[openOverlay.id] = { appState.findOverlayVisible = true }
        items.append(openOverlay)

        let findNext = CommandPaletteItem(title: "Find Next", kind: .action)
        actions[findNext.id] = { _ = appState.editorController.findNext() }
        items.append(findNext)

        let findPrev = CommandPaletteItem(title: "Find Previous", kind: .action)
        actions[findPrev.id] = { _ = appState.editorController.findPrevious() }
        items.append(findPrev)
    }

    @MainActor
    private static func appendNavigationActions(
        into items: inout [CommandPaletteItem],
        actions: inout [CommandPaletteItem.ID: () -> Void],
        appState: AppState
    ) {
        let gotoLine = CommandPaletteItem(title: "Go to Line…", kind: .action, shortcut: "⌘L")
        actions[gotoLine.id] = { appState.gotoLineSheetVisible = true }
        items.append(gotoLine)

        let gotoSymbol = CommandPaletteItem(title: "Go to Symbol…", kind: .action, shortcut: "⌘⇧O")
        actions[gotoSymbol.id] = {
            appState.editorController.refreshSymbols()
            appState.gotoSymbolSheetVisible = true
        }
        items.append(gotoSymbol)
    }

    @MainActor
    private static func appendFoldingActions(
        into items: inout [CommandPaletteItem],
        actions: inout [CommandPaletteItem.ID: () -> Void],
        appState: AppState
    ) {
        let foldAll = CommandPaletteItem(title: "Fold All", kind: .action)
        actions[foldAll.id] = { appState.editorController.foldAll() }
        items.append(foldAll)

        let unfoldAll = CommandPaletteItem(title: "Unfold All", kind: .action)
        actions[unfoldAll.id] = { appState.editorController.unfoldAll() }
        items.append(unfoldAll)

        let toggleFold = CommandPaletteItem(title: "Toggle Fold at Cursor", kind: .action)
        actions[toggleFold.id] = {
            if let line = appState.editorController.currentLineNumber {
                appState.editorController.toggleFold(atLine: line)
            }
        }
        items.append(toggleFold)
    }

    @MainActor
    private static func appendAnnotationActions(
        into items: inout [CommandPaletteItem],
        actions: inout [CommandPaletteItem.ID: () -> Void],
        appState: AppState
    ) {
        let addTodo = CommandPaletteItem(title: "Add TODO at Cursor", kind: .action)
        actions[addTodo.id] = { addAnnotation(.todo, appState: appState) }
        items.append(addTodo)

        let addFixme = CommandPaletteItem(title: "Add FIXME at Cursor", kind: .action)
        actions[addFixme.id] = { addAnnotation(.fixme, appState: appState) }
        items.append(addFixme)

        let clearDemo = CommandPaletteItem(title: "Clear Demo Annotations", kind: .action)
        actions[clearDemo.id] = { appState.annotationsHub.clearAllDemoAnnotations() }
        items.append(clearDemo)

        let toggleBp = CommandPaletteItem(title: "Toggle Breakpoint at Cursor", kind: .action)
        actions[toggleBp.id] = {
            if let line = appState.editorController.currentLineNumber {
                appState.annotationsHub.toggleBreakpoint(at: line)
            }
        }
        items.append(toggleBp)

        let clearBp = CommandPaletteItem(title: "Clear All Breakpoints", kind: .action)
        actions[clearBp.id] = { appState.annotationsHub.clearAllBreakpoints() }
        items.append(clearBp)
    }

    @MainActor
    private static func addAnnotation(_ kind: AnnotationKind, appState: AppState) {
        guard let line = appState.editorController.currentLineNumber else { return }
        appState.annotationsHub.addDemoAnnotation(kind: kind, at: line)
    }
}
