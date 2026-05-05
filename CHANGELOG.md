# Changelog

## Unreleased

### Editor visual restyle — foundations (sub-project 3, partial)

Foundations and architectural skeleton landed; per-component subview
wiring (gutter, minimap, line highlight, caret, completion popover,
annotations, indent guides, fold chevrons) deferred to a follow-up
sprint. See [`docs/superpowers/plans/2026-05-05-editor-visual-restyle.md`](docs/superpowers/plans/2026-05-05-editor-visual-restyle.md)
Tasks 6–15.

#### Added

- `Theming/Bridges/` directory housing the four token bridges:
  `Tokens.Color → SwiftUI.Color` (`Color(tokens:)`),
  `Tokens.Color → NSColor` / `UIColor` (`init(tokens:)`),
  `Tokens.Easing → SwiftUI.Animation` (`Animation.timingCurve(easing:duration:)`),
  `Tokens.Animation → SwiftUI.Animation` named convenience
  (`Tokens.Animation.foldChevron`, the only call site this sub-project
  will use; later sub-projects' named animations land alongside).
- `Theme.color(forToken:)` — public hierarchical resolver. Drops
  trailing dotted segments on miss (`function.method.builtin` →
  `function.method` → `function` → `style.editor.foreground`); per-Theme
  `NSLock`-guarded cache keyed by `(name, appearance, foregroundHex)`.
- `CodeEditorContainerView.apply(theme:)` and
  `CodeEditorContainerView.appliedTheme` — equality-gated theme push
  point. Subview fan-out is the empty body for now; later tasks fill it
  as each subview's draw path migrates from hardcoded `PlatformColors`
  to theme reads.
- `CodeEditorRepresentableHelper.updateContainer` calls
  `container.apply(theme:)` so the SwiftUI environment's `\.codeTheme`
  flows into the AppKit/UIKit container on every refresh.

#### Changed

- `Theming/SwiftUI/Theme+SwiftUI.swift` moved to
  `Theming/Bridges/Theme+SwiftUI.swift`; only the `Theme.default` and
  `Theme.dark` static aliases survive the migration.
- `CodeEditor+CoordinatorsExtensions.swift` — four call sites
  (`textView.backgroundColor` / `.textColor` reads) now pull from
  `style.editor.background` / `.foreground` directly via
  `PlatformColor(tokens:)`.

#### Removed

- The four legacy `Theme` accessors `backgroundColor`, `textColor`,
  `lineNumberColor`, `selectedLineColor` (sub-project 2 transition
  surface). Direct `style.editor.*` reads replace them.
- `Theming/SwiftUI/` directory (now empty after the migration).

#### Tests

- `ColorBridgesTests` — sRGB roundtrip on SwiftUI / NSColor / UIColor.
- `AnimationBridgesTests` — `timingCurve(easing:duration:)` curve match,
  `foldChevron` shape stability.
- `SyntaxColorLookupTests` — direct hit, hierarchical fallback,
  full-miss-falls-through, cache stability.
- `ApplyThemePropagationTests` — container stores applied theme,
  equality-gate, different-theme replacement.

#### Deferred to future commits (sub-project 3 plan tasks 6–14)

- Subview-level theme reads: `GutterView`, `MinimapView`,
  `LineHighlightView`, `InsertionPointView`, `TextLayoutFragmentView`,
  `CompletionCellComponents`, `AnnotationView`/`AnnotationsContentView`.
- `AnnotationKind.color → color(in:)` retype and call-site migration.
- Indent guide rendering (new visual surface).
- Fold chevron rendering with `Tokens.Animation.foldChevron` rotation.
- `_GlassSurface` frosted-glass wrapper for the completion popover.
- Selection-color reads from `style.players[0].selection`.
- `BaseUIComponents.StandardUITheme` removal and
  `ThemeableUIComponent.theme` retype to `Theme`.
- DocC `Theme-System.md` example refresh (still references the deleted
  legacy accessors).

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
