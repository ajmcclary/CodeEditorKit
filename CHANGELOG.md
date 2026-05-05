# Changelog

## Unreleased

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
