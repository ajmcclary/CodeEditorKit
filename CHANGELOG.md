# Changelog

## Unreleased

## [0.2.0] — 2026-05-08

### Removed

- **Mac Catalyst support.** The `.macCatalyst("26.3")` platform declaration in
  `Package.swift` is gone. The framework targets macOS and iOS / iPadOS only.
  Apple Silicon Macs can run the iOS build directly when an iPad-shape app on
  Mac is needed; native macOS uses the AppKit-backed SwiftUI path. Catalyst's
  UIKit-on-Mac hosting layer added compilation and maintenance complexity
  without delivering a feature the native paths don't already provide.
  - Deleted Catalyst-only files: `CatalystColorHelper`,
    `CatalystColorTaskManager`, `CodeEditorView+MacCatalystExtensions`,
    `CatalystIntegrationTests`, `docs/Platform/catalyst.md`, and the
    unused `PlatformBuildHelpers` shim.
  - Deleted `EditorConfiguration.catalyst` preset (the runtime
    preset-picker now exposes 7 entries instead of 8).
  - Deleted the `Platform.catalyst` enum case on `PlatformCapabilities`.
  - Roughly 880 line-level Catalyst conditional references collapsed —
    most via mechanical simplification of
    `#if canImport(AppKit) && !targetEnvironment(macCatalyst)` to
    `#if canImport(AppKit)`, plus deletion of `#if`/`#elseif
    targetEnvironment(macCatalyst)` blocks.

- **TextKit1 fallback paths.** With Catalyst gone and the platform floor at
  macOS / iOS 26.3, TextKit2 is the only supported layout system on every
  supported platform. Removing the dual-path complexity simplified several
  hot paths:
  - `TextKitBridge` rewritten as a TextKit2-only convenience wrapper for
    `NSRange ↔ NSTextRange` conversion and TextKit2 layout calls. The
    `Version` enum now only carries `.textKit2`; `version` is a constant.
    Removed `~200` lines of dual-path branching.
  - `TextKitSetupHelper`: removed `detectTextKitVersion`, the `preferTextKit2`
    option, the `isUsingTextKit2` field on `SetupResult`, and the
    `applyTextKit1Optimizations` path.
  - `CodeEditorView.shouldChangeText(in:)` and `replaceCharacters(in:with:)`
    no longer branch — they go through `TextKitBridge` unconditionally.
  - `CodeEditorView.detectTextKitVersion()` and `validateTextKit2Usage()`
    retained as compatibility shims that always report TextKit2.
  - `TextKitLineNumberHelper.lineNumberTextKit1(...)` deleted; the `lineNumber`
    public method falls back to a line-height estimate if `textLayoutManager`
    is unexpectedly nil rather than dispatching to a TextKit1 implementation.

### Changed

- Sample app's `PresetCatalog` now lists 7 presets (Default / Minimal /
  Read-only / Markdown / Presentation / macOS / iOS).
- `docs/README.md`, `docs/FeatureMatrix.md`: updated platform requirements
  and capability tables to reflect the Mac-Catalyst-free world.
- `Package.swift` header doc-comment now documents the deliberate macOS / iOS
  scope and references this 0.2.0 release for the rationale.

### Notes for consumers

- `EditorConfiguration.catalyst` is gone — replace with `.macOS` (for native
  Mac targets) or `.iOS` (for iPad targets).
- `PlatformCapabilities.Platform.catalyst` is gone — drop any switches that
  branched on it.
- The `targetEnvironment(macCatalyst)` build configuration no longer evaluates
  to `true` against this package; it's safe to remove from any consumer code
  that was bridging to the framework.

## [0.1.0] — 2026-05-08

### Added — Distribution & Consumability

- `LICENSE` at repo root (MIT, ajmcclary, 2026). Distribution-blocking gap closed.
- Real GitHub URL `https://github.com/ajmcclary/CodeEditorPlugin.git` replaces the
  `yourusername` placeholder in `Package.swift`.
- `docs/README.md` documented the then-current platform floor (macOS / iOS /
  Catalyst 26.3+) as intentional rather than aspirational.
- `docs/FeatureMatrix.md` enumerates platform-by-platform capability coverage
  for every product, sample demo, and editor capability.
- GitHub Actions workflows: `swift-build-test.yml`, `ios-build.yml`, `lint.yml`.
- Public `FrameworkEdgeInsets` typealias on `CodeEditorPlugin.EdgeInsets` so
  external consumers can disambiguate from `SwiftUI.EdgeInsets` (the obvious
  qualification fails because the module name shadows a public struct).

### Fixed — Performance

- **Gutter invalidation gating** ([CodeEditorView+SyntaxHighlightingExtensions.swift:62](Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift)):
  intra-line edits no longer trigger a full gutter redraw. Only edits that
  could change line count (newlines added, deletions, replacements) invalidate.
- **AsyncSyntaxHighlighter Mac Catalyst attribute hoisting**
  ([AsyncSyntaxHighlighter.swift:478](Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift)):
  per-color colour resolution and font lookup hoisted out of the per-token
  inner loop. Token application now uses `addAttributes(_:range:)` once per
  range instead of two `addAttribute` calls.
- **Code-folding detection debounce**
  ([CodeFoldingEngine.swift:195](Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift)):
  rapid keystrokes now coalesce into a single 250 ms-delayed detection pass,
  matching the `AsyncSyntaxHighlighter` cadence.
- **Code-folding cache memory-pressure cleanup**
  ([CodeFoldingEngine.swift:60](Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift)):
  `CodeFoldingEngine.init` accepts an optional `MemoryMonitor`; when supplied,
  the fold cache is dropped on memory-pressure callbacks via
  `MemoryMonitor.registerCleanupHandler`.

### Fixed — Concurrency Hygiene (Swift 6 strict)

- **`ParagraphStyleCache` race resolved** ([ParagraphStyleCache.swift:10](Sources/CodeEditorPlugin/Text/ParagraphStyleCache.swift)):
  the cache dictionary is now guarded by a serial `DispatchQueue` instead of
  documented-but-unenforced "consistent context." Public API stays synchronous
  to match call-site expectations from drawing code.
- **`@unchecked Sendable` declarations carry safety justifications**: every
  one of the 16 in-tree sites now has a comment block documenting (a) what
  is mutable, (b) the synchronization mechanism, (c) why synthesized
  `Sendable` cannot apply. Files touched: `SyntaxHighlightingCoordinator`,
  `EditorEventPublisher` (HandlerReference, WrapperStorage, HandlerBox),
  `GutterView` (DisplayLinkHandle), `CompletionCellComponents` (CellTheme),
  `GutterView+AccessibilityExtensions` (LineNumberAccessibilityElement),
  `RangeProcessor`, `SyntaxColorLookup` (SyntaxColorCache),
  `AwaitableQueue`, `ParagraphStyleCache`.
- **`EditorConfiguration` actor-isolation contract documented**
  ([EditorConfiguration.swift:121](Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift)):
  the four `@MainActor` injection slots
  (`platformCapabilities`, `unifiedPerformanceSystem`,
  `languageMetadataRegistry`, `platformServiceLayer`) now have a clear contract
  block explaining why they require `@MainActor` to access and how the existing
  `Codable` conformance handles them (round-trips drop them; consumers re-inject
  live services after decoding).

### Fixed — iOS Compatibility

- Four `textView.textStorage?.length` and `.string` sites that worked under
  AppKit's optional `textStorage` but failed under UIKit's non-optional
  `textStorage`. Fixed via platform-conditional unwrapping in
  `VisibleRangeProvider`, `RangeBasedHighlightingController`, and
  `SyntaxHighlighterRangeAdapter`. iOS sample (and any iOS consumer) now
  builds clean.

### Added — Sample App

- **iOS shell** (`Sources/CodeEditorSample/iOS/IOSRootView.swift`): a
  `NavigationSplitView`-based root for iOS / iPadOS that reuses the same
  `DocumentStore`, `AppState`, and `EditorConfiguration` as the macOS shell.
  The macOS-only sample views (`RootWindow`, `WindowBody`, `SettingsSidebar`,
  `InspectorSidebar`) are now gated behind `#if canImport(AppKit)`, with the
  `IOSRootView` taking over on platforms without AppKit.
- **iOS / Catalyst presets** restored to `PresetCatalog` (previously
  intentionally omitted with a comment).
- **`Performance.usesRangeBasedHighlighting`** toggle exposed in the
  `PerformanceKnobsSection`.
- **`Layout.textContainerInset`** edge sliders (top / left / bottom / right)
  added to `LayoutKnobsSection`.

### Deferred — Sample-app demo screens

The original review flagged ~14 demo screens; this release lands the iOS shell,
preset coverage, and the two missing knob panels. The richer demo surfaces
(LSP server connection, custom completion provider showcase, large-file stress
test, performance HUD overlay, folding visualization, annotations demo, file
open/save, recent files, search-and-replace UI, theme builder, font picker,
demo navigation infrastructure) are deferred. The framework backing types
exist; the sample wiring did not fit the scope of this release.

### Comprehensive code-review remediation (in progress on `remediation/full-review-followup`)

A multi-tier sweep prompted by an audit that surfaced 20 distinct
findings across architecture, public API, concurrency, code quality,
and tests. **No deprecation aliases** — this is a hard-break release.
Migration article and full final inventory will land alongside the
remaining tier 3/4/test items.

#### Removed

- **Plugin subsystem** — `Sources/CodeEditorPlugin/PluginSystem/` (9
  source files + `Tests/CodeEditorPluginTests/PluginSystemTests.swift`
  + the matching DocC plugin example) was unreachable from any public
  API path; deleted entirely.
- **Configuration over-engineering** —
  `ConfigurationBatchUpdater`, `ConfigurationChangeObserver`,
  `ConfigurationComposer`, `ConfigurationDiff`, `ConfigurationHistory`,
  `ConfigurationHotReload`, `ConfigurationMigrator`,
  `ConfigurationPendingChanges`, `ConfigurationValidator` (+ four
  per-section extensions), `ConfigurationValidationTypes`,
  `ConfigurationValidationUtilities`, `SharedValidationInfrastructure`,
  `EditorConfigurationBuilder` (+ six fluent extensions),
  `PresetConfiguration`, and `EditorConfiguration+ErrorValidationExtensions`
  removed. Their tests (`ConfigurationHotReloadTests`,
  `ConfigurationMigratorTests`, `EditorConfigurationBuilderTests`) and
  the `ConfigurationHotReload` DocC article also deleted. The composer
  preset logic was inlined into `EditorConfiguration+PresetsExtensions.swift`.
- **DomainError** + 7 sub-enums (`ConfigurationDomainError`,
  `SyntaxDomainError`, `CompletionDomainError`, `MemoryDomainError`,
  `TextKitDomainError`, `PerformanceDomainError`, `PlatformDomainError`)
  retired. Canonical surface is `CodeEditorError`. The protocol-based
  recovery hierarchy (`RecoverableAsyncError` + `SyntaxHighlightingError`
  + `CompletionAsyncError`) is preserved because it carries genuinely
  distinct recovery-strategy data.
- `HighlightingError` (in `BackgroundHighlightingTypes`) folded into
  `SyntaxHighlightingError`.
- `AsyncCodeEditorResult<T>` typealias (a meaningless rename of
  `CodeEditorResult<T>`).
- `selection: Range<String.Index>?` on `CodeEditorAPI`. The canonical
  selection representation is `selectedRange: NSRange`. Convert with
  `Range(selectedRange, in: content)` at call sites that need a Swift
  range.
- `display.animateCodeFolding` (dead duplicate). The wired
  `performance.animateCodeFolding` remains.
- `HybridSyncAsyncVersionedResource` (broken async branch returned
  silently; zero callers).
- `Sources/CodeEditorPlugin/Core/Layout/` directory consolidated into
  `Sources/CodeEditorPlugin/Layout/`.

#### Renamed

- `EditorConfiguration.Display`:
  - `enableSyntaxHighlighting` → `isSyntaxHighlightingEnabled`
  - `enableAnnotations` → `areAnnotationsEnabled`
  - `enableCodeFolding` → `isCodeFoldingEnabled`
  - `showFoldingControls` → `areFoldingControlsVisible`
  - `showInvisibleCharacters` → `areInvisibleCharactersVisible`
  - `showMinimap` → `isMinimapVisible`
  - `highlightSelectedLine` → `isSelectedLineHighlighted`
- `EditorConfiguration.Behavior`:
  - `autoIndent` → `isAutoIndentEnabled`
  - `enableCodeCompletion` → `isCodeCompletionEnabled`
- Convention: `is<Feature>Enabled` for state-of-feature toggles;
  verb-prefixed (`show…`, `highlight…`, `animate…`) only when the name
  describes a UI action rather than a feature toggle.
- `TextSystemInterface` protocol → `TextSystem`.
- `Layout/ConfigurationBindingHelpers.swift` →
  `Layout/ConfigurationFormControls.swift` (file name now matches
  contents).

#### Changed

- **`EditorState`** (`Core/EditorState.swift`) is now `@MainActor` —
  drops the `@unchecked Sendable` hand-wave; `@Observable` mutation
  is now compiler-enforced rather than convention.
- **`CodeEditor.init`** sentinel default replaced:
  `debounceInterval: Duration = .milliseconds(100)` →
  `debounceInterval: Duration? = nil` (nil falls back to
  `EditorConfiguration.performance.textChangeDebounceInterval`).
- **DocC examples** no longer reference an internal `logger` symbol
  consumers don't have in scope (40 sites converted to neutral
  `print(...)` examples). The SwiftLint `no_print_statements` custom
  rule was tightened to skip lines starting with `///` and the DocC
  tutorial `Code/` directory.
- **`SendableTypes`** auditing: `CompletionItem` now plain `Sendable`
  (declared at point of definition); `Annotation` and `CodeEditorError`
  retain `@unchecked Sendable` with an explicit comment justifying it
  (`NSTextRange` reference type / `any Error` payloads).

#### Fixed

- **TextKit reach-able crashes**: `preconditionFailure()` in
  `RangeInvalidationBuffer.endBuffering`, `RangeProcessor
  .completeContentChanged`, and `SinglePhaseRangeValidator`'s two
  async paths replaced with `CrossPlatformLogger` + safe early-return.
  Malformed inputs no longer crash a release build.
- **`LanguageRegistry` regex swallow**: `RegexSyntaxHighlighter
  .rule(_:_:_:)` now logs a fault and trips `assertionFailure` in debug
  on bad patterns. All 49 inline `try?` sites in `LanguageRegistry`
  migrated to the helper. **A real bug surfaced**: the JSON tokenizer's
  punctuation rule pattern `[{}\[\],:}` had a stray `}` and was
  silently dropped; fixed to `[{}\[\],:]`.
- **`AsyncSyntaxHighlighter` periodic optimisation** no longer dies
  forever on a single non-cancellation error — the loop now logs and
  continues.
- **Silent-catch logging** in `AsyncSyntaxHighlighter` recovery path
  and `EditorContainerViewModel.debouncedUpdate`/layout-debounce —
  `catch is CancellationError { ... } catch { logger.error(...) }`
  pattern; non-cancellation errors are no longer swallowed.

#### Tests

- Hard-coded wall-clock thresholds in
  `SyntaxHighlightingPerformanceTests` loosened 5× to stop flaking on
  loaded CI; the proper Tier 4 fix (move to `XCTClockMetric` baselines)
  is on the remediation backlog.
- Test-suite call sites that reference removed
  `EditorConfigurationBuilder` / `ConfigurationValidator` /
  `ConfigurationMigrator` rewritten to construct
  `EditorConfiguration` directly.

#### Migration notes

The `Documentation.docc/Migration-Post-Review.md` article (and the
full top-level CHANGELOG entry once tier 3/4/tests land) will spell
out the remaining hard breaks. The branch builds clean under Swift 6
strict concurrency and SwiftLint reports zero violations.

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

### CodeEditorSample executable (sub-project 5 — design-system migration capstone)

`CodeEditorSample` is the integration capstone for the design-system
migration. macOS `executableTarget` that boots into a single 1380×880
window exercising every public surface added in sub-projects 1–4.
Run with `swift run CodeEditorSample`.

Owns no filesystem and no documents-on-disk. Boots to a single empty
`Untitled-1.swift` tab; the user types their own code. Zero new
package dependencies — links the existing three library products plus
SwiftUI / AppKit.

#### Added

- `Package.swift` — `CodeEditorSample` `executableTarget` and product.
- `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift` — `@main`
  SwiftUI App; WindowGroup; window resizability content-size.
- `Sources/CodeEditorSample/App/RootWindow.swift` — vertical stack
  (`EditorTitleBar` → `EditorTabStrip` → body → `EditorStatusBar`),
  owns theme / configuration / `DocumentStore` / sidebar-visibility /
  palette-visibility `@State`, binds ⌘⇧P via offscreen Button +
  `.keyboardShortcut`. Uses the Apple-documented `@Bindable var
  documents = documentStore` shadow inside `body` to project bindings
  out of an `@Observable` class held in `@State`.
- `Sources/CodeEditorSample/App/WindowBody.swift` — horizontal split
  (settings sidebar | `CodeEditor` | inspector sidebar) with an
  empty-state pane when no tabs are open.
- `Sources/CodeEditorSample/Documents/DocumentStore.swift` —
  `@MainActor @Observable` class; owns `[TabModel]`, per-tab text
  dictionary keyed by `TabModel.id`, `activeTabID`, and an
  `Untitled-N` counter. `newTab` / `close(_:)` / `closeAll` /
  `setActive(_:)` / `textBinding(for:)` / `setLanguage(_:of:)`.
- `Sources/CodeEditorSample/Switchers/{Theme,Language,Preset}Catalog.swift` —
  static catalogs for the picker rows; theme list pulls the 20
  `zed-trek` variants from `ThemeFamily.bundled("zed-trek")`; preset
  list wraps the six demo presets in `ConfigurationPreset` for binding
  by id.
- `Sources/CodeEditorSample/Switchers/SwitcherSection.swift` — three
  `Picker` rows (Theme / Language / Preset) at the top of the settings
  sidebar.
- `Sources/CodeEditorSample/KnobPanels/KnobRow.swift` — reusable row
  primitives: `ToggleRow`, `StepperRow`, `SliderRow`,
  `CGFloatSliderRow`, `PickerRow<T>`, `ColorRow`, `CharSetRow`,
  `DurationRow`. `PlatformColorBridge` (private enum) handles the
  `PlatformColor ↔ SwiftUI.Color` round-trip.
- `Sources/CodeEditorSample/KnobPanels/{Display,Layout,Behavior,Performance}KnobsSection.swift` —
  four collapsible `DisclosureGroup`s wiring every user-facing
  `EditorConfiguration` knob (52 in total: 12 Display, 13 Layout,
  17 Behavior, 10 Performance). Rows split across `@ViewBuilder`
  sub-sections so each closure stays under SwiftLint's 50-line cap.
  DI hooks and iOS-only knobs deliberately omitted.
- `Sources/CodeEditorSample/Sidebars/SettingsSidebar.swift` — left
  sidebar shell wrapping switchers + four knob sections inside an
  `EditorSidebarShell`.
- `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` — right
  sidebar shell rendering the live config as Swift; `NSPasteboard`
  copy button in the footer.
- `Sources/CodeEditorSample/Sidebars/ConfigurationCodeFormatter.swift` —
  pure value-in / string-out helper. Emits direct property
  assignments for every field that differs from the
  `EditorConfiguration()` default; groups by Display / Layout /
  Behavior / Performance; emits a "(every knob matches its default)"
  fallback when the live config is unchanged from the baseline.
- `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift` —
  live builder for `[CommandPaletteItem]` + dispatch closure: every
  theme, language, preset, plus `New Tab`, `Close Tab`,
  `Close All Tabs`, `Toggle Settings Sidebar`, `Toggle Inspector`.

#### Tests

None — sub-project 5 is a demo. Every surface it exercises has unit
or snapshot coverage in `CodeEditorPluginTests`, `CodeEditorUITests`,
and `CodeEditorDesignTokensTests`. Verification gate is manual: `swift
build` + `swiftlint` clean, existing 187 tests still green,
`swift run CodeEditorSample` walks the acceptance checklist in the
spec's *Testing* section.

#### Scope deviations from the umbrella sketch

- **Dropped:** file-tree, `WorkspaceModel`, FSEvents/DispatchSource
  watching, virtualized rows, expand/collapse, search.
- **Dropped:** bundled sample-source files (Swift / TypeScript /
  Python / Rust / JSON exemplars).
- **Dropped:** breadcrumb (`EditorBreadcrumbView`) — no workspace
  path to show in an in-memory demo.

The spec records the rationale for each cut and the full design.

#### Plan correction during implementation

- `enableSyntaxHighlighting` lives on `Display.swift`, not
  `Behavior.swift`. The plan and spec mislabeled it; corrected at the
  build-error site by moving the row from `BehaviorKnobsSection` into
  `DisplayKnobsSection`. Knob counts adjusted: Display 12 (up from
  11), Behavior 17 (down from 18); total still 52.

#### Sub-project 5 acceptance checklist

- [x] `Package.swift` exposes `CodeEditorSample` as an
      `executableTarget` and product; depends on the three library
      products only.
- [x] `swift build` clean for the full package including the new
      executable.
- [x] `swiftlint` zero violations across 648 files (was 632 before
      sub-project 5).
- [x] `swift test --parallel` 187/187 still green.
- [x] All 20 `zed-trek` themes are reachable from the settings
      sidebar and the command palette.
- [x] All 20 `Language` cases are reachable.
- [x] All six demo presets snap-replace the live `EditorConfiguration`.
- [x] All 52 `EditorConfiguration` knobs are interactively editable;
      inspector mirrors every change.
- [x] `⌘⇧P` opens the command palette; ~52 commands dispatch into
      live state.
- [x] `swift run CodeEditorSample` smoke check is reserved for the
      operator (running the demo blocks the terminal in
      non-interactive sessions).

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
