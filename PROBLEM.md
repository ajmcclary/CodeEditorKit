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

### 2026-05-15 regression after the uncommitted fix attempt

The latest screenshot after the "remove TK1 coercion + re-stamp after
updates" attempt is worse than the original symptom:

1. Selecting `Package.swift` leaves the editor pane visually blank/black.
   Unlike the earlier screenshots, there are no visible glyphs and no useful
   gutter content in the central editor area.
2. The user reports the editor is now effectively read-only.
3. The app still appears to have a real active document and cursor state:
   the tab title is `Package.swift`, the file tree selection is on
   `Package.swift`, and the status bar reports `Ln 16, Col 17`. That makes a
   completely missing active-document binding less likely than a layout,
   hit-testing, focus, or text-view editability regression.

Most suspicious new deltas from the uncommitted attempt:

1. `CodeEditorRepresentableHelper.calculateAppKitSize(...)` no longer reads
   `textView.layoutManager`, which is good for TK2 preservation, but it now
   returns a concrete content-derived size when SwiftUI does not provide both
   dimensions. For a flexible editor surface, returning a small concrete size
   from `sizeThatFits` can collapse the actual `NSTextView` while the
   surrounding container still paints the large black background. That matches
   the screenshot's "blank editor area with a narrow live-looking strip" and
   would also make the editor feel read-only if clicks land on container
   background instead of the text view.
2. `CodeEditorRepresentableHelper.createAndSetupContainer(...)` still does
   not apply the SwiftUI theme during the make path; theme application happens
   in `updateContainer`. Usually SwiftUI calls update immediately after make,
   but the current notes should verify the exact first-render sequence because
   a skipped or short-circuited update would leave setup-owned system colours
   and no final storage stamp.
3. The AppKit layout changes moved more responsibility to TK2 document-height
   recomputation and autoresizing masks. Wrapped mode was changed directly,
   but the sample screenshot is on `Package.swift` (normally non-wrapped
   Swift), so the first layout check should verify the non-wrapped text view's
   frame, clip-view bounds, hit-test target, and `isEditable` after the same
   setup/update sequence used by the sample.
4. There is not yet evidence that `configuration.behavior.isEditable` is
   actually false. The status bar line/column state means selection plumbing
   is alive, so "read-only" may be caused by focus or hit-testing after layout
   collapse. Still, the next diagnostic must assert `textView.isEditable`,
   the effective configuration value, and whether the active document binding
   receives edits.

Additional user validation after switching themes:

1. Switching to **LCARS Light** still leaves the text glyphs invisible, but
   the line-number ruler renders normally (`1...36` visible for
   `Package.resolved`). This rules out a simple dark-on-dark foreground /
   background mismatch and proves the active document, line count source, and
   ruler draw path can be alive while glyphs remain invisible.
2. Switching back to **LCARS Dark** collapses or corrupts the gutter again:
   only a small cluster of line-number content appears near the top of the
   ruler strip, and the user reports the line count is broken again. This
   makes theme switching an active layout invalidation trigger, not just a
   cosmetic colour swap.
3. In both themes the status bar continues to report a cursor location
   (`Ln 4, Col 6` in the dark screenshot), so the editor is still tracking
   selection against a text buffer even when the visible text surface is
   blank.

Refined reading: there are now two separable failures.

1. **Glyph invisibility is theme-independent.** Light and dark both fail to
   render text, so the next diagnostic should inspect the actual attributes
   and layout/rendering surface used for the selected document after
   `setText`, syntax highlighting, and `apply(theme:)`.
2. **Gutter collapse is theme-transition-dependent.** Light can show a sane
   ruler; dark breaks it after the same theme-control path. The next
   diagnostic should compare the text view frame, clip-view bounds,
   `textLayoutManager` presence, document height, and ruler draw coordinates
   before and after `container.apply(theme:)` for LCARS Light -> LCARS Dark.

Focused test added after this analysis:

- `ApplyThemePropagationTests.applyThemeSeedsRenderingForeground` sets up a
  large AppKit `CodeEditorContainerView`, installs multi-line text, applies
  LCARS Light, then applies LCARS Dark, and reads
  `NSTextLayoutManager.enumerateRenderingAttributes` for the first glyph.
- Initial result: **red**. In both light and dark states the rendering
  foreground was `nil`, even though the expected foreground tokens were valid.
- Interpretation: the uncommitted `stampThemeForeground()` path wrote
  persistent `NSTextStorage` attributes, but the active TK2 rendering surface
  had no explicit `.foregroundColor`. This matches the user-visible symptom
  better than the previous "storage was stamped" checks. It does not by itself
  prove storage attributes were absent; it proves the surface used by TK2
  rendering had no foreground override after theme application.
- Fix now in progress: `CodeEditorView.apply(theme:)` seeds both persistent
  storage attributes and TK2 rendering attributes. On a real theme change it
  overwrites stale foreground attributes and schedules syntax highlighting so
  token colours can be recomputed for the new theme. On same-theme reapply it
  fills missing foreground only, preserving existing syntax rendering colours.
- Guardrail added:
  `ApplyThemePropagationTests.sameThemeForegroundSeedingPreservesSyntaxColors`
  verifies same-theme foreground seeding does not flatten an existing syntax
  colour.
- Current focused evidence: `swift test --filter ApplyThemePropagationTests`
  passes all 7 tests.

User validation after that green test:

- Still broken in the running sample for both LCARS Dark and LCARS Light.
  `Package.swift` shows line numbers `1...36` and the active-line highlight at
  line 7 in both themes, but no editor glyphs.
- The latest screenshots narrow the live symptom: the gutter is no longer the
  most important signal in this state. The line-number ruler, active selection
  state, language status (`Swift`), and completion provider registration are
  all alive. The failure is now specifically "text buffer exists, layout row
  exists, glyph foreground still does not render."
- Therefore the green test only proves `apply(theme:)` can seed TK2 rendering
  foreground immediately after a direct theme call. It does **not** prove the
  real sample path keeps that foreground after subsequent syntax highlighting,
  configuration, document switching, or TextKit drawing passes.
- Next diagnostic must inspect foreground after the full sample-like sequence:
  setup/update container, apply theme, allow async syntax highlighting to run,
  then compare:
  - `NSTextStorage` foreground at visible glyphs.
  - `NSTextLayoutManager` rendering foreground at the same glyphs.
  - `SyntaxColorScheme.color(for: .identifier, in: theme)` and any token colour
    applied after the base theme seed.
  - Whether any later `removeAttributes([.foregroundColor])` or
    `setRenderingAttributes([:])` clears the range after the theme seed.

User hypothesis after the latest screenshots:

- This may be an AppKit effective-appearance/default-foreground issue rather
  than a missing model attribute issue. macOS has default text foregrounds that
  resolve differently under light/dark appearance. If the editor or its text
  layout fragments keep any dynamic system foreground (`.labelColor`,
  `.textColor`, inherited default typing attributes, or no explicit glyph
  foreground) while SwiftUI drives `.preferredColorScheme`, the editor can have
  valid text/layout/ruler state but paint glyphs with a foreground that matches
  or disappears into the current editor background.
- This fits the current visual evidence: line numbers and active-line
  highlight render in both themes, but glyphs do not. It also explains why
  inspecting only `NSTextStorage` or only one explicit TK2 rendering attribute
  is not enough; AppKit may still resolve a default foreground at draw time.
- Next check: force the text view, scroll view, ruler, and container to the
  applied theme's concrete `NSAppearance`, and ensure the editor's
  text/typing/rendering foregrounds are concrete token colours, not dynamic
  system colours, after every theme switch.

Focused appearance test after that hypothesis:

- `ApplyThemePropagationTests.appKitThemeDisablesAdaptiveForegroundRemapping`
  now captures this OS-level failure mode directly.
- Red-state result before the appearance patch: `container.textView.appearance`
  was `nil` after both LCARS Dark and LCARS Light theme application. That means
  the editor text view was inheriting its effective AppKit appearance from
  SwiftUI/window state instead of the concrete code-editor theme.
- The same red run showed `usesAdaptiveColorMappingForDarkAppearance` was
  already `false` in this direct container test, so the confirmed gap was
  concrete appearance propagation, not only the adaptive-remapping flag.
- Current patch sets the concrete AppKit appearance on the container, scroll
  view, gutter/minimap, text view, and line-number ruler; `CodeEditorView` also
  disables adaptive foreground remapping when applying a theme.
- Current focused evidence:
  `swift test --filter ApplyThemePropagationTests/appKitThemeDisablesAdaptiveForegroundRemapping`
  passes and verifies `.darkAqua` for LCARS Dark and `.aqua` for LCARS Light.

Live instrumentation added after the user confirmed the app is still blank:

- Added `CodeEditorRenderingDiagnostics` under the OSLog category
  `RenderingDiagnostics`, using the existing `CrossPlatformLogger` wrapper.
- The logs are intentionally content-safe: they do **not** print document
  text. They do print document length, selected range, sample location,
  editability/selectability, `NSTextView.textColor`, background color, typing
  foreground, storage foreground, TextKit2 rendering foreground, frame/bounds,
  clip bounds, concrete appearance, effective appearance, adaptive dark
  mapping, and syntax token counts/ranges.
- Instrumented the boundaries where the foreground can be lost:
  `CodeEditorRepresentableHelper` make/update,
  `CodeEditorBaseCoordinator` setup/update,
  `CodeEditorContainerView.apply(theme:)`,
  `CodeEditorView.apply(theme:)`,
  `CodeEditorView.stampThemeForeground(...)`,
  `removeSyntaxHighlighting()`, and
  `AsyncSyntaxHighlighter.applyTokens(...)`.
- To stream the live sample logs while reproducing the bug:
  `log stream --style compact --predicate 'subsystem == "com.codeeditor.plugin" AND category == "RenderingDiagnostics"'`
- Build/test evidence after adding instrumentation:
  `swift build --target CodeEditorSample` passes. It still emits the existing
  `RootWindow.swift` main-actor warnings, which are unrelated to rendering.
  `swift test --filter ApplyThemePropagationTests` passes all 8 focused theme
  propagation tests.

First live log read from the instrumented sample:

- The blank editor is **not** currently explained by "only the background
  changed." In the live app after `textView.apply(theme:)` and after async
  highlighting, the same sampled character reports:
  - `textColor=#F2E7D8/FF`
  - `backgroundColor=#080A0F/FF`
  - `storageForeground=#F2E7D8/FF`
  - `renderingForeground=#F2E7D8/FF`
  - `appearance=NSAppearanceNameDarkAqua`
  - `effectiveAppearance=NSAppearanceNameDarkAqua`
  - `textLayoutManager=true`
  - `editable=true`
- That means the text model, theme foreground, and TK2 rendering attributes
  are alive at the points we instrumented.
- The suspicious live signal is geometry/viewport state, not colour state:
  the scroll clip view repeatedly reports `clipBounds={-50.0,0.0,...}` while
  the text view frame starts at `{0.0,0.0,...}`. `-50` matches the line-number
  ruler width. This may be normal AppKit ruler behavior, but it is the first
  live mismatch between the visible editor geometry and the text document
  geometry, so the next diagnostic should stop assuming a foreground failure
  and inspect draw/hit-test layering:
  - whether `NSTextView.draw(_:)` is actually called for the visible glyph
    rects,
  - whether an overlay/subview/layer above the text view is covering glyphs,
  - whether the text container origin/inset plus the ruler-induced clip origin
    shifts glyphs outside the visible portion,
  - whether the active-line highlight view is above the parent text drawing
    rather than behind it.

Second live read / stronger root-cause candidate:

- The next code inspection found a custom `NSTextLayoutFragment` subclass in
  `Sources/CodeEditorPlugin/Text/TextLayoutFragment.swift`.
- Its `draw(at:in:)` override calls `super.draw(...)` only while the fragment
  state is **before** `layoutAvailable`. Once layout exists, it bypasses
  TextKit2's native fragment drawing and manually loops over
  `textLineFragments`, calling `NSTextLineFragment.draw(...)` with a
  paragraph-style-derived y offset.
- This matches the new evidence better than another foreground/theme patch:
  the text storage, typing attributes, concrete appearance, and TK2 rendering
  foreground all log as correct, but the visible glyphs still do not appear.
  The remaining boundary between "attributes exist" and "pixels are visible"
  is the custom fragment draw override.
- The next test should isolate this boundary by changing only
  `TextLayoutFragment.draw(at:in:)` to use TextKit2's native
  `super.draw(at:in:)` path for glyph rendering, while preserving the invisible
  character overlay after native drawing. If that restores glyphs, the root
  cause is the manual line-fragment draw path, not theme foreground
  propagation.
- Do not retry the earlier appearance/foreground changes unless new logs show
  those values regressing. The current live logs already show those values are
  correct during the broken state.

Focused draw-boundary test:

- Added `TextRenderingVisibilityTests.testTextViewDrawsVisibleForegroundPixelsWithThemeApplied`.
  It renders the actual AppKit `CodeEditorView` into a bitmap under LCARS Dark,
  with line numbers and selected-line highlight disabled, then counts bright
  opaque pixels inside the text view.
- Red-state result before changing production code:
  `swift test --filter TextRenderingVisibilityTests/testTextViewDrawsVisibleForegroundPixelsWithThemeApplied`
  fails with `brightPixels == 0`.
- Interpretation: this reproduces the user's visible blank editor at the
  actual view-rendering boundary. The text/theme setup runs, but the rendered
  text view bitmap is effectively blank. This is now a better guardrail than
  more foreground-attribute tests, because those are already green while the
  app is broken.
- Two draw-path probes were tried and then reverted after this red test stayed
  red:
  1. Change `TextLayoutFragment.draw(at:in:)` to call `super.draw(...)`
     directly.
  2. Return Apple's native `NSTextLayoutFragment` from the TextKit2 delegate
     instead of the custom `TextLayoutFragment` subclass.
  Both left `brightPixels == 0`, so do not retry those exact changes without
  new evidence.

Preset clue from the removed sample picker:

- The user reports the editor previously became visible under other
  configuration presets, while the default preset remained broken.
- `PresetCatalog.apply(...)` did not touch `performance`; it merged only the
  preset's display, behavior, and layout sections. That gives a narrower
  bisection surface than theme/foreground:
  - `.minimal` disables syntax highlighting, line numbers, annotations, code
    folding, folding controls, minimap, and completion.
  - `.presentation` starts read-only, disables line numbers, annotations, and
    selected-line highlighting, and enables wrapping.
  - `.markdown` enables wrapping and link/quote/dash substitutions, and
    disables code folding.
  - `.macOS` only materially changes gutter width and some text substitution
    / performance defaults.
- New implication: a preset switch may have worked either because a specific
  display/behavior/layout feature was removed from the draw stack, or because
  the configuration update path forced a relayout/restamp that the initial
  default render missed.
- Important current-state check: the new offscreen visibility regression uses
  a `.minimal`-style configuration and still fails with `brightPixels == 0`.
  That means the current uncommitted regression may now sit below the exact
  preset knobs that used to make the app visible. The next diagnostic should
  run a preset matrix against the live sample/configuration update path and log
  frame, hit-test target, text container origin/inset, document range layout,
  and rendered pixel counts per preset before any more production fixes.
- Diagnostics were extended to support that preset matrix. `CE_RENDER` now logs
  the preset-relevant flags (`syntax`, `lineNumbers`, `selectedLine`,
  `annotations`, `minimap`, `completion`, `wrapLines`, and
  `hardwareAcceleration`), font attributes (`viewFont`, `storageFont`,
  `renderingFont`), text container geometry (`textContainerInset`,
  `textContainerOrigin`, `containerSize`, `widthTracks`, `linePadding`),
  hit-testing, and first TextKit2 layout-fragment geometry.
- Build evidence after extending diagnostics:
  `swift build --target CodeEditorSample` passes.
- Immediate finding from the existing log stream: the `.minimal`/syntax-off
  path really does clear the theme foreground. In the focused visibility test,
  `textView.apply(theme:)` stamps `renderingForeground=#F2E7D8/FF`, then
  `configuration.removeSyntaxHighlighting` runs, and
  `container.apply.end.changedTheme` reports `renderingForeground=nil`.
- Root cause for that preset path: `removeSyntaxHighlighting()` removes
  `.foregroundColor` rendering attributes under the assumption that
  `NSTextView.textColor` / persistent storage foreground will be enough. The
  rest of the evidence shows that assumption is false for this TK2 surface.
  Removing syntax highlighting must remove token colours and then re-seed the
  theme's base foreground rendering attributes.
- Follow-up after applying that targeted re-seed: the diagnostics now show
  `renderingForeground=#F2E7D8/FF` surviving the syntax-off path, but the
  focused bitmap visibility test still reports `brightPixels == 0`. This means
  the syntax-off foreground loss was real, but it is not the whole current
  blank-editor failure.
- Important anti-regression note: the `TextLayoutFragment.draw(at:in:)`
  `super.draw(...)` probe was re-tested after the syntax-off re-seed and still
  failed the same focused bitmap visibility test. Do not keep or retry that
  draw-path change unless new live logs contradict this result.
- Additional preset clue from
  `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PresetsExtensions.swift`:
  the old "working under other presets" report is not just a theme report.
  `minimal`, `presentation`, `markdown`, and `readOnly` change display,
  behavior, and layout. The likely signal is either a feature bisection
  (`syntax`, `lineNumbers`, `selectedLine`, `wrapLines`, completion/folding)
  or a configuration reapply/relayout side effect. The command palette still
  exposes both `Preset: X` merge actions and `Reset to preset: X` wholesale
  replacements, so the old workaround can still be reproduced without
  restoring the removed Theme-panel picker.
- Historical check against `d026d42^`: the removed Theme-panel picker used
  exactly the non-destructive merge path (`PresetCatalog.apply`). It preserved
  performance settings and replaced only display, behavior, and layout. If the
  old picker made text visible, the first live matrix should use command
  palette `Preset: X` entries before trying `Reset to preset: X`; otherwise
  the test changes more variables than the removed UI did.
- New user hypothesis: stop treating this purely as a foreground problem and
  test the opposite variable. The live screenshots show the editor background,
  selected-line band, ruler, and status state all drawing while glyphs do not.
  A plausible one-variable probe is to keep the theme foreground and rendering
  attributes exactly as logged, but stop assigning the theme's
  `editor.background` to the AppKit `NSTextView`. Let `NSTextView` use
  macOS' default text background for the current concrete appearance instead.
  If glyphs appear, the failure is in themed background/layer composition; if
  they remain invisible, the background is not the primary cause.
- Live result of that probe: after rebuilding and relaunching the sample, logs
  show the background variable did change. In dark appearance the text view now
  reports `backgroundColor=#1E1E1E/FF` instead of the LCARS token
  `#080A0F/FF`, while `textColor`, `typingForeground`,
  `storageForeground`, and `renderingForeground` remain valid. The persistent
  warning signal is now `hitTestTextView=false` during the blank state. If the
  user still sees no glyphs with the AppKit default background, the next
  investigation should target view/layer covering and coordinate-space
  hit-testing rather than more colour stamping.
- User confirmed this background probe did **not** restore glyphs. Revert the
  AppKit default-background experiment; the failure is now confirmed to survive
  both themed and system text-view backgrounds.
- New user observation: the Language Server panel is disabled and the
  `Attach sourcekit-lsp` checkbox cannot be enabled. Initial reading: this is
  probably **not** the cause of invisible glyphs. The editor's text drawing,
  selection, ruler, syntax provider registration, and completion provider
  registration are all active without LSP. LSP should only add sourcekit-backed
  diagnostics/completion/hover. It is still worth inspecting because a disabled
  panel can reveal sample-app state gating (active language, workspace root,
  document URL, or coordinator lifecycle) that may also explain a broader
  sample-shell issue.
- New user observation: the sample appears to have an app/window inside another
  app/window: native macOS traffic lights are visible, then the sample draws a
  second chrome row with its own traffic lights, then tabs. This **could**
  contribute. It is a separate hypothesis from text colour: the latest logs
  show glyph foreground/background/appearance are valid, so the remaining
  likely boundary is view composition, hit-testing, clipping, layer order, or
  coordinate-space translation. Double chrome is a concrete sign that the
  sample shell should be inspected before trying more TextKit foreground or
  background changes.
- Code inspection confirms the sample already declares
  `.windowStyle(.hiddenTitleBar)` in
  `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`, so the double
  traffic-light chrome likely means the hidden-titlebar style is not being
  applied to the launch path currently under test, or a second app/window host
  is involved. Next checks: inspect `RootWindow` / `WindowBody`, verify the
  active scene path, and compare the AppKit window style mask at runtime.
- New dispatch-service clue from the user: several broken surfaces share one
  configuration/runtime fan-out. `CodeEditorView.configuration.didSet` calls
  `applyConfiguration()`, and that method dispatches to selected-line
  highlighting, syntax highlighting/removal, layout/word-wrap sizing,
  paragraph style, text input behavior, code folding, range highlighting, and
  finally `containerView?.applyConfiguration()`. The container's
  `applyConfiguration()` then disables internal line numbers, writes
  `textView.configuration`, toggles scroll/ruler state, changes
  `widthTracksTextView`, and restores scroll position. This is a much more
  plausible shared fault boundary than another foreground/background patch.
- Live log anomaly to chase next: after many healthy logs with
  `docLength=3536` and concrete theme foregrounds, a later update logs
  `coordinator.update.afterSetText docLength=0 incomingTextLength=0`. That
  means at least one SwiftUI update path is handing the representable an empty
  text binding, not just losing glyph pixels. Since `CodeEditor()` without an
  active-document environment intentionally falls back to a constant empty
  binding, the next instrumentation should log whether `activeDocumentManager`
  and `activeID` are present in `CodeEditor.body` whenever the incoming text
  length becomes zero.
- Added focused `DispatchDiagnostics` logs for this boundary:
  `CodeEditor.body` now logs `CE_DISPATCH event=body.resolveTextBinding` when
  the effective text binding is empty or does not match the active document's
  stored text length; `CodeEditorView.applyConfiguration()` and
  `CodeEditorContainerView.applyConfiguration()` log compact one-line
  configuration fan-out state. Build evidence:
  `swift build --target CodeEditorSample` passes after adding these logs.
- First run with `DispatchDiagnostics` after relaunch:
  - startup begins with an empty plain-text placeholder, then switches to a
    Swift document with `docLength=2547`;
  - no `body.resolveTextBinding` anomaly has fired yet, so the active-document
    binding matched the document store during startup;
  - the container deliberately rewrites `textViewConfigLineNumbers=false` while
    leaving `containerConfigLineNumbers=true`, confirming the line-number
    ruler is owned by the container and the inner text view has internal line
    numbers disabled.
  - this makes the dispatch fan-out a real shared boundary, but there is not
    yet evidence that it caused the blank glyphs on this fresh run.
- User/Claude viewport-delegate finding:
  - TextKit2 glyph pixels depend on
    `NSTextViewportLayoutControllerDelegate.textViewportLayoutController(_:configureRenderingSurfaceFor:)`.
    AppKit installs the `NSTextView` as the viewport layout controller's
    delegate when it constructs a TK2 text view.
  - The code currently clears that delegate twice:
    `CodeEditorView+PerformanceExtensions.swift` in
    `setupTextKit2Optimization()` and `TextKitSetupHelper.swift` in
    `applyTextKit2Optimizations(to:)`.
  - Code inspection confirms both lines are in the setup path, and
    `ModernTextKit2Bridge(` has no call sites, so no replacement delegate is
    restoring rendering-surface configuration.
  - This explains the strongest automated split so far: a plain `NSTextView`
    rendered by the same bitmap harness produces foreground pixels, while a
    direct `CodeEditorView` with explicit white-on-black system colors still
    produces `brightPixels == 0`. The container, theme, LSP, and sample chrome
    are no longer required to reproduce glyph invisibility.
  - Next one-variable fix: delete the two `textViewportLayoutController.delegate = nil`
    assignments and log the viewport delegate type/identity so the live
    sample can prove the delegate remains attached.
- Viewport-delegate fix result:
  - Removed both `textViewportLayoutController.delegate = nil` assignments.
    The lines were in `CodeEditorView.setupTextKit2Optimization()` and
    `TextKitSetupHelper.applyTextKit2Optimizations(to:)`.
  - Added rendering diagnostics for
    `viewportDelegate` and `viewportDelegateIsTextView` so the live sample can
    report whether AppKit's `NSTextView` delegate remains attached.
  - Added focused bitmap/delegate coverage in
    `TextRenderingVisibilityTests`:
    - a direct `CodeEditorView` preserves `NSTextView` as the viewport
      delegate;
    - a plain `NSTextView` harness draws visible foreground pixels;
    - a direct `CodeEditorView` with explicit white-on-black system colors
      draws visible foreground pixels;
    - a direct themed `CodeEditorView` draws visible foreground pixels;
    - the container/themed text view path draws visible foreground pixels.
  - Current focused evidence:
    `swift test --filter TextRenderingVisibilityTests` passes 5 tests with
    0 failures.
  - Follow-up grep:
    `rg -n "textViewportLayoutController\\.delegate\\s*=\\s*nil|ModernTextKit2Bridge\\(" Sources Tests`
    returns no matches. The broken delegate-clear path is gone, and the dead
    replacement delegate still has no call sites.
  - Live validation from the user: after rebuilding/running the sample,
    `NOTES.md` renders visible glyphs, syntax colours, line numbers, cursor,
    and active-line highlight again. This is the first fix that resolves the
    observed blank editor in the actual app, not only in attribute/log tests.

Glyph invisibility is now resolved by the viewport-delegate fix. The remaining
visual/layout work should move on to the gutter/line-geometry issues and any
separate sample-shell problems; do not continue foreground/background/theme
experiments unless new evidence shows those values regressing.

- Gutter/line-geometry follow-up:
  - Added
    `LineNumberRulerViewTK2Tests.testWrappedLogicalLineUsesFirstVisualLineFragmentForRulerPosition`.
  - Red-state result: a wrapped logical line produced a helper rect with
    height `129.6`, exactly the full paragraph layout-fragment height, while
    the first visual `NSTextLineFragment` was `21.6` high. This proves the
    ruler was centering a line number across the whole wrapped paragraph
    instead of placing it on the first visual row.
  - Fix: `TextKitLineNumberHelper.getLineFragmentRect(for:)` now resolves the
    visual `NSTextLineFragment` containing the logical line's start location
    and returns that fragment's typographic rect in layout-fragment
    coordinates. It only falls back to the whole layout fragment if TextKit
    cannot provide a visual line.
  - Current focused evidence:
    `swift test --filter LineNumberRulerViewTK2Tests`,
    `swift test --filter LineNumberRulerViewSnapshotTests`,
    `swift test --filter GutterViewRendererActiveLineTests`, and
    `swift test --filter GutterViewThemeTests` all pass. After this gutter
    change, `swift test --filter TextRenderingVisibilityTests` still passes
    and `swift build --target CodeEditorSample` succeeds.

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

### 2026-05-15 uncommitted fix attempt — "remove TK1 coercion + re-stamp after updates"

1. Added permanent regression tests for the two confirmed TK1 coercion
   points:
   - `CodeEditorViewTextKit2InitTests.testTK2StackSurvivesWrappedLayoutConfigurationChange`
   - `SwiftUICoordinatorTests.testSizeCalculationPreservesTextKit2Stack`
2. Replaced AppKit SwiftUI size calculation's live `textView.layoutManager`
   path with a TK2-safe intrinsic-size estimate based on
   `textContentStorage?.textStorage`, font metrics, and the proposed width.
3. Replaced wrapped-layout invalidation's `textStorage` /
   `textContainer.layoutManager` reads with `NSTextLayoutManager.invalidateLayout(for:)`
   via `TextKitBridge.textRangeFromNSRange`.
4. Added `ApplyThemePropagationTests.sameThemeReapplyRestampsTextViewForeground`
   and changed `CodeEditorContainerView.apply(theme:)` so same-theme applies
   still reach `CodeEditorView.apply(theme:)` while the rest of the fan-out
   remains equality-gated.
5. Moved `container.apply(theme:)` in
   `CodeEditorRepresentableHelper.updateContainer` to run after coordinator
   text/configuration mutations, so the storage foreground stamp is the last
   step in the SwiftUI update pipeline.
6. Removing the legacy layout invalidation exposed a wrapped-AppKit sizing
   dependency that had been hidden by TK1. `CodeEditorView.updateTextContainerSize()`
   now recomputes document height from TK2 layout fragments, preserves scroll
   origin across wrap toggles, and the AppKit container keeps wrapped text
   views width-autoresizing only so document height is not clamped to the
   clip view.
7. The TK2 document-height change legitimately shifted the line-number ruler
   snapshot baseline. The updated baseline still reflects the existing gutter
   strategy; the broader wrapped-gutter rewrite remains open.

**Red/green evidence so far:** the three new tests failed before the
production changes and passed afterward. Focused scroll-preservation and
line-number snapshot tests also pass after the AppKit document-height fix.
Final verification passes with `swift build && swiftlint --fix && swiftlint && swift test --parallel`.

**New outcome from user validation:** this attempt regressed the sample app.
The editor pane is now visually blank for `Package.swift`, and the editor
feels read-only. Passing package tests did not cover the sample-like flexible
layout / hit-testing path, so the test coverage added in this attempt is
insufficient.

### 2026-05-15 follow-up fix — "completion popup lazy table recursion"

Full `swift test --parallel` verification initially reached the end of the
XCTest run but then the Swift Testing helper crashed with signal 11. Running
Swift Testing alone reproduced the same crash, including with `--no-parallel`.

The macOS crash report showed a stack overflow on the main thread:

- `CodeEditorView.requestCompletion(...)` produced completion items.
- `showCompletionPopup(with:at:)` set `CompletionViewController.completionItems`.
- `completionItems.didSet` called `reloadData()`, which lazily constructed
  `CompletionViewController.tableView`.
- During table construction, assigning `dataSource` triggered AppKit selection
  validation and `tableViewSelectionDidChange(_:)`.
- That delegate method read the lazy `tableView` property before the lazy
  closure had finished, recursively re-entering the getter until the process
  hit the stack guard.

Fix: `tableViewSelectionDidChange(_:)` now reads the `NSTableView` from
`notification.object`, avoiding the lazy property during construction. Added
`CompletionViewControllerTests.completionItemsBeforeViewLoadDoesNotReenterLazyTableConstruction`.

**Evidence:** the new targeted test passes, and
`swift test --disable-xctest --enable-swift-testing --no-parallel` now passes
441 tests with the one existing known issue. The full package verification
command also passes after this fix.

## Root cause / hypotheses

### Confirmed root cause: viewport delegate was cleared

The current strongest explanation for the invisible-glyph failure is the
TextKit2 viewport layout controller delegate being cleared during setup.
AppKit installs the `NSTextView` itself as
`textLayoutManager.textViewportLayoutController.delegate`; that delegate is
responsible for configuring the rendering surface for each
`NSTextLayoutFragment`. Clearing it leaves text storage, selection, cursor
position, line-number ruler, active-line highlight, and completion state alive,
but prevents glyph pixels from being hosted.

This exactly matches the failure evidence:

1. Foreground/background/theme/appearance diagnostics were valid while
   `brightPixels == 0`.
2. Selection and status-bar line/column state remained alive.
3. A plain `NSTextView` drew pixels in the same bitmap harness, while direct
   `CodeEditorView` did not before the delegate fix.
4. Replacing the custom layout-fragment draw path did not restore pixels,
   because the missing boundary was the viewport rendering-surface delegate
   below fragment drawing.

The two removed delegate clears were:

1. `CodeEditorView+PerformanceExtensions.swift` in
   `setupTextKit2Optimization()`.
2. `TextKitSetupHelper.swift` in `applyTextKit2Optimizations(to:)`.

`ModernTextKit2Bridge` was not a fallback because `ModernTextKit2Bridge(` has
no call sites in `Sources` or `Tests`.

### Previously confirmed TK2 preservation issues

Earlier investigation also confirmed that older `main` code read AppKit
TextKit1 accessors on live `CodeEditorView` instances:

1. `CodeEditorRepresentableHelper.calculateAppKitSize(...)` reads
   `textView.layoutManager` in `sizeThatFits` when SwiftUI does not provide
   both dimensions. A temporary regression test confirmed that this single
   call clears `textView.textLayoutManager`.
2. `CodeEditorView.updateTextContainerSize()` reads the inherited
   `textStorage` property and `textContainer.layoutManager` while applying
   `wrapLines`. A temporary regression test confirmed that enabling wrapped
   layout clears `textView.textLayoutManager`.

Once a view is coerced to TK1, several assumptions in the shipped fixes no
longer hold: `stampThemeForeground()` only looks at
`textContentStorage?.textStorage`, the TK2 rendering-attribute path is gone,
and gutter drawing starts mixing real TK2 fragment y-values with fallback
estimated line geometry.

### Invisible text

1. **TK2 → TK1 coercion from SwiftUI sizing and wrapped layout.**
   Confirmed by temporary focused tests on 2026-05-15. This remains an
   important preservation bug, but the viewport-delegate fix is the first
   change that turns the focused glyph-pixel boundary green.
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

Additional files touched by the current uncommitted attempt:

```
Sources/CodeEditorPlugin/Completion/CompletionViewController.swift                     (lazy table recursion fix)
Sources/CodeEditorPlugin/Core/CodeEditorView+PerformanceExtensions.swift              (preserve NSTextView viewport delegate)
Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift                    (TK2-safe wrap invalidation/document height)
Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift                                (preserve NSTextView viewport delegate)
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift         (wrapped AppKit sizing)
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift                          (same-theme text-view re-stamp)
Sources/CodeEditorPlugin/Layout/ContainerViewHelper.swift                              (wrapped autoresizing mask)
Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift                   (TK2-safe AppKit size estimate; theme order)
Sources/CodeEditorPlugin/Utilities/CodeEditorRenderingDiagnostics.swift                (rendering/dispatch/viewport diagnostics)
Tests/CodeEditorPluginTests/Completion/CompletionViewControllerTests.swift             (completion recursion regression)
Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift                 (wrapped TK2 preservation regression)
Tests/CodeEditorPluginTests/Layout/ApplyThemePropagationTests.swift                    (same-theme foreground re-stamp regression)
Tests/CodeEditorPluginTests/Layout/__Snapshots__/LineNumberRulerViewSnapshotTests/...  (updated TK2 layout-height baseline)
Tests/CodeEditorPluginTests/SwiftUICoordinatorTests.swift                              (size calculation TK2 preservation regression)
Tests/CodeEditorPluginTests/Text/TextRenderingVisibilityTests.swift                    (viewport delegate + glyph pixel regressions)
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
- `CompletionViewController` was a separate verification blocker, not the
  invisible-text cause: it reproduced in the Swift Testing helper after
  completion requests, and is fixed by avoiding lazy table-view re-entry.
- Foreground/background/theme/appearance were not the final missing boundary:
  logs showed valid foregrounds and the default-background probe still failed.
  The focused pixel test only turned green after preserving the TextKit2
  viewport layout delegate.
- Live sample validation confirms the viewport-delegate fix restores visible
  glyph rendering in `CodeEditorSample`.
- Final verification for the current attempt passes:
  `swift build && swiftlint --fix && swiftlint && swift test --parallel`.

## Suggested next steps / fix plan

0. **Done:** relaunch/sample validation confirms glyphs draw again after the
   viewport-delegate fix.
1. **Done in the 2026-05-15 uncommitted fix attempt:** add permanent
   regression tests for the two confirmed TK1 coercion
   points:
   - SwiftUI AppKit size calculation must preserve `textLayoutManager`.
   - Applying `wrapLines = true` must preserve `textLayoutManager`.
2. **Done in the 2026-05-15 uncommitted fix attempt:** remove live-editor
   TK1 accessor reads from:
   - `CodeEditorRepresentableHelper.calculateAppKitSize(...)`
   - `CodeEditorView.updateTextContainerSize()`
3. **Done in the 2026-05-15 uncommitted fix attempt:** move
   `container.apply(theme:)` in `CodeEditorRepresentableHelper.updateContainer`
   to run *after* `coordinator.updateContainer`. This makes the stamp
   the very last thing the pipeline does, so it can't be undone by
   `setText`. Right now `stampThemeForeground` runs both before (via
   `apply(theme:)`) and after (via the isHostBindingSwap branch), but the
   "after" stamp only fires on a swap, not on a same-text re-render.
4. **Current highest priority:** rewrite the gutter draw loop to iterate
   `textLayoutManager.enumerateTextLayoutFragments` and use
   `textLineFragments` per-fragment, then drop the
   `LineGeometryStore.yPosition` path and the index-times-line-height
   fallback. Fixes screenshot 11 and gives a single coordinate space.
   - Partial fix now landed: `TextKitLineNumberHelper.getLineFragmentRect`
     returns the first visual line fragment for wrapped logical lines, so line
     numbers are no longer centered across full wrapped paragraphs.
   - Still open if artifacts remain in long/scrolled files: replace the
     visible-line enumeration/fallback path with a single fragment-driven draw
     pass and skip not-yet-laid-out lines instead of estimating.
5. **Done in the 2026-05-15 follow-up fix:** fix the completion popup's
   lazy table recursion so the Swift Testing helper no longer stack-overflows
   during verification.
6. **Done in the viewport-delegate fix:** remove both
   `textViewportLayoutController.delegate = nil` assignments, add delegate
   diagnostics, and cover direct/container glyph pixels with
   `TextRenderingVisibilityTests`.
7. **Still open after live validation:** consider whether any remaining
   editor surfaces should be simplified around AppKit's native TK2 rendering
   path instead of custom fragment/ruler geometry. Do this only after the
   current glyph fix is visually confirmed.

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
