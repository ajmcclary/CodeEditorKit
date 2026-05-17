# Remaining Phase 0–2 Extractions Design

Date: 2026-05-17
Status: Approved for implementation planning
Scope: Completion of the restructure begun in [`2026-05-17-phase-0-2-target-extraction-design.md`](./2026-05-17-phase-0-2-target-extraction-design.md). Picks up after the Pre-flight cleanup commit `cb9cb2e6` and the `CodeEditorCommon` extraction commit `f0c438f1`.

## 1. Why this spec exists

The prior spec assumed each target extraction would be a clean mechanical move. Task 2 (the `CodeEditorCommon` extraction) revealed that the actual codebase is internally cohesive in two ways the prior spec didn't anticipate:

1. **Cross-target extension files**: source dirs that are nominally domain-cohesive (`Platform/`, `Configuration/`, `Common`-staging) contain extensions on types from *other* future targets. These force moves-back to the umbrella before each extraction.
2. **Pervasive `internal`-default access**: when a target boundary is introduced, dozens of `internal` declarations that worked fine within a single target become invisible to callers across the new boundary. Task 2 needed ~30 ad-hoc access-modifier promotions, a crude bulk-perl pass, and a follow-up of targeted reverts.

The CodeEditorCommon extraction cost ~150 file edits across many iterations as a result. The remaining four extractions (TextModel, Configuration, Platform, Theming) would, by extrapolation, each have similar cost.

This spec restructures the remaining work to do the expensive cross-target access-modifier work once, upfront, so the per-target extractions become close to pure mechanical moves.

## 2. Architecture

Three phases.

**Phase A — Upfront `package`-promotion pass** (one commit, no `Package.swift` changes).
For each future-target source dir (`Text/`, `Documents/`, `Configuration/`, `Platform/`, `Theming/`), identify each `internal` (or unmarked) declaration that is referenced from outside its own dir, and promote it to `package` (Swift 5.9+ cross-target visibility without exposing it as public API). Use `public` only for genuinely user-facing API (verified via grep against `docs/`). File-local helpers stay `internal`.

**Phase B — Four target extractions** (one commit each).
| Order | Target | Sources | Depends on |
|---|---|---|---|
| 1 | `CodeEditorTextModel` | `Text/` (51 files), `Documents/` (2 files) | `CodeEditorCommon` |
| 2 | `CodeEditorConfiguration` | `Configuration/` (7 files) | `CodeEditorCommon`, `CodeEditorTextModel` |
| 3 | `CodeEditorPlatform` | `Platform/` (32 files) | `CodeEditorConfiguration` (per the flipped graph from the prior spec; Common is transitive) |
| 4 | `CodeEditorTheming` | `Theming/` (31 files), `Resources/Themes/` | `CodeEditorDesignTokens` only |

Each extraction is `git mv` + `Package.swift` edit + adding `import <NewTargetName>` statements in umbrella files that newly need to name the target. No promotion work in these commits — Phase A absorbed it.

**Phase C — Final verification** (one commit if anything needs cleanup, otherwise none).
Full `swift test --parallel`, `swiftlint`, and sample app smoke test.

## 3. The `package`-promotion pass (Phase A)

### 3a. Build a manifest of cross-directory references

Scripted scan across the five future-target source dirs. For each `internal` (or unmarked) declaration found, grep the rest of `Sources/CodeEditorPlugin/` for references. If hits exist outside the symbol's own dir, the symbol is a promotion candidate.

Example manifest entries (illustrative — the actual manifest is produced by the script during implementation):

```
Text/RangeMutationEngine.swift: enum RangeMutationEngine → referenced from Annotations/, Core/, Layout/
Configuration/EditorConfiguration+LayoutExtensions.swift: var <some-property> → referenced from Layout/
Platform/PlatformConstants.swift: static let <some-constant> → referenced from Core/, Performance/
```

Symbols not in the manifest stay `internal`.

### 3b. Promote each manifest entry

Edit the declaration to prefix with `package` (or `public` if the symbol appears in the documented public API surface — checked by grep against `docs/`). Use `package` by default; reserve `public` for genuinely user-facing API.

Three Swift-language caveats:
- **Protocol members can't have access modifiers** — skip protocol bodies.
- **A `package`/`public` member can't reference an `internal` type in its signature** — if a method takes/returns an `internal` type, either also promote that type or leave the method `internal`.
- **Attribute ordering** — `@discardableResult` and similar attributes stay where they are; the access modifier goes between the attribute and the keyword.

### 3c. Verify

- `swift build` — confirms no syntactic regressions and that all promoted symbols are resolvable.
- `swift test --parallel` — confirms no behavioral regressions.
- `swiftlint --fix && swiftlint` — confirms no new lint violations. The choice of `package` (not `public`) means SwiftLint's `missing_docs` rule does NOT fire on the newly-promoted symbols.

### 3d. Commit

One commit titled "Promote cross-boundary symbols to package for upcoming extractions". Body describes the scope and the auto-generated manifest count.

**Estimated scope:** 50–150 declarations across ~30–60 files. The commit is one large diff but each edit is trivial (single-token addition).

## 4. The four target extractions (Phase B)

### 4a. Per-extraction template

For each target, in the order above:

1. **Move source directory**: `git mv Sources/CodeEditorPlugin/<Dir>/ Sources/<NewTargetName>/`. For TextModel, includes both `Text/` and `Documents/`. For Theming, includes both `Theming/` and `Resources/Themes/`.
2. **Update `Package.swift`**: add a new `.target(name: "<NewTargetName>", dependencies: [...], swiftSettings: swiftSettings)` entry; add `"<NewTargetName>"` to `CodeEditorPlugin`'s `dependencies:` array.
3. **Add `import <NewTargetName>` to umbrella files that use the new target's types**: compiler errors identify these. Most edits in this phase are single-line additions.
4. **Resolve any newly-surfaced cross-target leaks**: if a file in the moved dir references a type from a still-umbrella dir, apply the "push the file back to its semantic home" pattern (same as Task 2's experience). Phase A should make this rare.
5. **Update test-target deps**: if any test target's source references the new target's types, add `"<NewTargetName>"` to that test target's `dependencies:`.
6. **Verify**: `swift build && swiftlint --fix && swiftlint && swift test --parallel`.
7. **Commit**.

### 4b. Per-target specifics

**Extraction 1 — `CodeEditorTextModel`.**
- Sources: `Text/` (51 files) + `Documents/` (2 files).
- The 4 view-coupled files relocated to `Core/Text/` in the pre-flight commit (`TextKitLineNumberHelper.swift`, `TextKitBridge.swift`, `LineGeometryEditHandler.swift`, `TextKit2RenderingOptimizer.swift`) **stay in `Core/`** — they belong with the view, not the model.
- The 2 files created in the pre-flight commit (`Text/IndexSet+RangeMutation.swift`, `Text/NSRange+RangeMutation.swift`) move with the rest.
- `Package.swift`: `dependencies: ["CodeEditorCommon"]`.
- Expect 30–60 umbrella `import CodeEditorTextModel` additions.

**Extraction 2 — `CodeEditorConfiguration`.**
- Sources: `Configuration/` (7 files).
- `Package.swift`: `dependencies: ["CodeEditorCommon", "CodeEditorTextModel"]`.
- Expect 10–25 umbrella `import CodeEditorConfiguration` additions.

**Extraction 3 — `CodeEditorPlatform`.**
- Sources: `Platform/` (32 files — minus the files relocated in pre-flight).
- `Package.swift`: `dependencies: ["CodeEditorConfiguration"]`. Common reaches via transitive linkage.
- Expect 20–40 umbrella `import CodeEditorPlatform` additions.
- Per the flipped graph from the prior spec (spec gap #3), Platform depends on Configuration, not the reverse.

**Extraction 4 — `CodeEditorTheming`.**
- Sources: `Theming/` (31 files) + `Resources/Themes/` JSON.
- `Package.swift`: `dependencies: ["CodeEditorDesignTokens"]`. Theming is a true leaf — the prior spec's claim that it depends on Platform was unsubstantiated by actual code references.
- Removes `resources: [.process("Resources/Themes")]` from the umbrella's target block; adds the same entry to the new Theming target.
- Sample-app smoke test required after this commit: confirm bundled themes still render. `Bundle.module` now resolves to `CodeEditorTheming.bundle`.
- Expect 20–40 umbrella `import CodeEditorTheming` additions.

### 4c. Failure-mode handling

If during any extraction the build surfaces problems beyond "add an import":

- **Missed promotion**: add a small fix-up commit BEFORE the extraction (not as an amendment) that promotes the symbol, then redo the extraction.
- **Cross-target leak**: apply the "move file back to umbrella in its semantic home" pattern, same as Task 2.
- **Hard cap**: if any single extraction exceeds ~30 file edits beyond imports, stop and re-brainstorm — the Phase A pass was insufficient and we need a different decomposition.

## 5. Testing

Test targets stay in place. No per-target test target split this session. After each commit:

- `swift build` — must succeed.
- `swift test --parallel` — must run with all current passes (the post-Task-2 baseline is 465 tests in 116 suites).
- `swiftlint --fix && swiftlint` — must end clean.

After the Theming extraction (Phase B extraction 4) specifically, run `swift run CodeEditorSample` and visually confirm the bundled themes still render correctly. This is a runtime concern — `Bundle.module` resolution — that the compiler cannot catch.

## 6. Risks

### R1 — Phase A misses a needed promotion

The manifest is built by grep. Cases like dynamic dispatch through a protocol where the underlying internal symbol isn't named at the call site are missed.

- **Mitigation**: build after Phase A; surface any unresolved-symbol errors as additions to the manifest. If any surface during a Phase B extraction, fix in a small pre-extraction commit (per §4c).

### R2 — Cross-target leaks beyond Task 2's discovered set

Files in `Text/`, `Configuration/`, `Platform/`, or `Theming/` may reference types from another future-target dir (e.g. `Text/` referencing a `Configuration/` type).

- **Mitigation**: pre-extraction grep per target (the same widened-grep pattern from the prior spec's R1 mitigation); apply the "move file to its semantic home" pattern.
- **Hard cap**: if more than 5 surprise files per target surface, stop and re-brainstorm.

### R3 — Theming JSON bundle resolution breaks at runtime

`Bundle.module` resolves to whichever target's bundle the calling file lives in. After moving Theming to its own target, code that previously loaded themes via `Bundle.module` from a still-umbrella file resolves to the wrong bundle.

- **Mitigation**: explicit sample-app smoke test after extraction 4. Roll back that commit if themes fail to load. The fix path: route all theme loading through a `CodeEditorTheming`-side helper that uses its local `Bundle.module`.

### R4 — `package` interacts unexpectedly with `@testable`

Test files that use `@testable import CodeEditorPlugin` see internal symbols of CodeEditorPlugin but not of CodeEditorCommon. Phase A is umbrella-internal promotion (declarations in dirs about to become new targets, but currently still inside the umbrella), so this shouldn't directly affect tests — but if a test breaks because it was relying on internal access to a now-promoted symbol, the fix is to add `@testable import <NewTargetName>` to the failing test file.

### R5 — `package` not accepted by Swift Syntax macros or protocol witnesses

Some macro-generated code or protocol conformances may not accept `package` access on synthesized symbols. Caught at build time during Phase A or B. Fall back to `public` for that specific symbol; document the case for future reference.

### R6 — Inherited risks from the prior spec

R1 (hidden Text/ cross-boundary imports), R2 (Configuration view coupling), R6 (`Resources/Themes` migration) from the prior spec still apply. Their mitigations from that spec carry forward unchanged.

## 7. Exit criteria

- 5–6 new commits on `main` (1 Phase A + 4 Phase B + at most 1 Phase C cleanup).
- `swift build` succeeds at end of session.
- `swift test --parallel` succeeds at end of session.
- `swiftlint --fix && swiftlint` clean at end of session.
- Sample app builds and runs; bundled themes render correctly.
- `ls Sources/` shows 10 directories: `CodeEditorCommon`, `CodeEditorConfiguration`, `CodeEditorDesignTokens`, `CodeEditorPlatform`, `CodeEditorPlugin`, `CodeEditorSample`, `CodeEditorTextModel`, `CodeEditorTheming`, `CodeEditorTreeSitterLanguages`, `CodeEditorUI`.
- `Sources/CodeEditorPlugin/` loses `Text/`, `Documents/`, `Configuration/`, `Platform/`, `Theming/`, `Resources/`.

## 8. Out of scope

Deferred to future brainstorms:
- Splitting `CodeEditorPluginTests` into per-target test targets.
- Converting `CodeEditorPlugin` umbrella into a thin re-export shim.
- Exposing new targets as SPM `products`.
- Moving the package to `~/Workspace/packages/`.
- Splitting the still-large `Core/`, `Layout/`, `Features/`, `Languages/`, `Completion/`, `SyntaxHighlighting/`, `LSP/`, `Performance/`, `SwiftUI/`, `Annotations/`, `Search/`, `Workspace/`.

## 9. References

- [`docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md`](./2026-05-17-phase-0-2-target-extraction-design.md) — Prior spec for the Pre-flight cleanup (commit `cb9cb2e6`) and the CodeEditorCommon extraction (commit `f0c438f1`). This new spec picks up where that one left off.
- [`docs/superpowers/plans/2026-05-17-phase-0-2-target-extraction.md`](../plans/2026-05-17-phase-0-2-target-extraction.md) — Prior plan with the spec-gap notes that drove this re-brainstorm.
- [`NEXT.md`](../../../NEXT.md) — Original full restructuring strategy.
- [`CLAUDE.md`](../../../CLAUDE.md) — Project conventions.
