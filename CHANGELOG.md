# Changelog

## Unreleased

### Editor visual restyle (sub-project 3 of the design system migration)

Push-model theme propagation landed end-to-end. Every editor-internal
rendering surface (gutter, minimap, line highlight, caret, annotations,
selection fill, completion popover) now reads colors from `Theme` via an
equality-gated `apply(theme:)` chain that the SwiftUI representable
forwards from `\.codeTheme` on every refresh. New visual surfaces —
indent guides and fold chevrons — ship as pure-value primitives ready to
plug into the fragment renderer in a follow-up.

#### Added

- `Theming/Bridges/` directory housing the four token bridges:
  `Tokens.Color → SwiftUI.Color` (`Color(tokens:)`),
  `Tokens.Color → NSColor` / `UIColor` (`init(tokens:)`),
  `Tokens.Easing → SwiftUI.Animation` (`Animation.timingCurve(easing:duration:)`),
  `Tokens.Animation → SwiftUI.Animation` named convenience
  (`Tokens.Animation.foldChevron`).
- `Theme.color(forToken:)` — public hierarchical resolver. Drops
  trailing dotted segments on miss (`function.method.builtin` →
  `function.method` → `function` → `style.editor.foreground`); per-Theme
  `NSLock`-guarded cache keyed by `(name, appearance, foregroundHex)`.
- `SyntaxColorScheme.color(forToken:in:)` — recommended entry point for
  per-run color decisions; routes through `Theme.color(forToken:)` so
  call sites get hierarchical dotted fallback over `style.syntax`.
- `CodeEditorContainerView.apply(theme:)` and
  `CodeEditorContainerView.appliedTheme` — equality-gated theme push
  point that fans out to `gutterView`, `minimapView`, and `textView`.
- `CodeEditorView.apply(theme:)` — sets the macOS
  `selectedTextAttributes[.backgroundColor]` to
  `style.players[0].selection` and the iOS `tintColor` to
  `style.players[0].cursor`.
- `GutterView` + `GutterViewRenderer` `apply(theme:)`. Background from
  `style.editor.gutterBackground`; inactive line numbers from
  `style.editor.lineNumber`; active number from
  `style.editor.activeLineNumber`.
- `LineHighlightView.apply(theme:)` — fill from
  `style.editor.activeLineBackground`.
- `InsertionPointView.apply(theme:)` — caret from
  `style.players[0].cursor`.
- `MinimapView.apply(theme:)` (both AppKit and UIKit variants) —
  background from `style.editor.background`; viewport indicator from
  `style.scrollbar.thumbBackground`; track from
  `style.scrollbar.trackBackground`.
- `AnnotationKind.color(in:)` reads from `style.status.{info,warning,
  error}.base`. `AnnotationView.apply(theme:)` and
  `AnnotationsContentView.apply(theme:)` fan-out.
- `IndentGuideGeometry` — pure-value indent column arithmetic
  (leading whitespace × `tabWidth`, tabs counted as `tabWidth` spaces;
  blank-line continuity inherits prior depth).
- `FoldChevronAnimation` — animation gate keyed off
  `config.performance.animateCodeFolding`; `FoldChevronHitTester` —
  16×lineHeight hit-rect at the leading edge of the gutter, plus a
  `chevronHit(at:lineHeight:visibleLineYs:)` lookup.
- `CompletionPopoverThemeMetrics` — value-typed bundle of theme-derived
  popover metrics (selected-row, primary/secondary text, border, corner
  radius). `UnifiedCompletionCellView` /
  `UnifiedCompletionTableViewCell` gain `apply(theme:)` that updates
  label colors from these metrics.
- `Layout/Glass/_GlassSurface` — internal frosted-glass wrapper backing
  the AppKit/UIKit completion popover. Tinted from
  `theme.platform.glass.tint @ glass.opacity`.
- `ThemeableUIComponent` — retyped to expose the editor's `Theme` value
  type directly via `appliedTheme` + `apply(theme:)`. Empty-extension
  conformances on `GutterView`, `LineHighlightView`,
  `InsertionPointView`, `AnnotationsContentView`, `AnnotationView`, and
  the platform-specific minimap views.

#### Changed

- `Theming/SwiftUI/Theme+SwiftUI.swift` moved to
  `Theming/Bridges/Theme+SwiftUI.swift`; only the `Theme.default` and
  `Theme.dark` static aliases survive the migration.
- `CodeEditor+CoordinatorsExtensions.swift` — four call sites
  (`textView.backgroundColor` / `.textColor` reads) now pull from
  `style.editor.background` / `.foreground` directly via
  `PlatformColor(tokens:)`.
- Minimap draw paths (AppKit + UIKit) prefer the themed background /
  viewport / track colors when a theme is in flight, falling back to
  `MinimapConfiguration`'s static defaults otherwise.

#### Removed

- The four legacy `Theme` accessors `backgroundColor`, `textColor`,
  `lineNumberColor`, `selectedLineColor` (sub-project 2 transition
  surface). Direct `style.editor.*` reads replace them.
- `Theming/SwiftUI/` directory (now empty after the migration).
- `BaseUIComponents.StandardUITheme`, `BaseUITheme`, the generic
  `BaseConfigurableView` / `BaseReusableTableCellView` /
  `BaseReusableTableViewCell` infrastructure, and `UIComponentFactory`.
  None had consumers inside or outside the package.

#### Tests

- `ColorBridgesTests` — sRGB roundtrip on SwiftUI / NSColor / UIColor.
- `AnimationBridgesTests` — `timingCurve(easing:duration:)` curve match,
  `foldChevron` shape stability.
- `SyntaxColorLookupTests` — direct hit, hierarchical fallback,
  full-miss-falls-through, cache stability.
- `ApplyThemePropagationTests` — container stores applied theme,
  equality-gate, different-theme replacement.
- `GutterViewThemeTests` — gutter background, inactive/active line
  numbers, equality gate.
- `LineHighlightInsertionPointThemeTests` — fill / caret reads.
- `MinimapViewThemeTests` — background / viewport / track reads.
- `AnnotationThemeTests` — `AnnotationKind.color(in:)` mappings;
  `AnnotationView` / `AnnotationsContentView` propagation.
- `SyntaxColorAndSelectionTests` — `SyntaxColorScheme.color(forToken:in:)`
  and macOS / iOS selection paths.
- `IndentGuideTests` — geometry, blank-line continuity, disabled-when-
  zero.
- `FoldChevronTests` — animation gate behavior, hit-rect geometry, hit
  lookup.
- `CompletionCellGlassTests` — popover metrics, `_GlassSurface` tint,
  cell `apply(theme:)`.
- `ThemeableUIComponentTests` — `ThemeableUIComponent` conformance for
  the wired views.

#### Deferred to follow-up commits

- Token-colored minimap bars (the minimap renderer doesn't yet carry
  `TokenName` into its draw routine).
- `TextLayoutFragmentView` rendering of indent guides / per-run colors —
  the geometry primitives ship; the fragment-render plumbing (active-
  column recompute on selection-change, font-advance probes) is its own
  concern.
- `GutterView` migration from triangle-glyph fold control to SF Symbol
  chevron rotation that consumes the new animation/hit-test primitives.
- DocC `Theme-System.md` example refresh (still references the deleted
  legacy accessors).

### CodeEditorUI chrome primitives (sub-project 4)

Eight chrome components, two SwiftUI Style protocols, the
`EditorState @Observable` class + environment key in
`CodeEditorPlugin`, the `PlatformGlassSurface` modifier, the
`Theme+Chrome` / `Theme+Glass` bridges, and 50 baseline PNG snapshots
across two themes. Build clean, lint zero violations, every test
green.

#### Done (commits)

| Task | Commit | Description |
|---|---|---|
| 1 | `ad91963` | `EditorState` + value types in `CodeEditorPlugin` |
| 2 | `ccda1fc` | `CodeEditorUI` target skeleton + `Package.swift` |
| 3 | `9417cfa` | `Theme+Chrome` + `Theme+Glass` bridges |
| 4 | `a897a4f` | `PlatformGlassSurface` + snapshot scaffolding |
| 5 | `7c92c08` | `EditorTrafficLights` + `EditorTitleBar` |
| 6 | `50cd969` | `EditorBreadcrumbView` |
| 7 | `44118e2` | `EditorStatusBar` |
| 8 | `1d6ffd3` | `EditorTabStrip` + Style |
| 9 | `ce60ad8` | `EditorSidebarShell` |
| 10 | `fc1646c` | `EditorCommandPalette` + Style + Row |
| 11 | `013721e` | `EditorStateBridge` helper (coordinator wiring deferred) |
| 12 | this commit | Conformance audit + DocC sweep + sign-off |

#### Task 12 — added

- `ConformanceAuditTests` — compile-time audit covering the chrome
  surface: `View` on every chrome view, `ViewModifier` on
  `PlatformGlassSurface`, the declared style protocol on
  `Default`/`Compact` style implementers, `Hashable + Sendable` on
  value enums (`PlatformGlassSurface.Role`, `CommandPaletteItem.Kind`),
  `Hashable + Identifiable + Sendable` on `CommandPaletteItem`, and
  `Sendable` on `TrafficLightsConfiguration`. Generic chrome views
  audited via concrete `EmptyView` instantiations; AppKit-only types
  gated on `canImport(AppKit)` to mirror the production declarations.

#### Task 12 — DocC sweep

- `CodeEditorUI` umbrella enum gains a full `## Topics` discussion
  grouping every public symbol by surface (Window chrome, Tab strip,
  Status bar & breadcrumb, Sidebar, Command palette, Liquid Glass).
- Per-case docs added to `PlatformGlassSurface.Role` (background +
  tint multiplier + shadow per role) and to `CommandPaletteItem.Kind`
  (semantic intent + glyph for each case).
- `init()` doc comments added to `DefaultEditorTabStripStyle` and
  `CompactEditorTabStripStyle` for symmetry with
  `DefaultEditorCommandPaletteStyle`.

#### Sub-project 4 acceptance checklist

- [x] `CodeEditorUI` ships as a separate library product wired into
      `Package.swift`.
- [x] `EditorState @Observable` + `\.editorState` environment key live
      in `CodeEditorPlugin`; chrome views read from the environment
      with explicit-argument overrides where applicable.
- [x] `Theme+Chrome` and `Theme+Glass` SwiftUI bridges expose
      `theme.titleBarColor` / `theme.glassTintColor` / `popoverShadow`
      / etc. directly.
- [x] `PlatformGlassSurface` modifier implements the role → background
      / tint-multiplier / shadow mapping spec'd in the umbrella.
- [x] All eight chrome components ship with init docs, are
      snapshot-tested in light + dark across realistic states, and
      are pinned by a compile-time conformance audit.
- [x] Two SwiftUI Style protocols (`EditorTabStripStyle`,
      `EditorCommandPaletteStyle`) ship with their `Configuration`
      shape, default implementer, and view-modifier installer.
- [x] AppKit-only chrome (`EditorTrafficLights`, `EditorTitleBar`,
      `EditorSidebarShell`) is gated on `canImport(AppKit)`.
- [x] `swift build` clean, `swiftlint` zero violations,
      `swift test --parallel` all green.

#### Deferred to follow-up commits

- `EditorStateBridge` ↔ `CrossPlatformCoordinator` two-way wiring
  (selection / language / hardware-acceleration flow from the editor
  back into `EditorState`) — captured in the Task 11 commit message;
  belongs to sub-project 5.
- DocC `Theme-System.md` example refresh (still references the
  legacy accessors removed in sub-project 3).

### Theme rewrite (sub-project 2 of the design system migration)

#### Added

- New `Theme`, `ThemeFamily`, `ThemeStyle` value types under
  `CodeEditorPlugin.Theming`, modelling the Zed v0.2.0 theme JSON
  schema. Every public type is `Sendable`, `Hashable`, `Codable`.
- 17 sub-struct value types (`EditorColors`, `ChromeColors`,
  `ElementStates`, `BorderColors`, `TextLevels`, `IconLevels`,
  `StatusPalette`, `VCSPalette`, `ScrollbarColors`, `SearchColors`,
  `PredictiveColors`, `HintColors`, plus `Player`, `SyntaxStyle`,
  `TerminalColors`, and the nested `States`/`Status`/`VCS` structs).
- `PlatformExtension` value type extending the Zed schema with
  Liquid Glass / shadow / field knobs. Always present on a `Theme`;
  derived from the rest of the style via `derived(from:appearance:)`
  when JSON omits the `platform` key.
- Custom `Codable` decoder in `ThemeStyle` that reads Zed's flat
  dotted snake_case keys (e.g., `editor.gutter.background`,
  `text.muted`) and routes each to the correct sub-struct via a
  per-prefix `init(flat:warnings:path:)` constructor.
- `WarningCollector`-based lenient decoding: missing or malformed
  individual color keys fall back to a `ThemeFallbackPalette` default
  and accumulate as `ThemeWarning` values rather than throwing.
- Loader API:
  - `ThemeFamily(jsonData:)` / `ThemeFamily(contentsOf:)` for the
    throwing path.
  - `ThemeFamily.loaded(jsonData:)` / `loaded(contentsOf:)` returning
    `(ThemeFamily, [ThemeWarning])` for callers that want to surface
    diagnostics.
  - `ThemeFamily.bundled(_:)` and `Theme.bundled(family:variant:)`
    for resource lookup.
  - `Theme.lcarsDark` — the library default.
  - `Theme.fallback(appearance:)` — final fallback assembled from
    internal palette colors.
- `.codeTheme(_:)` SwiftUI modifier and `EnvironmentValues.codeTheme`
  environment value (default: `Theme.lcarsDark`).
- Bundled `zed-trek.json` (20 variants — *Black Alert*, *Borg Cube*,
  *Command*, *Federation*, *LCARS*, *Mission Control*, *Ready Room*,
  *Red Alert*, *Sick Bay*, *Yellow Alert*, each in Dark/Light) under
  `Sources/CodeEditorPlugin/Resources/Themes/`. Authored by
  ajmcclary, vendored with attribution from
  `~/Downloads/zed-trek/themes/zed-trek.json`.

#### Removed (breaking)

- `Theme.Colors` and `Theme.Fonts` — replaced by `Theme.style.*`.
- `CodeEditorSwiftUITheme` — covered by `Theme.style.editor.*` plus
  the SwiftUI bridge accessors on `Theme` (`backgroundColor`,
  `textColor`, `lineNumberColor`, `selectedLineColor`).
- `.codeEditorTheme(_:)` modifier — replaced by `.codeTheme(_:)`.
- `EditorTheme` and `ThemeColors` from
  `PluginSystem/PluginAPI.swift` — `ThemeAPI` now takes/returns the
  new `Theme` directly.

#### Default behavior

- Library default theme is now `LCARS Dark` (from the bundled
  `zed-trek` family), not the previous `CodeEditorSwiftUITheme.default`
  (clear / system colors).

#### Scope deviations from the umbrella spec

- The umbrella sketched five "neutral" defaults (Xcode Dark/Light, VS
  Code Dark, GitHub, Solarized) plus Zed Trek; this rollout ships
  **only Zed Trek**. The neutrals can be added in a separate
  follow-up if anyone needs them.
- `PlatformExtension` is non-optional, with derived defaults — the
  umbrella was silent on this and `derived(from:appearance:)`
  resolves the question.

#### Tests

- 53 new tests under `Tests/CodeEditorPluginTests/Theming/` covering
  foundation primitives, leaf value types, the central decoder,
  bundled-resource lookup, all 20 Zed Trek variants decoding cleanly
  with zero warnings, lenient-decode behavior (missing keys,
  malformed colors, absent `platform`, emphasis-only syntax entries),
  conformance audit, encode/decode roundtrip equivalence, and the
  SwiftUI modifier.
- `LCARS Dark` style structure snapshot via swift-snapshot-testing +
  CustomDump.
