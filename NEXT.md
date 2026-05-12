# NEXT — CodeEditorSample Gap Analysis

The sample already covers a lot: 25 languages, 20 themes, 8 presets, all four knob domains (Display/Layout/Behavior/Performance), find/replace, command palette, annotations demo, multi-tab, iOS + macOS. But several first-class framework subsystems are completely invisible to a consumer reading this code.

## Missing capabilities (framework features the sample doesn't demonstrate)

**LSP — entirely stubbed.** `Sources/CodeEditorPlugin/LSP/` ships `LSPManager`, `LSPClient`, `LSPCompletionProvider`, `ProcessTransport`, `WebSocketTransport`, full diagnostic/hover/definition/symbol params, `LSPServerConfiguration` (local + remote), retry config, and capability negotiation. The sample only sets `workspaceRoot` via `WorkspaceKnobsSection.swift`. There is no actual server attached, no diagnostics surfaced, no hover/definition action, no inline error squiggle.

**Code completion — protocol is hidden.** `CompletionManager`, the `CompletionProvider` protocol, `SmartCompletionEngine`, `CompletionDebouncer`, and the ready-made language member completions (Swift/JS/TS/Python/Go/Rust/C++/Java/Ruby/PHP/YAML/Markdown/JSON) are never wired to a UI. A toggle exists in `BehaviorKnobsSection.swift` but no panel shows what completions look like or how to register a custom provider.

**Performance HUD missing.** `PerformanceMonitor`, `MemoryMonitor`, `UnifiedPerformanceSystem`, `PerformanceInsights`, `AdaptivePerformanceMode`, and the metric/report families have no live view. This is a major selling point of the framework and there is no `PerformanceInspectorPanel.swift` next to `LSPStatusPanel.swift`.

**Event stream invisible.** `UnifiedEventSystem` + `EditorEvent` (textDidChange, selectionDidChange, languageDidChange, themeDidChange, …) — no event log panel. The `.eventSystem(_:)` modifier is undemonstrated.

**Workspace search.** `PortableProjectSearchAdapter` and `ProjectSearchProvider` exist; the sample's find/replace is single-file only. A workspace search sidebar is the obvious demo.

**Symbol navigation backed by real data.** `SymbolNavigator` + `DocumentSymbolProvider` are framework-grade; `GotoSymbolSheet.swift` likely fakes the symbol list. Verify it queries the provider.

**File tree / workspace browser.** Workspace root is configurable but nothing displays its contents. A `FileSystemActor`-backed file tree in the left sidebar would close the loop.

**Document persistence.** ⌘S/⌘O are no-ops per `DocumentStore.swift`. With `FileSystemActor` available, this should actually save.

**CodeEditorUI components underused.** `EditorBreadcrumbView`/`BreadcrumbComponent`, `EditorSidebarShell`, `EditorTitleBar`, `EditorTrafficLights`, and `PlatformGlassSurface` aren't exercised. A breadcrumb row between tabs and editor is the easiest win.

**Theme authoring.** Only the bundled `zed-trek` family is shown. Loading a user-supplied Zed JSON from disk would showcase `ThemeFamily.bundled(...)` as well as the JSON pipeline.

**Custom syntax highlighter.** `SyntaxHighlighter` / `HighlightingStrategy` protocols — no example of plugging one in.

**Error recovery UI.** `CodeEditorError`, `ErrorRecoveryCoordinator`, `RecoverableAsyncError` — no demo error state, no recovery affordance.

**Find/Replace match highlighting.** `EditorActions/FindReplaceOverlay.swift` tracks counts but doesn't decorate matches in the text. `SearchReplaceEngine` supports this.

**Design tokens.** `CodeEditorDesignTokens` is imported across UI but the sample never *teaches* it — no panel showing token swatches, type ramp, or how to consume `Tokens.Color.EditorColors`/`Tokens.Spacing`.

## What needs to be presented (concrete additions)

| New surface | Where it goes | What it demos |
|---|---|---|
| `LSPInspectorPanel` | Inspector sidebar | Spawn a local server via `ProcessTransport`, show capabilities + live diagnostics |
| `PerformanceInspectorPanel` | Inspector sidebar | FPS, memory, highlight times, adaptive-mode state |
| `EventLogPanel` | Inspector sidebar | Tail of `EditorEvent` stream with filtering |
| `WorkspaceFileTreeSidebar` | New left-rail above settings, or as a Switcher tab | Tree from `workspaceRoot` via `FileSystemActor` |
| `ProjectSearchSidebar` | New left section | Cross-file find using `PortableProjectSearchAdapter` |
| `BreadcrumbBar` between tabs and editor | `WindowBody.swift` | `EditorBreadcrumbView` |
| `DiagnosticsGutterDemo` | Wire `AnnotationsDataSource` to LSP `Diagnostic` | Live error/warning badges |
| `CompletionDemoOverlay` | Behavior knobs | Register a custom `CompletionProvider`, show fired items |
| `ThemeImporter` | Switchers | Load Zed JSON from disk |
| `DesignTokenGallery` | Settings tab | Swatches/typography ramp showing `CodeEditorDesignTokens` |

## What to refactor in the existing sample

1. **`AppState` is a god object.** It owns theme, configuration, documents, editor controller, annotations, find state. Split into feature-scoped `@Observable` models (`ThemeModel`, `ConfigurationModel`, `FindReplaceModel`, etc.) — the `pfw-observable-models` and `pfw-dependencies` conventions favor this, and the framework's DI story is "no singletons."

2. **`PresetCatalog.swift` likely duplicates framework presets.** Verify it uses `EditorConfiguration.minimal`/`.readOnly()`/`.markdown()`/`.presentation()` directly rather than reconstructing them; the sample should be the canonical demonstration of how presets compose.

3. **`GotoSymbolSheet.swift`** — if it's static, replace with `SymbolNavigator` + `DocumentSymbolProvider` so the sheet *is* the API demo.

4. **Find/Replace overlay** should call `SearchReplaceEngine` for both navigation and decoration, not maintain its own match counter logic.

5. **`InspectorSidebar.swift`'s config export** should also accept paste-in (round-trip), demonstrating `EditorConfiguration` parsing/validation (`validate()`, `validateAndThrow()`).

6. **`AnnotationsHub`** is currently a demo data source. Promote its protocol surface as a documented example of how third parties plug in custom annotation providers — it is the clearest existing pattern for "user-supplied data source", and the LSP diagnostic demo above should consume the same protocol.

7. **iOS feature parity.** `IOSRootView.swift` exposes Editor/Settings/Themes/Languages only — no presets, no annotations panel, no workspace knobs. Mirror the macOS knob sections through `NavigationSplitView`.

8. **`SettingsScene.swift`** (macOS ⌘,) is reportedly untouched boilerplate. It should host the more "global" settings (theme, presets, performance), while the inline sidebar focuses on per-document knobs — current arrangement has both showing everything.

9. **`canImport(AppKit)` switching is fine, but `RootWindow.swift`/`WindowBody.swift`/`IOSRootView.swift` re-implement layout twice.** Extract a shared `EditorWorkspaceScene` view that composes sidebars + main editor and let each platform supply its own chrome.

10. **No tests.** `Sources/CodeEditorSampleTests` exists per `Package.swift`; ensure the sample's `DocumentStore`, `AnnotationsHub`, and switcher catalogs have at least smoke tests using `pfw-testing` and `pfw-snapshot-testing` conventions — the sample is the de facto integration test for the public API.

## Recommended next step

The biggest single demo gap is **LSP + diagnostics + completion + performance HUD**, because those are the four headline features a framework consumer evaluates first. Start with a `PerformanceInspectorPanel` (low risk, no external dependencies) or sketch the LSP wiring (higher value but needs a real server binary to be useful).
