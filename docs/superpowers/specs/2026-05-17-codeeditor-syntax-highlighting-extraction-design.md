# CodeEditorSyntaxHighlighting Extraction (§6.2.7) — Design

Carve-out extraction of the pure syntax-highlighting engine from the
`CodeEditorPlugin` umbrella target into a new `CodeEditorSyntaxHighlighting`
SPM target. The nine controllers/adapters that directly reference
`CodeEditorView` stay in the umbrella, relocated to a `Core/SyntaxHighlighting/`
sub-bucket. Mirrors how Diagnostics (`e60f7857`) handled umbrella-coupled
glue files (`IOSLargeFileOptimizer`, `ViewportManager`) rather than
fighting the coupling with marker protocols.

## Goals

1. Lift the pure highlighting engine (color schemes, tokenizers, parsing
   helpers, regex / SwiftSyntax highlighters, scheme cache, descriptor
   execution, performance instrumentation) into its own SPM target so
   tokenizer or theme-mapping changes stop rebuilding the umbrella.
2. Compile-time enforce the internal layering. The nine files that depend
   on `CodeEditorView` (controllers / adapters / range applier) stay in
   the umbrella as editor-surface glue.
3. Resolve the `CodeEditorDependencies.makePlatformCapabilities()` factory
   calls in `AdaptiveColorSystem.swift` (5 sites) by inlining
   `PlatformCapabilities()` directly — same pattern Diagnostics used in
   `PerformanceInsights.swift` / `AdaptivePerformanceMode.swift`.
   `AsyncSyntaxHighlighter`'s `makeProductionPerformanceMetrics()` call
   stays untouched: that file remains in the umbrella.

## Non-goals

- Not productizing the new target. No `.library(name: "CodeEditorSyntaxHighlighting", …)`
  entry in `Package.swift`. Matches the Languages precedent (§6.2.6).
- Not refactoring the highlighter pipeline. No logic changes in
  `RegexSyntaxHighlighter`, `SwiftSyntaxHighlighter`, `BackgroundSyntaxHighlighter`,
  `AsyncSyntaxHighlighter`, or `SyntaxHighlightingCoordinator`.
- Not promoting `CodeEditorViewProtocol`. We are not introducing a
  `HighlightableTextView` protocol, generic parameter, or any other
  abstraction over `CodeEditorView`.
- Not splitting test targets. `CodeEditorPluginTests` gains
  `CodeEditorSyntaxHighlighting` as a direct dependency.
- Not renaming the package or moving to `~/Workspace/packages/`. Those
  are §6.2.14 / §6.2.16 territory.

## Target shape & dependency edges

New target at `Sources/CodeEditorSyntaxHighlighting/`. Direct dependencies
derived from the import survey across the 36 moving files:

```swift
.target(
    name: "CodeEditorSyntaxHighlighting",
    dependencies: [
        "CodeEditorCommon",
        "CodeEditorDesignTokens",
        "CodeEditorDiagnostics",
        "CodeEditorLanguages",
        "CodeEditorPlatform",
        "CodeEditorTextModel",
        "CodeEditorTheming",
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax")
    ],
    path: "Sources/CodeEditorSyntaxHighlighting",
    swiftSettings: swiftSettings
)
```

Notably **not** included (only consumed by stay-in-umbrella files):
`CodeEditorConfiguration` (only `AsyncSyntaxHighlighter`), `IssueReporting`
(only `HighlightProviderState`).

Umbrella target `Package.swift` changes:

- Drop `.product(name: "SwiftSyntax", …)` and `.product(name: "SwiftParser", …)`
  from `CodeEditorPlugin`'s `dependencies:` — those products now live on
  the new target.
- Add `"CodeEditorSyntaxHighlighting"` to `CodeEditorPlugin`'s `dependencies:`.
- Audit umbrella `exclude:` patterns. After commit 1 relocates the nine
  stay-in-umbrella files, the existing `SyntaxHighlighting` directory
  becomes empty; the new target's `path:` is a sibling source root, so
  no `exclude:` entry is needed for it.
- `CodeEditorPluginTests` gains `"CodeEditorSyntaxHighlighting"` as a
  direct dep.

Phase placement: phase 3.5, between Languages (phase 3) and the phase-4
feature engines.

## What stays unchanged

- Public umbrella API. Consumers `import CodeEditorPlugin` keep working.
- The internal `RangeHighlightProviding` protocol's surface (still takes
  `CodeEditorView`). It stays in the umbrella alongside its conformers
  (`SyntaxHighlighterRangeAdapter`, `RegexRangeHighlightProvider`).
- `CodeEditorViewProtocol`. Untouched.
- `AsyncSyntaxHighlighter`'s `CodeEditorDependencies.makeProductionPerformanceMetrics()`
  factory call. That file remains in the umbrella, so the call still has
  umbrella visibility.
- Snapshot tests, themes JSON resources, SwiftLint config.

## File inventory

### Moves to `Sources/CodeEditorSyntaxHighlighting/` (36 files)

Root (26):

- `AdaptiveColorSystem.swift` (inline 5 factory call sites)
- `BackgroundHighlightingActor.swift`
- `BackgroundHighlightingTypes.swift`
- `BackgroundSyntaxHighlighter.swift`
- `FastJSONTokenizer.swift`
- `HighlightingStrategyExecutor.swift`
- `LanguageRegistry.swift`
- `OptimizedSyntaxHighlightingCoordinator.swift`
- `RegexSyntaxHighlighter.swift`
- `RegexSyntaxHighlighter+BuilderExtensions.swift`
- `RegexSyntaxHighlighter+IntervalTreeExtensions.swift`
- `RegexSyntaxHighlighter+LanguagesExtensions.swift`
- `RegexSyntaxHighlighter+TypesExtensions.swift`
- `SmartTokenCache.swift`
- `StyleElement.swift`
- `StyledRangeContainer.swift`
- `SwiftSyntaxHighlighter.swift`
- `SwiftSyntaxHighlighter+SharedExtensions.swift`
- `SyntaxColorScheme.swift`
- `SyntaxHighlightingCoordinator.swift`
- `SyntaxHighlightingCoordinator+Extensions.swift`
- `SyntaxHighlightingPerformanceMonitor.swift`
- `SyntaxHighlightingPerformanceTracker.swift`
- `Theme+TokenColor.swift`
- `TokenName.swift`
- `ViewportSyntaxCoordinator.swift`

`Parsing/` (6):

- `LanguagePatternDetector.swift`
- `PatternExtractor.swift`
- `SyntaxTreeParser.swift`
- `TextParsingUtilities.swift`
- `TokenExtractor.swift`
- `WordBoundaryFinder.swift`

`RegexQuery/` (4):

- `HeuristicFoldProvider.swift`
- `HeuristicSymbolProviderFacade.swift`
- `QueryCaptureMap.swift`
- `RegexIncrementalRangeQueryParser.swift`

### Stays in umbrella, relocated to `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/` (9 files)

- `RangeAttributeApplier.swift` — stores `weak var textView: CodeEditorView?`
- `VisibleRangeProvider.swift` — stores `weak var textView: CodeEditorView?`
- `HighlightProviderState.swift` — stores `weak var textView: CodeEditorView?`
- `RangeBasedHighlightingController.swift` — stores `weak var textView: CodeEditorView?` + 2 more sites
- `RangeHighlightProviding.swift` — internal protocol whose method signatures take `CodeEditorView`
- `SyntaxHighlighterRangeAdapter.swift` — conforms to `RangeHighlightProviding`; takes `CodeEditorView` params
- `AsyncSyntaxHighlighter.swift` — 5 method-signature sites; also retains its `CodeEditorDependencies.makeProductionPerformanceMetrics()` call
- `StreamingHighlighter.swift` — 1 method-signature site
- `RegexQuery/RegexRangeHighlightProvider.swift` — conforms to `RangeHighlightProviding`; 5+ method-signature sites

## Three-commit sequence

Match the established cleanup-then-extract pattern (`48b9fcd5` + `e60f7857`).

**Commit 1 — "Relocate umbrella-coupled SH glue to Core/SyntaxHighlighting/."**

Pure `git mv` of the nine stay-in-umbrella files from
`Sources/CodeEditorPlugin/SyntaxHighlighting/` to
`Sources/CodeEditorPlugin/Core/SyntaxHighlighting/`. No `Package.swift`
edit. No import-statement changes (the files are still in the umbrella
target, so all their existing references resolve).

Verification: `swift build && swift test --filter SyntaxHighlighting`
green; `swiftlint` clean.

**Commit 2 — "Inline CodeEditorDependencies factory calls in AdaptiveColorSystem."**

Replace the 5 `CodeEditorDependencies.makePlatformCapabilities()` sites
in `AdaptiveColorSystem.swift` with direct `PlatformCapabilities()`
construction. Sites:

- `textBackgroundColor()` default arg (line 29)
- `selectionColor()` default arg (line 44)
- `lineNumberColor()` default arg (line 59)
- `gutterBackgroundColor()` default arg (line 74)
- `cachedSchemeFor(theme:capabilities:)` nil fallback (line 97)

Before committing, verify the `liveValue` closure for the
`platformCapabilitiesFactory` key in `CodeEditorDependencies` reduces to
`PlatformCapabilities()` — Diagnostics extraction confirmed this; reconfirm
here to be defensive.

Verification: `swift build && swift test --filter AdaptiveColorSystem`
green; `swiftlint` clean. Standalone-verifiable; bisects cleanly if a
regression appears.

**Commit 3 — "Extract CodeEditorSyntaxHighlighting target."**

1. `git mv` the 36 pure-engine files from
   `Sources/CodeEditorPlugin/SyntaxHighlighting/` (root + `Parsing/` +
   `RegexQuery/`) to `Sources/CodeEditorSyntaxHighlighting/`. Preserve
   the `Parsing/` and `RegexQuery/` subdirectory structure.
2. Delete the now-empty `Sources/CodeEditorPlugin/SyntaxHighlighting/`
   directory (the nine relocated files moved in commit 1).
3. Add the new `.target(name: "CodeEditorSyntaxHighlighting", …)` entry
   in `Package.swift` with the dep list from §3.
4. Update the `CodeEditorPlugin` umbrella target:
   - Remove `SwiftSyntax` / `SwiftParser` products from its deps.
   - Add `"CodeEditorSyntaxHighlighting"` to its deps.
   - Audit and update `exclude:` patterns if any reference the moved
     directories.
5. Update `CodeEditorPluginTests` target to add
   `"CodeEditorSyntaxHighlighting"` as a direct dep.
6. Add `import CodeEditorSyntaxHighlighting` to umbrella files and tests
   that reference the moved types. Grep baseline (taken before commit 1
   relocated the nine stay-in-umbrella files):
   - 14 umbrella `.swift` files outside `Sources/CodeEditorPlugin/SyntaxHighlighting/`
     reference moved types.
   - 18 test files reference moved types.
   - UI and Sample targets reference none.

   After commit 1 the nine files at `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/`
   (controllers, adapters, applier) also reference moved types — they
   are the original call sites for `StyledRangeContainer`,
   `HighlightedToken`, `TokenType`, and the `RangeHighlightProviding`
   conformer types. Re-grep before commit 3 to capture them; expect the
   total to land at roughly 22–23 umbrella files needing the new import.
7. Promote access modifiers as build errors surface. Most highlighter
   classes are already `public` from phase-A promotion (`8bac96cb`);
   anything left at `internal` that's hit from the umbrella side
   gets a one-step bump to `package`. Likely candidates (verify during
   execution): `SmartTokenCache`, `BackgroundHighlightingActor`,
   internal helpers on `SyntaxHighlightingCoordinator`,
   `StyledRangeContainer` mutation methods.
8. Watch for `Sendable` diagnostics under Swift 6.3 strict concurrency.
   `FoldingType: Sendable` precedent from Languages — apply the same
   conservative `Sendable` conformance to types newly crossing the
   target boundary.

Verification: `swift build && swiftlint --fix && swiftlint && swift test --parallel`
green; `swift package describe` shows the new target with the documented
file count and dep edges; `swift build --target CodeEditorSyntaxHighlighting`
builds in isolation; `./Scripts/run-sample.sh debug` launches and renders
Swift syntax-coloured text, JSON, and Python.

## Risks

1. **Hidden umbrella back-references discovered mid-extraction.** The
   grep for `CodeEditorView` references in the 36 moving files was
   exhaustive over identifier matches but won't catch usage via implicit
   re-exports. Mitigation: build after each `git mv` step in commit 3
   rather than batching the moves and the build. Time-boxed: a missed
   reference adds one targeted edit per occurrence.
2. **Strict-concurrency regressions on the new target boundary.**
   `StyledRangeContainer`, `BackgroundHighlightingActor`, `SmartTokenCache`,
   `LanguageRegistry` cross the new boundary. Types currently `internal`
   may need `Sendable` conformance as they become `package` or
   `public`-visible from umbrella. Swift 6.3 `StrictConcurrency`
   diagnostics surface every gap.
3. **Clean-build cost shifts to the new target.** Net incremental-build
   time improves (umbrella stops pulling SwiftSyntax/SwiftParser), but
   a clean `swift build` does not. Acceptable.
4. **`AdaptiveColorSystem` factory inline correctness.** The five
   `PlatformCapabilities()` replacements must match the `liveValue`
   closure exactly. Diagnostics extraction validated this; reconfirm
   by reading `CodeEditorDependencies.swift` before commit 2.
5. **Stale `exclude:` patterns in `Package.swift`.** Earlier extractions
   added `SyntaxHighlighting` to the umbrella's `exclude:` array
   defensively (it isn't there now, but check). Stale entries cause
   confusing missing-source warnings, not failures.
6. **Sample-app visual regression undetected by unit tests.** Snapshot
   tests cover most rendered surfaces, but the `liveValue` factory inline
   could shift `selectionColor` / `gutterBackgroundColor` if the closures
   differ. Add the sample-app launch step to the validation plan and
   visually spot-check.

## Open questions resolved in this spec

| Question (NEXT.md §10 / §6.0) | Resolution |
|---|---|
| Is §6.2.7 SH "near-mechanical"? | No. Nine files reference umbrella `CodeEditorView`; carve-out is required. |
| Promote `CodeEditorViewProtocol` to expose `textKitBridge` / `textEditEventHub` / `configuration` / `appliedTheme`? | No. The nine coupled files stay in the umbrella. |
| Productize the new target? | No `.library` entry. Matches Languages precedent. |
| Source-root location for the 36 moving files? | `Sources/CodeEditorSyntaxHighlighting/` (physical move, sibling root). |
| Residual home for the nine stay-in-umbrella files? | `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/` — F3 pattern (matches `Core/Configuration/`, `Core/Platform/`, `Core/Text/`). |
| Test target split? | No. `CodeEditorPluginTests` gains `CodeEditorSyntaxHighlighting` as a dep. |
| Inline `CodeEditorDependencies.make*()` factory calls? | Yes for `AdaptiveColorSystem`'s 5 sites (commit 2); `AsyncSyntaxHighlighter`'s call stays untouched (its file remains in the umbrella). |

## Validation plan

After each commit:

- `swift build` (all targets) — must be green.
- `swiftlint --fix && swiftlint` — strict mode; warnings = errors.

After commits 1 and 2 (additive-only file moves and a localized inline):

- `swift test --filter SyntaxHighlighting` (and `--filter AdaptiveColorSystem`
  for commit 2). Skip the full `--parallel` suite per the
  `feedback_test_confirmations.md` memory.

After commit 3 (the actual target extraction):

- `swift test --parallel` — full suite once.
- `swift package describe` — verify target boundaries, `path:` entries,
  and `exclude:` patterns match the spec.
- `swift build --target CodeEditorSyntaxHighlighting` — new target
  builds in isolation.
- `./Scripts/run-sample.sh debug` — launch the sample app and confirm:
  Swift highlighting renders, paste a Python file (still highlights),
  paste a JSON file (still highlights), Find/Replace overlay highlights
  matches (uses `StyledRangeContainer`), minimap shows colored runs
  (uses `MinimapStyleDataSource` → `StyledRangeContainer`).
- Update `NEXT.md` §6.0 status table and §10 to mark §6.2.7 done with
  the deviation list, mirroring the Diagnostics entry.

## Follow-up

Lands the SH boundary that unblocks:

- **§6.2.8 feature engines.** `Folding` and `Symbols` no longer have to
  share an SPM target with the SH engine to use `StyledRangeContainer`
  / `HighlightedToken` / `TokenType` — they will `import CodeEditorSyntaxHighlighting`.
- **§6.2.11 `CodeEditorLayout`.** `MinimapStyleDataSource` already
  references `StyledRangeContainer`; the Layout extraction picks up
  `CodeEditorSyntaxHighlighting` as a direct dep.
- **§6.2.12 `Core/` split.** The nine `Core/SyntaxHighlighting/` files
  travel cleanly with the eventual `CodeEditorView` target — they are
  already grouped under `Core/`.

The factory-inline pattern (`CodeEditorDependencies.make*()` → direct
init) is now applied at every leaf-target extraction boundary it has
appeared at (Diagnostics, SH). When the next extraction surfaces a new
factory site, default to inlining unless there's a concrete reason not
to.
