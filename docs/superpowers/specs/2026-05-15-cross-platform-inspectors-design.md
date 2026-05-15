# Cross-Platform Inspector Panels + iOS NavigationSplitView 3-Column — Design

**Status:** Draft (brainstorming complete; awaiting user review)
**Date:** 2026-05-15
**Closes:** Combined slice of NEXT.md A.3 #7 ("iOS feature parity") and A.3 #9 ("`canImport(AppKit)` switching… extract a shared `EditorWorkspaceScene`"), scoped to the inspector surface. The other open slices of A.3 #7 (workspace files/search on iOS, tab strip, find/replace, command palette) are explicitly deferred.
**Scope:** Sample-side, plus a single gate removal in `CodeEditorUI`. No framework changes.

## Context

The macOS sample exposes a rich inspector right-rail (LSP / Performance / Completion / Annotations / EventLog / Configuration text + Copy). The iOS sample's `Inspectors` detail panel currently renders only `EventLogPanel` plus a `ContentUnavailableView` explaining that the other inspectors are macOS-only.

That explainer is mostly an artifact of how the panels were originally written. A read of the code shows:

- `LSPInspectorPanel`, `PerformanceInspectorPanel`, `CompletionInspectorPanel`, `AnnotationsInspectorPanel` are gated `#if canImport(AppKit)`, but their bodies are pure SwiftUI — the gate is transitive (they used to live inside the AppKit-only `EditorSidebarShell`), not because the panels themselves need AppKit.
- `EditorSidebarShell` itself is `#if canImport(AppKit)` only because its docstring once promised it didn't cover iPad's navigation idiom; the body uses `platformGlassSurface(.panel)`, which is fully cross-platform.
- `PerformanceSampleCoordinator` and `CompletionSampleCoordinator` are gated, but neither uses AppKit symbols beyond one `NSScreen.main?.maximumFramesPerSecond` lookup in the performance coordinator.
- The single hard AppKit dependency in the inspector surface is `NSPasteboard.general` in `InspectorSidebar.copyToPasteboard(_:)` — replaceable with a one-file `Pasteboard.writeString(_:)` helper.
- The one inspector genuinely AppKit-bound is `LSPInspectorPanel`'s data source, because `LSPSampleCoordinator` depends on the framework's `LSPManager`, which is itself `#if canImport(AppKit)` today (B.1 LSP iOS coverage is approved-as-spec but not implemented).

iPad also lacks a 3-column layout. The current `IOSRootView` is a 2-column `NavigationSplitView` (sidebar list + detail), which means inspectors are a *destination* rather than an *ambient panel*. With the inspector panels themselves portable, we can promote iPad to a true 3-column form and give it parity with the macOS three-pane shell.

This spec lights up real inspector data on iOS, extracts the shared `InspectorPanelStack` view that both platforms host, drops three preparatory `#if canImport(AppKit)` gates, and promotes iPad to a user-toggleable 3-column `NavigationSplitView`.

## Goals

- Render the full inspector stack (LSP / Performance / Completion / Annotations / EventLog / Config) on iPad and iPhone.
- iPad gets a 3-column `NavigationSplitView` with a user-toggleable right inspector column.
- iPhone keeps its current 2-column behaviour; `Inspectors` sidebar destination still works.
- Replace `NSPasteboard.general` with a cross-platform `Pasteboard.writeString(_:)` helper.
- Drop `#if canImport(AppKit)` gates where the body has no AppKit dependency (`EditorSidebarShell`, 4 inspector panel views, 2 sample coordinators).
- Move `memoryMonitor` / `performanceObservation` / `performance` / `completion` out of the `#if canImport(AppKit)` block in `AppState`. Keep `lsp` AppKit-only.
- Show an in-panel "unavailable" hint inside `LSPInspectorPanel` on iOS so the LSP slot is visible and self-documenting until B.1 lands.
- Snapshot-test the new `InspectorPanelStack` on both platforms.

## Non-goals

- **iOS workspace surface** (`FilePanelView` / `ProjectSearchPanelView` on iOS). Out — separate slice in NEXT.md A.3 #7 decomposition.
- **iOS tab strip / multi-document switching UX.** Out — separate slice.
- **iOS find/replace overlay.** Out — separate slice.
- **iOS command palette.** Out — separate slice.
- **iOS presets switching surface.** Out — the settings detail's existing knob sections cover preset-shaped configuration today.
- **B.1 LSP iOS coverage.** Not moved forward by this slice. The iOS `LSPInspectorPanel` renders with hardcoded `.off` state + footnote; B.1 lands the real `LSPSampleCoordinator` iOS path later, and this spec does not block on it.
- **Promoting `EditorTitleBar` / `EditorTrafficLights` to cross-platform.** They stay AppKit-only; iOS uses system navigation chrome.
- **`EditorWorkspaceScene` shell.** Discussed during brainstorming and explicitly rejected: macOS uses `HStack` with toggles + custom chrome (title bar, tab strip, status bar, command palette overlay); iPad uses `NavigationSplitView`. The layout primitives don't compose. We share *content fragments* (`InspectorPanelStack`) instead of a wrapper scene.
- **`AppState` decomposition follow-ups** (`AnnotationsModel`, `NavigationModel`, coordinator wrappers). Out — separate from this spec.

## Approach

Three orthogonal pieces, all sample-side except the `EditorSidebarShell` gate removal:

1. **Extract `InspectorPanelStack`** — a cross-platform `View` that composes the six panels in order, lifted out of `InspectorSidebar`.
2. **Drop preparatory AppKit gates** — on `EditorSidebarShell`, four inspector panel views, two sample coordinators, and the gated property block in `AppState`.
3. **Reshape iPad layout** — promote `IOSRootView` to a 3-column `NavigationSplitView` with a toolbar inspector toggle; the inspector column hosts `InspectorPanelStack` when the `.editor` sidebar destination is selected.

After this:

- macOS `InspectorSidebar` shrinks to a thin `EditorSidebarShell` wrapper around `InspectorPanelStack`. Renders identically.
- iPad's `.editor` destination renders the editor in the middle column and inspector panels in the right column (toggleable). Other destinations (Settings / Themes / Languages / Inspectors) collapse the right column.
- iPhone is visually unchanged. The existing `.inspectors` sidebar destination now renders `InspectorPanelStack` (six real panels) instead of `EventLogPanel` + the macOS-only explainer.
- The iOS LSP panel shows a disabled `Attach sourcekit-lsp` toggle plus a one-line footnote pointing at B.1.

## Surface changes

### New file — `Sources/CodeEditorSample/Sidebars/InspectorPanelStack.swift`

```swift
import CodeEditorPlugin
import SwiftUI

/// Cross-platform composition of the six inspector panels. Hosted by
/// macOS `InspectorSidebar` (wrapped in `EditorSidebarShell`) and by
/// `IOSRootView` (rendered raw in the `NavigationSplitView` detail
/// column). Reads everything off `AppState`; owns no state itself
/// except the performance-report sheet binding, which the host passes
/// in so the sheet survives column-visibility toggles.
struct InspectorPanelStack: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var appState: AppState
    @Binding var showingPerformanceReport: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                lspPanel
                performancePanel
                completionPanel
                AnnotationsInspectorPanel(
                    hub: appState.annotationsHub,
                    controller: appState.documents.editorController
                )
                eventLogPanel
                configurationText
            }
        }
        .sheet(isPresented: $showingPerformanceReport) {
            performanceReportSheet
        }
    }

    @ViewBuilder
    private var lspPanel: some View {
        #if canImport(AppKit)
        LSPInspectorPanel(
            state: appState.lsp.state,
            counts: appState.lsp.diagnosticCounts,
            serverPath: appState.lsp.resolvedServerPath,
            lastError: appState.lsp.lastError,
            isSwiftActive: appState.documents.store.active?.language == .swift,
            onToggle: { handleToggle() }
        )
        #else
        LSPInspectorPanel(
            state: .off,
            counts: .empty,
            serverPath: nil,
            lastError: nil,
            isSwiftActive: false,
            onToggle: {}
        )
        Text("iOS: remote-server support arrives with the LSP iOS coverage rollout.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        #endif
    }

    // performancePanel, completionPanel, eventLogPanel, configurationText,
    // performanceReportSheet — lifted verbatim from InspectorSidebar.

    #if canImport(AppKit)
    private func handleToggle() { /* lifted from InspectorSidebar */ }
    #endif
}
```

The `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` body shrinks to:

```swift
struct InspectorSidebar: View {
    @Bindable var appState: AppState
    @State private var showingPerformanceReport = false

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Configuration",
            content: {
                InspectorPanelStack(
                    appState: appState,
                    showingPerformanceReport: $showingPerformanceReport
                )
            }
        )
        .frame(width: 360)
    }
}
```

The Copy button lives inside `InspectorPanelStack.configurationText` so it renders on both platforms from a single source via `Pasteboard.writeString`. The `EditorSidebarShell` footer slot is no longer used (default `EmptyView()`); the macOS shell ends with the config-text card just like iOS.

### New file — `Sources/CodeEditorSample/Extensions/Pasteboard.swift`

```swift
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum Pasteboard {
    @MainActor
    static func writeString(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}
```

### Gate removals — no body changes beyond the gate itself

- `Sources/CodeEditorUI/Sidebar/EditorSidebarShell.swift` — drop the top-level `#if canImport(AppKit)` / `#endif`. Rewrite the docstring: from "Available on macOS. Absent on iOS…" to "Used by both platforms. Renders a glass-backed panel with optional section/prominent header."
- `Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift` — drop gate + unused `import AppKit` if present.
- `Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift` — drop gate.
- `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift` — drop gate.
- `Sources/CodeEditorSample/Sidebars/AnnotationsInspectorPanel.swift` — drop gate.
- `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` — keeps its `#if canImport(AppKit)` (it's macOS chrome by design).
- `Sources/CodeEditorSample/App/Performance/PerformanceSampleCoordinator.swift` — drop gate; replace `import AppKit` with the cross-platform import block; replace `NSScreen.main?.maximumFramesPerSecond ?? 60` with `Self.screenMaxFPS()`:
  ```swift
  private static func screenMaxFPS() -> Int {
      #if canImport(AppKit)
      return NSScreen.main?.maximumFramesPerSecond ?? 60
      #elseif canImport(UIKit)
      return UIScreen.main.maximumFramesPerSecond
      #else
      return 60
      #endif
  }
  ```
- `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift` — drop gate + `import AppKit` (no AppKit symbols used; the gate was defensive only).

### `Sources/CodeEditorSample/App/AppState.swift`

Move four properties out of the `#if canImport(AppKit)` block:

```swift
let memoryMonitor = MemoryMonitor()
let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))
private(set) var performance: PerformanceSampleCoordinator!
private(set) var completion: CompletionSampleCoordinator!

#if canImport(AppKit)
private(set) var lsp: LSPSampleCoordinator!
#endif
```

Update `init()` so the `PerformanceSampleCoordinator` + `CompletionSampleCoordinator` wiring blocks live outside the existing `#if canImport(AppKit)` block. The `LSPSampleCoordinator` block stays gated.

### `Sources/CodeEditorSample/iOS/IOSRootView.swift`

Reshape to a 3-column `NavigationSplitView` with toolbar inspector toggle:

```swift
struct IOSRootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Bindable var appState: AppState

    @State private var sidebarSelection: IOSSidebarSection? = .editor
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showingPerformanceReport = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            detail(for: selectedSection)
                .navigationTitle(title(for: selectedSection))
                .toolbar { toolbar(documents: appState.documents.store) }
        } detail: {
            inspectorRail
        }
        .onChange(of: sidebarSelection) { _, newValue in
            if newValue != .editor {
                columnVisibility = .doubleColumn
            }
        }
        // existing modifiers — codeTheme, sheets — preserved.
    }

    @ViewBuilder
    private var inspectorRail: some View {
        if selectedSection == .editor {
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: $showingPerformanceReport
            )
            .navigationTitle("Inspectors")
        } else {
            EmptyView()
        }
    }

    @ToolbarContentBuilder
    private func toolbar(documents: EditorDocuments) -> some ToolbarContent {
        // existing File menu — unchanged
        ...

        if hSizeClass != .compact {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    columnVisibility = (columnVisibility == .all) ? .doubleColumn : .all
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .disabled(selectedSection != .editor)
            }
        }
    }
}
```

The existing `inspectorsUnavailable` view is **deleted**; the `.inspectors` sidebar destination's `detail(for:)` branch becomes:

```swift
case .inspectors:
    InspectorPanelStack(
        appState: appState,
        showingPerformanceReport: $showingPerformanceReport
    )
```

The `.performanceObserver(appState.performanceObservation)` modifier is added to the iOS editor pane (it had been omitted because `performanceObservation` was AppKit-gated).

## Data flow

```
AppState (init, @MainActor, @Observable)
  ├── memoryMonitor: MemoryMonitor                  [moved out of #if]
  ├── performanceObservation: PerformanceObservation [moved out of #if]
  ├── performance: PerformanceSampleCoordinator      [moved out of #if]
  ├── completion:  CompletionSampleCoordinator       [moved out of #if]
  ├── annotationsHub: AnnotationsHub                 [cross-platform]
  ├── eventLog: EventLogSampleCoordinator            [cross-platform]
  └── lsp: LSPSampleCoordinator                      [#if canImport(AppKit) only]

iPad IOSRootView
  └── NavigationSplitView
      ├── sidebar (5 destinations)
      ├── content = detail(for: .editor) → CodeEditor + .performanceObserver(...)
      └── detail (inspectorRail, visible when .editor selected)
          └── InspectorPanelStack(appState:, $showingPerformanceReport)
              ├── LSPInspectorPanel(state: .off, ...) + iOS footnote
              ├── PerformanceInspectorPanel ← appState.performance.snapshot
              ├── CompletionInspectorPanel ← appState.completion.snapshot
              ├── AnnotationsInspectorPanel ← appState.annotationsHub + controller.symbols
              ├── EventLogPanel ← appState.eventLog.snapshot
              └── ConfigurationCodeFormatter.render(appState.configuration.current)
                      + Copy → Pasteboard.writeString
```

`NavigationSplitView`'s `columnVisibility` binding is the source of truth on iPad; the toolbar button toggles between `.all` and `.doubleColumn`. System-driven rotation events update it autonomously and we let them through. Switching `sidebarSelection` away from `.editor` forces `.doubleColumn` so the inspector column collapses for non-editor destinations.

## Edge cases

| Case | Handling |
|---|---|
| iPhone (compact width class) | `NavigationSplitView`'s 3-column form collapses to single-stack navigation automatically. Toolbar inspector toggle button is hidden by the `hSizeClass != .compact` check. Inspector rail never renders. `.inspectors` sidebar destination remains the iPhone path. |
| iPad portrait at launch | `NavigationSplitView` defaults to `.doubleColumn`. User taps toolbar toggle to reveal inspector. System overlays the column like Files.app — acceptable iPad idiom. |
| Selecting non-`.editor` destination on iPad with inspector column open | `.onChange(of: sidebarSelection)` forces `columnVisibility = .doubleColumn` so the inspector collapses. Returning to `.editor` does not auto-reopen (sticky off). |
| `.inspectors` sidebar destination on iPad | Renders `InspectorPanelStack` in the content (middle) column. Same content as the inspector rail, framed as a full-width focused view. Two-ways-in: acceptable per brainstorming. |
| Performance report sheet across column toggle | `showingPerformanceReport` is `@State` on the host (`InspectorSidebar` on macOS, `IOSRootView` on iOS) and passed in as `Binding`. Sheet survives column-visibility toggles because the host parents it. |
| LSPInspectorPanel on iOS | `state = .off`, `isSwiftActive = false`, `onToggle = {}` → toggle disabled. Footnote text under the toggle explains the constraint. No fake "starting…" or "running" states. |
| `PerformanceSampleCoordinator.targetFPS` on iOS | `UIScreen.main.maximumFramesPerSecond`. Deprecation chatter (UIScreen.main is soft-deprecated in iOS 16+) is acceptable for sample telemetry; window-scene threading is overkill. |
| `EditorSidebarShell` gate removal blast radius | Only macOS call sites consume it today. iPad inspector rail uses bare `InspectorPanelStack` in `NavigationSplitView`'s detail column. Removal is preparatory; no iOS site exercises the shell in this slice. |
| `EventLogPanel` previously rendered standalone in iOS `inspectorsUnavailable` | Removed from there. Now rendered inside `InspectorPanelStack`. iPhone `.inspectors` destination still surfaces it via the stack. |

## Testing

| Test | Type | Location |
|---|---|---|
| `InspectorPanelStack` macOS render — all panels populated with mock data | Snapshot (`.image`, precision 0.99) | `Tests/CodeEditorSampleTests/InspectorPanelStackSnapshotTests.swift` |
| `InspectorPanelStack` iOS render — LSP `.off` + footnote, other panels populated | Snapshot (iOS branch, `#if !canImport(AppKit)`) | same file |
| `Pasteboard.writeString` round-trip | XCTest — write "hello"; assert read-back on the platform's pasteboard | `Tests/CodeEditorSampleTests/PasteboardTests.swift` |
| `PerformanceSampleCoordinator` cross-platform init | Swift Testing — construct with mock dependencies; assert `targetFPS > 0` and snapshot fields initialised | `Tests/CodeEditorSampleTests/PerformanceSampleCoordinatorCrossPlatformTests.swift` |
| `CompletionSampleCoordinator` cross-platform init | Swift Testing — attach to a stub controller; assert `snapshot.registeredProviders` non-empty after attach | `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorCrossPlatformTests.swift` |

**Skipped on purpose**

- No automated test for `IOSRootView` 3-column / column-visibility behaviour. Without `ViewInspector` (not in the dependency set) or a full UI-test target, verifying `NavigationSplitView` column visibility is not first-class. Manual iPad simulator verification (step 5 of the verification gate) covers it.
- No tests for `EditorSidebarShell` cross-platform gate removal beyond the build-passes-on-iOS check.
- No tests for individual inspector panel views — they're unchanged. The existing `CompletionInspectorPanelSnapshotTests` / `PerformanceInspectorPanelSnapshotTests` (NEXT.md D) cover the per-panel rendering.
- No framework-side tests — no framework changes.

**Snapshot strategy**: follow the existing convention. Record with `isRecording: true`, eyeball, commit the PNG. `__Snapshots__/` excluded from git via `Package.swift`.

**Snapshot fixturing**: `InspectorPanelStack` reads from `AppState`, which is constructible without dependencies on a real workspace. The snapshot tests construct a sample `AppState`, optionally drive a few coordinator state mutations (e.g., open a fixture document so `completion.snapshot.registeredProviders` is non-empty), then snapshot. Implementation may also opt to refactor `InspectorPanelStack` to take per-panel inputs directly if the AppState fixturing proves brittle.

**Pre-existing flakes** (NEXT.md D, not blockers for this slice):

- `LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness` — flake under parallel load.
- `EditorStatusBarSnapshots/*` — SIGSEGV/SIGBUS under `swift test --parallel`. If it fires during this slice's verification, fall back to serial run; orthogonal problem.

## Verification gate

1. `swift build` (all targets).
2. `swiftlint --fix && swiftlint` — strict mode, no warnings.
3. `swift test --filter InspectorPanelStack && swift test --filter Pasteboard && swift test --filter CrossPlatform` (targeted).
4. `swift run CodeEditorSample` — macOS visual check that `InspectorSidebar` renders identically to before.
5. iPad simulator — open `.editor` destination, toggle inspector column, verify all six panels render; LSP panel shows disabled toggle + footnote; toggle hides inspector column.
6. iPhone simulator — verify single-column behaviour visually unchanged; `.inspectors` destination renders the new `InspectorPanelStack` (6 panels) instead of the old EventLog-plus-explainer.

## Risks

| Risk | Mitigation |
|---|---|
| `EditorSidebarShell` gate removal breaks something subtle on iOS | Only macOS call sites consume it in this slice; iPad inspector rail uses bare `InspectorPanelStack`. Worst case is a future iOS site renders oddly — caught at use, not here. |
| `NSScreen.main` / `UIScreen.main` deprecation chatter | Branch internally; `UIScreen.main.maximumFramesPerSecond` is acceptable for sample telemetry. Scene-aware lookup is overkill. |
| `PerformanceSampleCoordinator` 1Hz timer always-on on iOS | Timer only runs while the panel is `.onAppear`-ed → `start()`; stops on `.onDisappear` → `stop()`. iOS inspector column collapsed by default → never starts. Same lifecycle as macOS. |
| iPhone behaviour regression from `NavigationSplitView` 3-column form | iPhone collapses 3-column to single stack automatically. Toolbar toggle gated on `hSizeClass != .compact`; rail content gated on `selectedSection == .editor`. iPhone visual behaviour is unchanged from today. |
| `LSPInspectorPanel` on iOS shows confusing disabled toggle | Footnote line immediately below names the constraint. Mirrors macOS's "isSwiftActive == false" disabled visual rhythm. |
| Two-ways-in inspector overlap on iPad (`.inspectors` destination AND inspector column render same content) | Accepted trade-off. The `.inspectors` destination is the iPhone path; on iPad it doubles as a single-task full-width view. Document at file head. |
| Sheet across column toggle | Host owns `@State` for sheet visibility; `Binding` threaded into panel stack. Sheet survives column-visibility toggles. |
| Snapshot tests produce huge PNGs from a 6-panel scroll | Use `.image(precision: 0.99)` to absorb sub-pixel drift, matching existing inspector snapshot suite convention. |

## Done criteria

1. `InspectorPanelStack.swift` and `Pasteboard.swift` exist; macOS `InspectorSidebar` shrinks to a thin `EditorSidebarShell { InspectorPanelStack(...) }` wrapper.
2. `EditorSidebarShell` is cross-platform (no `#if canImport(AppKit)`); docstring rewritten.
3. Four inspector panel files and two sample coordinator files no longer carry `#if canImport(AppKit)`.
4. `AppState` exposes `memoryMonitor` / `performanceObservation` / `performance` / `completion` on both platforms; `lsp` remains AppKit-only.
5. `IOSRootView` renders a 3-column `NavigationSplitView` on iPad with toolbar inspector toggle (hidden on iPhone via `hSizeClass`); iPhone single-column behaviour visually unchanged.
6. On iPad `.editor` selected + inspector toggled on: LSP, Performance, Completion, Annotations, EventLog, Config render. LSP shows disabled toggle + footnote.
7. macOS `InspectorSidebar` renders identically to before (regression-free refactor).
8. `swift build && swiftlint --fix && swiftlint && swift test --filter InspectorPanelStack && swift test --filter Pasteboard && swift test --filter CrossPlatform` all pass.
9. NEXT.md A.3 #7 entry updated to record the inspector-parity slice as done; the remaining slices (workspace surface, tab strip, find/replace, command palette, presets) listed as still open.
10. NEXT.md A.3 #9 entry updated to reflect that the "shared scene" intent landed as `InspectorPanelStack` content sharing rather than an `EditorWorkspaceScene` layout wrapper, with rationale noted (layout-primitive divergence between platforms).
