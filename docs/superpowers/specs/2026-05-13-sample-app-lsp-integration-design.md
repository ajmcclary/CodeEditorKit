# Sample-App LSP Integration — Design

**Status**: Approved, ready for implementation planning
**Date**: 2026-05-13
**Scope**: `CodeEditorSample` target + small additions to `CodeEditorPlugin`
**Platforms**: macOS only (iOS sample is unaffected)

## Problem

The framework ships a complete LSP subsystem (`LSPManager`, `LSPClient`, `ProcessTransport`, `WebSocketTransport`, diagnostic/hover/definition/symbol params, retry config, capability negotiation, `LSPCompletionProvider`), but the sample only sets `workspaceRoot` via `WorkspaceKnobsSection.swift`. No server is attached, no diagnostics are surfaced, no hover or definition is exposed, and no inline error decoration exists. The sample is the de facto reference for how to consume the public API, so this gap leaves a major framework subsystem undocumented.

## Goals

1. Wire `sourcekit-lsp` to the active Swift document in the sample, end-to-end.
2. Surface diagnostics in the gutter and inline (wavy red underline).
3. Provide working Hover (mouse popover) and Go-to-Definition (⌘-click) actions.
4. Replace `LSPStatusPanel.swift` with `LSPInspectorPanel.swift` showing real server state.
5. Add the minimum framework surface needed to make this clean, so the sample remains a canonical reference and not a hack.

## Non-Goals

- LSP-based code completion (separate NEXT.md item — `CompletionDemoOverlay`).
- iOS LSP support (`ProcessTransport` is macOS-only; remote LSP on iOS is out of scope).
- Multi-server UX. Sample wires sourcekit-lsp only; the `LanguageServerConfig` plumbing trivially extends but no multi-server picker.
- Persisting the workspace root or open tabs across launches (separate NEXT.md item — Document persistence).
- Splitting `AppState` into feature-scoped models (separate NEXT.md refactor item; this spec adds `AppState.lsp` to the existing object and acknowledges the deferred work).
- Hover/click via Apple Pencil or touch.

## Architecture Overview

```
┌──────────────────────── CodeEditorPlugin (framework) ────────────────────────┐
│                                                                              │
│   CodeEditorView ─── applyTemporaryAttributes(_:to:)                         │
│        │       └──── .onTextHover(idleDelay:action:)                         │
│        │       └──── .onCommandClick(action:)                                │
│        │                                                                     │
│        ├── EditorController (existing)                                       │
│        └── AnnotationsDataSource (existing) ◄─── feeds gutter badges         │
│                                                                              │
│   LSPManager (existing) ─── activeClients, registerLanguageServer,           │
│                              start/stop, requestHover, requestDefinition     │
│                                                                              │
│   New public type: SourcePosition { line, character }                        │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │  (public API only)
                                       │
┌──────────────────────── CodeEditorSample (target) ──────────────────────────┐
│                                                                              │
│   AppState (existing, @Observable)                                           │
│     └── lsp: LSPSampleCoordinator                  ◄── new, @Observable      │
│           ├── LSPManager                                                     │
│           ├── DocumentMirror     (in-mem doc → temp file URI)                │
│           ├── DiagnosticsBridge  (LSPClient.diagnostics → AnnotationsHub)    │
│           └── HoverSession       (hosts current hover popover state)         │
│                                                                              │
│   Views                                                                      │
│     ├── LSPInspectorPanel   (replaces LSPStatusPanel.swift)                  │
│     ├── LSPHoverPopover     (SwiftUI popover view content)                   │
│     └── (Editor view in WindowBody attaches .onTextHover/.onCommandClick)    │
│                                                                              │
│   DocumentStore.openFile(url:) — new sample-internal method for jump         │
│                                                                              │
│   macOS-only:  whole feature is wrapped in #if canImport(AppKit)             │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Boundary rules

- Framework grows by three public APIs and one public type. None know about LSP.
- LSP-specific glue lives entirely in the sample. A third-party consumer reads the sample to learn the pattern.
- `LSPSampleCoordinator` is the single owner of LSP state. `AppState.lsp` exposes it.
- iOS sample is unchanged — the entire feature is gated on `#if canImport(AppKit)`.

## Framework Additions

### `SourcePosition` — new public type

```swift
public struct SourcePosition: Sendable, Hashable {
    public let line: Int       // zero-based
    public let character: Int  // zero-based, UTF-16 code unit offset within the line
    public init(line: Int, character: Int)
}
```

File: `Sources/CodeEditorPlugin/Core/SourcePosition.swift`. UTF-16 offset chosen to match AppKit text APIs and the LSP wire format.

### `CodeEditorView.applyTemporaryAttributes(_:to:)`

```swift
public extension CodeEditorView {
    func applyTemporaryAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        to range: NSRange
    )
    func clearTemporaryAttributes(in range: NSRange)
    func clearAllTemporaryAttributes()
}
```

Layers over `NSTextLayoutManager.addRenderingAttribute(_:value:for:)` (the project is TextKit 2 per `CLAUDE.md`). A sample-side range registry tracks applied ranges so reapplication after edits is possible. Files:

- `Sources/CodeEditorPlugin/Text/TemporaryAttributesStore.swift` — internal store
- `Sources/CodeEditorPlugin/Core/CodeEditorView+TemporaryAttributesExtensions.swift` — public extension (`+Extensions` suffix per `CLAUDE.md`)

### `.onTextHover(idleDelay:action:)`

```swift
public extension View {
    func onTextHover(
        idleDelay: Duration = .milliseconds(500),
        action: @escaping @Sendable (SourcePosition?) async -> Void
    ) -> some View
}
```

`NSTrackingArea`-based; receives the resolved position under the pointer, or `nil` when over chrome (gutter, ruler). Pointer-only (mouseMoved events). Previous task is cancelled on pointer move before completion. File: `Sources/CodeEditorPlugin/Layout/TextHoverModifier.swift`.

### `.onCommandClick(action:)`

```swift
public extension View {
    func onCommandClick(
        action: @escaping (SourcePosition) -> Void
    ) -> some View
}
```

`NSEvent` local monitor on the editor window. Synchronously consumes the click so the editor does not reposition the caret. File: `Sources/CodeEditorPlugin/Layout/CommandClickModifier.swift`.

### Internal geometry helper

`EditorController` already contains private mouse-to-position translation logic for caret placement. The two new modifiers share this logic via a new internal `EditorGeometry` helper. No new public geometry primitives.

## Sample Components

All files wrapped in `#if canImport(AppKit)`. New files live under `Sources/CodeEditorSample/App/LSP/` unless noted.

### `LSPSampleCoordinator`

```swift
@MainActor
@Observable
final class LSPSampleCoordinator {
    enum State: Equatable {
        case off
        case starting
        case initializing
        case running(capabilities: ServerCapabilitiesSummary)
        case failed(message: String)
    }

    private(set) var state: State = .off
    private(set) var diagnosticCounts: DiagnosticCounts = .zero
    private(set) var lastError: String?

    func start(workspaceRoot: URL?) async
    func stop() async
    func requestHover(at: SourcePosition, in: TabModel.ID) async -> LSPHoverContent?
    func requestDefinition(at: SourcePosition, in: TabModel.ID) async -> [Location]
    func handleTextChange(for: TabModel.ID, newText: String)
}
```

Owns: `LSPManager`, `MemoryMonitor`, `DocumentMirror`, `DiagnosticsBridge`. Resolves `sourcekit-lsp` via `xcrun --find sourcekit-lsp` (via `Process`, captures stdout, trims). Resolution failure → `.failed`.

**Type mapping**: `Location` is the framework's existing LSP type (returned by `LSPManager.requestDefinition`) — passed through unchanged. `LSPHoverContent` is a sample-side struct that wraps the framework's `Hover` result with the markdown content pre-resolved (LSP `Hover.contents` can be markdown, plain text, or markdown blocks; the coordinator collapses the variants for the popover). The implementer may use the framework `Hover` directly if the variant handling is simple enough.

`ServerCapabilitiesSummary` is a sample-side struct that summarizes the LSP `ServerCapabilities` into 5–7 human-readable flags (hover, definition, diagnostics, completion, etc.).

### `DocumentMirror`

Per-tab on-disk shadow file. For each Swift tab:

- On first open: writes the current text to `<root>/.codeeditor-sample/<tab-uuid>.swift` where `<root>` is `workspaceRoot ?? FileManager.default.temporaryDirectory.appendingPathComponent("CodeEditorSample-LSP")`. Sends `textDocument/didOpen`.
- On `handleTextChange(for:newText:)`: writes the new text (debounced 150ms) and sends `textDocument/didChange` with full-text sync.
- On tab close / LSP stop: sends `textDocument/didClose` and deletes the shadow file.
- On `start()`: cleans up any leftover shadow directory from a previous run.

Non-Swift tabs are filtered out before mirroring.

### `DiagnosticsBridge`

```swift
@MainActor
final class DiagnosticsBridge {
    init(client: LSPClient, hub: AnnotationsHub, editorView: CodeEditorView)
    func start()
    func stop()
}
```

Observes the `LSPClient.diagnostics` `@Published` dictionary via Combine. On each emission for the active tab's mirror URI:

1. `editorView.clearAllTemporaryAttributes()` (drops stale squiggles).
2. For each diagnostic: convert LSP range → `NSRange` (UTF-16, current doc text) and call `editorView.applyTemporaryAttributes` with `.underlineStyle = NSUnderlineStyle([.single, .patternDot]).rawValue` and `.underlineColor = NSColor.systemRed` (warnings use `.systemYellow`, info/hint use `.systemBlue`).
3. Translate to `[Annotation]` (severity → kind, message → text, line from `range.start.line`).
4. `hub.replaceDiagnosticAnnotations(annotations)` → triggers `editorController.reloadAnnotations()`.
5. Updates `coordinator.diagnosticCounts`.

Active-tab scope: only the active tab's diagnostics paint squiggles. Diagnostics for other tabs are cached in a `[tabID: [Annotation]]` dict so gutter badges refresh on tab switch.

### `LSPInspectorPanel`

Replaces `Sources/CodeEditorSample/Sidebars/LSPStatusPanel.swift`. Single section in the right-rail `InspectorSidebar`. Renders:

- **Header**: title "Language Server" + state pill (Off / Starting… / Initializing… / Running / Failed)
- **Toggle**: "Attach sourcekit-lsp" — enabled only when active tab language is Swift; calls `coordinator.start/stop`
- **Capability summary** (running): collapsible disclosure with capability flags
- **Diagnostic counts**: `🔴 3   🟡 1   🔵 0`
- **Last error** (failed): one-line + "Show details" link to a sheet
- **Resolved server path**

The Python/TypeScript rows from the old panel are removed.

### Hover + Command-click wiring

In `App/WindowBody.swift`:

```swift
.onTextHover { position in
    guard let position else { hoverSession.dismiss(); return }
    await hoverSession.show(at: position, in: activeTabID)
}
.onCommandClick { position in
    Task { await appState.lsp.jumpToDefinition(at: position, in: activeTabID) }
}
```

`HoverSession` (sample-side, owned by `LSPSampleCoordinator`) is `@Observable` with `var displayed: HoverContent?`. `WindowBody` renders `.popover(item: $hoverSession.displayed)` anchored to the editor; `LSPHoverPopover` renders markdown content from the LSP `Hover` result.

### Additions to existing sample files

- `DocumentStore.openFile(url: URL)` — reads file, creates a tab, infers language from extension. Used by the definition-jump path. Tabs opened this way carry an `originURL` (informational only; persistence is out of scope).
- `AnnotationsHub.replaceDiagnosticAnnotations(_ annotations: [Annotation])` — new bucket alongside breakpoints/demo annotations. Diagnostics stay separate so toggling LSP off doesn't drop user breakpoints.
- `AppState.lsp: LSPSampleCoordinator` — owned property, initialized in `AppState.init`. See note in Deferred Refactors.

### Files deleted

- `Sources/CodeEditorSample/Sidebars/LSPStatusPanel.swift`

## Data Flow

### Server startup

```
User toggles ON in LSPInspectorPanel
  → coordinator.start(workspaceRoot:)
    → resolve sourcekit-lsp via xcrun                        [state: .starting]
    → LSPManager.registerLanguageServer(swiftConfig)
    → LSPManager.startLanguageServer(for: "swift")           [state: .initializing]
      → LSPClient connects, sends initialize, awaits result
    → coordinator reads serverCapabilities, summarizes        [state: .running]
    → DocumentMirror.openAllSwiftTabs() sends didOpen for each
    → DiagnosticsBridge.start() begins observing client.$diagnostics
```

### Edit propagation

```
NSTextView edit
  → DocumentStore.markDirty(tabID, newText)        (existing)
  → AppState onTextChange                          (existing)
  → coordinator.handleTextChange(for:newText:)
    → DocumentMirror schedules debounced write (150ms)
      → on fire: writes file + sends didChange (full-text sync)
```

### Diagnostic delivery

```
sourcekit-lsp sends publishDiagnostics
  → LSPClient decodes, updates @Published diagnostics[uri]   (existing)
  → DiagnosticsBridge handles emission
    1. Filter to active tab's mirror URI
    2. clearAllTemporaryAttributes() on the editor view
    3. For each diagnostic: convert range → NSRange, applyTemporaryAttributes
    4. Translate to [Annotation], call hub.replaceDiagnosticAnnotations
    5. Update coordinator.diagnosticCounts → panel re-renders
```

### Hover

```
Mouse settles 500ms over editor text
  → framework's .onTextHover fires with SourcePosition
  → action(position) runs as a child task
    → coordinator.requestHover(at:in:)
      → LSPManager.requestHover(filePath: mirrorURL.path, line:, character:)
    → if non-nil: hoverSession.show(content)
  → Mouse moves before completion: framework cancels task, popover dismisses
```

### Definition jump

```
.onCommandClick fires with SourcePosition
  → coordinator.requestDefinition(at:in:) → [Location]
  → take first location:
    if URI under workspaceRoot:
      existing tab → activate + scrollToLine
      else → documents.openFile(url:) → new tab + scrollToLine
    else (stdlib / outside workspace):
      LSPInspectorPanel shows toast: "Defined in <path>:<line>"
```

`EditorController.scrollToLine(_:)` is the existing scroll API (to be verified during implementation).

### Teardown

```
coordinator.stop()
  → DiagnosticsBridge.stop()           (cancel Combine subscription)
  → editorView.clearAllTemporaryAttributes()
  → hub.replaceDiagnosticAnnotations([])  (clears gutter)
  → DocumentMirror sends didClose for every tab, deletes shadow files
  → LSPManager.stopLanguageServer(for: "swift")
  → state = .off
```

Shadow-file cleanup is best-effort. On next launch, `start()` re-runs the cleanup pass.

## Error Handling

### sourcekit-lsp not found

`xcrun --find sourcekit-lsp` exits non-zero. Coordinator sets `state = .failed("sourcekit-lsp not found. Install Xcode or run xcode-select.")`. No retry; user must re-toggle.

### Server process exits unexpectedly

`LSPClient` already has `LSPRetryConfiguration` (existing framework). Coordinator keeps `state = .running` during the retry window; on exhaustion, transitions to `.failed("Server crashed after N restart attempts")` and tears down per the teardown flow. Uses the framework's default retry budget.

### `initialize` request times out or rejects

Surfaced as a throw from `LSPManager.startLanguageServer(for:)`. Coordinator → `.failed(error.localizedDescription)`. Manager rolls back its own internal state.

### Shadow-file write fails

Permission denied / read-only volume. `DocumentMirror` reports via `IssueReporting.reportIssue(...)` (per `pfw-issue-reporting`), logs via `CrossPlatformLogger`, and skips the affected tab. Partial failure preferred over total failure. If the mirror directory itself can't be created, the coordinator transitions to `.failed("Cannot create LSP scratch directory at <path>")`.

### Diagnostic range out of bounds

Race between server reading an older buffer and the user editing. `DiagnosticsBridge` clamps the range to `[0, text.length)`. Empty after clamping: drop from the squiggle pass but keep the gutter annotation at `min(range.start.line, lastLine)`. No reporting — normal during fast editing.

### Hover / definition request fails

- Hover: swallow the error; do not show the popover. Hover is best-effort.
- Definition: surface as a one-line toast in the inspector: "Could not resolve definition: <reason>". Empty result: "No definition found."

### Concurrent state changes

- Toggle is disabled while `state` is `.starting` or `.initializing` — handled by the SwiftUI binding.
- `workspaceRoot` picker is disabled while LSP is running; panel shows a hint to stop LSP before changing. Avoids a multi-step teardown/restart flow for v1.

### Logging

All LSP-related errors are logged at `.error` via `CrossPlatformLogger.logger(for: .lsp)`. User-facing messages truncate paths longer than ~50 chars; full message available via the "Show details" link.

## Testing Strategy

### Framework unit tests — `Tests/CodeEditorPluginTests/`

- `SourcePositionTests.swift` (Swift Testing) — round-trip with `LSPTypes.Position`, Equatable/Hashable.
- `TemporaryAttributesStoreTests.swift` (XCTest) — apply/clear semantics, edit survival (right-edge edit preserves range, internal shrink clamps, full-replace drops). Skip on iOS.
- `TextHoverModifierTests.swift` (XCTest, hosting controller + synthesized `NSEvent`) — fires after delay with non-nil position, cancels on early movement, fires with nil over gutter.
- `CommandClickModifierTests.swift` (XCTest) — ⌘-click fires once with correct position, plain click does not, caret unchanged (event consumed).

### Sample target unit tests — `Tests/CodeEditorSampleTests/`

- `DocumentMirrorTests.swift` (XCTest) — file written per temp workspaceRoot, debounce coalesces rapid changes, closeTab deletes file, start() cleans stale shadows.
- `DiagnosticsBridgeTests.swift` (Swift Testing) — fake LSPClient (`FakeLSPClient` in `Tests/CodeEditorSampleTests/Support/`) emits diagnostics, assert hub mutation + counts update + clamping for out-of-bounds.
- `LSPSampleCoordinatorStateTests.swift` (Swift Testing) — state transitions, resolver failure → `.failed`, stop from `.running` clears state.
- `LSPInspectorPanelSnapshotTests.swift` (XCTest + SnapshotTesting) — five state snapshots; light + dark for `.running`.

### Test doubles — `Tests/CodeEditorSampleTests/Support/`

- `FakeLSPClient` — mirrors public surface the sample reads from: `@Published diagnostics`, `serverCapabilities`, `requestHover/requestDefinition` returning canned values.
- `StubProcessResolver` — replaces the `xcrun` lookup with a configurable closure for coordinator tests. Injected via the coordinator's init.

Both stay in the sample test target. We don't promote them into framework test scaffolding until a second consumer needs them.

### Integration smoke test — gated

- `LSPLiveIntegrationTests.swift` (XCTest) — `try XCTSkipUnless(env["CODE_EDITOR_LSP_LIVE"] == "1", ...)`. Opens a Swift file with a deliberate type error, waits up to 5s for diagnostics, asserts at least one error-severity annotation on line 0. Not run in CI by default.

### Manual verification checklist

The implementer runs through this before declaring done:

- Toggle on with no workspaceRoot → temp dir works, diagnostics appear
- Toggle on with workspaceRoot set to a real Swift package → diagnostics from package files
- Edit a Swift file, introduce a syntax error → squiggle + gutter badge appear within ~1s
- Fix the error → both disappear
- Hover over an identifier → markdown popover after ~500ms
- ⌘-click an in-workspace identifier → opens correct file at correct line
- ⌘-click a stdlib identifier → toast in inspector
- Toggle off → all squiggles, gutter badges, popover dismissed; shadow files deleted
- Kill `sourcekit-lsp` manually via `kill` → after retries exhaust, state → `.failed`
- iOS build: no `LSPInspectorPanel` visible, app behaves as before

## Deferred Refactors

These are intentionally **not** in scope but worth recording:

1. **AppState decomposition (NEXT.md item 1).** This spec adds `AppState.lsp` to the existing god object. Splitting `AppState` into `ThemeModel`, `ConfigurationModel`, `LSPModel`, etc. is its own refactor and should not block LSP wiring.

2. **Document persistence (NEXT.md).** Tabs are still in-memory. `DocumentStore.openFile(url:)` is sample-internal and does not save back. The follow-up persistence spec should adopt the `originURL` field already added here.

3. **Workspace root persistence.** Still not stored across launches. Affects this feature in that re-attaching LSP requires re-picking workspaceRoot each launch. Acceptable for a demo; revisit with the persistence spec.

4. **Promoting test doubles.** `FakeLSPClient` is sample-only. If a future consumer wants framework-grade LSP test scaffolding, promote it with a clean fake-transport design rather than lifting the sample's quick-and-dirty version.

5. **Multi-server picker.** The architecture supports it (`LanguageServerConfig` is per-language); UX is deferred.

## Acceptance Criteria

This spec is implemented when:

1. Toggling on `LSPInspectorPanel` with `xcrun --find sourcekit-lsp` returning a valid path attaches a client and transitions state through `.starting → .initializing → .running`.
2. Editing a Swift document produces server-side diagnostics that appear as gutter badges (via `AnnotationsHub`) and inline wavy red underlines (via `applyTemporaryAttributes`) within ~1 second of the debounce.
3. Hovering over an identifier for ~500ms shows a markdown popover with `LSPManager.requestHover` content. Pointer movement cancels.
4. ⌘-click on an identifier jumps to definition: same-file scrolls; in-workspace cross-file opens a new tab; out-of-workspace shows a toast in the inspector.
5. Toggling off cleans up all state: squiggles cleared, gutter annotations replaced with empty, shadow files deleted, server stopped.
6. iOS build is unchanged. `swift build --target CodeEditorSample` succeeds on macOS and iOS simulator.
7. All new tests pass under `swift test --parallel`. SwiftLint strict mode clean. The manual verification checklist passes against a fresh checkout.
