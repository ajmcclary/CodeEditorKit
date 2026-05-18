# §6.2.8e CodeEditorAnnotations extraction — design

**Status:** spec for the next session.

**Position in the restructure:** continues §6.2.8 feature-engine extractions. Per NEXT.md §10, remaining feature engines are `Annotations` and `Completion` (with `SmartEditing` deferred to §6.2.12). This spec covers `Annotations` only; `Completion` is sequenced last per §6.2.8's "Completion last (most call sites)" guidance.

**Precedents this builds on:**

- §6.2.7 `CodeEditorSyntaxHighlighting` (`f2798287`) — first carve-out (36 moved, 9 stayed).
- §6.2.8a `CodeEditorFolding` (`76abf928`) — second carve-out (4 moved, 4 stayed).
- §6.2.8b `CodeEditorSymbols` (`fefe8f93`) — third carve-out (2/3 moved, 1 stayed; +1 split-out file).
- §6.2.8d `CodeEditorSearch` (`18f9d43a`) — fourth carve-out (1 moved, 1 stayed in umbrella, 1 migrated to sample; first cross-restructure public-API removal).
- §6.2.8f `CodeEditorWorkspace` (`c1739137`) — clean extraction, productized opt-in.

---

## 1. Goal

Extract pure annotation primitives (data model, view chrome, kind enum) from `Sources/CodeEditorPlugin/Annotations/` into a new SPM target `CodeEditorAnnotations`. Leave `AnnotationsDataSource` in the umbrella (relocated to `Core/Annotations/`) because its `textView(_:viewForLineAnnotation:textLineFragment:proposedViewFrame:)` method takes `CodeEditorView` as a parameter on the public protocol surface — the same umbrella-coupling shape SH/Folding/Symbols/Search ran into.

Net result: 7 files move to the new target; 1 file relocates inside the umbrella. Zero access-modifier promotions expected (every moving top-level type is already `public` with an explicit `public init`). Zero public-API breaking changes.

---

## 2. Scope

### 2.1 Files that move to `Sources/CodeEditorAnnotations/`

| File | Lines | Why it moves |
|---|---|---|
| `Annotation.swift` | 108 | Pure value type (`public struct Annotation: Sendable`). Imports `CodeEditorCommon` + Foundation. Only `CodeEditorView` reference is in a `@SeeAlso` doc comment. |
| `AnnotationKind.swift` | 87 | Pure enum (`public enum AnnotationKind`). Imports `CodeEditorPlatform` + `CodeEditorTheming`. Theme-aware `color(in:)` accessor. |
| `AnnotationView.swift` | 601 | Public view chrome (`public class AnnotationView: PlatformView`). Imports `CodeEditorPlatform` + `CodeEditorTheming`. AppKit/UIKit conditional. No `CodeEditorView` reference (verified by grep). |
| `AnnotationsContentView.swift` | 162 | Public view chrome (`public class AnnotationsContentView: PlatformView`). Imports `CodeEditorPlatform` + `CodeEditorTheming`. No `CodeEditorView` reference. |
| `CodeEditorViewAnnotation.swift` | 61 | Plain struct (`public struct CodeEditorViewAnnotation`). Imports `CodeEditorCommon`. Despite the file name, no `CodeEditorView` reference — it's the "what gets passed to the data source" value type. |
| `LineAnnotation.swift` | 18 | Trivial protocol with `id: String` and `location: any NSTextLocation`. |
| `MessageLineAnnotation.swift` | 31 | Small struct + nested enum. Used by LSP diagnostics bridging. |

**Total moving: 7 files, ~1,068 lines.**

### 2.2 File that stays in the umbrella (relocated to `Core/Annotations/`)

| File | Lines | Why it stays |
|---|---|---|
| `AnnotationsDataSource.swift` | 120 | `public protocol AnnotationsDataSource` whose required method `textView(_ textView: CodeEditorView, viewForLineAnnotation:...)` takes `CodeEditorView` as a parameter (line 115). Carving it out would force `CodeEditorView` (or the `package`-scoped `CodeEditorViewProtocol`) to either move down or be made public — both larger changes than this session's scope. |

**Carve-out ratio:** 7 moved, 1 stayed. Worst moved-to-stayed ratio in the series so far (SH was 36:9, Folding 4:4, Symbols 2/3:1, Search 1:1, Workspace 2:0 clean). Not a problem — just an unusual shape for the series. Worth noting because future readers comparing across sessions will see Annotations as the most-extracted single carve-out.

### 2.3 Dependency edges for the new target

```
CodeEditorAnnotations → CodeEditorCommon
CodeEditorAnnotations → CodeEditorPlatform
CodeEditorAnnotations → CodeEditorTheming
```

**Correction to NEXT.md §4.1.** The original phase table claimed `Annotations → TextModel`. Grep across all 7 moving files shows zero `CodeEditorTextModel` imports; `NSRange` and `NSTextLocation` come from Foundation. This correction joins:

- §6.2.5 Theming's "Theming has no Platform dep" correction.
- §6.2.8b Symbols's "deps narrower than the plan implied — Languages, SyntaxHighlighting only" correction.
- §6.2.8f Workspace's "actual deps are none (Foundation only)" correction.

Pattern is now established: NEXT.md §4.1's dep claims are speculative until grep proves them.

### 2.4 Productization

**No `.library(name: "CodeEditorAnnotations", ...)` product entry.** The umbrella `CodeEditorPlugin` target depends on the new target — `Core/CodeEditorView+AnnotationsExtensions.swift`, `Core/CodeEditorView+LayoutExtensions.swift`, and `Layout/ThemeableUIComponent+Conformances.swift` all consume `Annotation` / `AnnotationView` / `AnnotationsContentView`. Matches Folding / Symbols / SH / Languages precedent (umbrella-consumed → routes through umbrella). Does not match Workspace / Search / Diagnostics (umbrella-independent → opt-in `.library`).

If a future refactor lifts the `AnnotationsExtensions` slice out of the umbrella into its own target, Annotations could become opt-in. That's a follow-up; not part of this session.

---

## 3. Execution shape

Two commits, matching §6.2.8a / §6.2.8b / §6.2.8d.

### 3.1 Pre-commit A — relocate the umbrella-coupled file

```
git mv Sources/CodeEditorPlugin/Annotations/AnnotationsDataSource.swift \
       Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift
```

Creates the `Core/Annotations/` semantic bucket (precedent: `Core/Folding/`, `Core/Symbols/`, `Core/Search/`). Builds remain green; the file is still in the umbrella target.

### 3.2 Commit B — extract `CodeEditorAnnotations`

1. **Create** `Sources/CodeEditorAnnotations/` with a `.gitkeep` and a `_ScaffoldPlaceholder.swift` (one-line `// Placeholder` file). Both deleted at the end of this commit. Rationale: SwiftPM resolves the package during the in-between state and needs at least one `.swift` file; §6.2.8f's plan author documented this lesson.
2. **Add the target to `Package.swift`:**
   ```swift
   .target(
       name: "CodeEditorAnnotations",
       dependencies: [
           "CodeEditorCommon",
           "CodeEditorPlatform",
           "CodeEditorTheming",
       ],
       path: "Sources/CodeEditorAnnotations"
   ),
   ```
   No `.library` product entry. Add `CodeEditorAnnotations` as a dependency of: umbrella `CodeEditorPlugin`, `CodeEditorSample`, `CodeEditorPluginTests`. (UI / UITests / DesignTokensTests / SampleTests don't reference Annotation types — verified.)
3. **`git mv`** the 7 files from `Sources/CodeEditorPlugin/Annotations/` to `Sources/CodeEditorAnnotations/`.
4. **Delete** `_ScaffoldPlaceholder.swift` and `.gitkeep` from the new target.
5. **Expand the umbrella's `exclude:` list** in `Package.swift` with `"Annotations"` (defensive — the source dir is empty post-extraction, but the precedent is set by §6.2.7 SH).
6. **Add `import CodeEditorAnnotations`** to consumers — see §4.
7. **`swift build && swiftlint --fix && swiftlint`** must pass.
8. **`swift test --filter AnnotationTests && swift test --filter AnnotationThemeTests`** for targeted verification. Per the memory rule, skip the full `swift test --parallel` after this additive-only change.

### 3.3 Expected access-modifier promotions

**Approximately zero.** Pre-flight grep confirmed every top-level type in the moving set is already `public` with an explicit `public init`:

- `Annotation` — explicit `public init(...)` (two overloads, lines 72 and 92).
- `AnnotationKind` — public enum with `public init(from messageKind:)` and `public static func infer(from:)`.
- `AnnotationView` — explicit `public init(annotation:frame:)` and `public required init?(coder:)`.
- `AnnotationsContentView` — explicit `public init(frame frameRect:)` and `public required init?(coder:)`.
- `CodeEditorViewAnnotation` — two explicit `public init(...)` overloads (lines 30 and 48).
- `LineAnnotation` — public protocol with public-by-default requirements.
- `MessageLineAnnotation` — explicit `public init(id:message:kind:location:)`.

This ties §6.2.8f Workspace (zero promotions) and §6.2.8d Search (zero promotions) for the smallest promotion surface in the series. Far smaller than §6.2.7 SH (~107) or §6.2.8b Symbols (7).

---

## 4. Consumer ripple

Pre-flight grep across `Sources/` and `Tests/` for the moving types identified **14 files** that gain `import CodeEditorAnnotations` — 4 umbrella (including the relocated `AnnotationsDataSource.swift`), 4 sample, 6 tests.

### 4.1 Umbrella (4 files)

- `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift` *(post-relocation)* — references `Annotation`, `CodeEditorViewAnnotation`, `PlatformView` (last via existing `import CodeEditorPlatform`).
- `Sources/CodeEditorPlugin/Core/CodeEditorView+AnnotationsExtensions.swift` — the layout-time call site that invokes `dataSource.textView(self, viewForLineAnnotation:...)`. References `Annotation`, `CodeEditorViewAnnotation`, `AnnotationView`.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift` — references `AnnotationsContentView` for layout-time positioning.
- `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` — declares `AnnotationView` and `AnnotationsContentView` as `ThemeableUIComponent` conformers. When §6.2.11 extracts `CodeEditorLayout`, this file migrates with it; the `CodeEditorLayout` target will then gain the `CodeEditorAnnotations` direct dep (matches NEXT.md §4.2's `Annotations --> Layout` edge).

`Sources/CodeEditorPlugin/Core/CodeEditorView.swift:466` declares `public weak var annotationsDataSource: AnnotationsDataSource?` — `AnnotationsDataSource` is in the same umbrella target (it stayed), so no new import needed here.

### 4.2 Sample (4 files)

- `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`
- `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`
- `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift`
- `Sources/CodeEditorSample/KnobPanels/AnnotationsKnobsSection.swift`

### 4.3 Tests (6 files)

- `Tests/CodeEditorPluginTests/AnnotationTests.swift`
- `Tests/CodeEditorPluginTests/Annotations/AnnotationThemeTests.swift`
- `Tests/CodeEditorPluginTests/CodeEditorViewTests.swift`
- `Tests/CodeEditorPluginTests/IOSAnnotationTests.swift`
- `Tests/CodeEditorPluginTests/Layout/ThemeableUIComponentTests.swift`
- `Tests/CodeEditorPluginTests/MemoryLeakTests.swift`

### 4.4 Targets unchanged

- `CodeEditorUI`, `CodeEditorUITests` — no Annotation reference.
- `CodeEditorDesignTokensTests` — no Annotation reference.
- `CodeEditorSampleTests` — currently no Annotation reference (verify in pre-flight; sample-side tests don't reference Annotation types as of `01d20149`).

### 4.5 SwiftLint `sorted_imports` ordering

`CodeEditorAnnotations` sorts alphabetically *before* `CodeEditorCommon`, `CodeEditorDesignTokens`, `CodeEditorDiagnostics`, `CodeEditorPlatform`, `CodeEditorSyntaxHighlighting`, `CodeEditorTheming`. Plan author: place the new import accordingly. **§6.2.8f Workspace's plan-written ordering was wrong** (SwiftLint moved `CodeEditorWorkspace` to the bottom on autofix); calling that lesson out here so the same mistake doesn't repeat with `CodeEditorAnnotations`.

### 4.6 `@testable` qualifiers

Per §6.2.8d's `EditorControllerSelectMatchTests` lesson, do **not** blanket-drop `@testable import CodeEditorPlugin` from tests. For each of the 6 test files in §4.3:

1. Add `import CodeEditorAnnotations`.
2. Verify whether `@testable import CodeEditorPlugin` is load-bearing for *non*-Annotation reasons (internal APIs accessed elsewhere in the file).
3. If load-bearing for other reasons, KEEP `@testable` alongside the new import.
4. If the file *only* uses `@testable` for Annotation types, replace with the plain `import CodeEditorAnnotations`.

Pre-flight expectation: most or all of these files keep `@testable` for other umbrella-internal reasons (`AnnotationTests.swift` constructs `CodeEditorView` directly; `MemoryLeakTests.swift` exercises umbrella internals). The new import joins the existing `@testable` rather than replacing it.

---

## 5. Risks & open questions

### 5.1 Risks

1. **Dead `@SeeAlso` doc-link in `Annotation.swift`.** Line 46 has `/// - SeeAlso: \`CodeEditorView.addAnnotation(_:)\`, \`AnnotationsDataSource\`` — after the move, `CodeEditorView` is in a different module. The doc comment still compiles (Swift doesn't validate `@SeeAlso` symbol references), and per CLAUDE.md the workspace has no DocC catalog, so there's nothing rendering this comment today. **Action: leave as-is, accept the dead link.**

2. **`AnnotationsDataSource` doc-comment `CodeEditorView` references.** The relocated file has 3 doc-comment mentions of `CodeEditorView` (lines 44, 68, 74). All compile because the file stays in the umbrella where `CodeEditorView` is in-scope. No change needed.

3. **`Layout/ThemeableUIComponent+Conformances.swift` migration coupling.** This file gains `import CodeEditorAnnotations` now; when §6.2.11 extracts `CodeEditorLayout`, the import migrates with it. Not a blocker — flagged so the §6.2.11 plan author doesn't reintroduce the in-target visibility assumption.

4. **No `Sources/CodeEditorPlugin/Annotations/` directory after extraction.** SwiftPM tolerates the empty dir under `exclude:`, but the defensive entry in §3.2 step 5 keeps the build deterministic. Same pattern §6.2.7 SH used.

### 5.2 Open questions

None blocking. Dependency edges, file split, and consumer ripple have all been verified by grep. The only unverified step is "does `swift build` succeed in the proposed end state" — that's plan-execution territory, not spec.

---

## 6. Expected deviations from this spec

Past extractions have always had deviations; documenting expected ones here so the plan author isn't surprised, and so the post-merge `NEXT.md §6.0` deviations entry has a head start.

1. **`Sources/CodeEditorSampleTests/`** — spec lists this as unchanged. If grep at execution time finds even one new Annotation reference (unlikely; nothing in `Tests/CodeEditorSampleTests/` as of `01d20149` references Annotation types), `CodeEditorSampleTests` gains `CodeEditorAnnotations` as a direct dep.
2. **`@testable` audit per file may surface a case where one test no longer needs `@testable`.** If `AnnotationThemeTests.swift` only references public Annotation types (likely), it could drop `@testable` and use plain `import CodeEditorAnnotations`. Verify per file.
3. **SwiftLint `sorted_imports` may flag the manual ordering** — autofix is the plan's safety net, but the plan author should write the imports in their final sorted position to avoid a separate fixup commit. §6.2.8f's lesson.
4. **Spec under-counts something.** Every prior extraction surfaced at least one access-modifier promotion or import the spec missed. Plan author: run a full `swift build` after step 3.2.4 (delete placeholder); the first error is where the spec was wrong. Common surprises: (a) a `private` extension that needed to be `package`, (b) a test mock that needed an init promoted, (c) a synthesised init on a `public` struct that was actually `internal`.

---

## 7. Test strategy

### 7.1 During execution

- After pre-commit A (file relocation): `swift build` must remain green. Skip tests; nothing functional changed.
- After commit B (extraction): `swift build && swiftlint --fix && swiftlint && swift test --filter AnnotationTests && swift test --filter AnnotationThemeTests`.
- After consumer-ripple sweep: re-run the same chain. The targeted test filter covers the moved surface; per the memory rule on additive-only changes, full `swift test --parallel` is not required.

### 7.2 Per-target build verification

Order matters. Test in this order to localize failures:

1. `swift build --target CodeEditorAnnotations` — fastest signal that the new target's dep set is correct.
2. `swift build --target CodeEditorPlugin` — picks up the 4 umbrella consumer imports.
3. `swift build --target CodeEditorSample` — picks up the 4 sample consumer imports.
4. `swift build` — full package; should be green at this point if steps 1-3 passed.

### 7.3 Post-merge smoke test

Sample-app visual verification: launch `CodeEditorSample`, open `AnnotationsKnobsSection`, toggle annotation visibility, change `AnnotationKind` (`.error` / `.warning` / `.info`), confirm badges render in the gutter with correct colors. Matches the §6.2.7 SH cadence of "sample-app theme rendering visually verified by the user on 2026-05-17" (NEXT.md §6.0).

### 7.4 No new test target

`CodeEditorPluginTests` remains the test home. Per-target test split (`CodeEditorAnnotationsTests` as its own target) is deferred to §6.2.15. Matches §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8f precedent.

---

## 8. Non-goals

- **Not reshaping `AnnotationsDataSource`.** Removing the `CodeEditorView` parameter from `textView(_:viewForLineAnnotation:...)` is a valid future refactor (every in-tree impl already ignores the parameter), but it's a public-API break and out of scope for this carve-out. Re-evaluate during §6.2.12 Core split.
- **Not productizing Annotations.** The umbrella's `Core/CodeEditorView+AnnotationsExtensions.swift` consumes Annotation types; while that holds, Annotations can't be opt-in.
- **Not adding new annotation kinds, view styles, or layout behavior.** This is import-graph surgery, not feature work — matches NEXT.md §9.
- **Not touching `Features/SmartEditing*` or `Completion/`.** SmartEditing is deferred (§6.2.8c blocked on §6.2.12); Completion is the last remaining §6.2.8 extraction and gets its own session.

---

## 9. Suggested next session after this lands

Per NEXT.md §10, after Annotations the §6.2.8 remaining work is:

- **§6.2.8 Completion** — final feature engine (most call sites; ~19 files; will likely be a larger carve-out).
- **§6.2.9 LSP + Debugger** — depends on Completion + Languages + Symbols. Confirm-or-delete Debugger first.

Annotations is the smaller of these two remaining slots, so this session lands first; Completion is the next session.

---

## Appendix A — Files grep'd

For pre-flight reproducibility:

```bash
# Coupling check — only AnnotationsDataSource.swift has a non-doc-comment CodeEditorView reference
grep -nE "CodeEditorView\b" Sources/CodeEditorPlugin/Annotations/*.swift

# Dep verification — no CodeEditorTextModel import in the moving set
grep -nE "^import " Sources/CodeEditorPlugin/Annotations/*.swift | sort -u

# Consumer ripple — 13 files reference moving Annotation types
grep -rn "MessageLineAnnotation\|LineAnnotation\b\|AnnotationKind\|CodeEditorViewAnnotation\|AnnotationView\|AnnotationsContentView\|AnnotationViewProtocol\|AnnotationsContentViewProtocol" \
    Sources/ Tests/ --include="*.swift" | grep -v "Sources/CodeEditorPlugin/Annotations"

# Promotion baseline — every top-level public type has explicit public init
grep -nE "(public init|public struct|public class|public protocol|public enum)" \
    Sources/CodeEditorPlugin/Annotations/*.swift
```

All four commands run clean against the working tree at `01d20149`. Plan author should re-run them in pre-flight to detect drift.
