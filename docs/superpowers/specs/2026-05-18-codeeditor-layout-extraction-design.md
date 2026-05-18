# §6.2.11 CodeEditorLayout extraction — design

**Status:** spec for the next session.

**Position in the restructure:** the first presentation-layer extraction. With §6.2.9 LSP (`d50fc04`) and the §6.2.8 feature engines complete (modulo deferred SmartEditing §6.2.8c), Layout is the next item on NEXT.md §10's queue. After this, §6.2.12 Core split is the riskiest single step; §6.2.13 SwiftUI, §6.2.14 umbrella re-export, §6.2.15 TestSupport, and the workspace relocation finish the restructure.

**Precedents this builds on:**

- §6.2.7 `CodeEditorSyntaxHighlighting` (`f2798287`) — 36:9 carve-out; ~107 access-modifier promotions. Largest pre-commit relocation to date.
- §6.2.8a `CodeEditorFolding` (`76abf928`) — 4:4 carve-out.
- §6.2.8b `CodeEditorSymbols` (`fefe8f93`) — 2:1 carve-out + one type extracted into its own file.
- §6.2.8e `CodeEditorAnnotations` (`9ce2934a`) — 7:1 carve-out; zero access-modifier promotions; bare-word-grep lesson.
- §6.2.8g `CodeEditorCompletion` (`28b78b4f`) — clean 19:0 extraction; relocated `SendableError` to `CodeEditorCommon` and `SwiftUICompletionTypes` to the new target mid-execution.
- §6.2.9 `CodeEditorLSP` (`d50fc04`) — 22:2 carve-out; **productized + umbrella-coupled**, matching the pattern Layout will adopt.

**Why Layout is a substantial carve-out, not a clean extraction:** the `Layout/` directory mixes self-contained primitives (layout caches, fold chevrons, glass surface, insertion point, line highlight, layout providers, event bus, theming conformances) with the editor's central view chrome (`CodeEditorContainerView`, `GutterView`, `MinimapView`, `ContentView`/`EditorContentView`, `ViewportManager`). The view-chrome cluster either references `CodeEditorView` directly *or* is a partial-file extension of an umbrella-resident type — both forms force it to stay in the umbrella until §6.2.12 Core split. Result: roughly half the directory carves out, half relocates inside the umbrella.

**Why pure-only carve-out (and not `CodeEditorViewProtocol`-based decoupling):** the user opted for pure-only carve-out during brainstorming. Heavy decoupling via `CodeEditorViewProtocol` promotion blurs §6.2.11 into §6.2.12 territory, contradicting §9's "import-graph surgery, not feature work" non-goal. Re-evaluation of the carve-out residue is part of §6.2.12.

---

## 1. Goal

Extract the pure subset of the 41-file `Sources/CodeEditorPlugin/Layout/` subsystem into a new SPM target `CodeEditorLayout`. **Carve-out shape** — ~21 files move; ~20 stay in umbrella relocated to a new `Core/Layout/` semantic bucket. Productized as a `.library(name: "CodeEditorLayout", targets: ["CodeEditorLayout"])` product per NEXT.md §6.3 "Probably" listing. The umbrella `CodeEditorPlugin` target gains `CodeEditorLayout` as a direct dependency (matches §6.2.9 LSP / §6.2.10 Diagnostics precedent — productized but umbrella-coupled, not the §6.2.8d Search / §6.2.8f Workspace umbrella-decoupled opt-out pattern).

One file split is required during execution: `ThemeableUIComponent+Conformances.swift` divides into an umbrella half (GutterView conformance) and a carry-set half (LineHighlightView + InsertionPointView conformances). `EditorEventBus.swift` vs `EditorEventBusInstaller.swift` are already two separate files in the directory — no split work needed; the bus moves, the installer stays. See §2.4.

Net result: 21 originals move to the new target + 1 split-out carry-set half (22 files total in `Sources/CodeEditorLayout/`); 19 originals stay in umbrella + 1 split-out umbrella half (20 files total in `Sources/CodeEditorPlugin/Core/Layout/`); the original 41 directory entries grow to 42 source files post-split. ~10–15 umbrella files gain `import CodeEditorLayout`; sample / UI gain no new deps (sample has zero Layout-resident references per the pre-survey); plugin-tests gain `import CodeEditorLayout` on roughly 5–10 files referencing carry-set types; 20–40 access-modifier promotions on the moving set's surfaces consumed by umbrella stay-set files.

---

## 2. Scope

### 2.1 Files that move to `Sources/CodeEditorLayout/`

~21 of 41 files from `Sources/CodeEditorPlugin/Layout/` (including `Glass/`). Each satisfies: (a) zero bare `CodeEditorView` references, AND (b) not a partial-file extension of an umbrella-resident type, AND (c) not transitively required only by an umbrella stay-set file.

**Estimated carry-set** (final list confirmed by plan's Task 1 audit):

| File | Top-level type / modifier | Notes |
|---|---|---|
| `AdaptiveLayoutProvider.swift` | `public struct AdaptiveLayoutProvider` + extensions on `View` / `EnvironmentValues` | Pure SwiftUI layout adapter |
| `BaseUIComponents.swift` | reusable UI primitives | No umbrella refs |
| `CommandClickModifier.swift` | `extension View { ... }` SwiftUI modifier | |
| `CompletionCellComponents.swift` | completion popover cell views | Likely consumes `CodeEditorCompletion` types |
| `CompletionPopoverThemeMetrics.swift` | theming metrics for completion popover | Likely consumes `CodeEditorCompletion` |
| `ComponentFrameCalculator.swift` | frame math helpers | |
| `ConfigurationFormControls.swift` | config UI controls | Consumes `CodeEditorConfiguration` |
| `EditorEventBus.swift` | event bus protocol + `EnvironmentValues` extension | The *Installer* is a separate file and stays |
| `FoldChevronAnimation.swift` | chevron animation helper | Likely consumes `CodeEditorFolding` |
| `FoldChevronHitTester.swift` | chevron hit-testing | Likely consumes `CodeEditorFolding` |
| `Glass/_GlassSurface.swift` | platform-conditional frosted-glass wrapper | Internal-by-convention (leading underscore); imports `CodeEditorDesignTokens` + `CodeEditorTheming` only |
| `GutterDebugSupport.swift` | gutter debugging helpers | **Audit:** confirm no `extension GutterView` and no `GutterView` references — if either, this file stays in umbrella |
| `InsertionPointIndicating.swift` | insertion point protocol | |
| `InsertionPointView.swift` | insertion point view | |
| `LayoutCache.swift` | layout caching | |
| `LayoutCoordinator.swift` | layout coordination | Has extensions on `UIEdgeInsets` / `NSEdgeInsets` (cross-platform) |
| `LayoutOptimizer.swift` | layout optimization helpers | |
| `LineHighlightView.swift` | current-line highlight view | |
| `MinimapStyleDataSource.swift` | minimap styling data source protocol | Consumed by stay-set `MinimapView`; direction is umbrella → new target, OK |
| `ResponsiveLayoutProvider.swift` | responsive layout adapter | |
| `TextHoverModifier.swift` | hover modifier | `extension View { ... }` |

Plus the **split-out new file:**

| File | Origin | Contents |
|---|---|---|
| `ThemeableUIComponent+LayoutConformances.swift` | split from `ThemeableUIComponent+Conformances.swift` | The `extension LineHighlightView: ThemeableUIComponent {}` and `extension InsertionPointView: ThemeableUIComponent {}` lines (plus any other conformances whose target lives in the carry-set) |

**The numeric estimate (~21) is a planning ceiling.** Plan Task 1 audits each candidate against the audit rules; any file that fails (e.g. `GutterDebugSupport` extending `GutterView`, `MinimapStyleDataSource` referencing umbrella-only types) drops back to the stay-set. The shape may end up 18:23 or 22:19; the spec range is 18–22 moving.

### 2.2 Files that stay in umbrella, relocated to `Sources/CodeEditorPlugin/Core/Layout/`

~20 files where (a) the file has at least one structural `CodeEditorView` reference, OR (b) the file is a partial-file extension of an umbrella-resident type (`CodeEditorContainerView`, `GutterView`, `MinimapView`, `EditorContentView`).

**Container cluster (10 files):**

| File | Why it stays |
|---|---|
| `CodeEditorContainerView.swift` | 1 `CodeEditorView` ref; the type itself |
| `CodeEditorContainerView+AppKitExtensions.swift` | `extension CodeEditorContainerView` + `extension LineNumberRulerView`; 5 `CodeEditorView` refs |
| `CodeEditorContainerView+Configuration.swift` | `extension CodeEditorContainerView` |
| `CodeEditorContainerView+Keyboard.swift` | `extension CodeEditorContainerView` |
| `CodeEditorContainerView+Minimap.swift` | `extension CodeEditorContainerView` |
| `CodeEditorContainerView+UIKitExtensions.swift` | `extension CodeEditorContainerView: TextViewDelegateParticipant`; 5 `CodeEditorView` refs |
| `ContainerLayoutHelper.swift` | 1 `CodeEditorView` ref |
| `ContainerViewHelper.swift` | 11 `CodeEditorView` refs (highest-coupling stay file after ContentView) |
| `ContainerViewInitializer.swift` | `extension CodeEditorContainerView` |
| `ContentView.swift` | 29 `CodeEditorView` refs; `extension EditorContentView: UIGestureRecognizerDelegate` |

**Gutter cluster (5 files):**

| File | Why it stays |
|---|---|
| `GutterView.swift` | 5 `CodeEditorView` refs; type itself; defines `extension GutterView` slices |
| `GutterView+AccessibilityExtensions.swift` | `extension GutterView`; 3 `CodeEditorView` refs |
| `GutterViewModel.swift` | 2 `CodeEditorView` refs; has `extension CGRect` that travels with it |
| `GutterViewRenderer.swift` | 5 `CodeEditorView` refs |
| `GutterInteractionHandler.swift` | `extension GutterView`; 3 `CodeEditorView` refs |

**Minimap cluster (2 files):**

| File | Why it stays |
|---|---|
| `MinimapView.swift` | 3 `CodeEditorView` refs; type itself |
| `MinimapViewModel.swift` | 2 `CodeEditorView` refs; `extension MinimapViewModel` + `extension CGRect` travel with it |

**Other (3 files):**

| File | Why it stays |
|---|---|
| `EditorEventBusInstaller.swift` | 2 `CodeEditorView` refs |
| `ViewportManager.swift` | 1 `CodeEditorView` ref; `extension CodeEditorView` at line 472 |
| *(split-out)* `ThemeableUIComponent+UmbrellaConformances.swift` | The `extension GutterView: ThemeableUIComponent {}` line; stays because `GutterView` is umbrella |

The relocation is `git mv Layout/<file>.swift Core/Layout/<file>.swift` for each. The new `Core/Layout/` directory is created during the relocation; no other content is added in the pre-commit. Joins the F3 sub-bucket family (`Core/Annotations/`, `Core/Configuration/`, `Core/Documents/`, `Core/Folding/`, `Core/LSP/`, `Core/Platform/`, `Core/Search/`, `Core/Symbols/`, `Core/SyntaxHighlighting/`, `Core/Text/`).

The umbrella's `Layout/` source directory becomes empty post-extraction. Add `"Layout"` to the umbrella target's `exclude:` list (defensive — matches §6.2.7 / §6.2.9 precedent).

### 2.3 Directory layout

```
Sources/CodeEditorLayout/                    # new target root
├── AdaptiveLayoutProvider.swift
├── BaseUIComponents.swift
├── CommandClickModifier.swift
├── CompletionCellComponents.swift
├── CompletionPopoverThemeMetrics.swift
├── ComponentFrameCalculator.swift
├── ConfigurationFormControls.swift
├── EditorEventBus.swift
├── FoldChevronAnimation.swift
├── FoldChevronHitTester.swift
├── GutterDebugSupport.swift              # subject to Task 1 audit
├── Glass/
│   └── _GlassSurface.swift
├── InsertionPointIndicating.swift
├── InsertionPointView.swift
├── LayoutCache.swift
├── LayoutCoordinator.swift
├── LayoutOptimizer.swift
├── LineHighlightView.swift
├── MinimapStyleDataSource.swift
├── ResponsiveLayoutProvider.swift
├── TextHoverModifier.swift
└── ThemeableUIComponent+LayoutConformances.swift   # split-out

Sources/CodeEditorPlugin/Core/Layout/         # new umbrella bucket
├── CodeEditorContainerView.swift
├── CodeEditorContainerView+AppKitExtensions.swift
├── CodeEditorContainerView+Configuration.swift
├── CodeEditorContainerView+Keyboard.swift
├── CodeEditorContainerView+Minimap.swift
├── CodeEditorContainerView+UIKitExtensions.swift
├── ContainerLayoutHelper.swift
├── ContainerViewHelper.swift
├── ContainerViewInitializer.swift
├── ContentView.swift
├── EditorEventBusInstaller.swift
├── GutterInteractionHandler.swift
├── GutterView.swift
├── GutterView+AccessibilityExtensions.swift
├── GutterViewModel.swift
├── GutterViewRenderer.swift
├── MinimapView.swift
├── MinimapViewModel.swift
├── ThemeableUIComponent+UmbrellaConformances.swift  # split-out
└── ViewportManager.swift
```

### 2.4 File splits

**`ThemeableUIComponent+Conformances.swift` (3 conformances → split into 2 files):**

Original file at `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` contains:

```swift
extension GutterView: ThemeableUIComponent {}
extension LineHighlightView: ThemeableUIComponent {}
extension InsertionPointView: ThemeableUIComponent {}
```

Split into:

- `Sources/CodeEditorPlugin/Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift` — only the `GutterView` conformance (because `GutterView` stays in umbrella). Imports whatever the protocol's home target is.
- `Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift` — the `LineHighlightView` + `InsertionPointView` conformances (both carry-set types). Imports the protocol's home target + any other deps the conformances need. Per §6.2.8e deviation note, this file is tagged to gain `import CodeEditorAnnotations` if the conformances reach Annotation types — confirm during execution.

**Protocol location verification — required at plan Task 1:** if `ThemeableUIComponent` itself lives in umbrella (e.g. `Core/`, `Layout/`), the carry-set half of the split needs umbrella access, which is impossible. **Mitigation:** if grep shows umbrella residence, the split collapses — both halves stay in umbrella, and the `LineHighlightView`/`InsertionPointView` types travel without their protocol conformances (regression from current behavior). The implementation plan documents this contingency.

**`EditorEventBus.swift` vs `EditorEventBusInstaller.swift`:** already two separate files in the directory. `EditorEventBus.swift` (the bus protocol + `EnvironmentValues` extension) moves; `EditorEventBusInstaller.swift` (2 `CodeEditorView` refs) stays. No split work needed.

---

## 3. Target dependencies

Best estimate from the import survey + carry-set inspection. Plan Task 1 verifies exhaustively before the main commit.

**High confidence (already-present imports across the carry-set):**

| Dep | Likely required by |
|---|---|
| `CodeEditorCommon` | logging, helpers (7 Layout files already import) |
| `CodeEditorPlatform` | `PlatformColor`/`PlatformFont`/`PlatformView` (25 of 41 Layout files import this today; majority of carry-set) |
| `CodeEditorConfiguration` | `AdaptiveLayoutProvider`, `LayoutCache`, `LayoutCoordinator`, `ComponentFrameCalculator`, `ConfigurationFormControls` (14 Layout files import today) |
| `CodeEditorTheming` | theme color/token reads (7 Layout files import today) |
| `CodeEditorDesignTokens` | spacing / typography tokens (4 Layout files import today, incl. `_GlassSurface`) |
| `CodeEditorDiagnostics` | logger / instrumentation (3 Layout files import today) |

**Moderate confidence (likely needed by specific carry-set files):**

| Dep | Likely required by |
|---|---|
| `CodeEditorCompletion` | `CompletionCellComponents.swift`, `CompletionPopoverThemeMetrics.swift` (consume `CompletionItem`, `CompletionKind`) |
| `CodeEditorFolding` | `FoldChevronAnimation.swift`, `FoldChevronHitTester.swift` (likely consume `FoldStoreElement` / `FoldInfo` / `FoldRegionAdapter`) |
| `CodeEditorAnnotations` | the split-out `ThemeableUIComponent+LayoutConformances.swift` if the moved conformances reach Annotation types (§6.2.8e pre-tag) |

**Low confidence — verify with grep:**

| Dep | Possible consumer |
|---|---|
| `CodeEditorTextModel` | `LayoutCache`, `LayoutCoordinator`, `ComponentFrameCalculator`, `MinimapStyleDataSource` may consume `NSTextLocation` / `LineGeometry` / range primitives |
| `CodeEditorLanguages` | unlikely but possible if `MinimapStyleDataSource` or completion components reference language descriptors |
| `CodeEditorSyntaxHighlighting` | unlikely — SH types are concentrated in the umbrella's `Core/SyntaxHighlighting/` files which are in the stay-set's gravitational pull |

**Explicitly NOT expected:** `CodeEditorSearch`, `CodeEditorWorkspace`, `CodeEditorLSP`, `CodeEditorSymbols`.

**Total deps estimate: 7–10.** Final set confirmed during execution.

**NEXT.md §4.1 dep-claim audit:** §4.1 lists Layout deps as `TextModel, Theming, Completion, Annotations, Folding, Platform`. The actual surveyed deps are wider — add `Common, Configuration, DesignTokens, Diagnostics`. May drop `TextModel` if no carry-set file imports it. Joins the established §4.1-correction pattern (§6.2.5 Theming, §6.2.8b Symbols, §6.2.8e Annotations, §6.2.8f Workspace, §6.2.8g Completion, §6.2.9 LSP).

**Build-graph slot:** Phase 7 per §4.1 semantic label. Build-graph reality slots `CodeEditorLayout` between phase 2 (Theming) and phase 4 (Completion / Folding / Diagnostics) depending on final dep set. Semantic label "Phase 7" kept (matches §4.1) even though the build graph slots it earlier — same pattern as §6.2.8e/§6.2.8f/§6.2.8g.

---

## 4. Access-modifier promotions (anticipated)

The carve-out boundary forces `internal → package` promotions wherever stay-set umbrella files reach types or members that move to the new target.

**Likely-needed promotions (verified at compile time):**

| Symbol | Likely current | Likely after | Reason |
|---|---|---|---|
| `LayoutCache`, `LayoutCoordinator`, `LayoutOptimizer` | internal class/struct | `package` | Consumed by `GutterViewModel` / `MinimapViewModel` / `CodeEditorContainerView` (umbrella) |
| `BaseUIComponents` exports | internal | `package` | Consumed by Gutter / Minimap / Container |
| `ComponentFrameCalculator` | internal | `package` | Consumed by container / gutter |
| `EditorEventBus` (the protocol) | internal | `package` | Implemented by stay-set `EditorEventBusInstaller` |
| `MinimapStyleDataSource` (the protocol) | internal | `package` | Implemented/consumed by stay-set `MinimapView` |
| `FoldChevronAnimation`, `FoldChevronHitTester` | internal | `package` | Consumed by stay-set `GutterView` (folding chevrons render in the gutter) |
| `InsertionPointIndicating`, `InsertionPointView` | internal | `package` | Consumed by stay-set `CodeEditorContainerView` / `ContentView` |
| `LineHighlightView` | internal | `package` | Consumed by stay-set `ContentView` / `CodeEditorContainerView` |
| `CompletionCellComponents`, `CompletionPopoverThemeMetrics` | internal | `package` | Consumed by stay-set completion popover wiring |
| `AdaptiveLayoutProvider`, `ResponsiveLayoutProvider` | public/internal | possibly explicit `public init()` | §6.2.8b lesson — synthesized inits on `public` types default to internal-visibility |
| `_GlassSurface` | internal | possibly `package` | If consumed by stay-set completion popover wiring; if not consumed at all by umbrella, stays `internal` |

**Estimated total: 20–40 promotions** — well above §6.2.8e Annotations's 0 and §6.2.9 LSP's ~7, well below §6.2.7 SH's ~107. The moving set is bigger than LSP and the stay-set's bridging surface (Container/Gutter/Minimap clusters consuming many carry-set types) is wider.

**§6.2.8b synthesized-init trap watch:** any `public struct` or `public class` in the carry-set that the umbrella or sample constructs will surface a "synthesized init is internal" error and require an explicit `public init`. Likely candidates: `AdaptiveLayoutProvider`, `ResponsiveLayoutProvider`, `EditorEventBus` (if it's a struct), `MinimapStyleDataSource` (if it's a struct). Surveys at compile time.

---

## 5. Consumer ripple

### 5.1 Umbrella sources gaining `import CodeEditorLayout`

After relocation, the ~20 stay-set files in `Sources/CodeEditorPlugin/Core/Layout/` collectively consume the carry-set heavily. Estimated 10–15 umbrella files gain the import:

- **Stay-set files (Core/Layout/):** approximately half of the 20 (any file referencing a carry-set type like `LayoutCache`, `EditorEventBus`, `FoldChevronAnimation`, `_GlassSurface`, `MinimapStyleDataSource`, `BaseUIComponents`, etc.). Bare-word grep at plan time enumerates.
- **Other umbrella files** that previously reached into `Layout/`-resident types may also need the import — primarily `Core/CodeEditorView+*Extensions.swift` slices that touch layout primitives, `Core/MemoryManagementCoordinator.swift` if it wires event bus / layout types, `SwiftUI/EditorController.swift` if it exposes any layout-typed public API.

Plan Task 1 enumerates with both compound-name grep (`\bLayoutCache|\bMinimapStyleDataSource|\bEditorEventBus|\bFoldChevron|\bGlassSurface|\bInsertionPoint|\bLineHighlight|\bThemeableUIComponent|\bBaseUIComponents|\bComponentFrameCalculator|\bConfigurationFormControls|\bAdaptive|\bResponsive`) AND bare-word grep on each carry-set top-level type name (§6.2.8e lesson).

### 5.2 Sample sources

Pre-survey found **zero** Layout-resident type references in `Sources/CodeEditorSample/`. **Caveat (§6.2.8d/§6.2.8e/§6.2.8f/§6.2.9 lesson):** verify with bare-word grep at plan time. Sample may have references the compound-name grep missed (e.g. bare `Layout`, `Glass`, `Gutter` tokens).

If verified clean: `CodeEditorSample` target does NOT gain `CodeEditorLayout` as a direct dep. If grep surfaces references: add the dep alphabetically and update the §5.4 Package.swift section.

### 5.3 UI sources

`Sources/CodeEditorUI/` has zero Layout-resident references per survey. `CodeEditorUI` does NOT gain a dep. Verified at plan time.

### 5.4 Tests

**`Tests/CodeEditorPluginTests/`** — survey identified ~10–15 test files referencing carry-set types:

- `GutterView` references (7 files — but `GutterView` stays in umbrella; these tests don't need the new import)
- `MinimapView` / `MinimapViewModel` references (~4 files — same: stay-set, no new import)
- `EditorEventBus` references (~3 files — carry-set; new import needed)
- `ViewportManager` references (~2 files — stay-set; no new import)
- `FoldChevronAnimation` / `FoldChevronHitTester` references (~1 file — carry-set; new import needed)
- `ContainerViewInitializer` references (~2 files — stay-set; no new import)
- `ThemeableUIComponent` references (~1 file — split between halves; new import needed if test reaches the carry-set conformances)

Estimate: 5–10 plugin-test files gain `import CodeEditorLayout`. All retain their existing `@testable import CodeEditorPlugin` per §6.2.8d lesson (don't blanket-drop `@testable`; some internal-only umbrella helpers still require it).

**`Tests/CodeEditorSampleTests/`** — zero Layout-resident references per survey. No new dep. Verified at plan time.

**Test placement:** all test files stay in their existing target. No new `CodeEditorLayoutTests` target. Matches §6.2.7/§6.2.8a/§6.2.8b/§6.2.8d/§6.2.8e/§6.2.8f/§6.2.8g/§6.2.9 precedent. Per-target test split deferred to §6.2.15.

---

## 6. Package.swift edits

### 6.1 New product entry

```swift
.library(name: "CodeEditorLayout", targets: ["CodeEditorLayout"]),
```

Slots into the `products:` list per NEXT.md §6.3 "Probably" listing. Alphabetical order.

### 6.2 New target entry

```swift
.target(
    name: "CodeEditorLayout",
    dependencies: [
        "CodeEditorCommon",
        "CodeEditorConfiguration",
        "CodeEditorDesignTokens",
        "CodeEditorDiagnostics",
        "CodeEditorPlatform",
        "CodeEditorTheming",
        // verified-at-execution additions:
        // "CodeEditorCompletion",
        // "CodeEditorFolding",
        // "CodeEditorAnnotations",
        // "CodeEditorTextModel",
    ],
    path: "Sources/CodeEditorLayout"
),
```

Comment lines indicate deps anticipated to land but not yet verified. Plan-execution removes the comment lines and uncomments confirmed deps.

### 6.3 Umbrella `CodeEditorPlugin` target updates

- `dependencies:` gains `"CodeEditorLayout"` (preserving alphabetical order — slots before `"CodeEditorLSP"`)
- `exclude:` list grows from `["Info.plist", "Languages", "LSP", "Performance", "SyntaxHighlighting"]` to `["Info.plist", "Languages", "Layout", "LSP", "Performance", "SyntaxHighlighting"]` (defensive — the source dir is empty post-extraction). Alphabetical order: `"Layout"` slots before `"LSP"`.

### 6.4 Sample / test target updates

- `CodeEditorPluginTests` target: `dependencies:` gains `"CodeEditorLayout"` (alphabetical position: between `Languages` and `LSP`).
- `CodeEditorSample`, `CodeEditorSampleTests`, `CodeEditorUI`, `CodeEditorUITests`: no change unless plan-time grep surfaces references.

---

## 7. Execution order

Three commits, matching the §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.9 cadence:

1. **Pre-commit — relocate the stay-set + split conformance file.**
   - Create `Sources/CodeEditorPlugin/Core/Layout/`.
   - `git mv Sources/CodeEditorPlugin/Layout/<file>.swift Sources/CodeEditorPlugin/Core/Layout/<file>.swift` for each of the 19 originals in the stay-set (the split-out `ThemeableUIComponent+UmbrellaConformances.swift` lands separately as a new file via the split).
   - Split `ThemeableUIComponent+Conformances.swift` into two files:
     - new: `Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift` holding the `extension GutterView: ThemeableUIComponent {}` line.
     - the original file remains at `Layout/ThemeableUIComponent+Conformances.swift` with only `extension LineHighlightView: ThemeableUIComponent {}` + `extension InsertionPointView: ThemeableUIComponent {}` remaining. It travels in the main commit via `git mv Layout/ThemeableUIComponent+Conformances.swift Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift` (single move + rename).
   - Verify with `swift build && swift test --filter Layout && swift test --filter Gutter && swift test --filter Minimap`.
   - Commit with message describing the relocation + split only.

2. **Main commit — extract `CodeEditorLayout`.**
   - Create `Sources/CodeEditorLayout/` + `Sources/CodeEditorLayout/Glass/`.
   - Edit `Package.swift`: add product, add target, update umbrella `dependencies:` + `exclude:`, update `CodeEditorPluginTests` deps.
   - `git mv` each of the ~21 carry-set files into `Sources/CodeEditorLayout/` (preserving the `Glass/` subdir layout). Rename the split file to `ThemeableUIComponent+LayoutConformances.swift` as part of its move.
   - Apply access-modifier promotions surfaced by the build (estimated 20–40).
   - Add `import CodeEditorLayout` to umbrella + test consumers (let SwiftLint sort).
   - `swift build && swiftlint --fix && swiftlint && swift test --parallel`.
   - Commit.

3. **Docs commit — update NEXT.md.**
   - Add §6.0 deviations block (file list, target deps, promotion count, deviations encountered).
   - Update §6.2.11 status line.
   - Update §10 "Suggested next session" to drop §6.2.11 and surface §6.2.12 (Core split).
   - Update §4.1's Layout row to reflect actual deps.
   - Update §4.2 Mermaid edges to add `Common → Layout`, `Configuration → Layout`, `DesignTokens → Layout`, `Diagnostics → Layout` (and drop `TextModel → Layout` if unverified).
   - Update §3 file count (Layout/ rows split between the new target and Core/Layout/).
   - Update §6.0 status paragraph (count of targets, source file counts).
   - Separate commit per series cadence.

---

## 8. Tests

Targeted post-step verification:

```bash
swift build && \
swift test --filter Layout && \
swift test --filter Gutter && \
swift test --filter Minimap && \
swiftlint --fix && swiftlint
```

Full `swift test --parallel` is run once at the end of the main commit. Per memory `feedback_test_confirmations.md`, no full re-run after additive-only edits — trust the build and targeted filters.

Snapshot tests live in `Tests/CodeEditorPluginTests/` (`Layout/__Snapshots__`, `Theming/__Snapshots__`) and don't need to move — the test target retains them. Per-target snapshot split is §6.2.15.

---

## 9. Expected deviations

These will be confirmed and recorded in NEXT.md §6.0 at completion:

1. **§4.1 dep claim is wrong** — actual deps add `Common, Configuration, DesignTokens, Diagnostics`; may drop `TextModel` if no carry-set file imports it. Pattern established across §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9.
2. **Carry-set count likely shifts ±2 files.** Plan Task 1 audit may move `GutterDebugSupport` to the stay-set (if it extends `GutterView`), or may surface a file currently considered "stay" that's actually a clean move (e.g. if `ContainerLayoutHelper.swift`'s single `CodeEditorView` ref is a doc-comment).
3. **Test file count likely shifts.** §6.2.8e lesson: bare-word grep catches what compound-name grep misses. Plan Task 1 surveys both.
4. **Sample / UI dep changes** — pre-survey says zero, but doc-comment-only references may surface (§6.2.8e / §6.2.9 lesson). If verified clean, sample / UI gain no new deps.
5. **Access-modifier promotion count** estimated 20–40; record actual.
6. **`ThemeableUIComponent` protocol location** — if the protocol lives in umbrella, the conformance split collapses (both halves stay), losing the `LineHighlightView`/`InsertionPointView` decoupling. Documented in §10 Risk 1.
7. **`SwiftLint sorted_imports`** will reorder new imports. `CodeEditorLayout` slots between `CodeEditorLanguages` and `CodeEditorLSP` (uppercase `L` > lowercase `a`, per §6.2.9 lesson — `Languages` then `Layout` then `LSP`). Plan-written order accounts for this.
8. **Phase 7 semantic label vs build-graph reality** — build graph slots Layout earlier than phase 7. Label kept (matches §4.1) — same pattern as §6.2.8e/§6.2.8f/§6.2.8g/§6.2.9.
9. **Productized + umbrella-coupled** — Layout joins LSP and Diagnostics in this pattern. Not Workspace/Search's umbrella-decoupled opt-out pattern.
10. **Carry-set may grow during execution.** §6.2.7 SH precedent: `RangeStore` relocated to TextModel mid-extraction; §6.2.8g Completion: `SendableError` to Common, `SwiftUICompletionTypes` to the new target. Layout candidates to watch: types currently in umbrella `Core/` or other targets that only the carry-set consumes.

---

## 10. Risks

1. **`ThemeableUIComponent` protocol location.** The conformance-split plan only works if the protocol itself lives in the carry-set (or a phase ≤4 target both halves can access). If `ThemeableUIComponent` is defined in umbrella, the split fails. **Mitigation:** plan Task 1 includes a `grep -rn 'protocol ThemeableUIComponent'` audit; if it's umbrella-resident, the conformance file stays whole in umbrella and the regression is documented in §6.0.

2. **"Pure" file may consume umbrella-resident type.** The Explore survey only counted `CodeEditorView` references. A file like `GutterDebugSupport.swift` may reference `GutterView` (umbrella) without referencing `CodeEditorView`. **Mitigation:** plan Task 1 audits each candidate against the full stay-set type list (`GutterView`, `MinimapView`, `CodeEditorContainerView`, `ContentView`, `EditorContentView`, `EditorEventBusInstaller`, `ContainerViewHelper`, `ContainerViewInitializer`, `ContainerLayoutHelper`) via bare-word grep — joins the §6.2.8e lesson.

3. **Direction check for `MinimapStyleDataSource`.** Carry-set; consumed by stay-set `MinimapView`/`MinimapViewModel`. Umbrella → new target direction is fine. **Confirm:** the data source does NOT in turn reach back into `MinimapView`/`MinimapViewModel`. If it does, it must move to stay-set.

4. **Access-modifier promotion surface is larger than recent precedent.** ~20–40 promotions expected (vs §6.2.9 LSP's ~7, §6.2.8e Annotations's 0). Each `let` / `var` / method on a carry-set type accessed from the stay-set must be promoted. The §6.2.8b lesson on synthesized inits for `public` types applies — explicit `public init`s will be needed.

5. **Pre-commit relocation ordering.** 19 files relocate from `Layout/` to `Core/Layout/` + 1 split. That commit must build + test green before the main carry-set move. Easy to break test discovery if paths change inside the relocated files; **mitigation:** between relocation and commit, run `swift build && swift test --filter Layout && swift test --filter Gutter && swift test --filter Minimap`.

6. **Carve-out residue is large enough that the new target name is slightly misleading.** "CodeEditorLayout" implies the container + gutter + minimap. The new target ships layout *primitives* (cache, coordinator, providers, event bus, popover bits) without the container/gutter/minimap *types*. The umbrella's relocated `Core/Layout/` holds the high-coupling chrome. This is structurally correct (the container/gutter/minimap will move in §6.2.12) but warrants a one-line note in the new target's source comments and in `NEXT.md` §4.3 explaining what `CodeEditorLayout` does and doesn't include today.

---

## 11. Out of scope

- **No `CodeEditorViewProtocol` work.** Protocol stays exactly as-is.
- **No `CodeEditorView` refactoring.** That's §6.2.12.
- **No `CodeEditorContainerView`/`GutterView`/`MinimapView` decoupling.** Those types stay in umbrella until §6.2.12 splits Core.
- **No SmartEditing work.** §6.2.8c blocked on §6.2.12.
- **No Sample-app extraction work.** Sample stays at the umbrella level.
- **No tree-sitter / language additions.** §9 non-goal.
- **No public-API removals from the umbrella.** Per §6.2.9 LSP precedent, umbrella files that reference now-carry-set types simply gain `import CodeEditorLayout`; no `EditorController` method migrations to the sample.
- **No `@_exported import` umbrella shim.** Deferred to §6.2.14.
- **No per-target test split.** Deferred to §6.2.15.
- **No move to `~/Workspace/packages/`.** Deferred to the final restructure session.

---

## 12. Definition of done

- All ~21 moving files compile in the new `CodeEditorLayout` target.
- The ~20 stay-set files compile in their new `Core/Layout/` home with `import CodeEditorLayout` added where they consume carry-set types.
- `swift build && swiftlint --fix && swiftlint && swift test --parallel` is green.
- Umbrella public API surface unchanged (no `EditorController` / `MemoryManagementCoordinator` / `CodeEditorAPI` signature changes; the spec anticipates no public-API removals).
- `CodeEditorLayout` product is importable standalone (verified by `swift build --target CodeEditorLayout` and a brief grep for accidental umbrella imports inside the new target's sources).
- The `ThemeableUIComponent+Conformances.swift` split landed (or, per Risk 1 contingency, the no-split decision documented in §6.0).
- NEXT.md §6.0 has a deviations block recording: final file move counts, final target deps, final access-modifier promotion count, any §4.1 / §4.2 corrections, sample / test import counts, and any unexpected sub-steps that surfaced during execution.
- §6.2.11 status line in NEXT.md updated to "done — carve-out, see §6.0".
- §10 "Suggested next session" updated to surface §6.2.12 (Core split) as the next item.
