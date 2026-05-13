# Editor Visual Restyle

> **Archive note:** Historical working note from May 2026. It may mention pre-0.2.0 Catalyst, plugin, or theme APIs; use `AGENTS.md`, `docs/README.md`, and `docs/FeatureMatrix.md` for current package truth.

**Date:** 2026-05-05
**Status:** brainstorm complete — pending user review of written spec
**Type:** sub-project spec — sub-project 3 of the [Design System Migration umbrella](2026-05-05-design-system-migration-design.md).
**Scope:** internal-only re-derivation of every editor-internal rendering surface from the new `Theme` and `Tokens.*` namespaces, plus four token bridges, a syntax-color resolver, indent guides, fold chevrons, and a frosted-glass completion popover. Public API is unchanged.

## Goal

Re-derive every editor-internal rendering surface from the new `Theme` and `Tokens.*` namespaces. Where the prior visuals came from hardcoded `PlatformColors` literals (gutter text via `PlatformColors.secondaryLabel`, line highlight via `PlatformColors.tintColor.withAlphaComponent(0.1)`, caret via `PlatformColors.label`, etc.), they will now come from the active `Theme` resolved at the SwiftUI boundary and pushed into the platform views. Add the one new visual that the design system requires but the editor doesn't currently render: indent guides.

## Context

This is sub-project 3 in the Design System Migration rollout. Sub-project 1 (`CodeEditorDesignTokens`) and sub-project 2 (Theme rewrite + Zed Trek bundled themes) have shipped. The package is pre-1.0; this sub-project introduces zero public API breakage.

### What exists today

| Concern | State |
|---|---|
| `Layout/` views | Use hardcoded `PlatformColors` literals throughout (`secondaryLabel`, `tintColor.withAlphaComponent(0.1)`, `label`, `controlBackground`, `systemBlue.withAlpha(0.3)`). **Zero** theme reads. |
| `Annotations/AnnotationKind` | Has all six kinds (info/note/todo/fixme/warning/error) with hardcoded `PlatformColors.systemRed`/`systemYellow`/`systemOrange`/`systemBlue` and SF Symbol names. |
| `Tokens.Color → SwiftUI.Color` | Shipped (`Color(tokens:)` in `Theming/SwiftUI/Theme+SwiftUI.swift`). |
| `Tokens.Color → NSColor`/`UIColor` | Not present. |
| `Tokens.Easing → SwiftUI.Animation` | Not present. |
| `Tokens.Animation → SwiftUI.Animation` builders | Not present. |
| Syntax color lookup | `TokenName` exists but no `Theme.color(forToken:)` resolver. The slot sub-project 2 reserved for `color(forLegacyToken:)` was never shipped. |
| Theme propagation | `CodeEditor` reads `\.codeTheme` from environment; never plumbed into Layout/. |
| Indent guides | Theme keys exist (`style.editor.indentGuide`, `indentGuideActive`). No rendering anywhere. |
| Fold chevrons | Not rendered in gutter. |
| Selection rendering | Native TextKit2 defaults; no theme color, no blend mode. |
| Legacy `Theme` accessors | Sub-project 2 left four convenience accessors for the old `CodeEditorSwiftUITheme` surface: `backgroundColor`, `textColor`, `lineNumberColor`, `selectedLineColor`. To be removed here. |
| `BaseUIComponents.StandardUITheme` | Static struct of `PlatformColors`-typed defaults. To be removed here; `ThemeableUIComponent.theme` retypes to `Theme`. |

## Strategy

### Theme wiring

A single read at the SwiftUI boundary, pushed downward via the existing `EditorConfiguration` propagation pattern.

```
SwiftUI                        AppKit/UIKit
─────────                      ─────────────
@Environment(\.codeTheme)
        │
        ▼
CodeEditorRepresentable
  .updateNSView(_:context:)
  .updateUIView(_:context:)
        │ context.environment.codeTheme
        ▼
containerView.apply(theme:)         ←── equality-gated; no-op if unchanged
        │
        ├──▶ gutterView.apply(theme:)
        ├──▶ minimapView.apply(theme:)
        ├──▶ lineHighlightView.apply(theme:)
        ├──▶ insertionPointView.apply(theme:)
        ├──▶ textLayoutFragmentRenderer.apply(theme:)
        ├──▶ completionPopover.apply(theme:)
        └──▶ annotationsContentView.apply(theme:)
```

Each `apply(theme:)` early-outs on `oldTheme == newTheme` and otherwise updates layer/draw state and triggers `setNeedsDisplay` (or its UIKit equivalent). The propagation mirrors the existing config flow in `CodeEditorContainerView+Configuration.swift`.

Rationale: `Theme` is a value type that changes rarely. A parallel observation graph (`@Observable` coordinator, Combine subject, etc.) would cost more in plumbing than the equality check costs in dispatch.

### Bridges

Four new files under `Sources/CodeEditorPlugin/Theming/Bridges/`. The existing `Theming/SwiftUI/Theme+SwiftUI.swift` is moved here so all bridge code lives together; the `Theming/SwiftUI/` directory is deleted.

```
Theming/Bridges/
  Tokens.Color+SwiftUI.swift     // Color(tokens:) (migrated from Theme+SwiftUI.swift)
  Tokens.Color+Platform.swift    // NSColor(tokens:), UIColor(tokens:)
  Tokens.Easing+SwiftUI.swift    // Animation.timingCurve(_:duration:) builder
  Tokens.Animation+SwiftUI.swift // named convenience animations
  Theme+SwiftUI.swift            // four legacy accessors deleted; only what survives
```

**`Tokens.Color → NSColor` / `UIColor`.** sRGB initializers using `NSColor(srgbRed:green:blue:alpha:)` and `UIColor(red:green:blue:alpha:)`. The UIKit form is sRGB-based per Apple docs; `displayP3Red:` is *not* used.

**`Tokens.Easing → Animation`.** A free function building `Animation.timingCurve(easing.x1, easing.y1, easing.x2, easing.y2, duration: …)`. Duration is the consumer's responsibility.

**`Tokens.Animation → Animation` builders.** This sub-project has exactly one named animation call site (the fold chevron). Ship it as the named convenience; everything else uses the underlying `Tokens.Easing → Animation` primitive directly until a real call site demands a name.

| Builder | Duration | Easing |
|---|---|---|
| `.foldChevron` | `durQuick` (200ms) | `easeOutSoft` |

The bridge file is the single home for additional named builders; sub-projects 4 and 5 will land theirs here as their call sites arrive.

**Legacy `Theme` accessor removal.** The four convenience properties sub-project 2 added (`backgroundColor`, `textColor`, `lineNumberColor`, `selectedLineColor`) are deleted. Layout/ now reads `theme.style.editor.background`/`.foreground`/`.lineNumber`/`.activeLineBackground` directly.

### Syntax color resolver

A new internal API on `Theme`, declared in `Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift`.

```swift
extension Theme {
    /// Resolves a TokenName to a Tokens.Color via hierarchical fallback over
    /// `style.syntax`, ending at `style.editor.foreground`. Result is cached
    /// per-Theme to avoid repeated string-walks during large highlight passes.
    public func color(forToken token: TokenName) -> Tokens.Color
}
```

**Algorithm.** Given a dotted token string `a.b.c`:

1. Try `style.syntax["a.b.c"]?.color`. Hit → return.
2. Drop the trailing `.c`, try `style.syntax["a.b"]?.color`. Hit → return.
3. Continue until `style.syntax["a"]?.color`. Hit → return.
4. Final fallback: `style.editor.foreground`.

This matches Zed's and TextMate's resolution. Tokens already in `style.syntax` (Zed-conformant or our own emissions) work without an alias table; an alias table is added only if a parser-emitted string isn't valid Zed dotted notation. None of the parsers we ship today need one.

**Bold/italic.** `SyntaxStyle.fontWeight` (100…900) and `.fontStyle` (`.normal`/`.italic`) are honored: the highlight pipeline produces an attribute run with `(color, weight, style)` per token. Weight maps to `NSFontDescriptor`/`UIFontDescriptor` weight via the resolver; italic toggles `NSFontDescriptor.SymbolicTraits.italic` (or UIKit equivalent).

**Caching.** A `@unchecked Sendable` final-class `_SyntaxColorCache` keyed by token-string, scoped per `Theme` instance via `ObjectIdentifier` of an internal box. The token vocabulary is bounded (~50 distinct strings per highlight pass for typical files); the cache fills once and then services hits. No eviction — each cache lives as long as its `Theme`.

**Six unmapped Zed tokens.** `embedded`, `link_text`, `link_uri`, `variant`, `predictive`, `boolean.special`. Per [umbrella open question](2026-05-05-design-system-migration-design.md#open-questions-for-future-sub-project-specs), these have no current TokenName analog. Decision: keep TokenName as-is; document these as theme-defined, parser-unused; revisit when markdown / embedded-language / Rust-variant parser support is added (none of which is in this sub-project's scope). `predictive` is a separate UI surface (`theme.style.predictive`), not a syntax token; it's consumed by inline-completion ghost-text rendering only and was already modeled by sub-project 2.

### Components touched

Every platform view gains an `apply(theme: Theme)` method per the wiring section.

| Component | Today | New theme key(s) | Notable change |
|---|---|---|---|
| `GutterViewRenderer.swift` | `PlatformColors.secondaryLabel` | `style.editor.lineNumber`, `style.editor.lineNumberActive` | Two colors: inactive numbers + active line number. |
| `GutterView.swift` (background) | `PlatformColors.clear` | `style.editor.gutterBackground` | Solid fill behind the numbers. |
| `MinimapView.swift` | `PlatformColors.controlBackground`, `systemBlue.withAlpha(0.3)` | `style.editor.background`, `style.scrollbar.thumbBackground`, `style.scrollbar.trackBackground` | Background from editor canvas; viewport indicator from scrollbar palette; token-colored bars from `Theme.color(forToken:)`. |
| `LineHighlightView.swift` | `PlatformColors.tintColor.withAlphaComponent(0.1)` | `style.editor.activeLineBackground` | Solid translucent fill; alpha is part of the theme color, not a hardcoded multiplier. |
| `InsertionPointView.swift` | `PlatformColors.label` | `style.players[0].cursor` | Single read; blink behavior unchanged. |
| `TextLayoutFragmentView` (Text/) | TextKit2 defaults | `style.editor.foreground`, `Theme.color(forToken:)`, `style.players[0].selection`, `style.editor.indentGuide`, `style.editor.indentGuideActive` | Per-run colors via resolver; selection-fill color (plain alpha — see [Selection](#selection-fill)); indent-guide draw inside fragment. |
| `CompletionCellComponents.swift` (popover) | `CompletionCellTheme.default/.compact` | `style.elevatedSurfaceBackground`, `style.borders.base`, `style.text.base`, `style.text.muted`, `style.elements.activeBackground`, `theme.platform.glass`, `theme.platform.shadows.popover` | Frosted-glass surface via internal `_GlassSurface`; `CompletionCellTheme` rewritten as a `Theme`-derived value. |
| `AnnotationKind.swift` | `PlatformColors.systemRed/Yellow/Orange/Blue` (computed property) | `style.status.error`, `.warning`, `.info`, `.conflict` | `color` becomes `func color(in theme: Theme) -> PlatformColor`. SF Symbol names unchanged. |
| `AnnotationView.swift` | reads `AnnotationKind.color` directly | now `kind.color(in: theme)` | Single call-site touch; rendering otherwise unchanged. |
| `AnnotationsContentView.swift` | — | — | Gains `apply(theme:)`; passes theme to per-annotation `AnnotationView` instances. |
| Fold chevron (in `GutterView`) | not rendered | `style.icon.muted`; `Tokens.Animation.foldChevron` (gated on `config.performance.animateCodeFolding`) | New rendering. SF Symbol `chevron.right`/`chevron.down`; rotates on fold-toggle; instant rotation if gating is off. |
| `BaseUIComponents.swift` | `StandardUITheme` static struct | — | `StandardUITheme` deleted; `ThemeableUIComponent.theme` retyped from `StandardUITheme` to `Theme`. |

### Indent guides

Per Q4=B, indent guides are drawn inside `TextLayoutFragmentView`'s draw path.

**Geometry.** For each line fragment:

1. Read leading-whitespace prefix from the fragment's text.
2. Compute the number of indent columns: `whitespaceAdvance / (tabWidth × spaceAdvance)` rounded down. Tabs count as `tabWidth` spaces (using `config.layout.tabWidth`).
3. For each indent column `i ∈ 1..<indentCount`, draw a 1pt vertical line from the fragment's top to its bottom at `x = leadingPadding + i × tabWidth × spaceAdvance`.
4. Color: `style.editor.indentGuide` for inactive guides, `style.editor.indentGuideActive` when `i == activeIndentColumn`.

**Active column.** A single `activeIndentColumn: Int?` field on the fragment-render config struct. Recomputed on selection-change events (already published by `UnifiedEventSystem`). The recomputation walks up from the cursor's line to find the indent depth of the enclosing scope (= leading whitespace of the cursor's line, in indent units).

**Blank-line continuity.** A blank line copies the indent depth of its prior non-blank neighbor, so guides stay continuous across blank lines (the standard editor behavior). Each fragment caches its "effective indent depth" in the fragment's render config; blank fragments inherit from the prior fragment in the same paragraph chunk. No cross-fragment recomputation on edits — the standard fragment-invalidation path handles it.

**Toggle.** Driven by `config.layout.tabWidth > 0` (always on by default; tab width 0 disables guides). No new public configuration knob — this sub-project forbids public API changes; a "show indent guides" knob can be added in a later commit if real demand emerges.

**Cost.** O(indent-depth) per fragment draw; depth is bounded by visible-region tab stops, typically <10. Drawn once per fragment redraw, no offscreen layer, no scroll-sync code.

### Fold chevron

A chevron is drawn for every line that begins a foldable region, in the gutter, to the left of the line number.

| Aspect | Value |
|---|---|
| Glyph | SF Symbol `chevron.right` (folded) / `chevron.down` (unfolded). |
| Color | `style.icon.muted`. |
| Size | `Tokens.Size.Icon.micro` (12pt). |
| Animation, on | `Tokens.Animation.foldChevron` (`durQuick` × `easeOutSoft`); rotation animates between 0° and 90°. |
| Animation, off | Instant rotation, no animation. |
| Click target | 16×fullLineHeight region, hit-tested in `GutterInteractionHandler.swift`. |

Fold-toggle dispatches the existing fold action; this sub-project does not touch fold logic itself.

### Completion popover frosted glass

`CompletionCellComponents.swift` rewritten so all colors and metrics flow from `Theme` and `Tokens.*`.

- Popover background: a new internal `_GlassSurface` view wraps `NSVisualEffectView(material: .menu, blendingMode: .behindWindow)` on macOS and `UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))` on iOS/Catalyst.
- The glass is tinted by `theme.platform.glass.tint` at `theme.platform.glass.opacity`. Implementation: a colored tint layer/view at the configured alpha — on macOS, a sublayer above the `NSVisualEffectView`; on iOS/Catalyst, a colored subview inside the `UIVisualEffectView.contentView` per UIKit convention. `_GlassSurface` exposes `apply(theme:)` like every other component.
- Cell typography from `Tokens.Typography`; cell padding from `Tokens.Spacing.sm`; corner radius from `Tokens.Shape.radiusMD`.
- Selected-row background: `style.elements.activeBackground`.
- Cell text: `style.text.base`; secondary kind/glyph: `style.text.muted`.
- Border: `style.borders.base` at `Tokens.Shape.strokeHairline`.
- Shadow: `theme.platform.shadows.popover`.

`_GlassSurface` is internal to `CodeEditorPlugin`. Sub-project 4 will introduce the public `PlatformGlassSurface` in `CodeEditorUI` and the popover migrates to use it; `_GlassSurface` is deleted at that point.

### Selection fill

Per Q3=C: set the platform text view's selection color from `theme.style.players[0].selection` (alpha included).

- macOS (`NSTextView` subclass, our `CodeEditorView`): override `selectedTextAttributes` to include `.backgroundColor: NSColor(tokens: theme.style.players[0].selection)`.
- iOS/Catalyst (`UITextView` subclass): set `tintColor` to the selection color. UITextView's selection background uses `tintColor` at a system-defined alpha; this sub-project works *with* that rather than overriding draw.

Caveats:

- iOS uses the system's selection-rendering alpha multiplier on top of `tintColor`. iOS selection α may differ slightly from `players[0].selection.alpha`. Acceptable for this sub-project; correctness work is deferred.
- No mix-blend implementation. The visual gap from `Design/editor.jsx` is documented but accepted.

### Files added

```
Sources/CodeEditorPlugin/Theming/Bridges/
  Tokens.Color+SwiftUI.swift          (Color(tokens:) migrated from Theme+SwiftUI.swift)
  Tokens.Color+Platform.swift
  Tokens.Easing+SwiftUI.swift
  Tokens.Animation+SwiftUI.swift
Sources/CodeEditorPlugin/Theming/Internal/
  SyntaxColorLookup.swift             (Theme.color(forToken:))
Sources/CodeEditorPlugin/Layout/Glass/
  _GlassSurface.swift                 (internal; migrated to public PlatformGlassSurface in sub-project 4)
```

### Files rewritten

| File | Change |
|---|---|
| `Sources/CodeEditorPlugin/Theming/SwiftUI/Theme+SwiftUI.swift` | Move to `Theming/Bridges/`. Delete the four legacy accessors (`backgroundColor`, `textColor`, `lineNumberColor`, `selectedLineColor`). |
| `Sources/CodeEditorPlugin/Layout/GutterView.swift` and `GutterViewRenderer.swift` | Add `apply(theme:)`; theme reads for background and number colors; fold-chevron rendering. |
| `Sources/CodeEditorPlugin/Layout/MinimapView.swift` | `apply(theme:)`; theme reads for background, viewport indicator, token bars. |
| `Sources/CodeEditorPlugin/Layout/LineHighlightView.swift` | `apply(theme:)`; theme read for active-line fill. |
| `Sources/CodeEditorPlugin/Layout/InsertionPointView.swift` | `apply(theme:)`; theme read for caret color. |
| `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift` | Rewrite around `Theme` + `Tokens.*`; introduce `_GlassSurface` consumption. |
| `Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift` | Delete `StandardUITheme`; retype `ThemeableUIComponent.theme: Theme`. |
| `Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift` | Hit-testing for fold-chevron click target. |
| `Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift` | Per-run color via resolver; selection fill color; indent-guide draw; active-column field on render config. |
| `Sources/CodeEditorPlugin/SyntaxHighlighting/` (highlight pipeline) | Producer of attribute runs consumes `Theme.color(forToken:)` instead of any prior hardcoded color source. Specific file (`SyntaxHighlightingCoordinator.swift` and/or the per-language providers under `Languages/`) determined during implementation step 7; alias-table need verified at the same time per the resolver section above. |
| `Sources/CodeEditorPlugin/Annotations/AnnotationKind.swift` | `color` retyped to `func color(in theme: Theme) -> PlatformColor`. |
| `Sources/CodeEditorPlugin/Annotations/AnnotationView.swift` | Updated call-site. |
| `Sources/CodeEditorPlugin/Annotations/AnnotationsContentView.swift` | Adds `apply(theme:)`. |
| `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (or platform extensions) | Selection-color reads from `theme.style.players[0].selection`. |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` | `updateNSView`/`updateUIView` reads `\.codeTheme` from environment and calls `containerView.apply(theme:)`. |
| `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Configuration.swift` | Adds the `apply(theme:)` fan-out. |

### Files deleted

| File | Why |
|---|---|
| `Sources/CodeEditorPlugin/Theming/SwiftUI/` directory | Empty after `Theme+SwiftUI.swift` migrates to `Theming/Bridges/`. |

(No call-site-only deletions warrant their own line; the four legacy `Theme` accessors are deleted *inside* `Theme+SwiftUI.swift` during its migration, and `BaseUIComponents.StandardUITheme` is deleted *inside* `BaseUIComponents.swift`.)

## Tests

Located under `Tests/CodeEditorPluginTests/Theming/Editor/` and `Tests/CodeEditorPluginTests/Layout/`. Use existing `swift-snapshot-testing` and `swift-custom-dump` deps.

### Bridges

| Test | Asserts |
|---|---|
| `Color_SwiftUI_Bridge_PreservesSRGB` | `Color(tokens: .init(hex: 0x0A84FF)).cgColor` resolves to sRGB components 10/132/255. |
| `Color_NSColor_Bridge_PreservesSRGB` | `NSColor(tokens:)` round-trips r/g/b/alpha at 8-bit precision. |
| `Color_UIColor_Bridge_PreservesSRGB` | Same for `UIColor` under `canImport(UIKit)`. |
| `Easing_To_Animation_Curve` | `Tokens.Easing(0.16, 1.0, 0.3, 1.0)` produces a `timingCurve(0.16, 1.0, 0.3, 1.0, duration: …)` snapshot. |
| `Animation_FoldChevron_IsStable` | Snapshot of the resolved `Animation` for `Tokens.Animation.foldChevron` doesn't drift. |

### `Theme.color(forToken:)`

| Test | Asserts |
|---|---|
| `Resolver_DirectHit` | `theme.color(forToken: "keyword")` returns `style.syntax["keyword"]?.color`. |
| `Resolver_HierarchicalFallback` | With `syntax["function"]` set and `syntax["function.method"]` absent, `color(forToken: "function.method") == syntax["function"]?.color`. |
| `Resolver_FullMissFallsThroughToForeground` | Unknown token → `style.editor.foreground`. |
| `Resolver_CachedAfterFirstHit` | Two consecutive lookups for the same token take the cached path; verified by behaviour, not by exposing internals. |

### Per-component snapshots (using `Theme.lcarsDark`)

| Component | Snapshot |
|---|---|
| `GutterView` | 20-line render at 14pt, active line = 8. Active number color, inactive number color, gutter background. |
| `LineHighlightView` | One active-line stripe over a gradient stub; alpha matches `style.editor.activeLineBackground`. |
| `InsertionPointView` | Solid 2pt caret with theme cursor color. |
| `MinimapView` | 200-line synthesized minimap; viewport-indicator color from `style.scrollbar.thumbBackground`. |
| `AnnotationView` | One badge per `AnnotationKind`; color matches `style.status.{error,warning,info,conflict}`. |
| `CompletionCellComponents` | Popover with three completion items; selection on item 2; glass surface visible. |
| `TextLayoutFragmentView` | One-line fragment with mixed `keyword`/`identifier`/`string` runs; resolver-derived per-run colors. |
| `IndentGuideRendering` | 12-line nested function; guides at 1–4 indent depths, active column = 3. |

### Behaviour

| Test | Asserts |
|---|---|
| `ApplyTheme_EqualityGated_NoOps` | `apply(theme:)` called twice with the same value calls `setNeedsDisplay` only once. |
| `ApplyTheme_FansOutOnContainer` | `containerView.apply(theme:)` propagates to every subview's `apply(theme:)` exactly once. |
| `IndentGuide_BlankLineContinuity` | A blank line between two indented lines renders guides at the prior line's depth. |
| `IndentGuide_DisabledWhenTabWidthZero` | `config.layout.tabWidth = 0` → no guides drawn. |
| `FoldChevron_AnimationGated` | `config.performance.animateCodeFolding = false` → rotation completes synchronously; `true` → rotation uses `foldChevron`. |
| `Selection_ColorFromPlayer0` | macOS selection background equals `players[0].selection`; iOS `tintColor` set to the same. |
| `AnnotationKind_ColorInTheme` | `kind.color(in: theme)` returns `theme.style.status.{error,warning,info,conflict}` for the four mapped kinds. |

### Explicitly *not* tested in this sub-project

- Mix-blend selection fidelity (deferred).
- Comment-scanner correctness (own brainstorm).
- Markdown / embedded-language / Rust-variant syntax mapping.
- Theme-transition animation between themes.
- Public `PlatformGlassSurface` API (sub-project 4).

## Acceptance criteria

- [ ] `swift build` succeeds with no warnings.
- [ ] `swift test` passes; new snapshots pass on second run.
- [ ] `swiftlint` reports zero violations across changed files.
- [ ] `Sources/CodeEditorPlugin/Layout/`, `Annotations/`, `Text/` contain **zero** `PlatformColors.system*` / `PlatformColors.label` / `PlatformColors.tintColor` references for editor visual decisions (one-shot grep gate). System colors may remain for non-theme concerns (control-state, accessibility) — those are flagged inline in code review.
- [ ] The four legacy `Theme` accessors (`backgroundColor`, `textColor`, `lineNumberColor`, `selectedLineColor`) are removed.
- [ ] `BaseUIComponents.StandardUITheme` is removed; `ThemeableUIComponent.theme` is retyped to `Theme`.
- [ ] `Sources/CodeEditorPlugin/Theming/Bridges/` exists with the four bridge files plus the migrated `Theme+SwiftUI.swift`.
- [ ] `Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift` exists; `Theme.color(forToken:)` is callable.
- [ ] `Sources/CodeEditorPlugin/Layout/Glass/_GlassSurface.swift` exists and is used by the completion popover.
- [ ] Indent guides render by default at `config.layout.tabWidth = 4`; active-column guide appears under cursor's enclosing scope; guides remain continuous across blank lines.
- [ ] Fold chevrons render in the gutter; click toggles fold state; animation honors `config.performance.animateCodeFolding`.
- [ ] Public API surface unchanged. The only new public symbol is `Theme.color(forToken:)`; that one is intentional and documented.
- [ ] DocC comments on every new internal symbol.
- [ ] CHANGELOG entry recording: editor restyle, four bridges added, indent guides added, fold chevrons added, completion popover frosted-glass, legacy `Theme` accessors removed.

## Recommended commit slicing

For the implementation plan to expand on:

1. Add `Tokens.Color+SwiftUI`, `Tokens.Color+Platform`, `Tokens.Easing+SwiftUI`, `Tokens.Animation+SwiftUI` bridges + tests. Migrate `Theme+SwiftUI.swift` to `Theming/Bridges/`. Delete the four legacy accessors.
2. Add `Theme.color(forToken:)` resolver + cache + tests; **do not call yet**.
3. Add `apply(theme:)` stubs (no-ops) on every Layout/Annotations platform view; wire `CodeEditorRepresentable.updateNSView/updateUIView` to read `\.codeTheme` and call `containerView.apply(theme:)`. Add `apply(theme:)` fan-out in `CodeEditorContainerView+Configuration.swift`.
4. Wire small components: `GutterView` background + `GutterViewRenderer` numbers; `LineHighlightView`; `InsertionPointView`. Snapshot tests.
5. Wire `MinimapView` background + viewport indicator + token bars.
6. Retype `AnnotationKind.color → color(in:)`; wire `AnnotationView` + `AnnotationsContentView`.
7. Wire `TextLayoutFragmentView`: per-run color via resolver; selection fill color.
8. Add indent-guide rendering inside `TextLayoutFragmentView`; add `activeIndentColumn` to render config; recompute on selection event.
9. Add fold chevrons in gutter; hit-testing in `GutterInteractionHandler`; animation gating.
10. Rewrite `CompletionCellComponents`: `CompletionCellTheme` becomes `Theme`-derived; introduce `_GlassSurface`.
11. Delete `BaseUIComponents.StandardUITheme`; retype `ThemeableUIComponent.theme`. Final cleanup of any remaining hardcoded color reads.
12. Final SwiftLint sweep + DocC pass + CHANGELOG.

## Out of scope (explicit)

- Selection mix-blend implementation (Q3=C; deferred to a polish pass).
- Custom selection drawing on iOS; we accept system `tintColor` semantics.
- Comment-scanning / diagnostic intake for annotation badges (own brainstorm).
- Markdown / embedded-language / Rust-variant syntax — the six unmapped Zed token names remain theme-defined and parser-unused.
- Theme-transition animation between themes.
- Public `PlatformGlassSurface` API (sub-project 4).
- Any changes to `EditorConfiguration`'s public knob shape — including a "show indent guides" toggle.
- Comment-scanner regex configurability and language-awareness.

## Sub-project 4 hand-off

- `_GlassSurface` is internal to this sub-project. Sub-project 4 introduces the public `PlatformGlassSurface` in `CodeEditorUI`. The completion popover migrates from `_GlassSurface` to the public type as part of sub-project 4's commit slicing; `_GlassSurface` is deleted at that point.
- The four bridges under `Theming/Bridges/` are public on `CodeEditorPlugin`. Sub-project 4 reuses them rather than duplicating.
- The `apply(theme:)` propagation pattern established here is the template for any chrome surface that needs to consume theme: read `\.codeTheme` at the SwiftUI representable boundary, push downward through equality-gated `apply(theme:)` calls.

## Open questions deferred

| Question | Defer to |
|---|---|
| Selection mix-blend mode | polish pass after sub-projects 4–5 |
| iOS selection α fidelity vs `players[0].selection.alpha` | polish pass |
| Theme-transition animation | post-MVP |
| Comment-scanner for TODO/FIXME/NOTE | separate brainstorm |
| Markdown / embedded-language / Rust-variant syntax tokens | parser-side work; outside this rollout |
| Public `PlatformGlassSurface` shape | sub-project 4 |
| Public "show indent guides" config toggle | only if real demand emerges; not in this sub-project |

## References

- Umbrella spec: [`docs/superpowers/specs/2026-05-05-design-system-migration-design.md`](2026-05-05-design-system-migration-design.md).
- Sub-project 2 spec (shipped): [`docs/superpowers/specs/2026-05-05-theme-rewrite-design.md`](2026-05-05-theme-rewrite-design.md).
- Zed v0.2.0 schema: `https://zed.dev/schema/themes/v0.2.0.json`.
- Existing files restyled: `Sources/CodeEditorPlugin/Layout/{GutterView,GutterViewRenderer,MinimapView,LineHighlightView,InsertionPointView,CompletionCellComponents,BaseUIComponents,GutterInteractionHandler}.swift`, `Sources/CodeEditorPlugin/Annotations/{AnnotationKind,AnnotationView,AnnotationsContentView}.swift`, `Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift`, `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`, `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Configuration.swift`.
