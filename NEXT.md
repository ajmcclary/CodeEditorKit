# NEXT — Outstanding Work

Tracking what's left after the long refactor / review cycle that just landed. Two major buckets: sample-app gap analysis (where the sample fails to demonstrate framework surface) and framework-side leftovers (open items the review pass deliberately deferred).

---

## A. CodeEditorSample gap analysis

The sample already covers a lot: 25 languages, 20 themes, 8 presets, all four knob domains (Display/Layout/Behavior/Performance), find/replace, command palette, annotations demo, multi-tab, iOS + macOS. But several first-class framework subsystems are still invisible to a consumer reading this code.

### A.1 Missing capabilities (framework features the sample doesn't demonstrate)

~~**Event stream invisible.**~~ — done. `EventLogSampleCoordinator` + `EventLogPanel` now surface `UnifiedEventSystem.events` (text / selection / focus) layered with `controller.completionEvents()` in the macOS `InspectorSidebar` and the iOS `IOSRootView` Inspectors detail. Framework wiring converted three `eventPublisher.publishSync(...)` sites to `publishEvent(...)` and added focus-event responder overrides in `CodeEditorView+Responder.swift`. Spec: `docs/superpowers/specs/2026-05-14-event-log-panel-design.md`; plan: `docs/superpowers/plans/2026-05-14-event-log-panel.md`.

~~**Workspace search.**~~ — done. New `ProjectSearchPanelView` (Search tab of `WorkspaceSidebar`) drives `PortableProjectSearchAdapter` with case-sensitive / regex / file-extension controls; smart tab routing opens the file and selects the matched substring via `EditorController.selectMatch(_:)` + new `selectRange(_:scroll:)`. Spec: `docs/superpowers/specs/2026-05-14-workspace-surface-design.md`; plan: `docs/superpowers/plans/2026-05-14-workspace-surface.md`.

**Symbol navigation backed by real data.** `SymbolNavigator` + `DocumentSymbolProvider` are framework-grade; `GotoSymbolSheet.swift` likely fakes the symbol list. Verify it queries the provider.

~~**File tree / workspace browser.**~~ — done. `WorkspaceSidebar` (new left rail) hosts `FilePanelView` driven by a now-public `MacOSWorkspaceFileManager` (`WorkspaceFileTree` + `WorkspaceFileWatching`). Lazy disclosure, incremental updates from `WorkspaceFileWatching.events`, empty-state with Open Folder…, and File ▸ Open Folder… (⌘O). Spec / plan as above.

~~**Save-As for `Untitled-*` tabs.**~~ — done. `⌘S` on Untitled tabs now chains through `AppState.requestSave` → `requestSaveAs` → `DocumentPicker.save` (macOS `NSSavePanel`; iOS `UIDocumentPickerViewController` in export mode). Explicit Save As… (`⇧⌘S`) and Open File… (`⇧⌘O`) added; Go to Symbol… moved to `⌃⌘O`. `EditorDocuments.saveAs(to:)` rebinds the tab (url, name, language, isDirty). Spec: `docs/superpowers/specs/2026-05-15-save-as-open-file-design.md`; plan: `docs/superpowers/plans/2026-05-15-save-as-open-file.md`.

~~**`CodeEditorUI` components underused.**~~ — done. `EditorTitleBar`, `EditorTrafficLights`, `EditorBreadcrumbView`, and `PlatformGlassSurface` are exercised via `.windowStyle(.hiddenTitleBar)` + `RootWindow` chrome. `EditorSidebarShell` is now consumed three times: `WorkspaceSidebar` (Files / Search), `InspectorSidebar`, and via `SettingsScene`'s nested usage.

**Theme authoring.** Only the bundled `zed-trek` family is shown. Loading a user-supplied Zed JSON from disk would showcase `ThemeFamily.bundled(...)` as well as the JSON pipeline.

**Custom syntax highlighter.** `SyntaxHighlighter` / `HighlightingStrategy` protocols — no example of plugging one in.

**Error recovery UI.** `ErrorRecoveryCoordinator` and `RecoverableAsyncError` are unexercised — no demo error state with a user-triggered recovery affordance. `CodeEditorError.languageServerNotAvailable` / `.languageServerCommunicationFailed` already surface in `LSPSampleCoordinator` via `userFacingMessage(for:)` so the recovery-copy plumbing is wired; only the user-facing affordance is missing.

~~**Find/Replace match highlighting.**~~ — done. `FindReplaceOverlay` rewritten as a view-only host bound to a feature-scoped `FindReplaceModel`; framework `SearchOptions` gained `currentMatchColor` and the engine paints two layers + repaints on `findNext`/`findPrevious`. `EditorController.clearSearch` now actually clears highlights, and `replaceCurrent(with:)` lands the Xcode-style "replace then advance". Overlay also gained an expandable options row (case / whole-word / regex), live 150 ms debounced search, an Invalid-regex badge, and a single-match Replace button alongside Replace All. Spec: `docs/superpowers/specs/2026-05-15-find-replace-overlay-upgrade-design.md`; plan: `docs/superpowers/plans/2026-05-15-find-replace-overlay-upgrade.md`.

**Design tokens.** `CodeEditorDesignTokens` is imported across UI but the sample never *teaches* it — no panel showing token swatches, type ramp, or how to consume `Tokens.Color.EditorColors`/`Tokens.Spacing`.

### A.2 Concrete additions

| New surface | Where it goes | What it demos |
|---|---|---|
| ~~`EventLogPanel`~~ | ~~Inspector sidebar~~ | done |
| `WorkspaceFileTreeSidebar` | New left-rail above settings, or as a Switcher tab | Tree from `workspaceRoot` via `FileSystemActor` |
| `ProjectSearchSidebar` | New left section | Cross-file find using `PortableProjectSearchAdapter` |
| `ThemeImporter` | Switchers | Load Zed JSON from disk |
| `DesignTokenGallery` | Settings tab | Swatches/typography ramp showing `CodeEditorDesignTokens` |

### A.3 What to refactor in the existing sample

1. ~~**`AppState` is a god object.**~~ — conservative scope landed. `ThemeModel`, `ConfigurationModel`, and `DocumentsModel` extracted alongside the prior `FindReplaceModel`. `AppState` shrank from 306 to 179 lines and is now a composition root holding the un-extracted state (annotations hub, navigation flags, event system, find/replace) and the macOS-only coordinators. Knob panels and `SwitcherSection` migrated from `@Binding var X: Foo` to `@Bindable var X: FooModel` because the SwiftUI bindable projection through a `let`-bound nested `@Observable` class is not legal — passing the model directly is canonical (same shape as `FindReplaceOverlay`). `DocumentsModel.workspaceRootProvider` is a `[weak self]` closure injected at construction; `documents`, `annotationsHub`, and the macOS-only `lsp` / `performance` / `completion` fields are IUO `var`s (with SwiftLint inline disables) because Swift's definite-init analyzer rejects `[weak self]` captures during `let` initialization. Remaining slices (`AnnotationsModel`, `NavigationModel`, coordinator wrappers) deferred for follow-up designs. Spec: `docs/superpowers/specs/2026-05-15-appstate-decomposition-design.md`; plan: `docs/superpowers/plans/2026-05-15-appstate-decomposition.md`.

2. ~~**`PresetCatalog.swift` likely duplicates framework presets.**~~ Verified: already uses `EditorConfiguration.default` / `.minimal` / `.readOnly` / `.markdown` / `.presentation` / `.macOS` / `.iOS` / `.platformOptimized` directly. Smoke-tested in `SwitcherCatalogTests`.

3. ~~**`GotoSymbolSheet.swift`**~~ Verified: already reads from `controller.symbols` (`SymbolNavigator`-backed) and calls `controller.gotoSymbol(_:)` — no static stub to replace.

4. ~~**Find/Replace overlay** should call `SearchReplaceEngine` for both navigation and decoration, not maintain its own match counter logic.~~ — done alongside the A.1 entry above. Overlay now reads counters from `FindReplaceModel` (which mirrors `EditorController`); the framework paints both highlight layers via `SearchOptions.currentMatchColor` and the new `repaintCurrentMatch` hook.

5. **`InspectorSidebar.swift`'s config export** should also accept paste-in (round-trip), demonstrating `EditorConfiguration` parsing/validation (`validate()`, `validateAndThrow()`).

6. **`AnnotationsHub`** is currently a demo data source. Promote its protocol surface as a documented example of how third parties plug in custom annotation providers — it is the clearest existing pattern for "user-supplied data source", and the LSP diagnostic demo consumes the same protocol.

7. **iOS feature parity.** `IOSRootView.swift` exposes Editor/Settings/Themes/Languages/Inspectors only — no presets, no annotations panel, no workspace knobs. Mirror the macOS knob sections through `NavigationSplitView`. (Partial progress: the Inspectors detail now hosts `EventLogPanel` cross-platform — the first cross-platform inspector — alongside the existing macOS-only explainer.)

8. ~~**`SettingsScene.swift`** (macOS ⌘,)~~ — done. The inline `SettingsSidebar` is gone (deleted); `Settings { SettingsScene(...) }` is the only home for global settings. The left rail now hosts the workspace surface. Note: `SettingsScene` was already wired and populated before this work landed — the migration was a single-file deletion + binding rename, not a port of contents.

9. **`canImport(AppKit)` switching is fine, but `RootWindow.swift`/`WindowBody.swift`/`IOSRootView.swift` re-implement layout twice.** Extract a shared `EditorWorkspaceScene` view that composes sidebars + main editor and let each platform supply its own chrome.

10. ~~**Sample tests.**~~ Smoke coverage landed for the no-design path: `EditorDocumentsOpenFileTests` (`openFile` / `save` / `newTab`), `EditorDocumentsSampleExtrasTests` (`resetToSample`, `setLanguageRenaming`), `SwitcherCatalogTests` (`PresetCatalog` / `LanguageCatalog` / `ThemeCatalog`), `AnnotationsHubInstallTests`, `AnnotationsHubDiagnosticsTests`. Snapshot-test conventions still to apply for inspector panels.

---

## B. Framework-side leftovers from review pass

These items the recent review pass deliberately deferred. Each needs its own design conversation before code lands.

### B.1 LSP iOS coverage
Docs claim "remote servers on iOS" but the implementation of `LSPManager`, `LSPCompletionProvider`, `LSPSemanticTokenProvider`, `LSPDocumentManager`, `LSPClientRegistry`, `LSPContentCoordinator`, and `LSPPathResolver` is gated to `#if canImport(AppKit)`. Either add iOS support (likely via the existing `LSPClient` / `WebSocketTransport` primitives that are already cross-platform) or rewrite the docs and tighten the gates so the cross-platform / macOS-only split is honest.

Spec draft exists at `docs/superpowers/specs/2026-05-14-lsp-ios-coverage-design.md`.

### ~~B.2 `.codeCompletion(provider:) modifier is unread~~ — done
The modifier's closure is now wrapped as a `SwiftUIClosureCompletionProvider` and registered with the editor's `CompletionManager` from `CodeEditorBaseCoordinator` on every representable update (idempotent — only register/unregister on transitions, slot-swap on re-render). Built-in keyword completions are also live again: `LanguageKeywordCompletionProvider` is auto-registered per language by `CompletionManager.ensureBuiltInProvider(for:)`, called from `CodeEditorView.setupCompletionProviders()` and `language { didSet }`. The dead parallel `CompletionProviderRegistry` / `CompletionGenerationService` / `CompletionViewModel` / `EditorContainerViewModel` chain (plus the `EditorRuntime.completionProviderRegistry` accessor and `EditorCompletionRuntimeDependencies` struct) is gone. Spec: `docs/superpowers/specs/2026-05-15-completion-provider-unification-design.md`; plan: `docs/superpowers/plans/2026-05-15-completion-provider-unification.md`.

### ~~B.3 `EditorState.isDirty` and `EditorState.hardwareAccelerationActive` never written~~ — done
Closed. `EditorState.isDirty` now flows from a `DirtyTracker` driven by `CodeEditorBaseCoordinator` with four reset triggers (initial mount, host binding swap, `EditorController.markClean()`, and edits that return content to the baseline — covers undo). View-local semantics — the host owns document-level dirty tracking (e.g., `TabModel.isDirty`). `EditorState.hardwareAccelerationActive` is now written once at mount from `EditorConfiguration.Performance.useHardwareAcceleration` on macOS (always `true` on iOS — UIView is layer-backed); the knob actually gates `wantsLayer` across the editor's view family (text view, scroll view, container, gutter, minimap — seven source lines). Sticky at mount. Spec: `docs/superpowers/specs/2026-05-15-editor-state-mirror-completion-design.md`; plan: `docs/superpowers/plans/2026-05-15-editor-state-mirror-completion.md`.

### B.4 ~~JSON `usesRegexHighlighter` redundancy~~ — done
JSON now opts out of the regex pipeline (`usesRegexHighlighter: false`) to match the descriptor's own docstring and the actual routing in `HighlightingStrategyExecutor` (`.json` → `FastJSONTokenizer`). `RegexRangeHighlightProvider.makeProvider` has no production callers; the multi-language regex test was updated to filter on the flag.

### B.5 ~~NSRulerView gutter TextKit 1 island~~ — done
`LineNumberRulerView` now delegates `drawHashMarksAndLabels(in:)` to `GutterViewRenderer` + `TextKitLineNumberHelper`, and fold-control hit-testing routes through the same TK2 helper. `NSTextView._layoutManager` stays nil through first paint (asserted by `LineNumberRulerViewTK2Tests`) — the TK1 compatibility shim is no longer synthesized. Active-line line-number coloring is wired through a new defaulted `activeLineNumber: Int?` parameter on `GutterViewRenderer.draw(...)` and refreshed on macOS via an `NSTextView.didChangeSelectionNotification` observer. Spec: `docs/superpowers/specs/2026-05-14-tk2-gutter-rewrite-design.md`; plan: `docs/superpowers/plans/2026-05-14-tk2-gutter-rewrite.md`.

### B.6 ~~Save-As path~~ — done
Sample-side. Closed alongside the A.1 entry above. Zero framework changes; all I/O lives in `EditorDocuments+SampleExtras.swift` via the new `saveAs(to:)` plus security-scoped read/write helpers.

---

## C. Stale documentation diagrams

- ~~**`07-completion-system-architecture.md`**~~ — `SmartCompletionEngine` and `FuzzyMatcher` removed; class + sequence diagram rewritten around `CompletionManager` as the single funnel and `OptimizedFuzzyMatcher` as the lone matcher.
- ~~**`14-symbol-navigation-intelligence.md`**~~ — verified clean (only `OptimizedFuzzyMatcher` references).

The standing CLAUDE.md / AGENTS.md note about stale-claim symbols in older diagrams (`depermaid`, `ConfigurationBatchUpdater`, `PluginManager`, `ServiceLifecycle`, `CodeEditorSwiftUITheme`, `EditorTheme`, `LanguageConfig`, `CodeEditorLayoutManager`, `ConfigurationValidator`, `EditorConfigurationBuilder`, `ConfigurationMigrator`, `ConfigurationHotReload`, `PluginAPI`, `PluginContext`, `MarkdownPlugin`) still applies — no full diagram rewrite has happened.

---

## D. Test suite flakes / pre-existing failures

These were observed during the review pass and reproduce on bare `main`. Not introduced by recent work; worth investigating in a dedicated test-hygiene pass.

| Test | Symptom |
|---|---|
| ~~`RegexRangeHighlightProviderTests.testParsePerformance100KLines`~~ | Fixed: not a flake — fixture exceeded the parser's intentional 1 MB sync cap, so it returned 0 captures fast. Renamed to `testParseBailsOutForVeryLargeFiles` and rewritten to validate the cap contract. |
| `LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness` | Flake under parallel load; passes in isolation |
| ~~`ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`~~ | Fixed: `applyConfiguration` now snapshots `scrollView.contentView.bounds.origin` before layout-affecting mutations (`widthTracksTextView`, `isHorizontallyResizable`, container size) and restores it via `CATransaction` afterwards. The minimap-hidden branch of `layoutViewsAppKit` got the same save/restore for defence in depth. The wrap-on → wrap-off direction had been masked because that direction's reflow happened to leave origin near 0 already. |
| ~~`SyntaxHighlightingTests.testRegexHighlighterLanguageEnumMapping`~~ | Fixed: `.json` dropped from the `supportedLanguages` list — NEXT.md B.4 took JSON out of the regex pipeline. |
| ~~`SyntaxHighlightingTests.testRegexHighlighterCustomLanguageProducesTokens`~~ | Fixed: same root cause, `.json` entry dropped from the `(Language, source)` tuple list. |
| `EditorStatusBarSnapshots/*` | SIGSEGV/SIGBUS under `swift test --parallel` — swift-testing helper launching XCTest snapshot suites in parallel. Passes in isolation. Runner-level infra issue; needs serialisation hook before re-enabling under parallel. |
| ~~`PerformanceObservationTests.restartAfterStopResumesRefreshTicks`~~ | Fixed: test now uses `observation.refresh()` as a deterministic stand-in tick across the stop / restart boundary rather than relying on a 20 ms timer firing under parallel load. Still verifies the behaviour it claims — stop blocks recording, start after stop allows recording again. |
| ~~`PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`~~ | Fixed: added a public `PerformanceInsights.refresh()` hook (sync analogue of one timer tick); the test now drives metric collection explicitly instead of sleeping for a `Timer.scheduledTimer` tick that doesn't fire reliably in headless test envs. |
| ~~`CompletionInspectorPanelSnapshotTests` / `PerformanceInspectorPanelSnapshotTests` / `LineNumberRulerViewSnapshotTests.testRulerRendersBaselineFiveLines`~~ | Re-recorded reference PNGs to current rendering output — drift, not regression (sub-pixel text/glyph differences from OS-level rendering updates). |
| ~~`DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`~~ | Already updated in tree to `returnsFullCatalogue` (asserts the 5-label `SnippetTemplate` catalogue). |
| ~~`LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`~~ | Fixed: now asserts the message contains "language server" + "Swift" to match `CodeEditorError.languageServerNotAvailable("Swift")`'s `errorDescription` + `recoverySuggestion`. |
