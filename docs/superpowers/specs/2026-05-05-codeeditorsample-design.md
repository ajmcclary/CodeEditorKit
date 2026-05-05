# CodeEditorSample design (sub-project 5)

**Status:** spec
**Date:** 2026-05-05
**Sub-project:** 5 of 5 (design-system migration capstone)
**Depends on:** sub-projects 1–4 (`CodeEditorDesignTokens`, `CodeEditorPlugin`, `CodeEditorUI`)

## Purpose

`CodeEditorSample` is the **integration capstone** for the design-system
migration. It boots into a single window that exercises every public
surface added in sub-projects 1–4: the editor, every chrome primitive,
both Style protocols, the Liquid Glass surface, the bundled themes, and
the full `EditorConfiguration` knob set.

The demo is **not a real code editor**. It owns no filesystem, no
workspace, no documents-on-disk. Users type into in-memory tabs, flip
configuration knobs, and watch the chrome respond. That's the entire
value proposition: *kick the tires on the package without standing up a
host app.*

The resulting executable runs on macOS via `swift run CodeEditorSample`.
iOS / Catalyst hosts are out of scope — they would need an Xcode host
project, captured in [open question 5 of the umbrella](2026-05-05-design-system-migration-design.md).

## Scope

### What it ships

- **Window chrome** — `EditorTitleBar`, `EditorTabStrip` (default style),
  `EditorStatusBar`, two `EditorSidebarShell`s (settings-left,
  inspector-right), `EditorCommandPalette` (default style).
- **Multi-tab in-memory documents** — open / close / switch / dirty
  track. New-tab spawns an `Untitled-N` document; close removes from the
  store. No save-to-disk; the dirty dot reflects unsaved buffer changes
  but `⌘S` is a no-op (with a one-line status-bar toast: *"Demo —
  documents are in-memory only"*).
- **Theme picker** — all 20 zed-trek variants, presented as a flat
  scrolling list grouped by family color (Black Alert → Yellow Alert)
  with Dark / Light pills inline. Default on launch: `Theme.lcarsDark`.
- **Language picker** — all 20 `Language` cases, alphabetical, with
  display names. Default for new tabs: `.swift`.
- **Preset picker** — six `EditorConfiguration` presets:
  `.default`, `.minimal`, `.readOnly`, `.markdown`, `.presentation`,
  `.macOS`. (`.iOS` and `.catalyst` are skipped — they're
  platform-optimized variants whose effects don't read on a macOS demo.)
  Default on launch: `.default`.
- **Knob playground** — every user-facing public property of
  `EditorConfiguration.{display, layout, behavior, performance}` gets a
  control row, organized under four collapsible sections inside the
  settings sidebar's content slot. Special cases:
  - `display.selectedLineHighlightColor` → `ColorPicker`.
  - `behavior.completionTriggerCharacters` → `TextField`
    (comma-separated; commits on `Return` / focus loss).
  - `Duration` knobs (`highlightingDebounceInterval`,
    `textChangeDebounceInterval`) → `Slider` over milliseconds with the
    raw value displayed.
- **Configuration inspector** — a second `EditorSidebarShell` on the
  right showing the live `EditorConfiguration` rendered as Swift code.
  Updates on every knob change. A small "Copy" button copies the code
  to the pasteboard.
- **Command palette** — `⌘⇧P` opens it. Commands cover: every theme
  ("Theme: Borg Cube Dark"…), every language ("Language: Swift"…), every
  preset ("Preset: Minimal"…), tab actions ("New Tab", "Close Tab",
  "Close All Tabs"), and chrome toggles ("Toggle Settings Sidebar",
  "Toggle Inspector").
- **Window chrome composition** — see *Window architecture* below.

### What it drops from the umbrella sketch

- File-tree implementation, `WorkspaceModel`, FSEvents/DispatchSource
  watching, virtualized rows, expand/collapse, search.
- Bundled sample-source files (Swift / TypeScript / Python / Rust /
  JSON exemplars).
- "Open Folder…" menu, `NSOpenPanel`, host-folder workspace support.

These were dropped during brainstorming because they bloat the package
without exercising a CodeEditorPlugin / CodeEditorUI surface. A real
host app will own its own workspace abstraction.

### What it explicitly does not do

- Persist documents.
- Watch the filesystem.
- Run on iOS or Mac Catalyst (the demo links AppKit-gated chrome —
  `EditorTitleBar`, `EditorTrafficLights`, `EditorSidebarShell` — that
  isn't built on iOS).
- Hot-reload themes from a JSON directory (umbrella open question #2 —
  deferred indefinitely; not load-bearing for the demo).

## Package layout

`Package.swift` gains:

```swift
.executableTarget(
    name: "CodeEditorSample",
    dependencies: [
        "CodeEditorDesignTokens",
        "CodeEditorPlugin",
        "CodeEditorUI",
    ],
    swiftSettings: swiftSettings
)
```

No new dependencies. The executable links the existing three library
products plus stdlib + SwiftUI + AppKit.

## Source tree

```
Sources/
  CodeEditorSample/
    App/
      CodeEditorSampleApp.swift          # @main, WindowGroup, scene config
      RootWindow.swift                   # window-level layout: title bar, body, status bar
      WindowBody.swift                   # horizontal split: settings | editor | inspector
    Documents/
      DocumentStore.swift                # @Observable; tabs, active id, dirty tracking
      Document.swift                     # value type: id, name, language, text, isDirty
    Switchers/
      ThemeCatalog.swift                 # the 20 zed-trek themes, indexed by display name
      LanguageCatalog.swift              # Language.allCases, sorted by display name
      PresetCatalog.swift                # six demo presets, indexed by display name
      SwitcherSection.swift              # three Picker rows (Theme / Language / Preset)
    KnobPanels/
      DisplayKnobsSection.swift          # collapsible — every Display knob
      LayoutKnobsSection.swift           # collapsible — every Layout knob
      BehaviorKnobsSection.swift         # collapsible — every Behavior knob
      PerformanceKnobsSection.swift      # collapsible — every Performance knob
      KnobRow.swift                      # ToggleRow / StepperRow / SliderRow / PickerRow
    Sidebars/
      SettingsSidebar.swift              # EditorSidebarShell wrapper, hosts switchers + knobs
      InspectorSidebar.swift             # EditorSidebarShell wrapper, hosts code mirror
      ConfigurationCodeFormatter.swift   # EditorConfiguration -> Swift source string
    CommandPalette/
      CommandPaletteCatalog.swift        # builds [CommandPaletteItem] from the live state
Tests/
  (no tests — sub-project 5 is a demo executable; correctness is
   covered by the package's own tests. See Testing below.)
```

## Window architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ EditorTitleBar  (traffic-lights | "CodeEditorSample" | ∅ trailing)  │
├─────────────────────────────────────────────────────────────────────┤
│ EditorTabStrip  (default style — ScrollView of EditorTab + "+")     │
├──────────────┬───────────────────────────────────┬──────────────────┤
│              │                                   │                  │
│  Settings    │        CodeEditor                 │   Inspector      │
│  sidebar     │        (the live editor view,     │   sidebar        │
│  (left)      │         bound to the active       │   (right)        │
│  ~280pt      │         document's text)          │   ~360pt         │
│              │                                   │                  │
│  Switchers   │                                   │  Live config as  │
│  ──────      │                                   │  Swift code,     │
│  Display     │                                   │  one-shot copy   │
│  Layout      │                                   │  button.         │
│  Behavior    │                                   │                  │
│  Performance │                                   │                  │
│              │                                   │                  │
├──────────────┴───────────────────────────────────┴──────────────────┤
│ EditorStatusBar  (default-rendered fields, no trailing slot)        │
└─────────────────────────────────────────────────────────────────────┘
```

- Title bar uses `EditorTrafficLights` decoratively (no callbacks);
  hosts in real apps wire the lights to the real `NSWindow`.
- Tab strip is the `default` style; the sample doesn't ship a custom
  style. (`compact` is exercised by the package's snapshot tests, not
  by the demo.)
- Both sidebars use `EditorSidebarShell`. The settings sidebar passes a
  `sectionTitle: "Settings"` and fills the `content` slot with a
  vertical scrolling stack of switchers + four collapsible knob
  sections. The inspector passes `sectionTitle: "Configuration"` and
  fills `content` with a monospaced text view of the rendered Swift +
  a footer "Copy" button.
- The breadcrumb (`EditorBreadcrumbView`) is **not** in the demo —
  there's no workspace path to show. (Decided during brainstorming.)
- Status bar uses no trailing slot — the language indicator and
  selection / indent / GPU badges that ship by default are enough.
  (Real apps fill the trailing slot themselves.)

### Window dimensions

Default size: 1380 × 880. Min size: 980 × 640 (below this, both
sidebars become inadequate).

## Document model

```swift
public struct Document: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var language: Language
    public var text: String
    public var isDirty: Bool
}

@Observable
public final class DocumentStore {
    public private(set) var documents: [Document] = []
    public var activeID: Document.ID?

    public func newDocument()
    public func close(_ id: Document.ID)
    public func closeAll()
    public func setActive(_ id: Document.ID)
    public func updateText(of id: Document.ID, to text: String)
    public func setLanguage(_ language: Language, of id: Document.ID)
}
```

- `DocumentStore` is the demo's source of truth for tabs and editor
  contents. Lives at the app level and is passed via SwiftUI
  environment to chrome + editor.
- New tabs default to `.swift`, are named `"Untitled-N.swift"` (N
  monotonically increases per session), and start dirty=false. First
  keystroke sets dirty=true.
- Closing the active tab activates the previous tab, or `nil` if the
  list becomes empty.
- "Close All Tabs" on an empty list is a no-op.
- Boot state: one document, `Untitled-1.swift`, language `.swift`,
  empty text, active. (Empty editor on launch was the explicit
  brainstorming pivot.)

## Switcher catalog

Three top-of-sidebar `Picker` rows (or popups, depending on what reads
better at 280pt — implementation chooses). Below each row, a one-line
caption shows the active selection in muted text.

- **Theme** — `[Theme]`. Source: `ThemeCatalog.all`. Selection updates
  the SwiftUI environment via `.codeTheme(_:)`.
- **Language** — `[Language]`. Selection updates the *active document's*
  language via `DocumentStore.setLanguage`. (Each tab has its own
  language; the picker reflects the active tab's value.)
- **Preset** — `[EditorConfiguration]`. Selection replaces the live
  `EditorConfiguration` wholesale. Knobs underneath update to reflect
  the new values.

The relationship between presets and the knob playground: presets
**replace** the entire config; knob edits **mutate one field** of the
current config. There is no "preset = … with overrides" model — the
preset picker just snapshots a baseline.

## Knob playground

Four collapsible `DisclosureGroup` sections inside the settings
sidebar's content slot, one per `EditorConfiguration` section:

| Section | Knobs |
|---|---|
| Display | `fontSize`, `isLineNumbersEnabled`, `enableAnnotations`, `highlightSelectedLine`, `selectedLineHighlightColor`, `showInvisibleCharacters`, `enableCodeFolding`, `showFoldingControls`, `minimumFoldableLines`, `animateCodeFolding`, `showMinimap` (11 knobs) |
| Layout | `tabWidth`, `insertSpacesForTabs`, `wrapLines`, `gutterWidth`, `lineNumberPadding`, `lineHeightMultiple`, `characterSpacing`, `textContainerWidthFraction`, `annotationBadgeSize`, `annotationBadgePadding`, `minimapWidth`, `foldingControlSize`, `foldingControlPadding` (13 knobs) |
| Behavior | `isEditable`, `isSelectable`, `autoIndent`, `enableCodeCompletion`, `isAutomaticLinkDetectionEnabled`, `isAutomaticQuoteSubstitutionEnabled`, `isAutomaticDashSubstitutionEnabled`, `autoCloseBrackets`, `autoCloseQuotes`, `isContinuousSpellCheckingEnabled`, `isGrammarCheckingEnabled`, `isAutomaticTextReplacementEnabled`, `isAutomaticSpellingCorrectionEnabled`, `isAutomaticTextCompletionEnabled`, `showInlineCompletionSuggestions`, `completionTriggerCharacters`, `autoScrollToCursor`, `enableSyntaxHighlighting` (18 knobs) |
| Performance | `maxSyntaxHighlightingLength`, `useHardwareAcceleration`, `renderingUpdateStrategy`, `maxVisibleLines`, `maxFileSize`, `highlightingDebounceInterval`, `smoothScrolling`, `textChangeDebounceInterval`, `animateCodeFolding`, `maxEventsPerSecond` (10 knobs) |

**Total: 52 knobs.** (Knob count is provisional — the implementation
plan re-reads the live struct and any drift is just a knob row adjust.)

### Knob-row primitives

```swift
struct ToggleRow: View   { let label: String; let binding: Binding<Bool> }
struct StepperRow: View  { let label: String; let binding: Binding<Int>;  let range: ClosedRange<Int> }
struct SliderRow: View   { let label: String; let binding: Binding<Double>; let range: ClosedRange<Double>; let format: FloatingPointFormatStyle<Double> }
struct PickerRow<T>: View where T: Hashable { let label: String; let binding: Binding<T>; let cases: [T]; let display: (T) -> String }
struct ColorRow: View    { let label: String; let binding: Binding<PlatformColor> }
struct CharSetRow: View  { let label: String; let binding: Binding<Set<Character>> }
struct DurationRow: View { let label: String; let binding: Binding<Duration>; let range: ClosedRange<Double> /* ms */ }
```

Excluded knobs (DI hooks, not user-facing): `eventSystem`,
`actorCoordinator`, `workspaceRoot`, `platformCapabilities`,
`unifiedPerformanceSystem`, `paragraphStyleCache`,
`languageMetadataRegistry`, `platformServiceLayer`, `memoryMonitor`.

Excluded knobs (iOS-only, demo is macOS): `enableIOSOptimizations`,
`iOSLargeFileThreshold`, `iOSMaxHighlightingChunk`.

### Range / step defaults

- `fontSize`: 9–32, step 1.
- `tabWidth`: 1–8, step 1.
- `gutterWidth`, `lineNumberPadding`, `minimapWidth`,
  `foldingControlSize`, `foldingControlPadding`,
  `annotationBadgeSize`, `annotationBadgePadding`: 0–80, step 0.5.
- `lineHeightMultiple`, `textContainerWidthFraction`,
  `characterSpacing`: 0.0–2.0, step 0.05.
- `minimumFoldableLines`, `maxEventsPerSecond`,
  `maxVisibleLines`: 1–10000, step 1.
- `maxSyntaxHighlightingLength`, `maxFileSize`: 1024–10_485_760
  (1KB–10MB), step 1024.
- `highlightingDebounceInterval`, `textChangeDebounceInterval`:
  0–1000ms, step 1.
- `renderingUpdateStrategy`: picker over `.adaptive`, `.immediate`,
  `.batched` (or whatever cases the enum has — read at impl time).

## Inspector panel

`InspectorSidebar` renders the active `EditorConfiguration` as Swift
source. The output is a sequence of direct-property-assignment lines
grouped by the four sections — this matches the recommended pattern
from `CLAUDE.md` ("Direct updates (preferred): config.display.… = …").

Example output:

```swift
var config = EditorConfiguration()

// Display
config.display.fontSize = 14
config.display.isLineNumbersEnabled = true
config.display.enableAnnotations = true
config.display.highlightSelectedLine = true
…

// Layout
config.layout.tabWidth = 4
config.layout.insertSpacesForTabs = true
…
```

- Lines are formatted by `ConfigurationCodeFormatter` (a pure value-in
  / string-out function, easy to unit-test).
- Only knobs whose value differs from `EditorConfiguration().<section>`
  default are emitted, to keep the output scannable.
- A footer button copies the rendered string to `NSPasteboard.general`.
- The text view is a plain SwiftUI `Text` with `.font(.system(.body, design: .monospaced))` —
  not a `CodeEditorView`. (Using the editor inside the inspector would
  pull a second highlighting pipeline into a panel that isn't editable;
  not worth the complexity.)

## Command palette commands

Built once per render of the palette, from the live state:

| Command | Action |
|---|---|
| `Theme: <name>` (×20) | Set active theme. |
| `Language: <name>` (×20) | Set active document's language. |
| `Preset: <name>` (×6) | Replace the live configuration. |
| `New Tab` | Spawn a new `Untitled-N.swift`. |
| `Close Tab` | Close the active tab. |
| `Close All Tabs` | Close every tab. |
| `Toggle Settings Sidebar` | Hide / show left sidebar. |
| `Toggle Inspector` | Hide / show right sidebar. |

Total: ~52 commands. The palette filters as the user types per the
existing `CommandPaletteFilter`.

The shortcut `⌘⇧P` is wired by the sample app via SwiftUI's
`.keyboardShortcut`. Sub-projects 1–4 deliberately don't bind keys —
hosts choose.

## Defaults on launch

| Field | Default |
|---|---|
| Theme | `Theme.lcarsDark` |
| Active language | `.swift` (the new tab's default) |
| Preset / configuration | `EditorConfiguration.default` |
| Documents | one tab: `Untitled-1.swift`, empty text |
| Settings sidebar | visible |
| Inspector sidebar | visible |
| Window size | 1380 × 880 |

## Testing

`CodeEditorSampleTests` is **not** added as a test target. Sub-project
5 is a demo executable; the surfaces it exercises (chrome views, theme
loading, configuration plumbing, command-palette filter) all have
unit + snapshot coverage in `CodeEditorPluginTests`,
`CodeEditorUITests`, and `CodeEditorDesignTokensTests`. Adding a
duplicate test target inside the executable buys little and adds
package surface.

The two pieces of demo logic *worth* unit-testing live in pure helper
files inside `CodeEditorSample/` itself:

- `ConfigurationCodeFormatter` — pure value-in / string-out. Add a
  small inline `@Suite` directly inside the demo's source folder *or*
  skip — formatter output is human-validated by visual inspection.
- `DocumentStore` — `@Observable` class. New / close / setActive /
  closeAll behavior is small enough to validate by running the demo.

**Decision:** ship without a `CodeEditorSampleTests` target. If
`ConfigurationCodeFormatter` proves load-bearing or fragile during
implementation, add a unit-test file inline at that point — not now.
This matches the umbrella's stance that the sample is the integration
capstone, not a tested library product.

The verification gate for sub-project 5 is **manual**:

- `swift build` clean.
- `swiftlint` zero violations across the new sources.
- `swift test --parallel` still green for the existing 187 tests.
- `swift run CodeEditorSample` opens a window matching the
  *Window architecture* layout above; every switcher works, every
  knob row's edit reflects in the inspector, command palette opens on
  `⌘⇧P` and dispatches the listed commands.

## Open questions resolved during brainstorming

- **Workspace boot path:** empty editor, no bundled samples, no FSEvents.
- **Sidebar fate:** left sidebar hosts switchers + knob playground;
  right sidebar hosts live-config inspector.
- **Breadcrumb fate:** dropped from the demo — there's no workspace
  path to show.
- **Switcher placement:** inside the settings sidebar, not the title
  bar's trailing slot or the status bar.
- **Knob granularity:** every user-facing public property of
  `EditorConfiguration.{display, layout, behavior, performance}` gets
  a row; DI hooks and iOS-only knobs are skipped.

## Open questions still on the table

These are intentionally deferred and called out so the implementation
plan can pick them up:

1. **Inspector code-formatting fidelity.** Should the inspector render
   floating-point values via `String(format: "%.2f", …)` or
   `.formatted()`? Default to `.formatted()` for now and revisit if
   the output looks noisy.
2. **`renderingUpdateStrategy` cases.** Need to read the live enum at
   implementation time — this spec assumes `.adaptive`, `.immediate`,
   `.batched` exist; if the actual cases differ, the picker just
   reflects the live cases.
3. **Theme list grouping.** The settings-sidebar theme picker can be
   a flat list or grouped by family color. Default to grouped during
   implementation; switch to flat if grouping bloats the row count.
4. **Empty-config-default suppression in inspector.** The spec says
   the inspector elides knob rows whose value matches the
   `EditorConfiguration()` default. If this elides almost everything
   on first launch (creating a misleading "this config is empty"
   feeling), implementation may switch to "always emit every knob" —
   captured here so it's not a surprise.

## References

- Umbrella spec: `docs/superpowers/specs/2026-05-05-design-system-migration-design.md`
- CodeEditorUI chrome spec: `docs/superpowers/specs/2026-05-05-codeeditorui-chrome-design.md`
- Theme rewrite spec: `docs/superpowers/specs/2026-05-05-theme-rewrite-design.md`
- `EditorConfiguration` source:
  `Sources/CodeEditorPlugin/Configuration/EditorConfiguration*.swift`
- `Language` enum: `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift`
- `Theme.lcarsDark`, bundled themes:
  `Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift`
