# Editor rendering: invisible text + gutter regression

Working notes for a still-unsolved rendering problem in `CodeEditorSample`.
Two fixes have shipped (commits `d026d42` and `14ff8ea`) and neither resolved
the symptom. Document everything so the next session starts with full
context.

## Symptoms

Observed on macOS, `swift run CodeEditorSample`, branch `main` at
`14ff8ea`.

1. **Glyphs do not render** in the editor pane. The text view accepts
   selection (`Ln 13, Col 28` in the status bar), the active-line highlight
   draws at the cursor position, the gutter draws line numbers, the tab
   strip + breadcrumbs work — but the text characters themselves are
   invisible on both light and dark themes.
2. **Gutter is intermittently scrambled**. With short, simple content
   (NOTES.md scrolled to the top, no wrap) the gutter is evenly spaced and
   the highlight lines up with the gutter row. With longer content or after
   scrolling, the gutter draws line numbers at irregular y positions:
   `1,2,3,4,5,6` clustered at the top, then a large gap, then `10,12`,
   another gap, then `13,20,21,32,35,38`, a giant gap, then `41,42,43` at
   the bottom — with the active-line highlight drawn in the empty void
   between gutter numbers. See screenshot 11 in the issue thread.
3. The previous user-discovered workaround — switching to a different
   *preset* in Settings → Theme — caused the text to appear. That control
   has been removed in `d026d42`. The only remaining switch in that tab is
   *Theme*, and switching themes does **not** make text appear.

## What we know about the codebase

- `CodeEditorView` is an NSTextView subclass driven by TextKit2
  (`NSTextLayoutManager`, `NSTextContentStorage`). The TK2 stack is
  intentionally AppKit-owned (see auto-memory:
  `project_nstextview_init_invariant`).
- The macOS gutter is an `NSRulerView` subclass
  (`LineNumberRulerView` in `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`)
  that draws via `GutterViewRenderer`. `TextKitBridge` comments note that
  the ruler can coerce the view from TK2 to TK1 ("`textLayoutManager` is
  nil and this method falls back to text-storage attributes so highlighting
  still renders").
- Syntax colours are applied by `RangeAttributeApplier` (TK2 rendering
  attributes via `NSTextLayoutManager.setRenderingAttributes`, with a
  text-storage attribute fallback when TK2 is unavailable). Tokens with a
  `nil` capture (whitespace, unrecognised) get the foreground attribute
  *removed*, leaving the run unattributed.
- The default theme is **LCARS Dark** (`editor.foreground: #F2E7D8`,
  cream). Mission Control Light is `#223142` (dark navy) on `#fbfdff`
  (off-white). Both should produce legible glyph colour on their canvases;
  the problem is not that the colour matches the background.
- `EditorConfiguration.Layout.lineHeightMultiple` defaults to `1.2`.
  `LineGeometryStore.defaultEstimatedHeight` is `17.0`pt and is **never**
  reconciled with measured TK2 line-fragment heights — `updateMeasuredHeight`
  has no callers anywhere in the repo.
- **2026-05-15 root-cause update:** two diagnostics reproduced
  TextKit2 loss before the third fix attempt:
  - Calling `CodeEditorRepresentableHelper.calculateSize(...)` with an
    unspecified AppKit proposal reads `textView.layoutManager` and makes
    `textView.textLayoutManager` become `nil`.
  - Applying a wrapped layout configuration (`configuration.layout.wrapLines = true`)
    reads the legacy `textStorage` / `textContainer.layoutManager` path in
    `CodeEditorView.updateTextContainerSize()`, also making
    `textView.textLayoutManager` become `nil`.
  These are deterministic TK2 → TK1 coercion points, not just timing races.

## Update / setup pipeline (current)

`CodeEditorRepresentableHelper.updateContainer` (file:
`Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`):

```
1. container.apply(theme:)                  // textView.apply(theme:)
2. coordinator.updateContainer(...)         // does setText, etc.
```

`coordinator.updateContainer` (file:
`Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`,
≈ line 422+):

```
let isHostBindingSwap = (storageText != text)
platformAdapter.setText(text, in: textView, preserveSelection: true)
if isHostBindingSwap { textView.stampThemeForeground() }
if textView.language != language { textView.language = language }
if textView.appliedTheme == nil { platformAdapter.applySystemEditorColors(to: textView) }
if container.configuration != configuration { container.configuration = configuration }
```

`coordinator.setupContainer` (same file, ≈ line 348+) runs on first mount
and does the equivalent dance but with `setText` running *before* a theme
has been applied, then guards `applySystemEditorColors` on
`appliedTheme == nil`.

`apply(theme:)` (file:
`Sources/CodeEditorPlugin/Core/CodeEditorView+Theme.swift`):

```swift
public func apply(theme: Theme) {
    if appliedTheme != theme {
        appliedTheme = theme
        // sets textColor, backgroundColor, typingAttributes[.foregroundColor],
        // selectedTextAttributes, insertionPointColor (AppKit) / tintColor (UIKit)
    }
    stampThemeForeground()  // always, even on equality-gate hit
}

internal func stampThemeForeground() {
    guard let theme = appliedTheme,
          let textStorage = textContentStorage?.textStorage,
          textStorage.length > 0 else { return }
    let foreground = PlatformColor(tokens: theme.style.editor.foreground)
    let range = NSRange(location: 0, length: textStorage.length)
    textStorage.beginEditing()
    textStorage.addAttribute(.foregroundColor, value: foreground, range: range)
    textStorage.endEditing()
}
```

`applyConfiguration` (file:
`Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift`)
sets `textColor` from `appliedTheme?.style.editor.foreground ?? PlatformColors.label`.

## What we have tried

### Commit `d026d42` — "themed text color, gutter alignment; drop demo pickers"

1. `apply(theme:)` was updated to also set `textColor`, `backgroundColor`,
   and `typingAttributes[.foregroundColor]` from `style.editor.foreground` /
   `.background`. Hypothesis: untokenised runs fall through to `textColor`,
   so setting that to the theme foreground would make them visible.
2. `applyConfiguration` was changed to read `appliedTheme?.style.editor.foreground`
   instead of unconditionally writing `PlatformColors.label`.
3. `SwitcherSection` (Settings → Theme tab) lost its Language and Preset
   chips. They were demo-only; the command palette + iOS still provide the
   paths. Side effect: removed the only ad-hoc way to retrigger
   `applyConfiguration → applySyntaxHighlighting`, which was the user's
   workaround.
4. `GutterViewRenderer.calculateLineNumberYPosition` switched from
   `LineGeometryStore.yPosition(forLineIndex:)` to
   `TextKitLineNumberHelper.getLineFragmentRect(for:)` plus
   `textContainerOrigin.y` so the gutter would follow real TK2 fragment
   positions instead of the store's unmeasured 17pt-per-line estimate.

**Outcome:** text still invisible. Gutter aligned correctly for short
content (screenshots 9 & 10) but degraded badly for the longer / scrolled
case (screenshot 11) — see "Hypotheses → Gutter" below.

### Commit `14ff8ea` — "stamp themed foreground on text storage"

1. Added `CodeEditorView.stampThemeForeground()`. It writes
   `editor.foreground` onto every character of the storage. Called from
   inside `apply(theme:)` (always — moved outside the equality gate) and
   from `coordinator.updateContainer` after `setText` when
   `isHostBindingSwap == true`. Hypothesis: TK2 doesn't honour
   `NSTextView.textColor` as a glyph fallback for runs without a per-range
   `.foregroundColor`, so we need to stamp the attribute synchronously.
2. Gated `platformAdapter.applySystemEditorColors(to:)` on
   `textView.appliedTheme == nil` in both `setupContainer` and
   `updateContainer`. The unconditional re-assert at the bottom of
   `updateContainer` had been overwriting `textColor`/`backgroundColor` on
   every SwiftUI tick — that explained why the change in (1) of `d026d42`
   never stuck.
3. `Package.swift` excludes `Sources/CodeEditorSample/README.md` from the
   `CodeEditorSample` target. Eliminates the SwiftPM "found 1 file(s)
   which are unhandled" warning. ✅ This part shipped working.

**Outcome:** text still invisible on both light and dark themes
(screenshots 9 & 10). The system-colour-override path is now correctly
gated — verified by inspection — and the storage stamp is being called.
Something else is preventing glyphs from rendering.

## Root cause / hypotheses

### Confirmed root cause

The current `main` branch still reads AppKit TextKit1 accessors on live
`CodeEditorView` instances:

1. `CodeEditorRepresentableHelper.calculateAppKitSize(...)` reads
   `textView.layoutManager` in `sizeThatFits` when SwiftUI does not provide
   both dimensions. A temporary regression test confirmed that this single
   call clears `textView.textLayoutManager`.
2. `CodeEditorView.updateTextContainerSize()` reads the inherited
   `textStorage` property and `textContainer.layoutManager` while applying
   `wrapLines`. A temporary regression test confirmed that enabling wrapped
   layout clears `textView.textLayoutManager`.

Once the view is coerced to TK1, several assumptions in the shipped fixes no
longer hold: `stampThemeForeground()` only looks at
`textContentStorage?.textStorage`, the TK2 rendering-attribute path is gone,
and gutter drawing starts mixing real TK2 fragment y-values with fallback
estimated line geometry.

### Invisible text

1. **TK2 → TK1 coercion from SwiftUI sizing and wrapped layout.**
   Confirmed by temporary focused tests on 2026-05-15. This is now the
   primary explanation for text remaining invisible after the previous two
   fixes.
2. **Order-of-operations across SwiftUI ticks.** SwiftUI may call
   `updateContainer` multiple times. `apply(theme:)` runs first in the
   helper, *then* `coordinator.updateContainer` runs `setText`. On the
   first call, `appliedTheme` is `nil`, so `apply(theme:)` records the
   theme but the storage may be empty at that point. On a later call,
   `isHostBindingSwap` may be `false` (text already matches), so the
   post-setText `stampThemeForeground` doesn't fire, and `apply(theme:)`
   short-circuits because the theme is unchanged. The "always stamp"
   branch in `apply(theme:)` runs but happens *before* `setText` for that
   tick, so it stamps then gets wiped immediately. Still plausible, but it
   is secondary to the confirmed TK1 coercion points above.
3. **TK2 → TK1 coercion from the ruler draw path.** The `NSRulerView` gutter has historically
   coerced the view to TK1. After coercion, `textContentStorage` may still
   be present but the `NSTextLayoutManager` is nil and rendering goes
   through TK1's `NSLayoutManager`. The stamp writes to NSTextStorage
   attributes; TK1 should honour them. Verify whether
   `textContentStorage?.textStorage` is the right surface after coercion
   versus `safeTextStorage` (the TK2-safe accessor used elsewhere).
4. **Another path is wiping `.foregroundColor`.** Candidates:
   `RangeAttributeApplier.textStorageDidApplyEdit` (clears attributes near
   edited ranges on every edit-with-characters-changed), the
   `AsyncSyntaxHighlighter` finalisation path, or `applyParagraphStyle`
   which calls `beginEditing/endEditing` on the storage and might emit a
   notification that another observer reacts to by stripping colour.
5. **Glyphs are drawn off-screen.** The gutter coordinate-space changes in
   `d026d42` shouldn't have moved the *text* view, but the
   `textContainerOrigin` override in
   `CodeEditorView+LayoutExtensions.swift` (≈ line 127) explicitly chose
   not to offset when an `NSRulerView` is present. Worth re-reading.

**Diagnostic status:** the original three-checkpoint logging is no longer
the cheapest next step. The failing boundary has been reproduced with
targeted tests; fix the known TK1 accessor reads first, then reassess the
theme-stamping order only if glyphs remain invisible.

### Gutter regression (screenshot 11)

Reasonably understood; not yet fixed.

`GutterViewRenderer.calculateLineNumberYPosition` (after `d026d42`) calls
`helper.getLineFragmentRect(for: lineRange)`, which is implemented as
`textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { return false }` —
it returns the **first** fragment at the start of the range. With Markdown
soft-wrap (`Layout.wrapLines == true` in the markdown preset) one logical
line can span multiple visual rows, but only one `NSTextLayoutFragment`
exists for the paragraph and its `layoutFragmentFrame` is the whole
paragraph's rect.

So:

- For a non-wrapped file, every `lineRange` maps to a fragment whose
  `minY` matches the visual row — gutter aligns. (Screenshots 9 & 10.)
- For a wrapped paragraph, the wrapped continuation rows get no gutter
  number (which is correct convention), but the *next* logical line's
  fragment is at a y that already accounts for all the wrap, leaving
  visible gaps in the gutter. (Visible in screenshot 11.)
- When TK2 hasn't laid out a fragment yet, `getLineFragmentRect` returns
  nil and we fall through to `CGFloat(lineIndex) * fontLineHeight` —
  which is in a completely different coordinate space and y-domain than
  the measured fragments above and below. This is what produces the
  overlapping `30/40 → "80"` digits and the wildly mis-located rows in
  screenshot 11.

The previous implementation (`LineGeometryStore.yPosition(forLineIndex:)`,
17pt × index) gave evenly-spaced but slightly-drifted numbers — a less
visually offensive failure mode.

**Better gutter strategy** (not implemented):

- Iterate `textLayoutManager.enumerateTextLayoutFragments` once per draw,
  visiting each fragment in order; for each fragment, walk
  `textLineFragments` to find the first visual line in the fragment, and
  draw the line number at that y. This places one number per logical line
  at the y of its first visual row, leaves continuation rows blank, and
  uses real layout coordinates throughout (no estimates, no mixed
  coordinate spaces).
- Drop the `LineGeometryStore.yPosition` path and the
  `CGFloat(lineIndex) * fontLineHeight` fallback. Skip drawing entirely
  for lines whose fragments aren't laid out yet — they'll appear on the
  next redraw triggered by TK2's layout.

### `applySystemEditorColors` interaction

Now gated on `appliedTheme == nil`, but worth re-checking: between
`makeNSView` (setupContainer) and the first `updateNSView` (which calls
`apply(theme:)`) the editor renders with system colours. If SwiftUI's
`.preferredColorScheme` hasn't propagated to the AppKit window yet, system
`.label`/`.textColor` could be the wrong appearance and the brief
pre-theme paint is what the user is actually seeing — but no, that
wouldn't persist across the entire session.

## Files touched by the two fix attempts

```
Package.swift                                                                          (warning fix; landed working)
Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift             (textColor defers to appliedTheme)
Sources/CodeEditorPlugin/Core/CodeEditorView+Theme.swift                               (apply(theme:) + stampThemeForeground)
Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift                               (TK2 fragment y; regressed for wrap)
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift               (gate applySystemEditorColors;
                                                                                        stamp after host setText)
Sources/CodeEditorSample/App/SettingsScene.swift                                       (drop unused SwitcherSection args)
Sources/CodeEditorSample/Switchers/SwitcherSection.swift                               (drop Language/Preset chips)
```

## Verified non-causes

- `swift build` clean, `swiftlint` clean.
- All targeted tests pass: `ApplyThemePropagationTests`,
  `GutterViewRendererActiveLineTests`, `GutterViewThemeTests`,
  `LineHighlightInsertionPointThemeTests`, `SyntaxColorAndSelectionTests`,
  `CodeEditorViewTextKit2InitTests`, `ConfigurationIntegrationTests`,
  `CodeEditorSampleTests` (incl. snapshot suites).
- `apply(theme:)` does receive a valid theme on each `updateContainer`
  (the active-line highlight is drawn with the correct theme tint).
- `textContentStorage?.textStorage` is the same accessor
  `applyParagraphStyle` uses successfully — paragraph style is being
  applied (the visible line-spacing in screenshots is consistent with
  `lineHeightMultiple = 1.2`).

## Suggested next steps / fix plan

1. **Add permanent regression tests** for the two confirmed TK1 coercion
   points:
   - SwiftUI AppKit size calculation must preserve `textLayoutManager`.
   - Applying `wrapLines = true` must preserve `textLayoutManager`.
2. **Remove live-editor TK1 accessor reads** from:
   - `CodeEditorRepresentableHelper.calculateAppKitSize(...)`
   - `CodeEditorView.updateTextContainerSize()`
3. **Move `container.apply(theme:)` in `CodeEditorRepresentableHelper.updateContainer`
   to run *after* `coordinator.updateContainer`.** This makes the stamp
   the very last thing the pipeline does, so it can't be undone by
   `setText`. Right now `stampThemeForeground` runs both before (via
   `apply(theme:)`) and after (via the isHostBindingSwap branch), but the
   "after" stamp only fires on a swap, not on a same-text re-render.
4. **Rewrite the gutter draw loop** to iterate
   `textLayoutManager.enumerateTextLayoutFragments` and use
   `textLineFragments` per-fragment, then drop the
   `LineGeometryStore.yPosition` path and the index-times-line-height
   fallback. Fixes screenshot 11 and gives a single coordinate space.
5. **Consider whether the editor should be rendering glyphs from a TK2
   surface at all** given how often the rest of the codebase comments
   about the NSRulerView coercing back to TK1. If the view spends most of
   its life on TK1, structure colour management around NSTextStorage
   attributes and the `NSTextView.textColor` fallback rather than TK2
   rendering attributes.

## Glossary of files mentioned

- `Sources/CodeEditorPlugin/Core/CodeEditorView+Theme.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift`
- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorPlatformAdapter.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift`
- `Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
- `Sources/CodeEditorPlugin/Text/TextKitLineNumberHelper.swift`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift`
- `Sources/CodeEditorPlugin/Text/ParagraphStyleCache.swift`
- `Sources/CodeEditorSample/App/SettingsScene.swift`
- `Sources/CodeEditorSample/Switchers/SwitcherSection.swift`

## Relevant commits

- `d026d42` — first attempt; themed `textColor`/`backgroundColor`,
  gutter TK2 fragment y, removed Language/Preset chips.
- `14ff8ea` — second attempt; `stampThemeForeground`, gated
  `applySystemEditorColors`, excluded sample README.

Both pushed to `origin/main`.
