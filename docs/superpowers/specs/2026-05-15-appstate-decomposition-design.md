# AppState Decomposition — Design

**Status:** Draft (brainstorming complete; awaiting user review)
**Date:** 2026-05-15
**Closes:** NEXT.md A.3 #1 ("`AppState` is a god object"), continuing the slice work begun by `FindReplaceModel`.
**Scope:** Sample app only (`Sources/CodeEditorSample/`). No framework changes.

## Context

`CodeEditorSample/App/AppState.swift` carries ~22 stored properties, ~199 read/write call sites across 11 feature areas, and a ~70-line `init()` that wires six handshakes (annotations hub ↔ controller, LSP attach, Performance attach, Completion attach, EventLog attach, workspace and project-search startup). NEXT.md A.3 #1 flags this as a god object and explicitly calls out the `pfw-observable-models` and `pfw-dependencies` conventions plus the framework's "no singletons" DI story as the direction to head.

Three feature-scoped `@Observable` models already exist as templates:

- `FindReplaceModel` (`EditorActions/FindReplaceModel.swift`) — the first slice extracted.
- `WorkspaceModel` (`Workspace/WorkspaceModel.swift`) — macOS-only file-tree state.
- `ProjectSearchModel` (`Workspace/ProjectSearchModel.swift`) — macOS-only cross-file search.

All three share the same shape: `@MainActor @Observable final class`, owned by `AppState` via composition, consumed by views with `@Bindable`. This spec extracts three more slices following the same pattern.

## Goals

- Pull `theme`, `configuration`, and `documents` + `editorController` + document I/O off `AppState` into focused models.
- Preserve the existing view API surface — call sites still bind through `appState` and read nested model properties.
- Keep `AppState.init()` as the composition root for cross-model wiring (annotations hub, coordinators, event log).
- Match the established `FindReplaceModel` / `WorkspaceModel` / `ProjectSearchModel` pattern (same class shape, same ownership).
- Ship per-slice PRs so each step is independently revertable and CI-green.

## Non-goals

- **Sample-app behavior changes.** This is a pure refactor; no new features, no UI changes, no I/O changes.
- **Behavior absorption.** ThemeModel and ConfigurationModel stay thin. The future Inspector config paste-in/round-trip (NEXT.md A.3 #5) and theme importer (NEXT.md A.1) are out of scope — they will attach to these models in their own designs.
- **AnnotationsModel / NavigationModel / coordinator wrappers.** Conservative scope. Annotations hub, sheet/palette booleans, and the macOS-only LSP / Performance / Completion coordinators stay flat on `AppState` for follow-up work.
- **Framework changes.** No `EditorDocuments`, `EditorController`, `AnnotationsHub`, or any other framework type is touched.
- **SwiftUI environment injection.** Views keep taking `@Bindable var appState: AppState`. No new `EnvironmentKey`s.
- **iOS feature additions.** Cross-platform parity work (NEXT.md A.3 #7) is unrelated and out of scope.

## Approach

Selected from three alternatives:

- **A. Thin wrappers, per-slice PRs.** *(chosen)*
- **B. Rich wrappers that also absorb planned behavior** (Inspector config paste-in, theme importer). Rejected — violates "don't add features the task doesn't require" and conflates decomposition with two unrelated feature designs.
- **C. Single mega-PR for all three slices.** Rejected — `FindReplaceModel` shipped as its own PR; per-slice keeps reviewability and bisectability.

Approach A relocates state with one model per slice, each a focused home that future feature work can extend. It matches the conservative scope the team has signalled by extracting `FindReplaceModel` as a single slice rather than bundling.

## Architecture

### File layout

Three new files, mirroring the existing model directory pattern:

```
Sources/CodeEditorSample/
├── App/
│   └── AppState.swift                       (shrinks ~70 lines)
├── Theme/
│   └── ThemeModel.swift                     NEW
├── Configuration/
│   └── ConfigurationModel.swift             NEW
└── Documents/
    └── DocumentsModel.swift                 NEW
```

`Theme/` and `Configuration/` are new directories; nothing else in the sample tree groups by these names today. `Documents/` already exists (it holds `EditorDocuments+SampleExtras.swift`), so `DocumentsModel.swift` slots in next to it.

`AppState.swift` keeps its path and remains the composition root. The existing `WorkspaceModel.swift`, `ProjectSearchModel.swift`, and `FindReplaceModel.swift` are unchanged.

### Model contracts

#### `ThemeModel`

```swift
@MainActor
@Observable
final class ThemeModel {
    var current: Theme

    init(initial: Theme = ThemeCatalog.default) {
        self.current = initial
    }
}
```

Single stored property. Views migrate from `appState.theme` to `appState.theme.current` (and `$appState.theme` to `$appState.theme.current` for bindings).

#### `ConfigurationModel`

```swift
@MainActor
@Observable
final class ConfigurationModel {
    var current: EditorConfiguration

    init(initial: EditorConfiguration = PresetCatalog.default.configuration) {
        self.current = initial
    }
}
```

Same shape. Knob panels' `$appState.configuration.display.…` becomes `$appState.configuration.current.display.…`. Environment injection (`\.codeEditorConfiguration`) reads `appState.configuration.current`.

#### `DocumentsModel`

The meatiest slice. Owns the documents collection, the framework's editor façade, the controller↔documents attach token, and document I/O (including iOS sheet state). Reads `workspaceRoot` from `AppState` through an injected closure so it doesn't have to own that piece.

```swift
@MainActor
@Observable
final class DocumentsModel {
    let store = EditorDocuments()
    let editorController = EditorController()

    @ObservationIgnored
    private var attachToken: AnyCancellable?

    @ObservationIgnored
    private let workspaceRootProvider: @MainActor () -> URL?

    #if !canImport(AppKit)
    var pendingSaveAs: SaveSheetState?
    var pendingOpenFile: Bool = false
    #endif

    init(workspaceRootProvider: @escaping @MainActor () -> URL?) {
        self.workspaceRootProvider = workspaceRootProvider
    }

    /// Wires the annotations data source onto the editor view once
    /// SwiftUI attaches it. Called by AppState.init after both this
    /// model and the hub are constructed because the hub isn't owned
    /// by this slice.
    func attachAnnotations(_ hub: AnnotationsHub) {
        attachToken = editorController.onAttach { [weak hub] ctrl in
            guard let hub else { return }
            ctrl.setAnnotationsDataSource(hub)
        }
    }

    // Save / Open orchestration (relocated verbatim from AppState).
    func requestSave()
    func requestSaveAs()
    func requestOpenFile()
    func handleSaveOutcome(_ outcome: EditorDocuments.SaveOutcome)

    #if !canImport(AppKit)
    func finalizeSaveAs(to url: URL)
    private func prepareSaveAsTemporaryFile(for active: EditorDocument) -> SaveSheetState?
    #endif
}
```

Four boundary decisions worth pinning down:

- **`workspaceRootProvider` closure.** Used in `requestSaveAs` (`defaultDirectory: workspaceRootProvider() ?? active.url?.deletingLastPathComponent()`) and `requestOpenFile` (`defaultDirectory: workspaceRootProvider()`). `AppState` passes `{ [weak self] in self?.workspaceRoot }` at construction. No duplicate state; `DocumentsModel` stays ignorant of workspace concerns.
- **`attachAnnotations` is a method, not init injection.** `AnnotationsHub` is constructed in `AppState.init()` and is not owned by `DocumentsModel`. AppState constructs both, then calls `documents.attachAnnotations(annotationsHub)`. This keeps the cross-slice dependency explicit at the composition root rather than hidden in a constructor.
- **Field rename `documents` → `store`.** Avoids the awkward `appState.documents.documents` call shape. Internal symbol rename only; no external Swift API.
- **iOS sheet state moves into `DocumentsModel`.** `pendingSaveAs` and `pendingOpenFile` follow the methods that drive them. `IOSRootView`'s `.sheet(item: $appState.pendingSaveAs)` becomes `.sheet(item: $appState.documents.pendingSaveAs)`.

### `AppState` after the refactor

`AppState` shrinks to the composition root plus the un-extracted state and macOS-only coordinators:

```swift
@MainActor
@Observable
final class AppState {
    // Slice models (composed)
    let theme = ThemeModel()
    let configuration = ConfigurationModel()
    let documents: DocumentsModel

    // Cross-cutting / un-extracted state
    var workspaceRoot: URL?
    let annotationsHub: AnnotationsHub
    let eventSystem = UnifiedEventSystem()
    let eventLog = EventLogSampleCoordinator()
    let findReplace = FindReplaceModel()
    var gotoLineSheetVisible: Bool = false
    var gotoSymbolSheetVisible: Bool = false
    var paletteVisible: Bool = false

    #if canImport(AppKit)
    let workspaceModel = WorkspaceModel()
    let projectSearchModel = ProjectSearchModel()
    let memoryMonitor = MemoryMonitor()
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))
    let lsp: LSPSampleCoordinator
    let performance: PerformanceSampleCoordinator
    let completion: CompletionSampleCoordinator
    #endif

    init() {
        self.documents = DocumentsModel(
            workspaceRootProvider: { [weak self] in self?.workspaceRoot }
        )

        let hub = AnnotationsHub()
        self.annotationsHub = hub
        hub.controller = documents.editorController
        documents.attachAnnotations(hub)

        #if canImport(AppKit)
        // LSP coordinator wiring (uses documents.editorController and documents.store).
        let coordinator = LSPSampleCoordinator(memoryMonitor: memoryMonitor)
        self.lsp = coordinator
        let storeRef = documents.store
        let editorControllerRef = documents.editorController
        coordinator.attach(controller: editorControllerRef, hub: hub) {
            [weak coordinator, weak storeRef] in
            guard let coordinator,
                  let store = storeRef,
                  let activeID = store.activeID,
                  let url = coordinator.mirrorURL(for: activeID) else { return nil }
            return "file://" + url.path
        }
        coordinator.onRequestOpen = { [weak storeRef] url in
            storeRef?.openFile(url: url)
        }
        coordinator.onRequestScroll = { [weak editorControllerRef] line in
            editorControllerRef?.gotoLine(line)
        }

        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            performanceObservation: performanceObservation
        )
        perfCoordinator.attach(controller: documents.editorController)
        self.performance = perfCoordinator

        let completionCoordinator = CompletionSampleCoordinator()
        self.completion = completionCoordinator
        completionCoordinator.attach(controller: documents.editorController)
        #endif

        eventLog.attach(controller: documents.editorController, eventSystem: eventSystem)

        #if canImport(AppKit)
        workspaceModel.setRoot(workspaceRoot)
        let initialRoot = workspaceRoot
        Task { @MainActor [projectSearchModel] in
            await projectSearchModel.setRoot(initialRoot)
        }
        #endif
    }
}
```

**Removed from `AppState`:** `theme`, `configuration`, `documents`, `editorController`, `attachToken`, all of `requestSave` / `requestSaveAs` / `requestOpenFile` / `handleSaveOutcome` / `prepareSaveAsTemporaryFile` / `finalizeSaveAs`, and iOS `pendingSaveAs` / `pendingOpenFile`.

**Retained:** annotations hub, navigation booleans (`gotoLineSheetVisible`, `gotoSymbolSheetVisible`, `paletteVisible`), event system, event log, find/replace model, workspace and project search models, and the macOS-only memory/perf monitors and coordinator references.

### Call-site rewrite cheat sheet

| Before | After |
|---|---|
| `appState.theme` | `appState.theme.current` |
| `$appState.theme` | `$appState.theme.current` |
| `appState.configuration` | `appState.configuration.current` |
| `$appState.configuration.display.x` | `$appState.configuration.current.display.x` |
| `appState.documents` | `appState.documents.store` |
| `appState.editorController` | `appState.documents.editorController` |
| `appState.requestSave()` | `appState.documents.requestSave()` |
| `appState.requestSaveAs()` | `appState.documents.requestSaveAs()` |
| `appState.requestOpenFile()` | `appState.documents.requestOpenFile()` |
| `appState.pendingSaveAs` (iOS) | `appState.documents.pendingSaveAs` |
| `$appState.pendingOpenFile` (iOS) | `$appState.documents.pendingOpenFile` |
| `appState.handleSaveOutcome(_:)` | `appState.documents.handleSaveOutcome(_:)` |
| `appState.finalizeSaveAs(to:)` (iOS) | `appState.documents.finalizeSaveAs(to:)` |

## Migration plan

Three PRs in order Theme → Configuration → Documents — smallest to largest. Each ships independently, runs the full quality gate, and is independently revertable.

### PR 1 — `ThemeModel`

1. Add `Sources/CodeEditorSample/Theme/ThemeModel.swift`.
2. In `AppState`: replace `var theme: Theme = ThemeCatalog.default` with `let theme = ThemeModel()`.
3. Sweep call sites per the cheat sheet (`appState.theme` → `appState.theme.current`; `$appState.theme` → `$appState.theme.current`). Touch set is bounded — chrome (`RootWindow`/`WindowBody`/`IOSRootView`), `\.codeEditorTheme` env injection, and the Settings/Themes switcher.
4. Run `swift build && swiftlint --fix && swiftlint && swift test --parallel`.

### PR 2 — `ConfigurationModel`

1. Add `Sources/CodeEditorSample/Configuration/ConfigurationModel.swift`.
2. In `AppState`: replace `var configuration: EditorConfiguration = …` with `let configuration = ConfigurationModel()`.
3. Sweep call sites. Knob panel bindings (`$appState.configuration.display.…`) become `$appState.configuration.current.display.…`. `\.codeEditorConfiguration` env injection reads `appState.configuration.current`.
4. Quality gate.

### PR 3 — `DocumentsModel`

Largest by line count and site count. Split into three logical commits within a single PR:

1. **Commit 3.1 — Introduce `DocumentsModel`.** Add `Sources/CodeEditorSample/Documents/DocumentsModel.swift` with the contract above. Move `requestSave` / `requestSaveAs` / `requestOpenFile` / `handleSaveOutcome` / `prepareSaveAsTemporaryFile` / `finalizeSaveAs` and the iOS sheet state from `AppState` byte-for-byte. Don't wire into `AppState` yet — the new file compiles standalone.
2. **Commit 3.2 — Compose in `AppState`.** Replace `let documents = EditorDocuments()`, `let editorController = EditorController()`, `private var attachToken: AnyCancellable?`, the save/open methods, and iOS sheet state with `let documents: DocumentsModel`. Initialize with `workspaceRootProvider: { [weak self] in self?.workspaceRoot }`. Move the `onAttach` token wiring into `documents.attachAnnotations(hub)`. Update the LSP / Performance / Completion / EventLog handshakes to reference `documents.editorController` and `documents.store`. `AppState.init()` drops ~60 lines.
3. **Commit 3.3 — Sweep call sites** per the cheat sheet, including the `documents` → `store` field rename inside `DocumentsModel`. ~80–100 sites across the command palette, `RootWindow`/`WindowBody`, Inspector, `IOSRootView`, command shortcuts in `CodeEditorSampleApp`, and knob panels that read documents.

Quality gate runs once at the end of PR 3.

**Unchanged in any PR:** `EditorDocuments`, `EditorController`, `AnnotationsHub`, every framework type, and any test that doesn't bind through `AppState`. This is pure sample-app refactor with zero framework touches.

## Testing

The new contracts mostly relocate already-tested code, so the strategy is lean on the existing safety net and add narrow smoke tests for the new boundaries.

### New tests (one file per model in `Tests/CodeEditorSampleTests/`)

- **`ThemeModelTests`**
  - `testInitialDefaultMatchesCatalog` — `ThemeModel().current` equals `ThemeCatalog.default`.
  - `testCurrentRoundTripsAssignment` — assign a non-default theme, read it back.
- **`ConfigurationModelTests`**
  - `testInitialDefaultMatchesPreset` — `ConfigurationModel().current` equals `PresetCatalog.default.configuration`.
  - `testCurrentRoundTripsAssignment` — assign `.minimal`, read it back.
- **`DocumentsModelTests`**
  - `testAttachAnnotationsInstallsDataSourceAfterControllerAttaches` — mirrors `AnnotationsHubInstallTests`. Construct `DocumentsModel`, call `attachAnnotations(hub)` before the controller attaches a view, simulate `onAttach`, assert `setAnnotationsDataSource` ran.
  - `testHandleSaveOutcomeAcceptsAllCases` — runs each `.saved` / `.untitled` / `.noTab` / `.failed` outcome through `handleSaveOutcome` without crashing. Validates the switch-statement move didn't drop a case.

Save/open methods themselves stay untested at the unit level — they fan out to `NSSavePanel` / `UIDocumentPickerViewController` and the underlying `EditorDocuments.openFile` / `save` / `saveAs` is already covered by `EditorDocumentsOpenFileTests` and `EditorDocumentsSampleExtrasTests`.

### Existing tests touched

None expected. `AnnotationsHubInstallTests`, `AnnotationsHubDiagnosticsTests`, `SwitcherCatalogTests`, `EditorDocumentsOpenFileTests`, and `EditorDocumentsSampleExtrasTests` all bind through framework types or `EditorDocuments` directly. If any test grep turns up `appState.theme` / `appState.configuration` / `appState.editorController` references mid-PR, they get the same path rewrite as production call sites.

### Quality gate

Run at the end of each PR: `swift build && swiftlint --fix && swiftlint && swift test --parallel`. Pre-existing flakes documented in NEXT.md D (`LineGeometryStoreBenchmarkTests`, `ScrollPositionPreservationTests`, `EditorStatusBarSnapshots`, etc.) are treated the same as today — green or pre-existing-failing-on-main, but not introduced by this refactor.

## Risks and rollback

### Risks

1. **Call-site sweep miss (especially PR 3).** ~199 sites across 11 features is enough that one path can slip. Mitigation is structural: every relocated property changes type, so the compiler flags missed sweeps as `Cannot infer member` or `Cannot convert value` errors, and SwiftLint strict mode treats any leftover warning as a build break.
2. **`attachAnnotations` ordering in `AppState.init()`.** The hub must exist before `documents.attachAnnotations(hub)` is called, and the call must happen before the SwiftUI representable triggers the editor controller's `onAttach` signal. The new `DocumentsModelTests.testAttachAnnotationsInstallsDataSourceAfterControllerAttaches` catches regression.
3. **`workspaceRootProvider` capture.** Closure captures `[weak self]` (AppState). AppState owns `DocumentsModel`, so the only retain-cycle risk would be if the closure escaped AppState's lifetime — the weak capture defangs it.
4. **iOS sheet bindings.** `$appState.pendingSaveAs` → `$appState.documents.pendingSaveAs` is exercised only when building for iOS. PR 3 must include a successful iOS build pass before merge.

### Rollback

Each PR is independently revertable. The order Theme → Configuration → Documents means a later revert never strands an earlier change in a half-state. Reverting any one PR restores the prior surface for that slice without touching the others.

## Out-of-scope follow-ups

These items remain open in NEXT.md and naturally attach to the new models once they exist:

- **A.3 #5** (InspectorSidebar config paste-in/round-trip) → `ConfigurationModel` becomes the home for `exportJSON()` / `importJSON(_:)` / `validate()` methods.
- **A.1 "Theme authoring"** (load Zed JSON from disk) → `ThemeModel` becomes the home for `loadZedJSON(at:)`.
- **A.3 #1 follow-up slices** — `AnnotationsModel`, `NavigationModel`, and coordinator wrappers. None of these is needed to deliver the current conservative scope; each becomes its own design conversation when next prioritised.
