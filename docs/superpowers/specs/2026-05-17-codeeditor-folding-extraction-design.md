# CodeEditorFolding Extraction (§6.2.8a) — Design

Carve-out extraction of the fold-storage primitives and provider
registry from the `CodeEditorPlugin` umbrella target into a new
`CodeEditorFolding` SPM target. Four files move into the new target;
four files that directly reference `CodeEditorView` stay in the
umbrella, relocated to a new `Core/Folding/` sub-bucket. Mirrors
§6.2.7's exact pattern (36 SH files moved, 9 stayed in
`Core/SyntaxHighlighting/`).

## Goals

1. Lift the pure fold-storage primitives (`FoldStoreElement`,
   `LineFoldStorage`, `FoldInfo`), the provider-driven storage builder
   (`FoldRegionAdapter`), and the language-provider registry
   (`FoldingProviderRegistry`) into their own SPM target. Storage and
   registry changes stop rebuilding the umbrella.
2. Compile-time enforce the internal layering. The four files that
   reference `CodeEditorView` directly (`CodeFoldingEngine`,
   `FoldPresentationStrategy`, `FoldingOperationsService`,
   `CodeFoldingConfiguration`) relocate from `Features/` to
   `Core/Folding/` as an explicit "umbrella-coupled fold glue" home —
   the §6.2.7 `Core/SyntaxHighlighting/` precedent.
3. Resolve NEXT.md §10 question 2 (`CodeFoldingConfiguration` home)
   by **keeping the type in the umbrella alongside its three
   consumers** (`CodeFoldingEngine`, `FoldingOperationsService`,
   `EditorConfiguration+CodeFolding`). Earlier brainstorming chose
   the new target; that choice was based on the assumption the engine
   would move with it. With the engine staying in umbrella, moving
   the 19-line config struct down would force every consumer to add
   an import for zero benefit. Rename the misnamed
   `Features/FoldableRegion.swift` (which only holds
   `CodeFoldingConfiguration`) to
   `Core/Folding/CodeFoldingConfiguration.swift` as part of the
   relocation.

## Non-goals

- Not productizing the new target. No `.library(name: "CodeEditorFolding", …)`
  entry in `Package.swift`. Matches the Languages / SyntaxHighlighting
  precedent (§6.2.6 / §6.2.7). Folding is core to the editor; no
  consumer would opt out.
- Not refactoring the folding pipeline. No logic changes in
  `CodeFoldingEngine`, `FoldingProviderRegistry`, `FoldRegionAdapter`,
  `FoldPresentationStrategy`, `FoldingOperationsService`, or
  `LineFoldStorage`.
- Not abstracting `CodeEditorView` out of the four umbrella-coupled
  files. The engine, operations service, and presentation strategy
  take `CodeEditorView` directly; introducing a protocol to lift
  them into the new target is §6.2.12 Core-split territory, not
  this session.
- Not pulling `FoldStoreElement` / `LineFoldStorage` / `FoldInfo` into
  `CodeEditorTextModel`. They conform to `RangeStoreElement` (a
  TextModel protocol post-§6.2.7) but they are fold-specific data
  shapes that travel with the folding target. TextModel stays free of
  feature-specific storage types.
- Not splitting `Features/` directory yet. `SearchReplaceEngine.swift`,
  `SymbolNavigator.swift`, `SmartEditing/`, `Debugger*.swift`, etc.
  stay put; their extractions follow in §6.2.8b–g.
- Not splitting test targets. `CodeEditorPluginTests` gains
  `CodeEditorFolding` as a direct dependency. Per-target test split
  is deferred to §6.2.15 (`CodeEditorTestSupport`).
- Not renaming the package or moving to `~/Workspace/packages/`. Those
  are §6.2.14 / §6.2.16 territory.

## Target shape & dependency edges

New target at `Sources/CodeEditorFolding/`. Direct dependencies
derived from the import survey across the 4 moving files:

```swift
.target(
    name: "CodeEditorFolding",
    dependencies: [
        "CodeEditorCommon",
        "CodeEditorLanguages",
        "CodeEditorSyntaxHighlighting",
        "CodeEditorTextModel"
    ],
    swiftSettings: swiftSettings
)
```

Phase 4. Sits alongside the other phase-4 engine targets that will land
in §6.2.8b–g (Symbols, SmartEditing, Search, Annotations, Workspace,
Completion).

Notably **not** included (no moving file imports them):
`CodeEditorDiagnostics` (only `CodeFoldingEngine` used it; engine
stays in umbrella), `CodeEditorPlatform` (only
`CodeFoldingConfiguration` used `PlatformColors`; stays in umbrella),
`CodeEditorConfiguration`, `CodeEditorTheming`,
`CodeEditorDesignTokens`, `SwiftSyntax`/`SwiftParser`.

Umbrella target `Package.swift` changes:

- Add `"CodeEditorFolding"` to `CodeEditorPlugin`'s `dependencies:`.
- Add `"CodeEditorFolding"` to `CodeEditorPluginTests`'s `dependencies:`.
- No new `exclude:` entries needed. After `git mv` removes the 4 pure
  files from `Sources/CodeEditorPlugin/Features/` and relocates the 4
  umbrella-coupled files into `Sources/CodeEditorPlugin/Core/Folding/`,
  `Features/` shrinks; both directories remain inside the umbrella
  source root. The new target's `path:` defaults to
  `Sources/CodeEditorFolding/` — a sibling source root.
- `CodeEditorUI` and `CodeEditorSample`: dependency added only if
  Step 0 pre-flight finds direct references to one of the four
  moving types. Initial expectation is no.

## File map

### Moves into new `Sources/CodeEditorFolding/` (4 files)

All from `Sources/CodeEditorPlugin/Features/`:

| File | Owns | Imports |
|---|---|---|
| `FoldStoreElement.swift` | `FoldStoreElement` struct (`RangeStoreElement` conformer) | Languages, TextModel |
| `LineFoldStorage.swift` | `LineFoldStorage` struct + `FoldInfo` struct | Languages, TextModel |
| `FoldRegionAdapter.swift` | `FoldRegionAdapter` class (uses `CodeFoldingProvider`) | Languages, TextModel |
| `FoldingProviderRegistry.swift` | `FoldingProviderRegistry` class (seeds 14 default providers) | Common, Languages, SH |

### Relocates inside umbrella from `Features/` → `Core/Folding/` (4 files)

`CodeEditorView`-coupled glue, parallel to §6.2.7's nine SH carve-outs
landing in `Core/SyntaxHighlighting/`:

| Old path | New path | Why it stays |
|---|---|---|
| `Features/CodeFoldingEngine.swift` | `Core/Folding/CodeFoldingEngine.swift` | `attach(to: CodeEditorView)`; holds reference to umbrella view |
| `Features/FoldingOperationsService.swift` | `Core/Folding/FoldingOperationsService.swift` | ~12 `CodeEditorView` references (textKitBridge, configuration, etc.) |
| `Features/FoldPresentationStrategy.swift` | `Core/Folding/FoldPresentationStrategy.swift` | Protocol methods take `CodeEditorView`; same for `AttributeFoldPresentationStrategy` |
| `Features/FoldableRegion.swift` (renamed) | `Core/Folding/CodeFoldingConfiguration.swift` | Holds only `CodeFoldingConfiguration`; consumed only by umbrella files; rename corrects misnomer (`FoldableRegion` itself lives in Languages target since §6.2.6) |

### Stays in umbrella (unchanged path)

| File | Role |
|---|---|
| `Core/CodeFoldingCoordinatorService.swift` | `public` service facade for Layout |
| `Core/EditorRuntime.swift` | Owns engine/coordinator lifecycle |
| `Core/CodeEditorView.swift` (`codeFoldingEngine` property) | Holds the engine instance |
| `Core/CodeEditorView+SetupExtensions.swift` (`setupCodeFoldingEngine` slice) | Extends umbrella `CodeEditorView` |
| `Core/CodeEditorView+CodeFoldingExtensions.swift` | Extends umbrella `CodeEditorView` |
| `Core/CodeEditorView+ConfigurationExtensions.swift` (`updateCodeFoldingConfiguration` slice) | Extends umbrella `CodeEditorView`; calls the bridge |
| `Core/CodeEditorView+CoreExtensions.swift` | References fold state on `CodeEditorView` |
| `Core/CodeEditorView+SyntaxHighlightingExtensions.swift` | References fold state on `CodeEditorView` |
| `Core/Configuration/EditorConfiguration+CodeFolding.swift` | Bridge between `EditorConfiguration` and `CodeFoldingConfiguration`; both types umbrella-side |

### Stays in Layout (umbrella for now; moves with §6.2.11)

`Layout/FoldChevronAnimation.swift`, `Layout/GutterInteractionHandler.swift`,
`Layout/GutterViewModel.swift`, `Layout/GutterViewRenderer.swift`,
`Layout/CodeEditorContainerView+AppKitExtensions.swift`. Each gains
`import CodeEditorFolding` only if it references a moving type
(`FoldStoreElement`, `LineFoldStorage`, `FoldInfo`, `FoldRegionAdapter`,
`FoldingProviderRegistry`). Pre-flight in Step 0 confirms exact list.

### Stays in SwiftUI (umbrella for now; moves with §6.2.13)

`SwiftUI/CodeEditor+ModifiersExtensions.swift`. Gains
`import CodeEditorFolding` only if it references a moving type.

### Stays in Languages target (already there since §6.2.6)

`Languages/CodeFoldingInterfaces.swift` — `FoldableRegion` struct,
`FoldingType` enum, `CodeFoldingProvider` protocol (all `public`).
The 11 per-language `*FoldingProvider.swift` files. No change.

### Stays in SyntaxHighlighting target (since §6.2.7)

`SyntaxHighlighting/RegexQuery/HeuristicFoldProvider.swift`. Already
`package`-promoted. `FoldingProviderRegistry` keeps its
`import CodeEditorSyntaxHighlighting`.

## Access-modifier promotions

Pattern from §6.2.6 / §6.2.7: `internal` → `package` for types and
members reached across the new boundary; private helpers stay
`private`. Initial promotion surface across the 4 moving files
(build errors drive the precise list):

| Symbol | Touched from | To |
|---|---|---|
| `FoldStoreElement` (struct + init + fields + `empty` static) | umbrella (relocated `CodeFoldingEngine`, `FoldingOperationsService`), Layout, tests | `package` |
| `LineFoldStorage` (struct + methods + init + `documentLength`) | umbrella, Layout, tests | `package` |
| `FoldInfo` (struct + fields) | umbrella, Layout, tests | `package` |
| `FoldRegionAdapter` (class + init + methods) | umbrella (relocated `CodeFoldingEngine`) | `package` |
| `FoldingProviderRegistry` (class + init + methods + `registeredLanguages` var) | umbrella (relocated `CodeFoldingEngine`), tests | `package` |

Private helpers in `LineFoldStorage` (`rebuildStoreFromIndex`,
`transform`, `intersects`) stay `private`. The nested
`LineFoldStorage.StoredFold` stays `private`.

`FoldableRegion` and `FoldingType` are already `public` (Languages
target). `CodeFoldingProvider` is already `public` (Languages target).
No new promotions needed on the Languages side.

## Consumer impact (imports to add)

Discovered via grep before the move; finalized after Step 0 pre-flight:

- **Umbrella (`Sources/CodeEditorPlugin/`), files that reference one of
  the 4 moving types after relocation:**
  - `Core/Folding/CodeFoldingEngine.swift` (relocated; uses
    `FoldRegionAdapter`, `FoldingProviderRegistry`, `LineFoldStorage`)
  - `Core/Folding/FoldPresentationStrategy.swift` (relocated; uses
    `FoldInfo`)
  - `Core/Folding/FoldingOperationsService.swift` (relocated; verify;
    may not need the import if it only uses `FoldableRegion` /
    `CodeFoldingConfiguration`)
  - `Core/CodeFoldingCoordinatorService.swift` (uses
    `LineFoldStorage` / `FoldInfo` per existing umbrella grep)
  - `Core/CodeEditorView+CodeFoldingExtensions.swift`
  - `Core/CodeEditorView+CoreExtensions.swift`
  - `Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
  - `Core/CodeEditorView+ConfigurationExtensions.swift`
  - `Layout/GutterViewModel.swift`
  - `Layout/GutterViewRenderer.swift`
  - `Layout/GutterInteractionHandler.swift`
  - `Layout/FoldChevronAnimation.swift`
  - `Layout/CodeEditorContainerView+AppKitExtensions.swift`
  - `SwiftUI/CodeEditor+ModifiersExtensions.swift`

  Exact list confirmed in Step 0 with
  `grep -l "FoldStoreElement\|LineFoldStorage\|FoldInfo\|FoldRegionAdapter\|FoldingProviderRegistry"`.

- **Tests (`Tests/CodeEditorPluginTests/`):**
  - `FeatureBehaviorTests.swift` (uses `FoldingProviderRegistry`)
  - `Features/LineFoldStorageTests.swift` (uses `LineFoldStorage`)
  - `Features/FoldingProviderOutputTests.swift` (uses
    `FoldingProviderRegistry`)
  - `ComprehensivePerformanceTests.swift`,
    `Features/CodeFoldingEngineLineSpanTests.swift`,
    `Features/CodeFoldingEngineCacheEvictionTests.swift` — verify
    in Step 0; if they only touch `CodeFoldingEngine` (umbrella),
    no new import needed.

- **Sample / UI:** confirmed by Step 0 pre-flight. Expected none.

## Execution plan

Each step leaves `swift build` green except the window between Step 3
(`git mv` pure files) and Step 6 (promotion loop complete). Two
commits expected: one pre-relocation (Step 2) to keep the relocate-
versus-extract diffs separable, mirroring §6.2.7's `818df5f6` →
`f2798287` sequence.

**Step 0 — Pre-flight audit (~10 min, read-only).**

- Grep `CodeEditorSample` and `CodeEditorUI` for the 5 moving type
  names. If any hit, plan import additions.
- Verify the carry-set is exactly the 4 pure files and the relocation
  set is exactly the 4 coupled files.
- Verify `CodeEditorError.serviceUnavailable("CodeFoldingEngine")`
  identifier string stays stable.
- Capture baseline test pass count for delta comparison.

**Step 1 — Scaffold target stanza (no source moves yet).**

- Create `Sources/CodeEditorFolding/` with a placeholder file so SPM
  accepts the target.
- Add the target stanza to `Package.swift` (see §"Target shape").
- Add `"CodeEditorFolding"` to umbrella + test target `dependencies:`.
- `swift build` — should be green; the new target has only the
  placeholder, the umbrella keeps all 8 files.

**Step 2 — Pre-relocation commit: move 4 coupled files into `Core/Folding/`.**

- `mkdir -p Sources/CodeEditorPlugin/Core/Folding`
- `git mv Features/CodeFoldingEngine.swift            Core/Folding/`
- `git mv Features/FoldingOperationsService.swift     Core/Folding/`
- `git mv Features/FoldPresentationStrategy.swift     Core/Folding/`
- `git mv Features/FoldableRegion.swift               Core/Folding/CodeFoldingConfiguration.swift`
  (rename to match contents — only holds `CodeFoldingConfiguration`)
- `swift build` — should be green; all files still in the umbrella
  target, no imports change.
- Commit: `Relocate umbrella-coupled fold glue to Core/Folding/`.
  Mirrors §6.2.7's `818df5f6`.

**Step 3 — Move the 4 pure files into the new target.**

- Delete the placeholder from Step 1.
- `git mv Sources/CodeEditorPlugin/Features/FoldStoreElement.swift         Sources/CodeEditorFolding/`
- `git mv Sources/CodeEditorPlugin/Features/LineFoldStorage.swift          Sources/CodeEditorFolding/`
- `git mv Sources/CodeEditorPlugin/Features/FoldRegionAdapter.swift        Sources/CodeEditorFolding/`
- `git mv Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift  Sources/CodeEditorFolding/`
- `swift build` — now red on missing imports + visibility.

**Step 4 — Add `import CodeEditorFolding` to umbrella + test callers.**

Insert the import alphabetically. List from §"Consumer impact",
finalized from Step 0 grep.

**Step 5 — Access-modifier promotions (`internal` → `package`).**

Bulk-promote per §"Access-modifier promotions". Apply in
`Sources/CodeEditorFolding/`, not the call sites.

**Step 6 — Compile loop until green.**

`swift build 2>&1 | tail -60` → fix → repeat. Expect 1–3 rounds for
straggler access modifiers. Fewer rounds than §6.2.7 because no
`@Published` cross-target access, no Combine surface, no
SwiftSyntax product migration.

**Step 7 — Test + lint.**

```
swift test --filter LineFoldStorage
swift test --filter FoldingProviderOutput
swift test --filter CodeFoldingEngine
swift test --filter FeatureBehavior
swift test --filter ComprehensivePerformance
swift build --target CodeEditorSample
swiftlint --fix && swiftlint
```

Targeted filters honor the memory rule about not over-running the
suite after additive-only steps. Full `swift test --parallel` is not
required to declare success.

**Step 8 — Sample app smoke (manual).**

Launch via `swift run CodeEditorSample`, open a Swift source file,
fold/unfold a function via the gutter chevron, save, reopen. No
regression vs. pre-change.

**Step 9 — Docs.**

- `CLAUDE.md`:
  - Add `Sources/CodeEditorFolding/` row under "Other source roots".
  - Add note that `Core/Folding/` is a new umbrella sub-bucket
    holding `CodeEditorView`-coupled fold glue.
  - Update umbrella file count (`Features/` shrinks by 8 — 4 moved
    out, 4 relocated to `Core/Folding/`).
  - Update the `Features/` directory description (drop the folding
    bullet).
- `NEXT.md` §6.0:
  - Add row for `CodeEditorFolding` with commit SHA, what landed,
    direct deps, "extracted 4 pure files; relocated 4
    `CodeEditorView`-coupled files to `Core/Folding/`".
  - Add a "Deviations during §6.2.8a `CodeEditorFolding`" block:
    surprise that half the files were umbrella-coupled, mid-flight
    revision of `CodeFoldingConfiguration` placement, rename of
    misnamed `FoldableRegion.swift` to `CodeFoldingConfiguration.swift`.
- `NEXT.md` §6.2.8: mark Folding sub-step as `[done — carve-out]`.
- `NEXT.md` §10: mark question 2 resolved
  (`CodeFoldingConfiguration` stays in umbrella).

**Step 10 — Main extraction commit.** Subject mirrors §6.2.7 style:
`Extract CodeEditorFolding target (§6.2.8a)`. Body lists the 4 moved
files, the 4 relocated files, deps, deviations, and a one-line
pointer to the pre-relocation commit from Step 2.

## Risks & open-but-acceptable items

1. **`FoldingProviderRegistry.init()` seeds 14 concrete providers.**
   `BraceFoldingProvider()`, `IndentationFoldingProvider()`,
   `MarkdownFoldingProvider()`, `XMLFoldingProvider()`,
   `ShellFoldingProvider()`, `SQLFoldingProvider()`,
   `RubyFoldingProvider()`, `DockerfileFoldingProvider()`,
   `TomlFoldingProvider()`, `LuaFoldingProvider()` (Languages target)
   + `HeuristicFoldProvider(language:)` (SH target). All required
   inits were promoted to `package init()` in §6.2.6 / §6.2.7. Should
   just work; if not, the failing call shows the specific missing
   modifier.

2. **`Core/Folding/` adds another umbrella sub-bucket.** CLAUDE.md
   already flags `Core/Configuration/`, `Core/Documents/`,
   `Core/Platform/`, `Core/Text/`, `Core/SyntaxHighlighting/` as F3
   dumping grounds awaiting §6.2.12 Core split. `Core/Folding/`
   joins that list. Documented as expected — re-evaluated during
   §6.2.12.

3. **Rename of `FoldableRegion.swift` → `CodeFoldingConfiguration.swift`.**
   Git tracks renames automatically when content is unchanged. The
   file's contents and access modifiers remain the same; only the
   path and filename change. No test or import edits needed beyond
   the relocation itself.

4. **`LineFoldStorage.documentLength` is computed-`var` without
   modifier.** In the existing source: `var documentLength: Int { … }`
   — i.e., `internal`. After promotion to `package`, verify
   callers (Layout, CodeFoldingCoordinatorService) compile cleanly.

5. **No `CodeFoldingCoordinatorService` refactor.** Service still
   takes `CodeEditorView` directly. Same constraint as §6.2.7's
   `RangeHighlightProviding` protocol — out of scope until §6.2.12.

6. **Reduced extraction value.** Original scope was 8 files; reality
   is 4. The fold engine itself, with all its caching and provider
   orchestration, stays in umbrella. Storage primitives + provider
   registry move. This is a smaller win than §6.2.6 / §6.2.7, but
   honest given the coupling. The full Folding extraction completes
   when §6.2.12 lands.

## Verification

Definition of done:

- `swift build` green for all targets.
- `swift test --filter LineFoldStorage`,
  `--filter FoldingProviderOutput`,
  `--filter CodeFoldingEngine`,
  `--filter FeatureBehavior`,
  `--filter ComprehensivePerformance` all pass.
- `swift build --target CodeEditorSample` green.
- `swiftlint` reports zero violations (strict mode is on).
- 4 files appear under `Sources/CodeEditorFolding/`.
- 4 files appear under `Sources/CodeEditorPlugin/Core/Folding/`.
- `Features/` no longer contains any `*Fold*` files.
- `CodeEditorPlugin` and `CodeEditorPluginTests` list
  `CodeEditorFolding` in their `dependencies:`.
- `CLAUDE.md` and `NEXT.md` updated per Step 9.
- Sample-app smoke (manual): launch, open a Swift file, fold/unfold a
  region with the gutter chevron, save and reopen — no regression vs.
  pre-change.
