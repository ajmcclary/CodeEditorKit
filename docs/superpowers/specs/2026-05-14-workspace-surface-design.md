# Workspace Surface — Design

**Status:** Approved, ready for implementation plan.
**Date:** 2026-05-14
**Closes (partial):** NEXT.md A.1 ("Workspace search", "File tree / workspace browser", "`CodeEditorUI` components underused"), A.3 #8 (`SettingsScene` migration), A.3 #9 (no — that's a follow-up).

## Problem

The sample exposes `workspaceRoot` and the framework ships `MacOSWorkspaceFileManager`, `PortableProjectSearchAdapter`, and `ProjectSearchProvider`, but nothing in the sample renders a workspace. Find/replace is single-file only. The left rail is a `SettingsSidebar` that duplicates what `⌘,` should host. The `EditorSidebarShell` from `CodeEditorUI` is exercised twice (Settings + Inspector) but never with workspace content. A consumer reading the sample cannot see how to plug the workspace APIs into a real UI.

This spec adds a workspace surface (file tree + project search) to the sample and migrates the inline settings to `SettingsScene` (`⌘,`). It is macOS-only by design — iOS coverage is tracked separately.

## Goals

- A left-rail workspace surface with a segmented Files / Search switcher, hosted in `EditorSidebarShell`.
- A real file tree backed by `MacOSWorkspaceFileManager`, with lazy disclosure and incremental updates from `WorkspaceFileWatching.events`.
- A real project search backed by `PortableProjectSearchAdapter`, exposing case-sensitive, regex, and file-extension controls.
- Smart tab routing for both surfaces: clicking a file or a search result reuses an existing tab when one is open and jumps to the matched range when applicable.
- `File ▸ Open Folder…` command (`⇧⌘O`), empty-state button, and footer button that all call into a shared `NSOpenPanel` helper.
- Migrate the existing `SettingsSidebar` into `SettingsScene` so `⌘,` hosts global settings; the new left rail is dedicated to workspace.

## Non-goals

- iOS workspace surface. iOS's existing Inspectors detail gets a corrected copy noting workspace browsing is macOS-only in the current sample. A future spec adds the iOS variant.
- `.gitignore` parsing. Ignore rules are a static built-in list (dotfiles + `.git`, `.build`, `.swiftpm`, `node_modules`, `DerivedData`, `__Snapshots__`, plus a small binary-extension deny-list for search indexing).
- Persistent workspace root across launches. `NSOpenPanel` returns a URL; `AppState.workspaceRoot` holds it for the session. No security-scoped bookmarks, no `NSDocumentController` recents.
- Reindexing on file events. The project search index rebuilds only on root change or via an explicit "Reindex" button. File-tree events do not poke the search index.
- `⌘O` (open file). Tracked separately under A.1's Save-As / open work.
- Framework API changes beyond a single small additive method (`EditorController.selectRange(_:scroll:)`) that exposes already-existing internal behavior used by `gotoSymbol`. Everything else — `WorkspaceFileTree`, `WorkspaceFileWatching`, `ProjectSearchProvider`, `PortableProjectSearchAdapter`, `EditorController.gotoLine`, `EditorController.nsLocation(forLSPLine:character:)`, `EditorDocuments.openFile` — is already public.
- `A.3 #9` (extract a cross-platform `EditorWorkspaceScene` view). Out of scope.

## Approach

Two new `@Observable` models live in the sample target — `WorkspaceModel` (tree + watching) and `ProjectSearchModel` (search + indexing). A new `WorkspaceSidebar` view wraps `EditorSidebarShell` and segments between `FilePanelView` and `ProjectSearchPanelView`. `SettingsSidebar.swift` is deleted; its form lifts into a rewritten `SettingsScene.swift` that the `Settings { … }` scene opens via `⌘,`. `WindowBody.swift` swaps `SettingsSidebar` for `WorkspaceSidebar` on the left rail. `RootWindow.swift` gains a `CommandGroup` with `Open Folder…` (`⇧⌘O`).

`AppState.workspaceRoot` remains the single source of truth. Both models observe it via an `.onChange` on `WorkspaceSidebar` host. The existing `WorkspaceKnobsSection` and the new menu command both write to the same `AppState.workspaceRoot` property. The NSOpenPanel logic currently inside `WorkspaceKnobsSection` is lifted into a reusable `WorkspacePicker` helper consumed by the section, the empty-state button, the footer button, and the menu command.

## File layout

```
Sources/CodeEditorPlugin/SwiftUI/
└── EditorController.swift                            + public func selectRange(_:scroll:) (additive)

Sources/CodeEditorSample/Workspace/                  (new directory)
├── WorkspaceModel.swift                              @Observable: tree state + WorkspaceFileWatching subscription
├── ProjectSearchModel.swift                          @Observable: search state + PortableProjectSearchAdapter
├── WorkspaceIgnoreRules.swift                        Static lists: dir ignores + binary-extension deny-list
├── WorkspacePicker.swift                             macOS NSOpenPanel helper (lifted from WorkspaceKnobsSection)
├── WorkspaceSidebar.swift                            EditorSidebarShell host + segmented Files/Search
├── FilePanelView.swift                               Lazy disclosure tree + empty + error states + footer
├── ProjectSearchPanelView.swift                      Header (query + 3 toggles + ext filter) + grouped results
└── EditorController+SelectMatch.swift                Sample-side helper: selectMatch(_:in:)

Sources/CodeEditorSample/Scenes/
└── SettingsScene.swift                               Rewritten: hosts the former SettingsSidebar form

Sources/CodeEditorSample/App/
└── AppState.swift                                    + workspaceModel; + projectSearchModel

Sources/CodeEditorSample/Windows/
├── RootWindow.swift                                  + .commands { Open Folder… (⇧⌘O) }; + Settings { SettingsView() }
└── WindowBody.swift                                  SettingsSidebar removed; WorkspaceSidebar added on the left

Sources/CodeEditorSample/iOS/
└── IOSRootView.swift                                 Inspectors detail copy updated (macOS-only note)

Sources/CodeEditorSample/Sidebar/
└── SettingsSidebar.swift                             Deleted; shared subviews relocate to KnobPanels/ if reused

Sources/CodeEditorSample/KnobPanels/
└── WorkspaceKnobsSection.swift                       NSOpenPanel logic removed; calls WorkspacePicker

Tests/CodeEditorSampleTests/
├── WorkspaceModelTests.swift                         Stub WorkspaceFileTree + AsyncStream
├── ProjectSearchModelTests.swift                     Stub ProjectSearchProvider
├── EditorControllerSelectMatchTests.swift            Text fixtures
└── Snapshots/
    └── WorkspaceSidebarSnapshots.swift               Five baselines
```

## Models

### `WorkspaceModel`

```swift
@MainActor
@Observable
final class WorkspaceModel {
    private(set) var rootURL: URL?
    private(set) var rootNode: WorkspaceFileNode?
    private(set) var childrenByURL: [URL: [WorkspaceFileNode]] = [:]
    var expandedDirectoryURLs: Set<URL> = []
    var selectedFileURL: URL?
    private(set) var loadError: Error?

    private var fileManager: (WorkspaceFileTree & WorkspaceFileWatching)?
    private var watchTask: Task<Void, Never>?
    private let factory: (URL) -> (WorkspaceFileTree & WorkspaceFileWatching)

    init(
        factory: @escaping (URL) -> (WorkspaceFileTree & WorkspaceFileWatching) =
            { url in MacOSWorkspaceFileManager(rootURL: url) }
    )

    func setRoot(_ url: URL?)
    func toggleExpanded(_ url: URL) async
    func refresh(directory url: URL) async
    func filteredChildren(of url: URL) -> [WorkspaceFileNode]
}
```

Behavior:

- `setRoot` cancels `watchTask`, swaps the file manager (via `factory`), primes `rootNode` + the root's filtered children, seeds `expandedDirectoryURLs` with the root, and starts a new `watchTask` that does `for await event in fileManager.events`.
- Event handling is **incremental**: `.created` and `.deleted` mutate only the parent directory's entry in `childrenByURL`; `.modified` is ignored for the tree; `.renamed` removes the old entry and inserts the new. Off-root paths are dropped silently.
- `WorkspaceIgnoreRules.shouldHide(_:)` is applied at `filteredChildren(of:)` time so toggling rules (future) is cheap.
- `loadError` surfaces transient enumeration failures so the panel can render an inline error row.

### `ProjectSearchModel`

```swift
@MainActor
@Observable
final class ProjectSearchModel {
    var query: String = ""
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var extensionFilter: String = ""
    private(set) var results: [ProjectSearchResult] = []
    private(set) var status: Status = .idle
    private(set) var indexedFileCount: Int = 0

    enum Status: Equatable {
        case idle
        case indexing
        case searching
        case ready
        case results(matchCount: Int, fileCount: Int)
        case noMatches
        case error(message: String)
    }

    private let adapter: ProjectSearchProvider
    private var indexTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var indexedRoot: URL?

    init(adapter: ProjectSearchProvider = PortableProjectSearchAdapter())

    func setRoot(_ url: URL?) async
    func runSearch() async
    func cancel()
    func clear()
    func reindex() async
}
```

Behavior:

- `setRoot` cancels both tasks; if non-nil, enumerates files via `FileManager.contentsOfDirectory(at:..., options:.skipsHiddenFiles)` recursively, applies `WorkspaceIgnoreRules.shouldHide(_:)` and the binary-extension deny-list, then `adapter.indexFiles(urls:)`. Status: `idle → indexing → ready`.
- `runSearch` is called by the view on `query`, `caseSensitive`, `useRegex`, or `extensionFilter` change. It calls `adapter.cancelSearch()` then `adapter.search(query:options:)`. Empty `query` → `clear()`. Single in-flight search; new invocations cancel the prior task.
- Debouncing: 250 ms on the query field; toggle changes fire immediately.
- `extensionFilter` parsing: split on comma/whitespace, trim leading `.`, lowercase. Empty list → no extension filter.
- Regex errors surface via `.error(message:)`. The search header renders an inline warning row above the results list (no modal).
- File-tree events do **not** trigger reindexing. Reindex happens only on root change or via the explicit "Reindex" button.

## Views

### `WorkspaceSidebar`

Wraps `EditorSidebarShell(sectionTitle: tab.rawValue)`. Inside the shell's `content`, a segmented `Picker("", selection: $tab)` switches between `FilePanelView` and `ProjectSearchPanelView`. Width: `minWidth: 240, idealWidth: 280, maxWidth: 360` to match the existing `InspectorSidebar` band.

The host owns the `.onChange(of: appState.workspaceRoot)` glue:

```swift
.onChange(of: appState.workspaceRoot) { _, newValue in
    appState.workspaceModel.setRoot(newValue)
    Task { await appState.projectSearchModel.setRoot(newValue) }
}
```

### `FilePanelView`

Three states:

1. **No root** — `ContentUnavailableView("No folder open", systemImage: "folder.badge.questionmark", description: …)` with a primary "Open Folder…" button calling `WorkspacePicker.choose { appState.workspaceRoot = $0 }`.
2. **Loaded** — `List` with `OutlineGroup` rooted on `workspace.rootNode`, children supplied by `workspace.filteredChildren(of:)`. File rows: tap → `appState.documents.openFile(url:)` (already de-dupes). Folder rows: tap → `Task { await workspace.toggleExpanded(node.url) }`. `expandedDirectoryURLs` drives disclosure state so it persists across re-renders. Sort: directories first, then alpha by name.
3. **Error** — inline row with `exclamationmark.triangle.fill` and `workspace.loadError?.localizedDescription`; folder still expandable to retry.

Footer (inside the content area, below the list): current root path (truncated middle), "Reload" button, "Open Folder…" button.

### `ProjectSearchPanelView`

Header:

- `TextField("Search workspace…", text: $search.query)` with submit/clear; 250 ms debounce on `.onChange(of: query)`.
- Three compact toggles: `Aa` (caseSensitive), `.*` (useRegex), and a `TextField("ext: swift, md", text: $search.extensionFilter)` for the extension filter.
- Toggle changes call `Task { await search.runSearch() }` immediately; the query field debounces.
- Status line (`.caption2`): `"\(matchCount) matches in \(fileCount) files"` / `"Searching…"` / `"Indexing \(indexedFileCount) files"` / `"No matches"` / inline error text.

Results list:

- `List` grouped by `result.fileURL`. Section header is the relative path from `workspace.rootURL` (path components limited to 3 with leading `…`), tappable to open the file at line 1.
- Per-result row: monospaced right-aligned line number + single-line `result.contextLine` preview with the matched substring highlighted via `AttributedString` ranges from `(column, matchedText.utf16.count)`.
- Row tap → `appState.documents.openFile(url: result.fileURL)`, then `appState.editorController.selectMatch(result)`.

### `SettingsScene` (rewrite)

A new `SettingsScene` SwiftUI `View` (declared in `SettingsScene.swift`) hosts a `Form` (or `ScrollView` mirroring the current `SettingsSidebar`) containing the same `KnobSection`s the inline sidebar previously hosted — Theme, Presets, Display, Layout, Behavior, Performance, Workspace. The form binds straight to `AppState.configuration` (via `@Bindable`) and `AppState.theme`. The app's `Scene` body adds `Settings { SettingsScene() }` alongside its `WindowGroup` so `⌘,` invokes it natively.

## Glue

### `AppState`

```swift
@Observable final class AppState {
    // existing fields …
    var workspaceRoot: URL?
    let workspaceModel = WorkspaceModel()
    let projectSearchModel = ProjectSearchModel()

    init() {
        // existing wiring …
        workspaceModel.setRoot(workspaceRoot)
        Task { await projectSearchModel.setRoot(workspaceRoot) }
    }
}
```

### Framework addition: `EditorController.selectRange(_:scroll:)`

```swift
extension EditorController {
    /// Selects `range` in the attached view and (optionally) scrolls it into view.
    /// No-op when no view is attached. The select+scroll behavior already exists
    /// inside `gotoSymbol(_:)`; this method exposes the same primitive without
    /// requiring a `DocumentSymbol`.
    public func selectRange(_ range: NSRange, scroll: Bool = true)
}
```

Single small additive method. Implemented against the attached `CodeEditorView` using the same calls `gotoSymbol(_:)` already makes internally (`setSelectedRangeWithoutScrolling` + `scrollToVisible(_:)`). No new public types.

### Sample-side controller helper

```swift
extension EditorController {
    /// Routes a project-search hit into the editor: computes the NSRange from
    /// (lineNumber, column, matchedText length), selects it, and scrolls it
    /// into view. Returns false when the document doesn't contain the indexed
    /// position (e.g., the file changed since indexing).
    @discardableResult
    func selectMatch(_ result: ProjectSearchResult) -> Bool
}
```

`ProjectSearchResult.lineNumber` / `.column` are 1-based; the framework's `nsLocation(forLSPLine:character:)` is 0-based, so the helper subtracts 1 from each. NSRange length = `result.matchedText.utf16.count`. Calls `selectRange(_:scroll:)` and returns `false` silently when `nsLocation` returns `nil` (file still opens at line 1).

### `RootWindow` commands

```swift
.commands {
    CommandGroup(after: .newItem) {
        Button("Open Folder…") { WorkspacePicker.choose { appState.workspaceRoot = $0 } }
            .keyboardShortcut("o", modifiers: [.command, .shift])
    }
}
```

`Settings { SettingsScene() }` is added alongside `WindowGroup` so `⌘,` opens the new settings UI.

### `WindowBody`

```swift
HStack(spacing: 0) {
    WorkspaceSidebar(workspace: appState.workspaceModel, search: appState.projectSearchModel)
        .onChange(of: appState.workspaceRoot) { _, newValue in
            appState.workspaceModel.setRoot(newValue)
            Task { await appState.projectSearchModel.setRoot(newValue) }
        }
    Divider()
    editorPane              // unchanged
    if inspectorVisible { InspectorSidebar(…) }
}
```

`SettingsSidebar.swift` is deleted. The boolean toggle that controlled `settingsVisible` is repurposed for `WorkspaceSidebar` visibility (default: always-visible).

### iOS

`IOSRootView.swift`'s Inspectors detail copy is updated to note that workspace browsing and project search are macOS-only in the current sample. No new iOS sections.

## Error handling

| Condition | Behavior |
|---|---|
| Workspace root deleted out-of-band | `.deleted` event clears `rootNode`; empty state shown. Search results kept until next `setRoot`. |
| Permission denied during enumeration | `WorkspaceModel.loadError` populated; inline error row. Search walk skips affected subtrees, no fatal error. |
| Regex compile failure | `ProjectSearchModel.status = .error(message: …)`; inline warning row above results. |
| Document outpaced by index | `selectMatch` returns `false`; file still opens at line 1. |
| `NSOpenPanel` cancelled | Returns without changing `workspaceRoot`. |
| Sandboxed URL persistence | Out of scope. Re-launch starts with `workspaceRoot == nil`. |
| In-flight indexing during root change | `setRoot` cancels prior `indexTask` and `searchTask`. |

## Testing

**Unit tests:**

- `WorkspaceModelTests` — stub `WorkspaceFileTree & WorkspaceFileWatching` with hand-fed `AsyncStream<WorkspaceFileEvent>`:
  - Ignore rules suppress the documented set
  - `.created` / `.deleted` / `.renamed` produce the expected mutations
  - `setRoot(nil)` clears state and cancels the watch task
  - `toggleExpanded` populates `childrenByURL` exactly once per directory
- `ProjectSearchModelTests` — stub `ProjectSearchProvider`:
  - Empty query clears results without calling `search`
  - Toggle change triggers a fresh search and cancels the prior task
  - Adapter error → `.error(message:)`
  - Extension filter parsing covers comma / whitespace / leading-dot
- `EditorControllerSelectMatchTests` (sample target) — text fixtures confirm out-of-range gracefully returns `false`; in-range produces the expected selection.
- `EditorControllerSelectRangeTests` (framework target) — verifies `selectRange(_:scroll:)` selects the given range; `scroll: false` does not move the visible viewport; no-op when no view is attached.

**Snapshot tests (`CodeEditorSampleTests`):**

`WorkspaceSidebarSnapshots` — five baselines following the existing `EditorSidebarShellSnapshots` convention:

1. Files, no root
2. Files, loaded with two expanded folders
3. Search, ready (no query)
4. Search, results populated
5. Search, regex error inline

Record with `isRecording: true`, commit the PNGs.

**Existing tests touched:**

- `EditorDocumentsOpenFileTests` already covers `openFile`'s de-dupe behavior; add one case asserting the workspace surface routes through it without divergence.

## Risks and notes

- `MacOSWorkspaceFileManager.events` uses a 2-second polling loop (FSEvents emulation). Acceptable for a sample; tree updates are not real-time.
- Sample-target imports of `CodeEditorPlugin` types (`WorkspaceFileTree`, `WorkspaceFileWatching`, `ProjectSearchResult`, `PortableProjectSearchAdapter`) are already in use elsewhere in the sample target — no new dependency wiring needed in `Package.swift`.
- The `Settings { SettingsView() }` scene must be added once globally; double-adding will produce a SwiftUI duplicate-scene warning at runtime.
- `selectMatch` builds on `EditorController.nsLocation(forLSPLine:character:)` (existing) plus the new `EditorController.selectRange(_:scroll:)` (this spec). The latter is the only public framework surface added.
- After this spec lands, A.3 #1 (Split `AppState` god object) has two concrete examples of feature-scoped `@Observable` models to extend, and A.3 #8 (`SettingsScene` migration) is complete.
