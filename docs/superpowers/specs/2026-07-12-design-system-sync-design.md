# Design-System Sync — Bring CodeEditorPlugin to Design-System Parity

**Date:** 2026-07-12
**Status:** Design (spec) — awaiting user review before planning.

## Goal

Bring this codebase's design layer into full parity with the evolved **CodeEditorPlugin Design System** (Claude Design project `50c9c2ef-8ed4-445e-870e-0273e3d082fc`, canonical artifact `colors_and_type.css`). The CSS header states it "mirrors the token system in `Sources/CodeEditorDesignTokens/` and the Zed Trek theme family in `Sources/CodeEditorTheming/Resources/Themes/zed-trek.json`" — i.e. this codebase is the origin, and the published design system has since evolved (contrast audit + new roles). We pull that evolution back in.

The sibling app RepoPrompt already performed the analogous sync (`~/Dev/repoprompt`, plan `2026-07-11-design-tokens-full-sync.md`). Its codegen-from-CSS philosophy is the template; our architecture differs (JSON-driven themes, not Swift-literal palettes), so the mechanism is adapted to **merge-into-JSON**.

## Decisions (locked with user)

1. **Full sync** — add the new themes/roles/scales **and** update the existing 20 themes' colors to the AAA-hardened CSS values. Existing-theme snapshots re-record; appearance shifts to the audited values.
2. **Homeless roles → `PlatformExtension`** — `on-accent`, `on-danger`, and an explicit `glass-tint` live in the existing `PlatformExtension` (our "things vanilla Zed lacks" struct). Diagnostics map to native Zed keys: `diag-error/warning/info/success` → `status.*.base`, `diag-modified` → `vcs.modified.base`.
3. **Elevation/focus-ring → DesignTokens layer** — the CSS shadow triplet and focus ring are *scheme-constant* (every dark theme shares them; every light theme shares them), so they become scheme-keyed `Tokens.Elevation`, not per-theme JSON. `PlatformExtension.derived(...)` sources its shadow from there → single source of truth.
4. **Merge-codegen for the JSON** — our `zed-trek.json` is a **superset** of the CSS (it carries `scrollbar.*`, `players`, `predictive`, `hint`, `status.background/border`, `vcs.*`, `border.disabled`, `icon.placeholder`, …). The codegen overwrites the ~50 CSS-defined keys over the existing JSON and preserves the rest — it does **not** regenerate the file from CSS alone (that would drop the superset keys).

## Out of scope

- Building new UI screens/components from the design project's HTML previews. The Claude Design MCP is unavailable this session, and this package is a framework, not an app; this effort is purely the token + theme-system sync.
- Broad application of the new roles across consumer views. New roles are *defined and exposed*; only the single obvious `onAccent` site (if one exists in `CodeEditorUI`) is wired. Broad wiring is a follow-up (matches RepoPrompt's "defer broad application").

## Architecture

Two layers, unchanged in shape:

- **`CodeEditorDesignTokens`** — static, theme-independent primitives. Gains: `Tokens.Size.Control`, `Tokens.Elevation` (new file), `Tokens.Typography.Tracking.tight`. (`Tokens.Spacing.smMd` already exists — no change.)
- **`CodeEditorTheming`** — per-theme semantic colors decoded from `zed-trek.json`. `PlatformExtension` gains `onAccent`/`onDanger` and an explicitly-loadable `glass.tint`. The JSON is regenerated (22 themes).

### Source of truth for the sync

Vendored copy of `colors_and_type.css` (identical to RepoPrompt's, dated 2026-07-11) is committed under the spec's tools folder. If the Claude Design MCP becomes available, re-fetch `get_file(project 50c9c2ef-…, path colors_and_type.css)` and diff before regenerating; otherwise the vendored copy is authoritative.

## Component 1 — `CodeEditorDesignTokens` additions

### `Tokens.Size.Control` (nested enum in `Size.swift`)

| Token | pt | CSS var |
|---|---|---|
| `height` | 32 | `--control-h` |
| `heightCompact` | 27 | `--control-h-compact` |
| `heightSmall` | 24 | `--control-h-sm` |
| `row` | 34 | `--row-h` |
| `rowCompact` | 28 | `--row-h-compact` |
| `chip` | 26 | `--chip-h` |
| `switchWidth` | 38 | `--switch-w` |
| `switchHeight` | 22 | `--switch-h` |
| `switchKnob` | 18 | `--switch-knob` |
| `accentBar` | 2 | `--accent-bar` |
| `titleBar` | 38 | `--titlebar-h` |
| `tabStrip` | 36 | `--tabstrip-h` |
| `statusBar` | 28 | `--statusbar-h` |

### `Tokens.Elevation` (new file `Elevation.swift`)

```
public struct Shadow: Sendable, Hashable { color: Tokens.Color; blur, x, y: Double }
static func popover(_ appearance: Theme.Appearance-agnostic scheme) -> Shadow
static func card(_:) -> Shadow
static func window(_:) -> Shadow
static let focusRingWidth: Double = 3
static func focusRing(accent: Tokens.Color) -> Tokens.Color   // accent @ 0.28 alpha
```

DesignTokens must not depend on `CodeEditorTheming`, so the scheme parameter is a local `enum Tokens.Elevation.Scheme { dark, light }` (or reuse an existing appearance-agnostic type in DesignTokens). Values (CSS `offset-x offset-y blur color` → `x y blur color`):

| | popover | card | window |
|---|---|---|---|
| **dark** | `#000000`@0.30, blur 36, y 10 | @0.18, blur 12, y 4 | @0.55, blur 80, y 24 |
| **light** | @0.12, blur 32, y 12 | @0.10, blur 12, y 4 | @0.18, blur 70, y 24 |

`x` = 0 for all. Blur is passed through verbatim (RepoPrompt confirmed the CSS card blur-12 already matched existing `.shadow(radius: 12)` sites).

### `Tokens.Typography.Tracking.tight`

`public static let tight: Double = -0.01  // em (CSS --tracking-tight: -0.01em)`. `caps` (0.5) is unchanged.

### Tests (DesignTokens)

- Extend `SizeTests`, add `Tokens.Size.Control` assertions (e.g. `.height == 32`, `.switchKnob == 18`).
- New `ElevationTests`: `Elevation.card(.dark).blur == 12`; `card(.dark).color != card(.light).color`; `window(.dark).y == 24`; `focusRingWidth == 3`; `focusRing(accent:)` alpha ≈ 0.28.
- Extend `TypographyTests` for `Tracking.tight == -0.01`.
- `TokensSnapshotTests` re-records (`isRecording: true`, then commit the regenerated JSON snapshot).

## Component 2 — `CodeEditorTheming` model change

### `PlatformExtension` (in `PlatformExtension.swift`)

- Add stored `public let onAccent: Tokens.Color` and `public let onDanger: Tokens.Color`.
- `glass.tint` becomes loadable from JSON `platform.glass.tint`; when absent, keep the current derived value (editor.bg). `onAccent`/`onDanger` fall back to sensible derivations when `platform.*` is absent (dark → `#05060A`-like near-bg / `text`; light → `#FFFFFF`) so pre-existing consumers and `Theme.fallback` still build.
- `PlatformExtension.derived(from:appearance:)` sources its shadow blur/offset/color from `Tokens.Elevation` instead of the inline literals, so the elevation values have one home.
- `flatten(into:)` round-trips the new `platform.on_accent` / `platform.on_danger` keys.

**No struct change for diagnostics** — they resolve through existing `StatusPalette` (`status.error/warning/info/success.base`) and `VCSPalette` (`vcs.modified.base`).

### Tests (Theming, in `Tests/CodeEditorPluginTests/Theming/`)

- `PlatformExtension` decode test: a theme with `platform.on_accent`/`on_danger`/`glass.tint` resolves them; a theme without still builds via fallback.
- Signature-value tests (hand-transcribed from CSS — independent path):
  - LCARS Dark: `surface == #161F33`, `tab.active_background == #111827`, `editor.gutter == #0D1018`, `onAccent == #05060A`, `syntax.comment == #939BA9`.
  - LCARS Light: `background == #FBF7F1`, `accents[0] == #9E5A18`, `editor.foreground == #2A1F0A`.
  - LCARS HC Dark: `background == #05060A`, `accents[0] == #FF9933`, `status.error.base == #F37F7F`, `text.placeholder == #99A1AD`.
  - LCARS HC Light: `background == #FBF7F1`.
- `ThemeFamily("zed-trek").themes.count == 22`; both HC variants resolvable by name.
- `ThemeStyleSnapshotTests` re-records.

## Component 3 — `zed-trek.json` regeneration (merge-codegen)

### Tooling (dev-only, not a build target)

Under `docs/superpowers/specs/2026-07-12-design-system-sync/tools/`:
- `colors_and_type.css` — vendored source (verbatim).
- `gen_theme_json.py` — parses the CSS `.theme-*` blocks, loads the existing `zed-trek.json`, and emits the new one.
- `zed-trek.generated.json` — script output, committed as a diff aid; the real `Sources/.../zed-trek.json` is replaced from it after spot-check.

### CSS → Zed key map (the ~50 semantic keys the merge overwrites)

| CSS var | Zed JSON key |
|---|---|
| `bg` | `background` |
| `surface` | `surface.background` |
| `elevated` | `elevated_surface.background` |
| `panel` | `panel.background` |
| `editor-bg` / `editor-fg` / `editor-gutter` | `editor.background` / `.foreground` / `.gutter.background` |
| `title-bar` / `toolbar` / `tab-bar` / `status-bar` | `title_bar.background` / `toolbar.background` / `tab_bar.background` / `status_bar.background` |
| `tab-active` / `tab-inactive` | `tab.active_background` / `tab.inactive_background` |
| `border` / `border-variant` / `border-focused` / `border-selected` | `border` / `border.variant` / `border.focused` / `border.selected` |
| `text` / `text-accent` / `text-muted` / `text-disabled` / `text-placeholder` | `text` / `text.accent` / `text.muted` / `text.disabled` / `text.placeholder` |
| `icon` / `icon-accent` / `icon-muted` | `icon` / `icon.accent` / `icon.muted` |
| `element-bg/hover/active/selected` | `element.background/hover/active/selected` |
| `ghost-hover/active/selected` | `ghost_element.hover/active/selected` |
| `accent-1..5` | `accents[0..4]` |
| `active-line` / `highlighted-line` | `editor.active_line.background` / `editor.highlighted_line.background` |
| `line-num` / `active-line-num` | `editor.line_number` / `editor.active_line_number` |
| `syn-<x>` | `syntax.<x>.color` (keyword/string/comment/function/type/number/constant/property/variable/punct→`punctuation`/tag/attr→`attribute`) |
| `diag-error/warning/info/success` | `status.error/warning/info/success.base` |
| `diag-modified` | `vcs.modified.base` |
| `on-accent` / `on-danger` | `platform.on_accent` / `platform.on_danger` |
| `glass-tint` | `platform.glass.tint` |

### Codegen rules

- **Merge, don't replace:** start from the existing theme object; overwrite mapped keys; leave all other keys intact.
- **Color normalization:** hex → uppercase `#RRGGBB`. `rgba(r,g,b,a)` → `#RRGGBBAA` with `AA = round(a*255)` uppercase (matches existing JSON, e.g. `rgba(126,200,222,0.094)` → `#7EC8DE18`).
- **Syntax key aliases:** CSS `syn-punct` → `punctuation`, `syn-attr` → `attribute`; others are the literal name.
- **Two new themes:** `LCARS High Contrast Dark` (from `.theme-lcars-hc`) and `LCARS High Contrast Light` (from `.theme-lcars-hc-light`). Their non-CSS superset keys (scrollbar, players, predictive, hint, `status.background/border`, `vcs.*` beyond modified, `border.disabled`, `icon.placeholder/disabled`, `element.disabled`, `ghost_element.background/disabled`, `title_bar.inactive_background`, `pane*`/`panel.focused_border`, `background.appearance`) are cloned from the existing `LCARS Dark` / `LCARS Light` themes, then the CSS HC values overlay on top.
- **Self-check in script:** assert LCARS-dark anchors independently (`surface == #161F33`, `tab.active_background == #111827`) and that all 22 blocks are emitted.

### Downstream reference updates

- Theme-count references 20 → 22: `Tests/**` count assertions, `CLAUDE.md` ("20 variants"), `docs/Diagrams/**`. Grep `\b20\b` near "theme"/"variant" and update.
- The `LCARS Dark` default (`Theme.lcarsDark` / `Theme.default`) is unchanged.

## Component 4 — Minimal wiring

- Ensure `onAccent`/`onDanger`/explicit `glassTint` are reachable through the SwiftUI/AppKit bridges (they already bridge `Tokens.Color`; add convenience accessors on `ThemeStyle`/`PlatformExtension` if needed).
- Wire `onAccent` at one obvious primary-button foreground site in `CodeEditorUI` **iff** such a site exists; otherwise leave defined-not-forced and note the follow-up. No sweeping refactor.

## Testing & verification strategy

- **TDD per task:** write/adjust the failing test first, then implement, then green. Snapshot suites re-record explicitly (`isRecording: true`) and the regenerated artifacts are committed.
- **Independent verification of codegen:** signature test values are hand-transcribed from the CSS, so a codegen bug diverges from the tests rather than being mirrored by them. Additionally spot-check `zed-trek.generated.json` against the raw CSS for LCARS dark/HC/light before replacing the real file.
- **Full gate (project standard):** `swift build && swiftlint --fix && swiftlint && swift test --parallel`. Per repo memory, skip full-suite reruns after purely additive steps; run targeted suites (`--filter`) between steps and the full gate at the end.
- **No orphan check:** grep for any now-dead derivation the explicit `glass.tint` replaces; confirm `Theme.fallback` and all decoders still build.

## Risks / call-outs

- **Snapshot churn is intended** (full sync). Re-recorded `TokensSnapshotTests` + `ThemeStyleSnapshotTests` images/JSON must be committed and eyeballed.
- **`PlatformExtension` init surface grows** — every construction site (memberwise init, `derived`, `fallback`, decoder) must thread `onAccent`/`onDanger`. Missing one is a compile error, caught by build.
- **SwiftLint strict + `missing_docs`** — new `public` members need `///`. Watch the struct-vs-actor asymmetry noted in CLAUDE.md (not relevant here; these are structs).
- **`canImport` discipline** — no new `#if os()`; DesignTokens stays platform-agnostic (the elevation `Scheme` enum is local, no AppKit).
```
