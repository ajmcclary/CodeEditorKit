# NEXT — Outstanding Work

Tracking what's left after the long refactor / review cycle that just landed. Two major buckets: sample-app gap analysis (where the sample fails to demonstrate framework surface) and framework-side leftovers (open items the review pass deliberately deferred).

---

## A. CodeEditorSample gap analysis

The sample already covers a lot: 25 languages, 20 themes, 8 presets, all four knob domains (Display/Layout/Behavior/Performance), find/replace, command palette, annotations demo, multi-tab, iOS + macOS. But several first-class framework subsystems are still invisible to a consumer reading this code.

### A.1 Missing capabilities (framework features the sample doesn't demonstrate)

**Event stream invisible.** `UnifiedEventSystem` + `EditorEvent` (textDidChange, selectionDidChange, languageDidChange, themeDidChange, …) — no event log panel. The `.eventSystem(_:)` modifier is undemonstrated. This is the natural next headline gap — three coordinator templates are already in place (LSP / Completion / Performance Inspector panels), so a fourth `EventLogPanel` is straightforward.

**Workspace search.** `PortableProjectSearchAdapter` and `ProjectSearchProvider` exist; the sample's find/replace is single-file only. A workspace search sidebar is the obvious demo.

**Symbol navigation backed by real data.** `SymbolNavigator` + `DocumentSymbolProvider` are framework-grade; `GotoSymbolSheet.swift` likely fakes the symbol list. Verify it queries the provider.

**File tree / workspace browser.** Workspace root is configurable but nothing displays its contents. A `FileSystemActor`-backed file tree in the left sidebar would close the loop.

**Save-As for `Untitled-*` tabs.** `⌘S` writes through `EditorDocuments.save(_:)` with `SaveOutcome` routing, but Save-As for untitled tabs was deliberately deferred. Needs an `NSSavePanel` flow on macOS and an iOS document-picker variant. `⌘O` is still a no-op.

**`CodeEditorUI` components underused.** `EditorTitleBar`, `EditorTrafficLights`, `EditorBreadcrumbView`, and `PlatformGlassSurface` are now exercised via `.windowStyle(.hiddenTitleBar)` + `RootWindow` chrome. Only `EditorSidebarShell` remains unconsumed.

**Theme authoring.** Only the bundled `zed-trek` family is shown. Loading a user-supplied Zed JSON from disk would showcase `ThemeFamily.bundled(...)` as well as the JSON pipeline.

**Custom syntax highlighter.** `SyntaxHighlighter` / `HighlightingStrategy` protocols — no example of plugging one in.

**Error recovery UI.** `ErrorRecoveryCoordinator` and `RecoverableAsyncError` are unexercised — no demo error state with a user-triggered recovery affordance. `CodeEditorError.languageServerNotAvailable` / `.languageServerCommunicationFailed` already surface in `LSPSampleCoordinator` via `userFacingMessage(for:)` so the recovery-copy plumbing is wired; only the user-facing affordance is missing.

**Find/Replace match highlighting.** `EditorActions/FindReplaceOverlay.swift` tracks counts but doesn't decorate matches in the text. `SearchReplaceEngine` supports this.

**Design tokens.** `CodeEditorDesignTokens` is imported across UI but the sample never *teaches* it — no panel showing token swatches, type ramp, or how to consume `Tokens.Color.EditorColors`/`Tokens.Spacing`.

### A.2 Concrete additions

| New surface | Where it goes | What it demos |
|---|---|---|
| `EventLogPanel` | Inspector sidebar | Tail of `EditorEvent` stream with filtering |
| `WorkspaceFileTreeSidebar` | New left-rail above settings, or as a Switcher tab | Tree from `workspaceRoot` via `FileSystemActor` |
| `ProjectSearchSidebar` | New left section | Cross-file find using `PortableProjectSearchAdapter` |
| `ThemeImporter` | Switchers | Load Zed JSON from disk |
| `DesignTokenGallery` | Settings tab | Swatches/typography ramp showing `CodeEditorDesignTokens` |

### A.3 What to refactor in the existing sample

1. **`AppState` is a god object.** It owns theme, configuration, documents, editor controller, annotations, find state, performance observation, and a host of coordinators. Split into feature-scoped `@Observable` models (`ThemeModel`, `ConfigurationModel`, `FindReplaceModel`, etc.) — the `pfw-observable-models` and `pfw-dependencies` conventions favor this, and the framework's DI story is "no singletons."

2. ~~**`PresetCatalog.swift` likely duplicates framework presets.**~~ Verified: already uses `EditorConfiguration.default` / `.minimal` / `.readOnly` / `.markdown` / `.presentation` / `.macOS` / `.iOS` / `.platformOptimized` directly. Smoke-tested in `SwitcherCatalogTests`.

3. ~~**`GotoSymbolSheet.swift`**~~ Verified: already reads from `controller.symbols` (`SymbolNavigator`-backed) and calls `controller.gotoSymbol(_:)` — no static stub to replace.

4. **Find/Replace overlay** should call `SearchReplaceEngine` for both navigation and decoration, not maintain its own match counter logic.

5. **`InspectorSidebar.swift`'s config export** should also accept paste-in (round-trip), demonstrating `EditorConfiguration` parsing/validation (`validate()`, `validateAndThrow()`).

6. **`AnnotationsHub`** is currently a demo data source. Promote its protocol surface as a documented example of how third parties plug in custom annotation providers — it is the clearest existing pattern for "user-supplied data source", and the LSP diagnostic demo consumes the same protocol.

7. **iOS feature parity.** `IOSRootView.swift` exposes Editor/Settings/Themes/Languages/Inspectors only — no presets, no annotations panel, no workspace knobs. Mirror the macOS knob sections through `NavigationSplitView`.

8. **`SettingsScene.swift`** (macOS ⌘,) is reportedly untouched boilerplate. It should host the more "global" settings (theme, presets, performance), while the inline sidebar focuses on per-document knobs — current arrangement has both showing everything.

9. **`canImport(AppKit)` switching is fine, but `RootWindow.swift`/`WindowBody.swift`/`IOSRootView.swift` re-implement layout twice.** Extract a shared `EditorWorkspaceScene` view that composes sidebars + main editor and let each platform supply its own chrome.

10. ~~**Sample tests.**~~ Smoke coverage landed for the no-design path: `EditorDocumentsOpenFileTests` (`openFile` / `save` / `newTab`), `EditorDocumentsSampleExtrasTests` (`resetToSample`, `setLanguageRenaming`), `SwitcherCatalogTests` (`PresetCatalog` / `LanguageCatalog` / `ThemeCatalog`), `AnnotationsHubInstallTests`, `AnnotationsHubDiagnosticsTests`. Snapshot-test conventions still to apply for inspector panels.

---

## B. Framework-side leftovers from review pass

These items the recent review pass deliberately deferred. Each needs its own design conversation before code lands.

### B.1 LSP iOS coverage
Docs claim "remote servers on iOS" but the implementation of `LSPManager`, `LSPCompletionProvider`, `LSPSemanticTokenProvider`, `LSPDocumentManager`, `LSPClientRegistry`, `LSPContentCoordinator`, and `LSPPathResolver` is gated to `#if canImport(AppKit)`. Either add iOS support (likely via the existing `LSPClient` / `WebSocketTransport` primitives that are already cross-platform) or rewrite the docs and tighten the gates so the cross-platform / macOS-only split is honest.

Spec draft exists at `docs/superpowers/specs/2026-05-14-lsp-ios-coverage-design.md`.

### B.2 `.codeCompletion(provider:)` modifier is unread
After the SwiftUI modifier return-types migration, `CodeEditorIntent.completionProvider` is set by the modifier but never read anywhere in `Sources/CodeEditorPlugin/`. The pre-existing bug was preserved — fixing it requires deciding how a host-supplied SwiftUI-shape provider should compose with `CompletionManager`'s provider registry.

### B.3 `EditorState.isDirty` and `EditorState.hardwareAccelerationActive` never written
The framework's `EditorState` mirror writes `language`, `selection`, and `lineCount`; the remaining two fields (`isDirty`, `hardwareAccelerationActive`) have no writer. `isDirty` needs an initial-text tracking design; `hardwareAccelerationActive` needs adaptive-perf-mode bridging.

### B.4 ~~JSON `usesRegexHighlighter` redundancy~~ — done
JSON now opts out of the regex pipeline (`usesRegexHighlighter: false`) to match the descriptor's own docstring and the actual routing in `HighlightingStrategyExecutor` (`.json` → `FastJSONTokenizer`). `RegexRangeHighlightProvider.makeProvider` has no production callers; the multi-language regex test was updated to filter on the flag.

### B.5 ~~NSRulerView gutter TextKit 1 island~~ — done
`LineNumberRulerView` now delegates `drawHashMarksAndLabels(in:)` to `GutterViewRenderer` + `TextKitLineNumberHelper`, and fold-control hit-testing routes through the same TK2 helper. `NSTextView._layoutManager` stays nil through first paint (asserted by `LineNumberRulerViewTK2Tests`) — the TK1 compatibility shim is no longer synthesized. Active-line line-number coloring is wired through a new defaulted `activeLineNumber: Int?` parameter on `GutterViewRenderer.draw(...)` and refreshed on macOS via an `NSTextView.didChangeSelectionNotification` observer. Spec: `docs/superpowers/specs/2026-05-14-tk2-gutter-rewrite-design.md`; plan: `docs/superpowers/plans/2026-05-14-tk2-gutter-rewrite.md`.

### B.6 Save-As path
Sample-side. `EditorDocuments.save(_:)` covers tabs that already have URLs. Save-As for `Untitled-*` tabs needs an `NSSavePanel` flow on macOS and an iOS document-picker variant. Tracked under A.1 above for the sample side; framework changes (if any) are minimal — `EditorDocuments` already exposes the storage and dirty tracking.

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
| `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap` | Consistent failure on `main` — not investigated |
| `EditorStatusBarSnapshots/*` | SIGSEGV/SIGBUS under `swift test --parallel` — swift-testing helper launching XCTest snapshot suites in parallel |
| `PerformanceObservationTests.restartAfterStopResumesRefreshTicks` | Flake under parallel load; passes in isolation |
| `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor` | FPS counter doesn't run in headless test env |
| ~~`DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`~~ | Already updated in tree to `returnsFullCatalogue` (asserts the 5-label `SnippetTemplate` catalogue). |
| ~~`LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`~~ | Fixed: now asserts the message contains "language server" + "Swift" to match `CodeEditorError.languageServerNotAvailable("Swift")`'s `errorDescription` + `recoverySuggestion`. |
