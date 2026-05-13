# CodeEditorUI Chrome Primitives

> **Archive note:** Historical working note from May 2026. It may mention pre-0.2.0 Catalyst, plugin, or theme APIs; use `AGENTS.md`, `docs/README.md`, and `docs/FeatureMatrix.md` for current package truth.

**Date:** 2026-05-05
**Status:** brainstorm complete — pending user review of written spec
**Type:** sub-project spec — sub-project 4 of the [Design System Migration umbrella](2026-05-05-design-system-migration-design.md).
**Scope:** new `CodeEditorUI` SwiftPM library target shipping eight chrome components, an additive `EditorState` `@Observable` type in `CodeEditorPlugin`, the env key wiring, two SwiftUI Style protocols (tab strip, command palette), and a Liquid Glass surface modifier. Editor-internal restyle (sub-project 3) and sample-app integration (sub-project 5) are out of scope.

## Goal

Ship a public chrome layer so consumers of `CodeEditorPlugin` can drop in an Apple-native, Liquid-Glass IDE shell — title bar, tab strip, breadcrumb, status bar, sidebar shell, command palette, glass surfaces — without owning the look themselves. Components are toolkit primitives that compose into a host's screen, not opinionated screens themselves.

## Context

This sub-project depends on:

- **Sub-project 1 (`CodeEditorDesignTokens`)** — shipped. Provides `Tokens.Color`, `Tokens.Spacing`, `Tokens.Animation`, etc.
- **Sub-project 2 (`Theme` rewrite)** — shipped. Provides `Theme.style.chrome` (title-bar/tab-bar/tab/status-bar/toolbar/panel/pane colors), `Theme.platform.glass` (Liquid Glass tint + opacity), `Theme.platform.shadows.popover`, `Theme.platform.field`. Default theme is `Theme.lcarsDark`. Existing SwiftUI bridge `Color(tokens:)` is shipped.

Sub-project 3 (editor visual restyle) and this sub-project run in parallel after sub-project 2; neither depends on the other. Sub-project 5 (`CodeEditorSample`) consumes both.

### What exists today

- `CodeEditor` SwiftUI entry point in `CodeEditorPlugin/SwiftUI/CodeEditor.swift` with `\.codeTheme`, `\.codeEditorConfiguration`, `\.codeEditorLanguage` env keys.
- `EditorConfiguration` value type (`Codable, Sendable`) covering `display`/`layout`/`behavior`/`performance`.
- No public observable editor-state type — selection/dirty/language are not exposed for chrome to read.
- No window/tab-strip/breadcrumb/status-bar primitives.

### What this sub-project adds

- A new SwiftPM library target **`CodeEditorUI`** with eight chrome components.
- A new public **`EditorState`** `@Observable final class` in `CodeEditorPlugin`, plus the `\.editorState` env key — additive, no breakage.
- New public value types in `CodeEditorPlugin/Core/`: `SelectionState`, `TabModel`, `BreadcrumbComponent` — referenced by `EditorState`.
- Theme bridge extensions in `CodeEditorUI/Theming/` mapping `Theme.style.chrome.*` and `Theme.platform.glass` to `SwiftUI.Color` / shadow tuples.
- Two SwiftUI Style protocols (`EditorTabStripStyle`, `EditorCommandPaletteStyle`) with default and compact built-ins.
- A `PlatformGlassSurface` `ViewModifier` wrapping the Tahoe-native Liquid Glass effect.

## Strategy

### Reactive model — `@Observable EditorState`

Chrome is **fully reactive**, not snapshot-driven. A single `@Observable final class EditorState` lives in `CodeEditorPlugin`. The host instantiates it (`@State private var editorState = EditorState()`) and injects via `.environment(editorState)`. Both `CodeEditor` (writes) and chrome components (read) see the same instance.

Fields split by writer:

| Writer | Field | Purpose |
|---|---|---|
| Editor | `selection: SelectionState?` | Caret/selection in active document. nil before mount. |
| Editor | `language: Language?` | Detected/explicit language. |
| Editor | `isDirty: Bool` | Unsaved changes in active document. |
| Editor | `hardwareAccelerationActive: Bool` | "Actually on," not "configured on." |
| Editor | `lineCount: Int` | Total lines in active document. |
| Host | `documentName: String` | Display name for active document. |
| Host | `documentURL: URL?` | File URL; drives breadcrumb defaults. |
| Host | `tabs: [TabModel]` | Open tabs. Host owns ordering + lifecycle. |
| Host | `activeTabID: TabModel.ID?` | Active tab. |
| Host | `breadcrumbPath: [BreadcrumbComponent]` | Breadcrumb trail. Host computes. |
| Host | `workspaceName: String` | Title-bar / sidebar workspace name. |

**MainActor-bound by convention.** `@unchecked Sendable` because `@Observable` doesn't synthesize `Sendable`. Mutation from non-main contexts is unsupported and will be documented as such.

### API style — Style protocol where named, plain views otherwise

Two components use the SwiftUI Style protocol pattern (à la `ButtonStyle`):

- `EditorTabStripStyle` with `Configuration` exposing `tabs`, `activeTabID`, `setActive`, `close`. Built-ins: `.default`, `.compact`. Installed via `.editorTabStripStyle(_:)`.
- `EditorCommandPaletteStyle` with `Configuration` exposing `prompt`, `query` binding, `visibleItems`, `highlightedID`, `onHighlight`, `onSelect`. Built-in: `.default`. Installed via `.editorCommandPaletteStyle(_:)`.

All other components are plain view structs with init parameters and `@ViewBuilder` slots for host content.

### Cross-platform tiering

The `CodeEditorUI` target compiles on macOS, iOS, and Mac Catalyst. Each component declares its own scope:

| Component | macOS | Catalyst | iOS |
|---|:-:|:-:|:-:|
| `EditorTitleBar` | ✓ | ✓ | — |
| `EditorTrafficLights` | ✓ | ✓ | — |
| `EditorTabStrip` | ✓ | ✓ | ✓ |
| `EditorBreadcrumbView` | ✓ | ✓ | ✓ |
| `EditorStatusBar` | ✓ | ✓ | ✓ |
| `EditorSidebarShell` | ✓ | ✓ | — |
| `EditorCommandPalette` | ✓ | ✓ | ✓ |
| `PlatformGlassSurface` | ✓ | ✓ | ✓ |

Implementation gates use `#if canImport(AppKit)` + `targetEnvironment(macCatalyst)` for macOS-or-Catalyst components. iOS-only fallbacks are not needed — title-bar/traffic-lights/sidebar-shell are simply absent on iOS.

### Liquid Glass — native Tahoe API, no abstraction

Platform floor (macOS/iOS/Catalyst 26.3) means SwiftUI's Liquid Glass APIs are unconditional. `PlatformGlassSurface` is a thin `ViewModifier` over the platform modifier (likely `.glassEffect(...)` — exact spelling pinned at implementation time; if the SDK ships a different name we adopt it verbatim). The wrapper layers, in fixed order:

1. The native glass effect.
2. A tint fill at `Theme.platform.glass.opacity` using `Theme.platform.glass.tint`.
3. A role-specific stroke and (for `.popover`) the `Theme.platform.shadows.popover` drop shadow.

**Per-role defaults**:

| Role | Background fill | Tint opacity multiplier | Shadow |
|---|---|---|---|
| `.titleBar` | `chrome.titleBarBackground` | 1.0 | none |
| `.tabBar` | `chrome.tabBarBackground` | 0.8 | none |
| `.statusBar` | `chrome.statusBarBackground` | 1.0 | none |
| `.panel` | `chrome.panelBackground` | 1.2 (clamped to 1) | none |
| `.popover` | `chrome.elevatedSurfaceBackground` | 1.2 (clamped to 1) | `platform.shadows.popover` |

### Module structure

#### Package.swift surgery

Additive: one new library product, one new target, one new test target.

```swift
products: [
    .library(name: "CodeEditorDesignTokens", targets: ["CodeEditorDesignTokens"]),
    .library(name: "CodeEditorPlugin",       targets: ["CodeEditorPlugin"]),
    .library(name: "CodeEditorUI",           targets: ["CodeEditorUI"]),   // NEW
],
targets: [
    .target(name: "CodeEditorDesignTokens", swiftSettings: swiftSettings),

    .target(
        name: "CodeEditorPlugin",
        dependencies: [
            "CodeEditorDesignTokens",
            .product(name: "Dependencies",   package: "swift-dependencies"),
            .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            .product(name: "SwiftSyntax",    package: "swift-syntax"),
            .product(name: "SwiftParser",    package: "swift-syntax")
        ],
        exclude: ["Info.plist"],
        resources: [.process("Resources/Themes")],
        swiftSettings: swiftSettings
    ),

    .target(                                                                // NEW
        name: "CodeEditorUI",
        dependencies: ["CodeEditorDesignTokens", "CodeEditorPlugin"],
        swiftSettings: swiftSettings
    ),

    // ... existing test targets ...

    .testTarget(                                                            // NEW
        name: "CodeEditorUITests",
        dependencies: [
            "CodeEditorUI",
            .product(name: "CustomDump",      package: "swift-custom-dump"),
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
        ],
        exclude: ["__Snapshots__"],
        swiftSettings: swiftSettings
    ),
]
```

#### Source tree

```
Sources/
  CodeEditorPlugin/
    Core/
      EditorState.swift                # NEW — @Observable; editor + host fields
      TabModel.swift                   # NEW — public value type used by EditorState.tabs
      SelectionState.swift             # NEW — public value type used by EditorState.selection
      BreadcrumbComponent.swift        # NEW — public value type used by EditorState.breadcrumbPath
    SwiftUI/
      EditorState+Environment.swift    # NEW — \.editorState env key

  CodeEditorUI/
    Window/
      EditorTitleBar.swift             # macOS + Catalyst
      EditorTrafficLights.swift        # macOS + Catalyst
    TabStrip/
      EditorTabStrip.swift             # all platforms
      EditorTabStripStyle.swift        # protocol + Configuration + DefaultEditorTabStripStyle + CompactEditorTabStripStyle
      EditorTab.swift                  # individual tab view (public for custom-style composition)
    Breadcrumb/
      EditorBreadcrumbView.swift       # all platforms (data model lives in CodeEditorPlugin)
    StatusBar/
      EditorStatusBar.swift            # all platforms
    Sidebar/
      EditorSidebarShell.swift         # macOS + Catalyst
    CommandPalette/
      EditorCommandPalette.swift       # opinionated view, all platforms
      EditorCommandPaletteStyle.swift  # protocol + Configuration + DefaultEditorCommandPaletteStyle
      EditorCommandPaletteRow.swift    # styleable row primitive
      CommandPaletteItem.swift         # data model
    Glass/
      PlatformGlassSurface.swift       # ViewModifier; reads \.codeTheme.platform.glass
    Theming/
      Theme+Chrome.swift               # Theme → SwiftUI.Color accessors for chrome.*
      Theme+Glass.swift                # Theme → glass tint/opacity/shadow accessors
    Environment/
      EditorChromeEnvironment.swift    # chrome-only env keys (e.g., implicit window-style hints)

Tests/CodeEditorUITests/
  EditorStateTests.swift               # type shape, mutation observation, conformance audit
  ChromeBindingTests.swift             # env value flow into chrome components
  StyleProtocolTests.swift             # default-style behavior, custom-style installation
  Snapshots/
    EditorTitleBarSnapshots.swift
    EditorTrafficLightsSnapshots.swift
    EditorTabStripSnapshots.swift
    EditorBreadcrumbSnapshots.swift
    EditorStatusBarSnapshots.swift
    EditorSidebarShellSnapshots.swift
    EditorCommandPaletteSnapshots.swift
    PlatformGlassSurfaceSnapshots.swift
  __Snapshots__/                       # excluded from package resources
```

## Public API

### `CodeEditorPlugin` additions

```swift
// Sources/CodeEditorPlugin/Core/EditorState.swift
@Observable
public final class EditorState: @unchecked Sendable {
    // Editor-written
    public var selection: SelectionState?
    public var language: Language?
    public var isDirty: Bool = false
    public var hardwareAccelerationActive: Bool = false
    public var lineCount: Int = 0

    // Host-written
    public var documentName: String = ""
    public var documentURL: URL?
    public var tabs: [TabModel] = []
    public var activeTabID: TabModel.ID?
    public var breadcrumbPath: [BreadcrumbComponent] = []
    public var workspaceName: String = ""

    public init() {}
}

// Sources/CodeEditorPlugin/Core/SelectionState.swift
public struct SelectionState: Hashable, Sendable {
    public var line: Int             // 1-based
    public var column: Int           // 1-based, in display columns
    public var selectionLength: Int  // 0 == caret-only
    public init(line: Int, column: Int, selectionLength: Int = 0)
}

// Sources/CodeEditorPlugin/Core/TabModel.swift
public struct TabModel: Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var url: URL?
    public var language: Language?
    public var isDirty: Bool
    public init(id: UUID = UUID(), name: String, url: URL? = nil,
                language: Language? = nil, isDirty: Bool = false)
}

// Sources/CodeEditorPlugin/Core/BreadcrumbComponent.swift
public struct BreadcrumbComponent: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: Kind
    public enum Kind: Sendable, Hashable { case workspace, folder, file, symbol }
    public init(id: UUID = UUID(), name: String, kind: Kind)
}

// Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift
extension EnvironmentValues {
    @Entry public var editorState: EditorState = EditorState()
}
```

`BreadcrumbComponent` lives in `CodeEditorPlugin/Core/` next to `TabModel` for the same reason: it's a small data-shape needed by `EditorState`, structurally identical to `TabModel`'s role, and forcing it into the chrome target would either require an existential dance or block `EditorState.breadcrumbPath` from being usable without `import CodeEditorUI`. The breadcrumb's *visual rendering* (chevron separators, kind glyphs, hover) lives in `CodeEditorUI`; the data shape lives where the rest of `EditorState`'s fields live.

### `CodeEditorUI` types

Concrete API shapes for each component were spec'd in the brainstorm and are summarized here. Implementation files own the full DocC.

```swift
// Window/EditorTitleBar.swift          — macOS + Catalyst
public struct EditorTitleBar<Trailing: View>: View {
    public init(
        title: String? = nil,                                 // nil → state.documentName
        trafficLights: TrafficLightsConfiguration = .standard,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    )
}

public struct TrafficLightsConfiguration: Sendable {
    public var onClose: (@Sendable () -> Void)?
    public var onMinimize: (@Sendable () -> Void)?
    public var onZoom: (@Sendable () -> Void)?
    public static let standard: Self = .init()                // decorative
}

// Window/EditorTrafficLights.swift     — macOS + Catalyst
public struct EditorTrafficLights: View {
    public init(configuration: TrafficLightsConfiguration = .standard,
                size: CGFloat = 14)
}

// TabStrip/EditorTabStrip.swift        — all platforms
public struct EditorTabStrip: View {
    public init(
        tabs: Binding<[TabModel]>,
        activeTabID: Binding<TabModel.ID?>,
        onClose: ((TabModel.ID) -> Void)? = nil
    )
}

// TabStrip/EditorTabStripStyle.swift   — all platforms
public protocol EditorTabStripStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
    typealias Configuration = EditorTabStripStyleConfiguration
}

public struct EditorTabStripStyleConfiguration {
    public let tabs: [TabModel]
    public let activeTabID: TabModel.ID?
    public let setActive: (TabModel.ID) -> Void
    public let close: (TabModel.ID) -> Void
}

public struct DefaultEditorTabStripStyle: EditorTabStripStyle { /* ... */ }
public struct CompactEditorTabStripStyle: EditorTabStripStyle { /* ... */ }
public extension EditorTabStripStyle where Self == DefaultEditorTabStripStyle {
    static var `default`: Self { .init() }
}
public extension EditorTabStripStyle where Self == CompactEditorTabStripStyle {
    static var compact: Self { .init() }
}

public extension View {
    func editorTabStripStyle<S: EditorTabStripStyle>(_ style: S) -> some View
}

// TabStrip/EditorTab.swift             — all platforms
public struct EditorTab: View {
    public init(
        tab: TabModel,
        isActive: Bool,
        onSelect: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    )
}

// Breadcrumb/EditorBreadcrumbView.swift — all platforms
// (BreadcrumbComponent is defined in CodeEditorPlugin/Core/, see above.)
public struct EditorBreadcrumbView: View {
    public init(
        components: [BreadcrumbComponent]? = nil,             // nil → state.breadcrumbPath
        onSelect: ((BreadcrumbComponent) -> Void)? = nil
    )
}

// StatusBar/EditorStatusBar.swift      — all platforms
public struct EditorStatusBar<Trailing: View>: View {
    public init(@ViewBuilder trailing: () -> Trailing = { EmptyView() })
}

// Sidebar/EditorSidebarShell.swift     — macOS + Catalyst
public struct EditorSidebarShell<Header: View, Content: View, Footer: View>: View {
    public init(
        sectionTitle: String? = nil,
        @ViewBuilder header: () -> Header = { EmptyView() },
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    )
}

// CommandPalette/EditorCommandPalette.swift — all platforms
public struct EditorCommandPalette: View {
    public init(
        isPresented: Binding<Bool>,
        items: [CommandPaletteItem],
        onSelect: @escaping (CommandPaletteItem) -> Void,
        prompt: String = "Type a command…"
    )
}

// CommandPalette/EditorCommandPaletteStyle.swift — all platforms
public protocol EditorCommandPaletteStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
    typealias Configuration = EditorCommandPaletteStyleConfiguration
}

public struct EditorCommandPaletteStyleConfiguration {
    public let prompt: String
    public let query: Binding<String>
    public let visibleItems: [CommandPaletteItem]
    public let highlightedID: CommandPaletteItem.ID?
    public let onHighlight: (CommandPaletteItem.ID) -> Void
    public let onSelect: (CommandPaletteItem) -> Void
}

public struct DefaultEditorCommandPaletteStyle: EditorCommandPaletteStyle { /* ... */ }
public extension EditorCommandPaletteStyle where Self == DefaultEditorCommandPaletteStyle {
    static var `default`: Self { .init() }
}

public extension View {
    func editorCommandPaletteStyle<S: EditorCommandPaletteStyle>(_ style: S) -> some View
}

// CommandPalette/CommandPaletteItem.swift — all platforms
public struct CommandPaletteItem: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let kind: Kind
    public let shortcut: String?                              // display-only, e.g., "⌘P"
    public enum Kind: Sendable { case file, symbol, action, setting }
    public init(id: UUID = UUID(), title: String, subtitle: String? = nil,
                kind: Kind, shortcut: String? = nil)
}

// CommandPalette/EditorCommandPaletteRow.swift — all platforms
public struct EditorCommandPaletteRow: View {
    public init(item: CommandPaletteItem, isHighlighted: Bool)
}

// Glass/PlatformGlassSurface.swift     — all platforms
public struct PlatformGlassSurface: ViewModifier {
    public let role: Role
    public enum Role: Sendable { case titleBar, tabBar, statusBar, panel, popover }
}
public extension View {
    func platformGlassSurface(_ role: PlatformGlassSurface.Role) -> some View
}

// Theming/Theme+Chrome.swift           — all platforms
public extension Theme {
    var titleBarColor: Color           { Color(tokens: style.chrome.titleBarBackground) }
    var titleBarInactiveColor: Color   { Color(tokens: style.chrome.titleBarInactiveBackground) }
    var tabBarColor: Color             { Color(tokens: style.chrome.tabBarBackground) }
    var tabActiveColor: Color          { Color(tokens: style.chrome.tabActiveBackground) }
    var tabInactiveColor: Color        { Color(tokens: style.chrome.tabInactiveBackground) }
    var statusBarColor: Color          { Color(tokens: style.chrome.statusBarBackground) }
    var toolbarColor: Color            { Color(tokens: style.chrome.toolbarBackground) }
    var surfaceColor: Color            { Color(tokens: style.chrome.surfaceBackground) }
    var elevatedColor: Color           { Color(tokens: style.chrome.elevatedSurfaceBackground) }
    var panelColor: Color              { Color(tokens: style.chrome.panelBackground) }
    var panelFocusedBorderColor: Color { Color(tokens: style.chrome.panelFocusedBorder) }
}

// Theming/Theme+Glass.swift            — all platforms
public extension Theme {
    var glassTintColor: Color { Color(tokens: platform.glass.tint) }
    var glassOpacity: Double  { platform.glass.opacity }
    var popoverShadow: (color: Color, blur: CGFloat, x: CGFloat, y: CGFloat) {
        let s = platform.shadows.popover
        return (Color(tokens: s.color), CGFloat(s.blur), CGFloat(s.xOffset), CGFloat(s.yOffset))
    }
}
```

### Component reads & writes

| Component | Reads (env) | Reads (state) | Mutates |
|---|---|---|---|
| `EditorTitleBar` | `\.codeTheme` | `state.documentName` (fallback) | none |
| `EditorTrafficLights` | `\.codeTheme` | none | none |
| `EditorTabStrip` | `\.codeTheme` | none (via bindings) | bound `tabs` / `activeTabID` |
| `EditorBreadcrumbView` | `\.codeTheme` | `state.breadcrumbPath` (fallback) | none |
| `EditorStatusBar` | `\.codeTheme`, `\.codeEditorConfiguration`, `\.editorState` | `selection`, `language`, `lineCount`, `hardwareAccelerationActive` | none |
| `EditorSidebarShell` | `\.codeTheme` | none | none |
| `EditorCommandPalette` | `\.codeTheme` | none (via bindings/init) | bound `isPresented`, internal query state |
| `PlatformGlassSurface` | `\.codeTheme` | none | none |

### Editor-write integration

`CodeEditor.body` resolves an `EditorState` from `\.editorState`. The existing coordinator-routed `onSelectionChange` callback writes:

- `state.selection = SelectionState(line:, column:, selectionLength:)`
- `state.language = effectiveLanguage`
- `state.lineCount = ...`
- `state.hardwareAccelerationActive = ...` on configuration application
- `state.isDirty = ...` when text mutates relative to a snapshot

Host-written fields are never touched. If `\.editorState` was never set by the host, the env's default empty `EditorState()` receives writes that no chrome reads — no leak, no observer, observation no-ops.

## Tests

Located under `Tests/CodeEditorUITests/`. Uses the package's existing `swift-snapshot-testing` and `swift-custom-dump` deps.

### Type-shape & conformance audits (cross-platform)

Reflection-based audit, mirroring sub-project 2's pattern.

| Test | Asserts |
|---|---|
| `AllPublicTypesAreSendable` | Every public type in `CodeEditorUI` declared `Sendable` is `Sendable`. |
| `EditorStatePublicShape` | `CustomDump` snapshot of a populated `EditorState` instance — pins field set against accidental edits. |
| `TabModelHashStable` | `TabModel`'s `Hashable` is order-independent over a populated `[TabModel]`. |
| `BreadcrumbComponentRoundtrip` | `BreadcrumbComponent` round-trips through `[BreadcrumbComponent]` with stable `Hashable` and `Identifiable.id`. |

### `EditorState` mutation observation

| Test | Asserts |
|---|---|
| `MutatingSelection_FiresObservers` | Subscribe via `withObservationTracking`; mutate `state.selection`; observer fires exactly once. |
| `MutatingTabs_FiresObservers` | Same for `state.tabs`. |
| `EnvironmentDefaultIsDistinct` | Two views reading `\.editorState` without an explicit `.environment(...)` see independent default instances (per SwiftUI env-default semantics). |

### Style-protocol behavior

| Test | Asserts |
|---|---|
| `DefaultTabStripStyle_RendersForEmptyTabs` | `.default.makeBody(configuration: .empty)` returns a non-empty body. |
| `DefaultTabStripStyle_RendersForManyTabs` | Same with 10 tabs, one active, two dirty. |
| `CompactTabStripStyle_RendersDifferently` | Snapshot diff vs `.default` is non-trivial (catches accidental compact == default). |
| `DefaultPaletteStyle_RendersWithEmptyQuery` | `.default.makeBody(configuration: .empty)` shows prompt + zero rows. |
| `DefaultPaletteStyle_RendersWithFilteredItems` | Items render in `visibleItems` order; highlighted row is visually distinct. |
| `CustomTabStripStyle_Installs` | A test-only `IdentityTabStripStyle` installed via `.editorTabStripStyle(_:)` is what the strip renders. |

### Visual snapshot tests (macOS-gated)

`#if os(macOS) && !targetEnvironment(macCatalyst)`. Two themes: `Theme.lcarsDark` and one Zed Trek light variant (chosen at implementation time; `LCARS Light` if it exists in the family, otherwise the closest light). Per component:

| File | Cases |
|---|---|
| `EditorTitleBarSnapshots.swift` | 2 themes × {empty trailing, 3 toolbar pills} = 4 |
| `EditorTrafficLightsSnapshots.swift` | 2 themes × {decorative, with-callbacks} = 4 |
| `EditorTabStripSnapshots.swift` | 2 themes × {empty, single, many, with-dirty, with-compact-style} = 10 |
| `EditorBreadcrumbSnapshots.swift` | 2 themes × {short, long-truncating} = 4 |
| `EditorStatusBarSnapshots.swift` | 2 themes × {no-doc, doc-with-selection, with-trailing-extras} = 6 |
| `EditorSidebarShellSnapshots.swift` | 2 themes × {header+content+footer} = 2 |
| `EditorCommandPaletteSnapshots.swift` | 2 themes × {open-empty-query, open-with-query, open-no-results} = 6 |
| `PlatformGlassSurfaceSnapshots.swift` | 2 themes × 5 roles = 10 |

`isRecording` defaults off; CI fails if PNGs drift.

### What's explicitly not tested

- **Liquid Glass shader fidelity.** Apple owns the rendering. Re-record without considering it a regression if a snapshot diff is purely a Liquid Glass visual change across OS releases.
- **Real `NSWindow` integration.** `EditorTrafficLights` is painted; no NSWindow surgery exists to test.
- **Keyboard-shortcut binding for command palette.** Host wires `.keyboardShortcut`. The palette's internal `Esc`/`↑/↓`/`Return` handling is tested via a small ViewInspector-style check on the default style's body.
- **Performance.** Chrome views are static-shaped; nothing to perf-test at this layer.
- **iOS pixel diffs.** SwiftUI rendering on iOS simulator is flakier and adds CI surface area without proportional value.

## Acceptance criteria

- [ ] `swift build` succeeds with `CodeEditorUI` as a library product; no warnings.
- [ ] `swift test --filter CodeEditorUI` passes; new snapshots pass on second run.
- [ ] `swiftlint` reports zero violations across `Sources/CodeEditorUI/` and the additive `EditorState`/`TabModel`/`SelectionState`/env-key files in `CodeEditorPlugin`.
- [ ] DocC comments on every public symbol.
- [ ] `EditorState` is public, `@Observable`, available from `CodeEditorPlugin`. `\.editorState` env key exists with a default empty instance.
- [ ] All eight component files exist per the source tree; each compiles on the platforms its `#if`/`@available` declares.
- [ ] `EditorTabStripStyle` and `EditorCommandPaletteStyle` follow the SwiftUI Style protocol pattern with `Configuration` types and `.default` static accessors.
- [ ] `PlatformGlassSurface` reads `Theme.platform.glass` and applies the Tahoe-native Liquid Glass modifier.
- [ ] `EditorTabStrip` works on iOS — scroll-on-overflow, active state, close button, language glyph.
- [ ] `EditorStatusBar` reads `\.editorState` and `\.codeEditorConfiguration` and renders `Ln/Col` + tab/space mode + hardware-accel dot.
- [ ] CHANGELOG entry recording: new `CodeEditorUI` library product, new public `EditorState` / `TabModel` / `SelectionState` / `\.editorState` env key in `CodeEditorPlugin`, eight chrome components, two Style protocols, `PlatformGlassSurface` modifier.

## Scope deviations from the umbrella sketch

Recorded explicitly so future readers can distinguish deliberate decisions from oversight:

1. **State pattern:** umbrella was silent on observability. This sub-project adopts **`@Observable EditorState`** in `CodeEditorPlugin`. The host owns most fields; the editor writes selection/language/dirty/hwAccel/lineCount.
2. **Command palette:** umbrella named only `EditorCommandPaletteStyle.swift`. This sub-project ships **both** the style protocol *and* an opinionated `EditorCommandPalette` view.
3. **Tab strip API:** umbrella sketched "host-owned state via binding"; this sub-project takes `Binding<[TabModel]>` + `Binding<TabModel.ID?>` directly, *not* via `EditorState`, so the strip is embeddable without a chrome-state instance. `EditorState.tabs`/`activeTabID` are convenience pass-throughs hosts can use.
4. **Traffic lights:** umbrella said "system traffic lights wrapper." This sub-project ships **painted SwiftUI lights**, not real `NSWindow` button surgery. Functional via optional callbacks.
5. **Cross-platform:** umbrella was silent on per-component availability. This sub-project adopts **tiered availability** — title bar/traffic lights/sidebar shell are macOS+Catalyst; tab strip/breadcrumb/status bar/command palette/glass surface are all-platform.
6. **No keyboard-shortcut binding** for command palette; host attaches `.keyboardShortcut`. Avoids `⌘P` vs `⌘⇧P` collision questions in the library.
7. **No drag-to-reorder, no middle-click-close** in tab strip v1. Reorder is host-implementable via the bound array; middle-click is additive later.

## Out of scope (explicit)

- **File tree implementation** — sub-project 5. `EditorSidebarShell` is a styled container; the tree is host-supplied.
- **Multi-document state machine** — sub-project 5. `[TabModel]`/`activeTabID` shapes are provided; tab-lifecycle logic is host-owned.
- **Workspace model / file watching** — sub-project 5.
- **Theme/language/preset switcher controls** — sub-project 5 (sample-app concerns).
- **Real `NSWindow` integration** — `.windowStyle(.hiddenTitleBar)` + window-toolbar APIs are host-applied. The library doesn't try to own window configuration.
- **Settings / preferences UI** — not on the roadmap.
- **Status-bar plugin slots** — host's `trailing` `@ViewBuilder` is the extensibility seam; we don't ship a registry.
- **Search/find-in-file UI** — `searchable` exists at the editor level; we don't ship a chrome-side search panel.
- **Editor visual restyle** — sub-project 3.

## Open questions deferred to sub-project 5

- Default keyboard shortcut for command palette presentation (`⌘⇧P`? `⌘P`?). Sample app picks one; library stays neutral.
- Whether the sample app's tab strip should reorder via drag (would inform whether to back-port that as an opt-in tab-strip behavior).
- iOS host story (separate Xcode project) — still open from the umbrella.

## Recommended commit slicing

For the implementation plan to expand on:

1. Add `EditorState` + `SelectionState` + `TabModel` + `BreadcrumbComponent` + `\.editorState` env key in `CodeEditorPlugin`. Tests: type-shape, mutation observation, breadcrumb roundtrip.
2. Add `CodeEditorUI` target skeleton + `Package.swift` wiring. Empty target compiles; test target compiles.
3. Add `Theme+Chrome.swift`, `Theme+Glass.swift`, `PlatformGlassSurface`. Snapshot tests for each role.
4. Add `EditorTrafficLights` + `EditorTitleBar` + macOS/Catalyst gating. Snapshots.
5. Add `EditorBreadcrumbView`. Snapshots.
6. Add `EditorStatusBar`. Snapshots.
7. Add `EditorTab` + `EditorTabStrip` + `EditorTabStripStyle` protocol + `Default`/`Compact` styles. Snapshots × style behavior tests.
8. Add `EditorSidebarShell`. Snapshots.
9. Add `CommandPaletteItem` + `EditorCommandPaletteRow` + `EditorCommandPaletteStyle` protocol + `Default` style + `EditorCommandPalette` view. Snapshots × style behavior tests.
10. Wire editor-side writes to `EditorState` (selection/language/dirty/hwAccel/lineCount) in `CodeEditor.body`'s coordinator path. Tests cover the write-path.
11. DocC pass + final SwiftLint sweep + CHANGELOG entry.

## References

- Umbrella spec: [`docs/superpowers/specs/2026-05-05-design-system-migration-design.md`](2026-05-05-design-system-migration-design.md).
- Sub-project 1 (shipped): same umbrella, Sub-project 1 section.
- Sub-project 2 spec (shipped): [`docs/superpowers/specs/2026-05-05-theme-rewrite-design.md`](2026-05-05-theme-rewrite-design.md).
- Design prototype: `Design/macos-window.jsx` (Tahoe window chrome), `Design/app.jsx` (full IDE shell), `Design/editor.jsx` (editor visual prototype).
- Existing public API surfaces this sub-project extends: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`, `Sources/CodeEditorPlugin/Theming/Theme.swift`, `Sources/CodeEditorPlugin/Theming/ChromeColors.swift`, `Sources/CodeEditorPlugin/Theming/PlatformExtension.swift`, `Sources/CodeEditorPlugin/Theming/SwiftUI/Theme+SwiftUI.swift`.
