# CodeEditorSymbols Extraction (§6.2.8b) — Design

Carve-out extraction of the symbol-navigation types and provider
registry from the `CodeEditorPlugin` umbrella target into a new
`CodeEditorSymbols` SPM target. Two files move into the new target
(with an additional file split out for clarity); one file that
directly references `CodeEditorView` stays in the umbrella, relocated
to a new `Core/Symbols/` sub-bucket. Mirrors §6.2.8a's pattern (4 pure
files moved, 4 stayed in `Core/Folding/`) and §6.2.7 before it.

## Goals

1. Lift the pure symbol-side primitives — `BreadcrumbItem` and
   `SymbolNavigationConfiguration` (`SymbolNavigationTypes.swift`), the
   language-provider registry (`SymbolProviderCatalog`), and the
   generic interval-tree storage type (`SymbolRangeIndex<Value>`) —
   into their own SPM target. Symbol-registry and storage changes
   stop rebuilding the umbrella.
2. Compile-time enforce the internal layering. The one file that
   references `CodeEditorView` directly (`SymbolNavigator`) relocates
   from `Features/` to `Core/Symbols/` as explicit
   "umbrella-coupled symbol glue" — the §6.2.7 / §6.2.8a precedent.
3. Split `SymbolRangeIndex<Value>` into its own file
   (`SymbolRangeIndex.swift`) when it moves. It is currently bundled
   inside `SymbolProviderCatalog.swift` by historical accident — a
   generic interval-tree-shaped storage type unrelated to the
   provider catalog. Mirrors §6.2.7's mid-move extraction of
   `RangeQueryParser` from `RegexRangeHighlightProvider`.

## Non-goals

- Not productizing the new target. No `.library(name: "CodeEditorSymbols", …)`
  entry in `Package.swift`. Matches the Languages / SyntaxHighlighting /
  Folding precedent (§6.2.6 / §6.2.7 / §6.2.8a). Symbols routes
  through the umbrella.
- Not refactoring the symbol-navigation pipeline. No logic changes in
  `SymbolNavigator`, `SymbolProviderCatalog`, `SymbolRangeIndex`,
  `BreadcrumbItem`, or `SymbolNavigationConfiguration`.
- Not abstracting `CodeEditorView` out of `SymbolNavigator`. The
  navigator references five `CodeEditorView` members directly
  (`language`, `textKitBridge.documentString`, `selectedRange` (rw),
  `configuration.behavior.autoScrollToCursor`,
  `scrollRangeToVisible(_:)`); designing a text-source / selection-
  source / scroll-target protocol to lift it into the new target is
  §6.2.12 Core-split territory, not this session. Same justification
  §6.2.7 used to reject `CodeEditorViewProtocol` promotion.
- Not relocating `OptimizedFuzzyMatcher`. Used by `SymbolNavigator`
  (umbrella) only; both stay in the umbrella for this chunk. Its
  eventual home is `CodeEditorCompletion` (§6.2.8 final sub-step,
  planned last).
- Not relocating `HeuristicSymbolProviderFacade`. It lives in
  `CodeEditorSyntaxHighlighting/RegexQuery/` per §6.2.6's reasoning
  (it consumes `HighlightedToken` / `TokenType` — highlighting-side
  concepts). New target depends on SH to reach it.
- Not splitting `Features/` directory further. `SearchReplaceEngine.swift`,
  `SmartEditing/`, `Annotations/`, `Workspace/`, `Debugger*.swift`, and
  the Completion sources stay put; their extractions follow in
  §6.2.8c–g.
- Not splitting test targets. `CodeEditorPluginTests` gains
  `CodeEditorSymbols` as a direct dependency. Per-target test split
  is deferred to §6.2.15 (`CodeEditorTestSupport`).
- Not renaming the package or moving to `~/Workspace/packages/`.
  §6.2.14 / §6.2.16 territory.

## Target shape & dependency edges

New target at `Sources/CodeEditorSymbols/`. Direct dependencies
derived from the import survey across the 2 moving files:

```swift
.target(
    name: "CodeEditorSymbols",
    dependencies: [
        "CodeEditorLanguages",
        "CodeEditorSyntaxHighlighting"
    ],
    swiftSettings: swiftSettings
)
```

Phase 4. Sits alongside the other phase-4 engine targets — Folding
already landed, the rest follow in §6.2.8c–g.

Notably **not** included (no moving file imports them):
`CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`,
`CodeEditorConfiguration`, `CodeEditorTheming`,
`CodeEditorDesignTokens`, `CodeEditorDiagnostics`,
`SwiftSyntax`/`SwiftParser`. Tighter than §6.2.8a Folding's
`Common, Languages, SH, TextModel` — Symbols' moving surface is
narrower.

Umbrella target `Package.swift` changes:

- Add `"CodeEditorSymbols"` to `CodeEditorPlugin`'s `dependencies:`.
- Add `"CodeEditorSymbols"` to `CodeEditorPluginTests`'s `dependencies:`.
- No new `exclude:` entries needed. After `git mv` removes the 2
  pure files from `Sources/CodeEditorPlugin/Features/` and relocates
  `SymbolNavigator.swift` into `Sources/CodeEditorPlugin/Core/Symbols/`,
  `Features/` shrinks; both directories remain inside the umbrella
  source root. The new target's `path:` defaults to
  `Sources/CodeEditorSymbols/` — a sibling source root.
- `CodeEditorUI` and `CodeEditorSample`: dependency added only if
  Step 0 pre-flight finds direct references to one of the moving
  types. Pre-survey expectation: no.

## File map

### Moves into new `Sources/CodeEditorSymbols/` (3 files — 2 from `Features/` + 1 split-out)

| File | Origin | Owns | Imports |
|---|---|---|---|
| `SymbolNavigationTypes.swift` | `Features/SymbolNavigationTypes.swift` | `BreadcrumbItem` struct, `SymbolNavigationConfiguration` struct | Languages, Foundation |
| `SymbolProviderCatalog.swift` | `Features/SymbolProviderCatalog.swift` (minus the trailing `SymbolRangeIndex`) | `SymbolProviderCatalog` struct + private `EmptySymbolProvider` | Languages, SH, Foundation |
| `SymbolRangeIndex.swift` | newly extracted from `SymbolProviderCatalog.swift` lines 66-127 | `SymbolRangeIndex<Value>` class + private `Node` class | Foundation |

### Relocates inside umbrella from `Features/` → `Core/Symbols/` (1 file)

`CodeEditorView`-coupled glue, parallel to §6.2.8a's four Folding
relocations and §6.2.7's nine SH relocations:

| Old path | New path | Why it stays |
|---|---|---|
| `Features/SymbolNavigator.swift` | `Core/Symbols/SymbolNavigator.swift` | `weak var textView: CodeEditorView?` (line 21), `attach(to: CodeEditorView)` (line 41), 5 distinct member accesses on `CodeEditorView` (lines 81, 86, 204, 207, 208, 267) |

### Stays in umbrella (unchanged path)

| File | Role |
|---|---|
| `SwiftUI/EditorController.swift` | Owns the `SymbolNavigator` instance via `lazy var symbolNavigator = SymbolNavigator()` (line 59). No new import — uses only `SymbolNavigator`, which stays in umbrella. |
| `Completion/OptimizedFuzzyMatcher.swift` | Used by `SymbolNavigator.searchSymbols(query:)`. Stays in umbrella. Both files in same target after relocation. |

### Stays in Languages target (already there since §6.2.6)

`DocumentSymbol`, `DocumentSymbolProvider` protocol, `DocumentSymbolKind`,
the 15 per-language `*SymbolProvider.swift` files (Swift, JavaScript,
CStyle, Python, Markdown, HTML, CSS, JSON, YAML, XML, SQL, Ruby, PHP,
Shell). All `package`-promoted in §6.2.6. No change.

### Stays in SyntaxHighlighting target (since §6.2.7)

`SyntaxHighlighting/RegexQuery/HeuristicSymbolProviderFacade.swift`.
Already `package`-promoted. `SymbolProviderCatalog` keeps its
`import CodeEditorSyntaxHighlighting`.

## Access-modifier promotions

Pattern from §6.2.6 / §6.2.7 / §6.2.8a: `internal` → `package` for
types and members reached across the new boundary; private helpers
stay `private`. Initial promotion surface — exactly five symbols
in the new `SymbolRangeIndex.swift`:

| Symbol | Touched from | To |
|---|---|---|
| `SymbolRangeIndex<Value>` (`final class`) | umbrella (relocated `SymbolNavigator`) | `package final class` |
| `SymbolRangeIndex.init()` (synthesised) | umbrella | `package init()` |
| `SymbolRangeIndex.insert(range:value:)` | umbrella | `package func` |
| `SymbolRangeIndex.findContaining(location:)` | umbrella | `package func` |
| `SymbolRangeIndex.removeAll()` | umbrella | `package func` |

Private nested `Node` class stays `private`. Private helpers
(`insert(range:value:into:)`, `findContaining(location:in:results:)`)
stay `private`.

`SymbolProviderCatalog`, `BreadcrumbItem`, `SymbolNavigationConfiguration`,
and `EmptySymbolProvider` need no promotion — already `public` or
already correctly scoped (`EmptySymbolProvider` is private).

`DocumentSymbol`, `DocumentSymbolProvider`, `DocumentSymbolKind`,
`Language` are already `public` on the Languages side.
`HeuristicSymbolProviderFacade` is already `package` on the SH side
(§6.2.6 / §6.2.7). No new promotions outside the new target.

Far smaller than §6.2.7's ~107 promotions; on par with §6.2.8a's ~5.

## Consumer impact (imports to add)

Discovered via grep before the move; finalized after Step 0
pre-flight:

- **Umbrella (`Sources/CodeEditorPlugin/`), files that reference one
  of the moving types after relocation:**
  - `Core/Symbols/SymbolNavigator.swift` (relocated) — references
    `SymbolRangeIndex<DocumentSymbol>` (line 28) and
    `SymbolProviderCatalog` (init signature line 36). Gains
    `import CodeEditorSymbols`.
  - `SwiftUI/EditorController.swift` — uses only `SymbolNavigator`
    (stays in umbrella). **No new import.**

- **Tests (`Tests/CodeEditorPluginTests/`):**
  - `FeatureBehaviorTests.swift` — uses `SymbolProviderCatalog.default`
    (line 375) and `SymbolProviderCatalog()` (line 387). Gains
    `import CodeEditorSymbols`.
  - `PerformanceRegressionTests.swift`,
    `ComprehensivePerformanceTests.swift` — use only `SymbolNavigator()`
    (umbrella). **No new import.**
  - `ReviewRemediationRegressionTests.swift` — references
    `"Optimized" + "SymbolNavigator"` as a literal string only.
    **No new import.**

- **Sample / UI / SampleTests:** confirmed by Step 0 pre-flight.
  Pre-survey expectation: no references; no new dependency edges.

Net ripple: **one umbrella import + one test import**. Smaller than
§6.2.8a Folding's (2 umbrella + 2 tests). Smaller than §6.2.7 SH's
(~19 umbrella + 18 tests).

## Execution plan

Each step leaves `swift build` green except the window between
Step 3 (`git mv` pure files) and Step 6 (promotion loop complete).
Two commits expected: one pre-relocation (Step 2) to keep the
relocate-versus-extract diffs separable, mirroring §6.2.8a's
`9704e80b` → `76abf928` sequence.

**Step 0 — Pre-flight audit (~5 min, read-only).**

- Grep `CodeEditorSample`, `CodeEditorUI`, and
  `Tests/CodeEditorSampleTests` for `SymbolNavigationConfiguration`,
  `BreadcrumbItem`, `SymbolProviderCatalog`, `SymbolRangeIndex`.
  If any hit, add to the import list. (Pre-survey expectation: none.)
- Confirm `Features/SymbolNavigator.swift`, `Features/SymbolProviderCatalog.swift`,
  and `Features/SymbolNavigationTypes.swift` are still the only
  symbol-side files at `Sources/CodeEditorPlugin/Features/` top
  level. (Survey timestamp: 2026-05-18.)
- Verify the umbrella `exclude:` list contents at time of execution,
  and decide whether any defensive entry is warranted (initial
  expectation: none — the new source root is a sibling).
- Capture baseline test pass count for delta comparison.

**Step 1 — Scaffold target stanza (no source moves yet).**

- Create `Sources/CodeEditorSymbols/` with a placeholder file so SPM
  accepts the target (e.g., a `Placeholder.swift` with an empty
  `internal enum`).
- Add the target stanza to `Package.swift` (see §"Target shape").
- Add `"CodeEditorSymbols"` to umbrella + test target
  `dependencies:`.
- `swift build` — should be green; the new target has only the
  placeholder, the umbrella keeps all 3 Symbols files.

**Step 2 — Pre-relocation commit: move `SymbolNavigator` into `Core/Symbols/`.**

- `mkdir -p Sources/CodeEditorPlugin/Core/Symbols`
- `git mv Sources/CodeEditorPlugin/Features/SymbolNavigator.swift \
         Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift`
- `swift build` — should be green; the file stays in the umbrella
  target, no imports change.
- Commit: `Relocate umbrella-coupled SymbolNavigator to Core/Symbols/`.
  Mirrors §6.2.8a's `9704e80b`.

**Step 3 — Split `SymbolRangeIndex` into its own file.**

- Create `Sources/CodeEditorPlugin/Features/SymbolRangeIndex.swift`
  (still in `Features/` at this moment — moves in Step 4) containing
  lines 66-127 of the existing `SymbolProviderCatalog.swift`:
  - `final class SymbolRangeIndex<Value>` class definition
  - Private nested `Node` class
  - Top-level `import Foundation` line
- Trim those lines from `Features/SymbolProviderCatalog.swift`.
- `swift build` — should be green; both files inside the umbrella;
  no imports change since `SymbolNavigator.swift` (the only consumer
  of `SymbolRangeIndex`) is also still inside the umbrella.
- (No commit yet — combines with Step 4 into the main extraction
  commit.)

**Step 4 — Move the 3 pure files into the new target.**

- Delete the placeholder from Step 1.
- `git mv Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift  Sources/CodeEditorSymbols/`
- `git mv Sources/CodeEditorPlugin/Features/SymbolProviderCatalog.swift  Sources/CodeEditorSymbols/`
- `git mv Sources/CodeEditorPlugin/Features/SymbolRangeIndex.swift       Sources/CodeEditorSymbols/`
- `swift build` — now red on missing imports + visibility.

**Step 5 — Add `import CodeEditorSymbols` to umbrella + test callers.**

Insert the import alphabetically:

- `Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift`
- `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

(List from §"Consumer impact", finalized from Step 0 grep.)

**Step 6 — Access-modifier promotions (`internal` → `package`).**

Apply the 5 promotions to `Sources/CodeEditorSymbols/SymbolRangeIndex.swift`
per §"Access-modifier promotions". Apply in the new target source,
not the call site. Use explicit `package` modifier (not relying on
default `internal`).

**Step 7 — Compile loop until green.**

`swift build 2>&1 | tail -60` → fix → repeat. Expect 1 round at most
given the tiny promotion surface. Smaller than §6.2.8a's typical
1–3 rounds.

**Step 8 — Test + lint.**

```
swift test --filter FeatureBehavior
swift test --filter SymbolNavigator
swift test --filter ComprehensivePerformance
swift test --filter PerformanceRegression
swift test --filter ReviewRemediationRegression
swift build --target CodeEditorSample
swiftlint --fix && swiftlint
```

Targeted filters honor the memory rule about not over-running the
suite after additive-only steps. Full `swift test --parallel` is not
required to declare success.

**Step 9 — Sample app smoke (manual).**

Launch via `swift run CodeEditorSample`, open a Swift source file,
open the symbol navigator / breadcrumb UI (if exposed by the sample),
confirm symbol list populates and breadcrumb tracks cursor. No
regression vs. pre-change.

**Step 10 — Docs.**

- `CLAUDE.md`:
  - Add `Sources/CodeEditorSymbols/` row under "Other source roots":
    `Sources/CodeEditorSymbols/` — symbol navigation surface:
    `BreadcrumbItem`, `SymbolNavigationConfiguration`,
    `SymbolProviderCatalog`, and generic `SymbolRangeIndex` storage
    (phase 4; new in §6.2.8b). The umbrella-coupled `SymbolNavigator`
    lives in `Sources/CodeEditorPlugin/Core/Symbols/`.
  - Add `Core/Symbols/` to the existing list of umbrella F3 sub-buckets
    in the source-tree comment (alongside `Core/Folding/`,
    `Core/Configuration/`, etc.).
  - Update umbrella file count. `Features/` shrinks by 3 (Types,
    Catalog, Navigator all leave); the umbrella *target* shrinks by
    2 (Types and Catalog leave the umbrella; Navigator stays in the
    umbrella under `Core/Symbols/`). Verify the exact pre/post
    counts during execution.
- `NEXT.md` §6.0:
  - Add row for `CodeEditorSymbols` with commit SHA, what landed,
    direct deps, "extracted 2 pure files + 1 split-out; relocated
    1 `CodeEditorView`-coupled file to `Core/Symbols/`".
  - Add a "Deviations during §6.2.8b `CodeEditorSymbols`" block:
    carve-out (1 of 3 files umbrella-coupled, matching §6.2.8a /
    §6.2.7 precedent); `SymbolRangeIndex` extracted to its own
    file (matching §6.2.7's `RangeQueryParser` extraction); tighter
    target deps than the plan implied (no `Common`, no `TextModel`);
    ~5 promotions (smaller than §6.2.7's ~107, on par with §6.2.8a's ~5);
    no productization; `FeatureBehaviorTests` is the only test
    file gaining the import.
- `NEXT.md` §6.2.8 line item: add a sub-bullet under §6.2.8a:
  `- **[done — carve-out, see §6.0]** **`CodeEditorSymbols`** (§6.2.8b)
  — 3 files moved to `Sources/CodeEditorSymbols/` (2 from `Features/`
  + 1 split-out `SymbolRangeIndex.swift`); 1 `CodeEditorView`-coupled
  file (`SymbolNavigator`) relocated to `Core/Symbols/`. Final deps:
  Languages, SyntaxHighlighting. (`<sha>` + pre-relocation `<sha>`)`
- `NEXT.md` §10: strike Symbols from the "Suggested next session"
  bullet for §6.2.8. The next engine in order is SmartEditing.

**Step 11 — Main extraction commit.** Subject mirrors §6.2.7 / §6.2.8a
style: `Extract CodeEditorSymbols target (§6.2.8b)`. Body lists the
3 moved files (noting `SymbolRangeIndex.swift` as a split-out from
`SymbolProviderCatalog.swift`), the 1 relocated file, deps,
deviations, and a one-line pointer to the pre-relocation commit
from Step 2.

## Risks & open-but-acceptable items

1. **`SymbolProviderCatalog.default` seeds 18 concrete providers**
   (`SwiftSymbolProvider`, `JavaScriptSymbolProvider`,
   `CStyleSymbolProvider` for 8 languages, `PythonSymbolProvider`,
   `MarkdownSymbolProvider`, `HTMLSymbolProvider`, `CSSSymbolProvider`,
   `JSONSymbolProvider`, `YAMLSymbolProvider`, `XMLSymbolProvider`,
   `SQLSymbolProvider`, `RubySymbolProvider`, `PHPSymbolProvider`,
   `ShellSymbolProvider` from Languages target;
   `HeuristicSymbolProviderFacade(language:)` from SH target for
   dockerfile/toml/lua; plus private `EmptySymbolProvider` for
   plainText). All required inits were promoted to `package init()`
   in §6.2.6 / §6.2.7. Should just work; if not, the failing call
   shows the specific missing modifier.

2. **`Core/Symbols/` adds another umbrella sub-bucket.** CLAUDE.md
   already flags `Core/Configuration/`, `Core/Documents/`,
   `Core/Folding/`, `Core/Platform/`, `Core/Text/`,
   `Core/SyntaxHighlighting/` as F3 dumping grounds awaiting
   §6.2.12 Core split. `Core/Symbols/` joins that list. Documented
   as expected — re-evaluated during §6.2.12.

3. **`SymbolNavigator` still references `CodeEditorView` directly.**
   Same constraint as §6.2.7's `RangeHighlightProviding` protocol
   and §6.2.8a's `CodeFoldingEngine` — out of scope until §6.2.12.

4. **`SymbolRangeIndex` file split during the same chunk.** Two
   precedents:
   - §6.2.7 extracted `RangeQueryParser` from
     `RegexRangeHighlightProvider.swift` mid-move because the conformer
     and its dependents lived in different targets.
   - §6.2.8a renamed `FoldableRegion.swift` →
     `CodeFoldingConfiguration.swift` mid-move to correct a
     filename/contents mismatch.
   Splitting `SymbolRangeIndex` follows the same precedent: a
   generic data structure bundled with an unrelated topic should
   stand alone. The file rename / extraction does not change the
   type's content or access semantics (until Step 6's promotions).

5. **Reduced extraction value.** Original §4.1 scope was 3 files,
   reality is 2 files moved + 1 file relocated. The navigator
   itself, with all its caching and `@Published` machinery, stays
   in umbrella. Types, configuration, registry, and storage move.
   Smaller than §6.2.6 / §6.2.7 wins, on par with §6.2.8a. The full
   Symbols extraction completes when §6.2.12 lands.

6. **No new test target.** `CodeEditorSymbols` ships without a
   `Tests/CodeEditorSymbolsTests/` peer. Per-target test split is
   §6.2.15 (`CodeEditorTestSupport`) territory; `FeatureBehaviorTests`
   in `CodeEditorPluginTests` exercises the moving surface today.

## Verification

Definition of done:

- `swift build` green for all targets in `Package.swift` (the new `CodeEditorSymbols` plus every existing library / executable / test target).
- `swift test --filter FeatureBehavior` passes (includes
  `testSymbolProviderCatalogCoversEveryLanguage`,
  `testSymbolNavigatorCachesPreserveSearchBreadcrumbAndLookupBehavior`).
- `swift test --filter SymbolNavigator` passes (the 3 perf tests +
  1 behavior test that touch the relocated file).
- `swift test --filter ComprehensivePerformance`,
  `--filter PerformanceRegression`,
  `--filter ReviewRemediationRegression` all pass.
- `swift build --target CodeEditorSample` green.
- `swiftlint` reports zero violations (strict mode is on).
- 3 files appear under `Sources/CodeEditorSymbols/`:
  `SymbolNavigationTypes.swift`, `SymbolProviderCatalog.swift`,
  `SymbolRangeIndex.swift`.
- 1 file appears under `Sources/CodeEditorPlugin/Core/Symbols/`:
  `SymbolNavigator.swift`.
- `Features/` no longer contains `SymbolNavigationTypes.swift`,
  `SymbolProviderCatalog.swift`, `SymbolNavigator.swift`, or any
  `Symbol*` files.
- `CodeEditorPlugin` and `CodeEditorPluginTests` list
  `CodeEditorSymbols` in their `dependencies:`.
- `CLAUDE.md` and `NEXT.md` updated per Step 10.
- Sample-app smoke (manual): launch, open a Swift source file,
  confirm symbol navigation / breadcrumb path (if exposed by the
  sample) populates and tracks cursor — no regression vs. pre-change.
