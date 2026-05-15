# AppState Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose `CodeEditorSample/App/AppState.swift` into a composition root + three feature-scoped `@MainActor @Observable` slice models — `ThemeModel`, `ConfigurationModel`, `DocumentsModel` — matching the existing `FindReplaceModel` / `WorkspaceModel` / `ProjectSearchModel` pattern.

**Architecture:** Three slice classes own their state and (where applicable) behavior; `AppState` retains the cross-model handshake in `init()` and the un-extracted state (annotations hub, navigation flags, event system, find/replace, macOS-only coordinators). Views keep `@Bindable var appState: AppState` and read nested properties (`appState.theme.current`, `appState.documents.store`). Sample-app only — no framework changes.

**Tech Stack:** Swift 6.3, `StrictConcurrency`, AppKit (macOS) + UIKit (iOS), SwiftUI, Combine (for `AnyCancellable` token), XCTest. Reference spec: `docs/superpowers/specs/2026-05-15-appstate-decomposition-design.md`.

---

## Background reading (skim before starting)

- Spec: `docs/superpowers/specs/2026-05-15-appstate-decomposition-design.md`
- Existing slice template: `Sources/CodeEditorSample/EditorActions/FindReplaceModel.swift`
- File being decomposed: `Sources/CodeEditorSample/App/AppState.swift`
- Existing related models: `Sources/CodeEditorSample/Workspace/WorkspaceModel.swift`, `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`
- Project conventions: `CLAUDE.md` — note `swift build && swiftlint --fix && swiftlint && swift test --parallel` is the quality gate, SwiftLint strict mode is on, never use `print()` or `!`, follow `canImport(AppKit)` (not `os(macOS)`)

This is a pure sample-app refactor. Zero framework changes.

---

## Task 1: PR 1 — `ThemeModel`

Smallest slice. Wraps `theme: Theme` in a focused class so future theme-authoring work (NEXT.md A.1) has a home. End state: one new file, `AppState.theme` is now a model, all consumers read `.current`.

**Files:**
- Create: `Tests/CodeEditorSampleTests/ThemeModelTests.swift`
- Create: `Sources/CodeEditorSample/Theme/ThemeModel.swift`
- Modify: `Sources/CodeEditorSample/App/AppState.swift` (line 15 region)
- Sweep call sites: `Sources/CodeEditorSample/App/RootWindow.swift`, `Sources/CodeEditorSample/App/SettingsScene.swift`, `Sources/CodeEditorSample/App/WindowBody.swift`, `Sources/CodeEditorSample/iOS/IOSRootView.swift`, `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`

- [ ] **Step 1 — Write the failing tests**

Create `Tests/CodeEditorSampleTests/ThemeModelTests.swift`:

```swift
@testable import CodeEditorSample
import XCTest

@MainActor
final class ThemeModelTests: XCTestCase {
    func testInitialDefaultMatchesCatalog() {
        let model = ThemeModel()
        XCTAssertEqual(model.current.id, ThemeCatalog.default.id)
    }

    func testCurrentRoundTripsAssignment() {
        let model = ThemeModel()
        let alternate = ThemeCatalog.all.first { $0.id != model.current.id }
        guard let alternate else {
            XCTFail("ThemeCatalog.all should expose more than one theme")
            return
        }
        model.current = alternate
        XCTAssertEqual(model.current.id, alternate.id)
    }
}
```

- [ ] **Step 2 — Run tests to verify they fail to compile**

```bash
swift test --filter ThemeModelTests 2>&1 | tail -30
```

Expected: build failure mentioning `cannot find 'ThemeModel' in scope`.

- [ ] **Step 3 — Create the model file**

Create `Sources/CodeEditorSample/Theme/ThemeModel.swift`:

```swift
import CodeEditorPlugin
import Observation

/// Active editor theme. First wrapper extracted in the AppState
/// decomposition (NEXT.md A.3 #1). Owns the `Theme` value and acts as
/// a future home for theme authoring (e.g., load Zed JSON from disk).
@MainActor
@Observable
final class ThemeModel {
    /// Currently active theme. Mirrored to `\.codeEditorTheme` and to
    /// `.preferredColorScheme` at the scene root.
    var current: Theme

    init(initial: Theme = ThemeCatalog.default) {
        self.current = initial
    }
}
```

- [ ] **Step 4 — Run tests to verify they pass**

```bash
swift test --filter ThemeModelTests 2>&1 | tail -10
```

Expected: `Test Suite 'ThemeModelTests' passed`.

- [ ] **Step 5 — Compose into `AppState`**

Modify `Sources/CodeEditorSample/App/AppState.swift`. Replace the `theme` declaration (currently around line 15) with:

```swift
    /// Active editor theme. Mirrored to `\.codeEditorTheme` and to
    /// `.preferredColorScheme` at the scene root. First slice of the
    /// AppState decomposition (NEXT.md A.3 #1).
    let theme = ThemeModel()
```

(`let` because `ThemeModel` is a class. Internal mutations happen via `theme.current = …`.)

- [ ] **Step 6 — Run the build to enumerate consumer breakage**

```bash
swift build 2>&1 | grep -E "error:" | head -40
```

Expected: a handful of `cannot convert value of type 'ThemeModel' to expected argument type 'Theme'` (and similar) errors clustered in the 5 files listed under the Files section.

- [ ] **Step 7 — Sweep call sites**

For each consumer file listed under Files, replace bare `appState.theme` with `appState.theme.current`. Bindings `$appState.theme` become `$appState.theme.current`. Mechanical pattern:

```bash
# Per file, the rewrite is:
#   appState.theme   ->  appState.theme.current
#   $appState.theme  ->  $appState.theme.current
# Verify nothing more nuanced than these two patterns is needed by
# running `swift build` after each file edit.
```

Open each of the five files, do the rewrite, and save. After each edit re-run `swift build 2>&1 | grep -E "error:" | head` to confirm errors shrink.

- [ ] **Step 8 — Run the full quality gate**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: green or only pre-existing-on-`main` failures from NEXT.md §D (`LineGeometryStoreBenchmarkTests`, `ScrollPositionPreservationTests`, `EditorStatusBarSnapshots`, etc.). No new failures.

- [ ] **Step 9 — Commit**

```bash
git add Sources/CodeEditorSample/Theme/ThemeModel.swift \
        Tests/CodeEditorSampleTests/ThemeModelTests.swift \
        Sources/CodeEditorSample/App/AppState.swift \
        Sources/CodeEditorSample/App/RootWindow.swift \
        Sources/CodeEditorSample/App/SettingsScene.swift \
        Sources/CodeEditorSample/App/WindowBody.swift \
        Sources/CodeEditorSample/iOS/IOSRootView.swift \
        Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift

git commit -m "$(cat <<'EOF'
Sample: extract ThemeModel from AppState

First of three slice models in the AppState decomposition
(NEXT.md A.3 #1). ThemeModel wraps the Theme value, AppState now
owns `let theme = ThemeModel()`, and consumers read .current.
EOF
)"
```

---

## Task 2: PR 2 — `ConfigurationModel`

Same shape as Task 1 but for `EditorConfiguration`. Wider knob-binding sweep (`$appState.configuration.display.…` → `$appState.configuration.current.display.…`).

**Files:**
- Create: `Tests/CodeEditorSampleTests/ConfigurationModelTests.swift`
- Create: `Sources/CodeEditorSample/Configuration/ConfigurationModel.swift`
- Modify: `Sources/CodeEditorSample/App/AppState.swift` (line 19 region)
- Sweep call sites: `Sources/CodeEditorSample/App/SettingsScene.swift`, `Sources/CodeEditorSample/App/WindowBody.swift`, `Sources/CodeEditorSample/iOS/IOSRootView.swift`, `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`, `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`. KnobPanels under `Sources/CodeEditorSample/KnobPanels/` typically bind `$appState.configuration.<domain>.<knob>` — sweep them too.

- [ ] **Step 1 — Write the failing tests**

Create `Tests/CodeEditorSampleTests/ConfigurationModelTests.swift`:

```swift
@testable import CodeEditorSample
import CodeEditorPlugin
import XCTest

@MainActor
final class ConfigurationModelTests: XCTestCase {
    func testInitialDefaultMatchesPreset() {
        let model = ConfigurationModel()
        XCTAssertEqual(
            model.current.display.isLineNumbersEnabled,
            PresetCatalog.default.configuration.display.isLineNumbersEnabled
        )
    }

    func testCurrentRoundTripsAssignment() {
        let model = ConfigurationModel()
        model.current = EditorConfiguration.minimal
        XCTAssertEqual(
            model.current.display.isLineNumbersEnabled,
            EditorConfiguration.minimal.display.isLineNumbersEnabled
        )
    }
}
```

- [ ] **Step 2 — Run tests to verify they fail to compile**

```bash
swift test --filter ConfigurationModelTests 2>&1 | tail -20
```

Expected: build failure mentioning `cannot find 'ConfigurationModel' in scope`.

- [ ] **Step 3 — Create the model file**

Create `Sources/CodeEditorSample/Configuration/ConfigurationModel.swift`:

```swift
import CodeEditorPlugin
import Observation

/// Active editor configuration. Bound directly from the knob panels;
/// flows into the editor via `\.codeEditorConfiguration`. Second slice
/// of the AppState decomposition (NEXT.md A.3 #1) — future home for
/// JSON import/export and validation (NEXT.md A.3 #5).
@MainActor
@Observable
final class ConfigurationModel {
    /// Currently active editor configuration. Read by the chrome and
    /// every knob panel.
    var current: EditorConfiguration

    init(initial: EditorConfiguration = PresetCatalog.default.configuration) {
        self.current = initial
    }
}
```

- [ ] **Step 4 — Run tests to verify they pass**

```bash
swift test --filter ConfigurationModelTests 2>&1 | tail -10
```

Expected: `Test Suite 'ConfigurationModelTests' passed`.

- [ ] **Step 5 — Compose into `AppState`**

Modify `Sources/CodeEditorSample/App/AppState.swift`. Replace the `configuration` declaration with:

```swift
    /// Active editor configuration. Bound directly from the knob panels;
    /// flows into the editor via `\.codeEditorConfiguration`. Second
    /// slice of the AppState decomposition (NEXT.md A.3 #1).
    let configuration = ConfigurationModel()
```

- [ ] **Step 6 — Run the build to enumerate consumer breakage**

```bash
swift build 2>&1 | grep -E "error:" | head -60
```

Expected: errors clustered in the files listed above, plus any knob panel under `Sources/CodeEditorSample/KnobPanels/` that binds `$appState.configuration.…`.

- [ ] **Step 7 — Sweep call sites**

Rewrite pattern:

```
appState.configuration             ->  appState.configuration.current
$appState.configuration            ->  $appState.configuration.current
appState.configuration.<anything>  ->  appState.configuration.current.<anything>
$appState.configuration.<anything> ->  $appState.configuration.current.<anything>
```

Verify with `swift build 2>&1 | grep -E "error:" | head` after each file. Don't introduce any new wrapper methods; this is pure path migration.

- [ ] **Step 8 — Run the full quality gate**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: green or pre-existing-failing-on-main.

- [ ] **Step 9 — Commit**

```bash
git add Sources/CodeEditorSample/Configuration/ConfigurationModel.swift \
        Tests/CodeEditorSampleTests/ConfigurationModelTests.swift \
        Sources/CodeEditorSample/App/AppState.swift \
        Sources/CodeEditorSample/App/SettingsScene.swift \
        Sources/CodeEditorSample/App/WindowBody.swift \
        Sources/CodeEditorSample/iOS/IOSRootView.swift \
        Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift \
        Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift \
        Sources/CodeEditorSample/KnobPanels/

git commit -m "$(cat <<'EOF'
Sample: extract ConfigurationModel from AppState

Second of three slice models in the AppState decomposition
(NEXT.md A.3 #1). ConfigurationModel wraps EditorConfiguration;
AppState now owns `let configuration = ConfigurationModel()` and
knob panels bind through .current.
EOF
)"
```

---

## Task 3: PR 3 commit 3.1 — Introduce `DocumentsModel`

Add the new model with its tests, but **do not wire it into `AppState` yet**. The file compiles standalone and the tests pass. The state mid-PR is: `AppState` still has the original `documents`, `editorController`, etc., and `DocumentsModel` exists as a new sibling file.

This task is intentionally split from Task 4 to keep the diff reviewable: commit 3.1 introduces the new class, commit 3.2 swings AppState onto it, commit 3.3 sweeps callers.

**Files:**
- Create: `Tests/CodeEditorSampleTests/DocumentsModelTests.swift`
- Create: `Sources/CodeEditorSample/Documents/DocumentsModel.swift`

- [ ] **Step 1 — Write the failing tests**

Create `Tests/CodeEditorSampleTests/DocumentsModelTests.swift`. Mirror the existing `AnnotationsHubInstallTests` pattern (`Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift`) for the attach test:

```swift
#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

@MainActor
final class DocumentsModelTests: XCTestCase {
    func testAttachAnnotationsInstallsDataSourceAfterControllerAttaches() {
        // Construct DocumentsModel the way AppState does — with a
        // workspaceRootProvider closure (here returning nil because
        // workspace is irrelevant to this test).
        let model = DocumentsModel(workspaceRootProvider: { nil })
        let hub = AnnotationsHub()

        model.attachAnnotations(hub)

        // Pre-attach, the controller has no underlying view so no
        // data source can be installed yet.
        XCTAssertFalse(
            model.editorController.isAttached,
            "Freshly-constructed controller should be unattached."
        )

        // Simulate what the SwiftUI representable does.
        let view = CodeEditorView(frame: .zero)
        model.editorController.attach(to: view)

        XCTAssertTrue(
            model.editorController.isAttached,
            "Controller should be attached after attach(to:)."
        )

        XCTAssertIdentical(
            view.annotationsDataSource,
            hub,
            "AnnotationsHub must be installed as the view's data source after attach."
        )
    }

    func testHandleSaveOutcomeAcceptsAllCases() {
        // Smoke: validates the switch-statement relocation didn't drop
        // a case. handleSaveOutcome only logs — we just need each case
        // to execute without crashing.
        let model = DocumentsModel(workspaceRootProvider: { nil })
        model.handleSaveOutcome(.saved(url: URL(fileURLWithPath: "/tmp/x")))
        model.handleSaveOutcome(.untitled)
        model.handleSaveOutcome(.noTab)
        model.handleSaveOutcome(
            .failed(error: NSError(domain: "test", code: 0))
        )
    }
}
#endif
```

The `#if canImport(AppKit)` gate matches the macOS-only test in the AnnotationsHub install file. iOS coverage of `DocumentsModel` is implicit via PR3 commit 3.3 sweeping the iOS root.

- [ ] **Step 2 — Run tests to verify they fail to compile**

```bash
swift test --filter DocumentsModelTests 2>&1 | tail -30
```

Expected: build failure mentioning `cannot find 'DocumentsModel' in scope`.

- [ ] **Step 3 — Create the model file**

Create `Sources/CodeEditorSample/Documents/DocumentsModel.swift`. This file relocates code from `AppState.swift` lines 41–53 (documents/editorController/attachToken), lines 124–136 (attach token wiring), lines 199–214 (handleSaveOutcome), lines 222–266 (requestSave/SaveAs/OpenFile), and lines 270–304 (iOS sheet state + helpers). Use `CrossPlatformLogger` for the logger (matching existing usage), never `print()`:

```swift
import CodeEditorPlugin
import Combine
import Foundation
import Observation

/// Documents + EditorController + I/O slice of AppState. Owns the
/// multi-tab `EditorDocuments` store, the framework's imperative
/// `EditorController` façade, the controller-onAttach token that wires
/// the AnnotationsHub data source, and the Save / Save-As / Open
/// orchestration (cross-platform, with iOS sheet state). Third slice of
/// the AppState decomposition (NEXT.md A.3 #1).
@MainActor
@Observable
final class DocumentsModel {
    /// Multi-tab document collection. Renamed from `documents` to
    /// `store` to avoid the awkward `appState.documents.documents`
    /// call shape after composition.
    let store = EditorDocuments()

    /// Imperative editor façade. Attached to the live `CodeEditor` via
    /// the `.editorController(_:)` modifier; sample features (find,
    /// goto, fold, annotations) all dispatch through this.
    let editorController = EditorController()

    /// Retains the `editorController.onAttach` subscription that wires
    /// the annotations data source after the SwiftUI representable
    /// attaches the underlying view. Dropping this would cancel the
    /// registration; kept for the model's lifetime.
    @ObservationIgnored
    private var attachToken: AnyCancellable?

    /// Closure returning the AppState-owned workspace root. Used as
    /// the default directory for save / open panels. Closure rather
    /// than stored URL so DocumentsModel doesn't have to mirror
    /// workspace state.
    @ObservationIgnored
    private let workspaceRootProvider: @MainActor () -> URL?

    #if !canImport(AppKit)
    /// State driving the iOS Save-As sheet. `IOSRootView` binds
    /// `.sheet(item: $appState.documents.pendingSaveAs)`; nil dismisses.
    var pendingSaveAs: SaveSheetState?

    /// State driving the iOS Open File… sheet. `IOSRootView` binds
    /// `.sheet(isPresented: $appState.documents.pendingOpenFile)`.
    var pendingOpenFile: Bool = false
    #endif

    init(workspaceRootProvider: @escaping @MainActor () -> URL?) {
        self.workspaceRootProvider = workspaceRootProvider
    }

    /// Wires the annotations data source onto the editor view once
    /// SwiftUI attaches it. Called by `AppState.init()` after both this
    /// model and the AnnotationsHub are constructed because the hub is
    /// not owned by this slice.
    ///
    /// Idempotent across reattaches — the controller's `onAttach`
    /// signal fires once per attach, and the data-source setter is
    /// safe to call repeatedly.
    func attachAnnotations(_ hub: AnnotationsHub) {
        attachToken = editorController.onAttach { [weak hub] ctrl in
            guard let hub else { return }
            ctrl.setAnnotationsDataSource(hub)
        }
    }

    /// Logs the result of a `EditorDocuments.save(_:)` call so the user
    /// sees feedback when ⌘S fires from the menu.
    func handleSaveOutcome(_ outcome: EditorDocuments.SaveOutcome) {
        let logger = CrossPlatformLogger.logger(
            subsystem: "CodeEditorSample",
            category: "DocumentStore"
        )
        switch outcome {
        case let .saved(url):
            logger.info("Saved \(url.path)")

        case .untitled:
            logger.warning("Tab is untitled — Save-As is not implemented in the demo.")

        case .noTab:
            logger.warning("Save invoked with no active tab.")

        case let .failed(error):
            logger.error("Save failed: \(error.localizedDescription)")
        }
    }

    /// `⌘S` command handler. Tries `store.save()`; if the active tab
    /// has no URL, transparently chains to `requestSaveAs()` so the
    /// user gets the save panel instead of a silent log entry.
    func requestSave() {
        let outcome = store.save()
        if case .untitled = outcome {
            requestSaveAs()
        } else {
            handleSaveOutcome(outcome)
        }
    }

    /// `⇧⌘S` command handler. Presents the platform save panel, then
    /// rebinds the active document to the chosen URL via
    /// `EditorDocuments.saveAs(to:)`.
    func requestSaveAs() {
        guard let active = store.active else {
            handleSaveOutcome(.noTab)
            return
        }
        #if canImport(AppKit)
        DocumentPicker.save(
            suggestedName: active.name,
            defaultDirectory: workspaceRootProvider() ?? active.url?.deletingLastPathComponent()
        ) { [self] url in
            let outcome = store.saveAs(to: url)
            handleSaveOutcome(outcome)
        }
        #else
        pendingSaveAs = prepareSaveAsTemporaryFile(for: active)
        #endif
    }

    /// `⇧⌘O` command handler. Presents the platform open panel and
    /// feeds the picked URL into `EditorDocuments.openFile(url:)`.
    func requestOpenFile() {
        #if canImport(AppKit)
        DocumentPicker.openFile(defaultDirectory: workspaceRootProvider()) { [self] url in
            store.openFile(url: url)
        }
        #else
        pendingOpenFile = true
        #endif
    }

    #if !canImport(AppKit)
    /// Writes the active document's text to
    /// `NSTemporaryDirectory()/<name>` so
    /// `UIDocumentPickerViewController(forExporting:asCopy: false)` has
    /// a file to move to the user's chosen destination.
    private func prepareSaveAsTemporaryFile(for active: EditorDocument) -> SaveSheetState? {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(active.name)
        do {
            try active.text.write(to: tempURL, atomically: true, encoding: .utf8)
            return SaveSheetState(temporaryURL: tempURL, suggestedName: active.name)
        } catch {
            handleSaveOutcome(.failed(error: error))
            return nil
        }
    }

    /// Invoked by `ExportDocumentSheet.onPick` after the user confirms
    /// the iOS document picker. Performs the rebind via
    /// `EditorDocuments.saveAs` and routes the outcome through the
    /// standard feedback channel.
    func finalizeSaveAs(to url: URL) {
        let outcome = store.saveAs(to: url)
        handleSaveOutcome(outcome)
    }
    #endif
}
```

- [ ] **Step 4 — Run tests to verify they pass**

```bash
swift test --filter DocumentsModelTests 2>&1 | tail -20
```

Expected: both tests pass on macOS. (The whole file is gated on `canImport(AppKit)` so iOS skips it.)

- [ ] **Step 5 — Run the full build to confirm `AppState` is untouched**

```bash
swift build 2>&1 | grep -E "error:" | head -10
```

Expected: zero errors. `DocumentsModel` is unused but valid Swift.

- [ ] **Step 6 — Commit (PR3 commit 3.1)**

```bash
git add Sources/CodeEditorSample/Documents/DocumentsModel.swift \
        Tests/CodeEditorSampleTests/DocumentsModelTests.swift

git commit -m "$(cat <<'EOF'
Sample: introduce DocumentsModel (unwired)

Third slice of the AppState decomposition (NEXT.md A.3 #1).
DocumentsModel owns store / editorController / attach token /
save / open / iOS sheet state, with a workspaceRootProvider
closure for save/open default directory. Not yet composed into
AppState — that's the next commit. Tests cover the attach
handshake and the SaveOutcome switch relocation.
EOF
)"
```

---

## Task 4: PR 3 commit 3.2 — Compose `DocumentsModel` into `AppState`

Swing `AppState` from owning `documents`/`editorController`/`attachToken`/save-open methods/iOS sheet state to owning a `DocumentsModel`. After this commit the build is broken at consumer sites — `appState.editorController` no longer exists. Commit 3.3 (Task 5) fixes those sites. This trade-off is acknowledged in the spec.

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

- [ ] **Step 1 — Rewrite `AppState.swift`**

Replace the entire file contents with the body below. Diff summary: remove `documents`, `editorController`, `attachToken`, all of `requestSave`/`requestSaveAs`/`requestOpenFile`/`handleSaveOutcome`/`prepareSaveAsTemporaryFile`/`finalizeSaveAs`, and iOS `pendingSaveAs`/`pendingOpenFile`. Add `let documents: DocumentsModel` with a closure-captured workspace root provider. Rewrite the LSP / Performance / Completion / EventLog handshakes to reference `documents.editorController` and `documents.store`.

```swift
import CodeEditorPlugin
import Combine
import Foundation
import Observation

/// Top-level shared state for the sample app. Owned once by
/// `CodeEditorSampleApp` and injected into both the main window and the
/// Settings (cmd-,) window so changes made in either are reflected
/// instantly in the other.
@MainActor
@Observable
final class AppState {
    // MARK: - Slice models

    /// Active editor theme slice. First slice of the AppState
    /// decomposition (NEXT.md A.3 #1).
    let theme = ThemeModel()

    /// Active editor configuration slice. Second slice of the AppState
    /// decomposition (NEXT.md A.3 #1).
    let configuration = ConfigurationModel()

    /// Documents + EditorController + I/O slice. Third slice of the
    /// AppState decomposition (NEXT.md A.3 #1). Constructed in init()
    /// because it takes a closure capturing `self.workspaceRoot`.
    let documents: DocumentsModel

    // MARK: - Cross-cutting / un-extracted state

    /// Workspace root for runtime-only LSP/file integrations.
    var workspaceRoot: URL?

    #if canImport(AppKit)
    /// File-tree state + WorkspaceFileWatching subscription for the
    /// left-rail Files panel. macOS-only.
    let workspaceModel = WorkspaceModel()

    /// Project-wide search state + PortableProjectSearchAdapter for the
    /// left-rail Search panel. macOS-only.
    let projectSearchModel = ProjectSearchModel()
    #endif

    /// Annotations data source backing both the breakpoint-toggle demo
    /// and the TODO/FIXME knobs. Held strongly here because
    /// `CodeEditorView.annotationsDataSource` is `weak`.
    let annotationsHub: AnnotationsHub

    /// Shared `UnifiedEventSystem` for the sample. Wired into the
    /// editor view via `.eventSystem(_:)` in both `WindowBody` (macOS)
    /// and `IOSRootView` (iOS).
    let eventSystem = UnifiedEventSystem()

    /// Cross-platform EventLog coordinator. Subscribes to `eventSystem`
    /// for framework-emitted EditorEvents and to
    /// `documents.editorController.completionEvents()` for completion
    /// activity.
    let eventLog = EventLogSampleCoordinator()

    /// Find / replace feature-scoped model. Owns query text, options,
    /// overlay visibility, debounce / clear lifecycle, and the derived
    /// match counters.
    let findReplace = FindReplaceModel()

    /// Whether the "Go to Line…" sheet is presented.
    var gotoLineSheetVisible: Bool = false

    /// Whether the "Go to Symbol…" sheet is presented.
    var gotoSymbolSheetVisible: Bool = false

    /// Whether the command palette overlay is visible.
    var paletteVisible: Bool = false

    #if canImport(AppKit)
    /// Shared `MemoryMonitor` instance fed into both `lsp` and
    /// `performance` coordinators.
    let memoryMonitor = MemoryMonitor()

    /// Shared `PerformanceObservation` instance. Installed onto the
    /// editor view via `.performanceObserver(_:)`.
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))

    /// Sample-side LSP coordinator. macOS-only.
    let lsp: LSPSampleCoordinator

    /// Sample-side Performance Inspector coordinator. macOS-only.
    let performance: PerformanceSampleCoordinator

    /// Sample-side Completion Inspector coordinator. macOS-only.
    let completion: CompletionSampleCoordinator
    #endif

    init() {
        // DocumentsModel needs workspaceRoot for save/open default
        // directories. Weak self so the model never retains AppState.
        self.documents = DocumentsModel(
            workspaceRootProvider: { [weak self] in self?.workspaceRoot }
        )

        let hub = AnnotationsHub()
        self.annotationsHub = hub
        hub.controller = documents.editorController
        // The controller is freshly constructed inside DocumentsModel —
        // its codeEditorView is nil, so a direct call to
        // setAnnotationsDataSource(hub) here would be a silent no-op.
        // Defer the install until the SwiftUI representable attaches
        // the underlying view.
        documents.attachAnnotations(hub)

        #if canImport(AppKit)
        let coordinator = LSPSampleCoordinator(memoryMonitor: memoryMonitor)
        self.lsp = coordinator
        let storeRef = documents.store
        let editorControllerRef = documents.editorController
        coordinator.attach(
            controller: editorControllerRef,
            hub: hub
        ) { [weak coordinator, weak storeRef] in
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

        // Performance Inspector wiring.
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

        // EventLog coordinator wiring. Cross-platform.
        eventLog.attach(
            controller: documents.editorController,
            eventSystem: eventSystem
        )

        #if canImport(AppKit)
        // Workspace surface wiring. Picks up any initial workspaceRoot.
        workspaceModel.setRoot(workspaceRoot)
        let initialRoot = workspaceRoot
        Task { @MainActor [projectSearchModel] in
            await projectSearchModel.setRoot(initialRoot)
        }
        #endif
    }
}
```

- [ ] **Step 2 — Run the build to confirm consumer breakage is the expected shape**

```bash
swift build 2>&1 | grep -E "error:" | head -80
```

Expected: clusters of two shapes —

- `value of type 'AppState' has no member 'editorController' / 'requestSave' / 'requestSaveAs' / 'requestOpenFile' / 'handleSaveOutcome' / 'pendingSaveAs' / 'pendingOpenFile' / 'finalizeSaveAs'` — these properties moved to `DocumentsModel`.
- `value of type 'DocumentsModel' has no member 'openFile' / 'active' / 'activeID' / 'save' / 'saveAs' / …` — `appState.documents` now resolves to `DocumentsModel`, not the `EditorDocuments` collection. Consumers need `appState.documents.store.<X>`.

These are the call sites Task 5 sweeps. If you see errors that are *not* shaped like either of the above — for example, an LSP coordinator method signature mismatch — stop and re-read the spec; something in this commit drifted.

- [ ] **Step 3 — Run the targeted suite to verify the new tests still pass**

```bash
swift test --filter DocumentsModelTests 2>&1 | tail -10
swift test --filter AnnotationsHubInstallTests 2>&1 | tail -10
```

Both should pass — `DocumentsModelTests` because the model is internally consistent; `AnnotationsHubInstallTests` because it now reads `appState.editorController`. Wait — that test currently reads `appState.editorController`. After this commit it must read `appState.documents.editorController`.

Add this fix as part of this same commit so `swift test --filter AnnotationsHubInstallTests` passes:

In `Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift`, replace every `appState.editorController` with `appState.documents.editorController`. That's three references on lines 26, 33, 36 (verify with `grep -n "appState\.editorController" Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift`). The `appState.annotationsHub` reference on line 43 stays unchanged because the hub is still on `AppState`.

Re-run:

```bash
swift test --filter AnnotationsHubInstallTests 2>&1 | tail -10
```

Expected: pass.

- [ ] **Step 4 — Confirm the rest of the build is still broken (expected)**

```bash
swift build 2>&1 | grep -E "error:" | wc -l
```

Expected: a positive integer in the dozens. That's the consumer fallout commit 3.3 will fix. **Do not** stage any other files in this commit.

- [ ] **Step 5 — Commit (PR3 commit 3.2)**

```bash
git add Sources/CodeEditorSample/App/AppState.swift \
        Tests/CodeEditorSampleTests/AnnotationsHubInstallTests.swift

git commit -m "$(cat <<'EOF'
Sample: compose DocumentsModel into AppState

AppState.init() shrinks ~60 lines: documents / editorController /
attach token / save-open methods / iOS sheet state move into the
new DocumentsModel slice. Cross-model wiring (annotations hub,
LSP/Performance/Completion/EventLog coordinator attach) updated
to reach through documents.editorController and documents.store.

Build is intentionally broken at consumer sites in this commit;
the next commit sweeps call sites per the spec's cheat sheet.
AnnotationsHubInstallTests updated inline since it touches AppState
directly.
EOF
)"
```

---

## Task 5: PR 3 commit 3.3 — Sweep call sites

Migrate every consumer of the relocated `AppState` properties to read through `appState.documents.…`. The build is currently broken (Task 4 left it that way). This commit makes the PR green.

**Files (touch set — ~80–100 sites total across these):**
- `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`
- `Sources/CodeEditorSample/App/RootWindow.swift`
- `Sources/CodeEditorSample/App/WindowBody.swift`
- `Sources/CodeEditorSample/App/SettingsScene.swift`
- `Sources/CodeEditorSample/iOS/IOSRootView.swift`
- `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`
- `Sources/CodeEditorSample/Workspace/FilePanelView.swift`
- `Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift`
- `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`
- `Sources/CodeEditorSample/KnobPanels/AnnotationsKnobsSection.swift`
- Any additional file the build errors point at — fix every error.

- [ ] **Step 1 — Establish the error baseline**

```bash
swift build 2>&1 | grep -E "error:" > /tmp/appstate-sweep-baseline.txt
wc -l /tmp/appstate-sweep-baseline.txt
```

Note the count. It will drop to 0 by the end of this task.

- [ ] **Step 2 — Apply the rewrite pattern**

For every file in the touch set, do the rewrites in the cheat sheet below. The exact string-level patterns:

| Pattern (before) | Pattern (after) |
|---|---|
| `appState.documents` | `appState.documents.store` |
| `appState.editorController` | `appState.documents.editorController` |
| `appState.requestSave(` | `appState.documents.requestSave(` |
| `appState.requestSaveAs(` | `appState.documents.requestSaveAs(` |
| `appState.requestOpenFile(` | `appState.documents.requestOpenFile(` |
| `appState.handleSaveOutcome(` | `appState.documents.handleSaveOutcome(` |
| `appState.finalizeSaveAs(` | `appState.documents.finalizeSaveAs(` |
| `appState.pendingSaveAs` | `appState.documents.pendingSaveAs` |
| `$appState.pendingSaveAs` | `$appState.documents.pendingSaveAs` |
| `appState.pendingOpenFile` | `appState.documents.pendingOpenFile` |
| `$appState.pendingOpenFile` | `$appState.documents.pendingOpenFile` |

The cheat-sheet patterns don't overlap with each other — each can be applied independently. Do the sweep file by file in your editor; don't run a workspace-wide sed.

Two reasons the sed-everything approach is risky:

1. After Task 4, `Sources/CodeEditorSample/App/AppState.swift` itself uses `documents.editorController` / `documents.store` *internally* (not via `appState.`). Those references are already correct — skip the file.
2. Consumer files all have *pre-Task-4* shape (`appState.documents.openFile`, `appState.editorController`, etc.). A workspace-wide `appState.documents` → `appState.documents.store` would be safe today but would silently break later if a new caller wrote `appState.documents.requestSave()` before the sweep — make the rewrite intentional, file by file.

- [ ] **Step 3 — Re-run the build, iterate until green**

```bash
swift build 2>&1 | grep -E "error:" | head -20
```

After each file edit, re-run. The error count should monotonically decrease. If a new error type appears that isn't in the cheat sheet, stop and check the spec.

Common surprise: the `KnobPanels/AnnotationsKnobsSection.swift` reads `appState.editorController` to call annotations methods. The rewrite is `appState.documents.editorController`.

- [ ] **Step 4 — Run the existing test suites that bind through `AppState`**

```bash
swift test --filter AnnotationsHubInstallTests
swift test --filter AnnotationsHubDiagnosticsTests
swift test --filter SwitcherCatalogTests
swift test --filter EditorDocumentsOpenFileTests
swift test --filter EditorDocumentsSampleExtrasTests
```

Expected: all pass. If any test references the relocated properties (grep `appState\.\(theme\|configuration\|documents\|editorController\|requestSave\|requestSaveAs\|requestOpenFile\|handleSaveOutcome\|finalizeSaveAs\|pendingSaveAs\|pendingOpenFile\)` under `Tests/`), apply the same rewrite pattern.

- [ ] **Step 5 — Build for iOS to verify iOS-only sheet bindings**

```bash
xcrun --sdk iphonesimulator swift build \
  -Xswiftc -sdk -Xswiftc "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -Xswiftc -target -Xswiftc "arm64-apple-ios17.0-simulator" \
  2>&1 | grep -E "error:" | head -20
```

Expected: clean. This catches `$appState.pendingSaveAs` and `$appState.pendingOpenFile` rewrites in `IOSRootView.swift` that the macOS build wouldn't surface.

If your environment doesn't expose `xcrun` (CI for example), substitute the project's iOS-build command. The point is: do not merge PR 3 without an iOS build pass.

- [ ] **Step 6 — Run the full quality gate**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: green or only pre-existing-failing-on-main from NEXT.md §D. Specifically, `DocumentsModelTests` (2 tests), `ThemeModelTests` (2 tests), `ConfigurationModelTests` (2 tests) all pass. No new failures.

- [ ] **Step 7 — Confirm `AppState.init()` actually shrank**

```bash
wc -l Sources/CodeEditorSample/App/AppState.swift
```

Expected: meaningfully smaller than the pre-PR baseline. Pre-PR length was ~306 lines; post-PR should be ~150-170 (a ~50% reduction).

- [ ] **Step 8 — Commit (PR3 commit 3.3) + mark NEXT.md A.3 #1 progress**

Update `NEXT.md` A.3 item 1's nested progress note to record the conservative-scope decomposition has landed. The relevant fragment is around line 49:

```
> First slice extracted: `FindReplaceModel` (find/replace state, debounce, lifecycle). The remaining decomposition (Theme / Configuration / Annotations / etc.) is unchanged in scope. Spec: `docs/superpowers/specs/2026-05-15-find-replace-overlay-upgrade-design.md`.
```

Replace with:

```
> Conservative scope landed: `ThemeModel`, `ConfigurationModel`, `DocumentsModel` extracted alongside the prior `FindReplaceModel`. `AppState` is now a composition root holding the un-extracted state (annotations hub, navigation flags, event system, find/replace) and the macOS-only coordinators. Remaining slices (`AnnotationsModel`, `NavigationModel`, coordinator wrappers) deferred. Spec: `docs/superpowers/specs/2026-05-15-appstate-decomposition-design.md`; plan: `docs/superpowers/plans/2026-05-15-appstate-decomposition.md`.
```

Then commit:

```bash
git add Sources/CodeEditorSample/App/CodeEditorSampleApp.swift \
        Sources/CodeEditorSample/App/RootWindow.swift \
        Sources/CodeEditorSample/App/WindowBody.swift \
        Sources/CodeEditorSample/App/SettingsScene.swift \
        Sources/CodeEditorSample/iOS/IOSRootView.swift \
        Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift \
        Sources/CodeEditorSample/Workspace/FilePanelView.swift \
        Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift \
        Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift \
        Sources/CodeEditorSample/KnobPanels/AnnotationsKnobsSection.swift \
        NEXT.md
# Plus any other files the sweep touched — `git status` should be empty after.

git commit -m "$(cat <<'EOF'
Sample: sweep call sites onto DocumentsModel

Migrates ~80–100 call sites across the chrome, inspector, knob
panels, command palette, and iOS root to read through
appState.documents.{store,editorController,requestSave,…}. The
documents field on DocumentsModel is named `store` (not `documents`)
to avoid `appState.documents.documents`. iOS sheet bindings
($appState.pendingSaveAs / $appState.pendingOpenFile) move with the
methods that drive them.

Build is green again. NEXT.md A.3 #1 conservative scope is now
complete; AnnotationsModel / NavigationModel / coordinator wrappers
remain deferred for future designs.
EOF
)"
```

---

## Done criteria

- [ ] `Sources/CodeEditorSample/Theme/ThemeModel.swift` exists and matches the contract.
- [ ] `Sources/CodeEditorSample/Configuration/ConfigurationModel.swift` exists and matches the contract.
- [ ] `Sources/CodeEditorSample/Documents/DocumentsModel.swift` exists with attach + save + open + iOS sheet state, and `documents` (the inner collection) is named `store`.
- [ ] `AppState.swift` no longer declares `theme`, `configuration`, `documents` (the old `EditorDocuments` field), `editorController`, `attachToken`, `requestSave`, `requestSaveAs`, `requestOpenFile`, `handleSaveOutcome`, `finalizeSaveAs`, `prepareSaveAsTemporaryFile`, `pendingSaveAs`, or `pendingOpenFile`.
- [ ] `AppState.init()` constructs the three slice models, wires the annotations hub via `documents.attachAnnotations`, and routes coordinator attach calls through `documents.editorController` / `documents.store`.
- [ ] All six new tests pass (`ThemeModelTests` x2, `ConfigurationModelTests` x2, `DocumentsModelTests` x2). `AnnotationsHubInstallTests` updated to read `appState.documents.editorController`. No other existing tests touched.
- [ ] `swift build && swiftlint --fix && swiftlint && swift test --parallel` returns clean (or only with pre-existing-on-main failures from NEXT.md §D).
- [ ] iOS build is green.
- [ ] Three commits per PR3 are visible in the log (introduce, compose, sweep). PR1 and PR2 are one commit each.
- [ ] `NEXT.md` A.3 #1 progress note updated.
