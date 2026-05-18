# §6.2.13 `CodeEditorSwiftUI` extraction — design

**Date:** 2026-05-18
**Section:** NEXT.md §6.2.13
**Status:** Approved — ready for plan
**Predecessors:** §6.2.12 `CodeEditorView` (`ae61428`, `8ab2075`, `d0324a9`), §6.2.8c `CodeEditorSmartEditing` (`0c2272d`)

**Position in the restructure:** the SwiftUI-surface extraction. With §6.2.12 having moved every `Sources/CodeEditorPlugin/Core/` file to `Sources/CodeEditorView/` and §6.2.8c having closed the §6.2.8 feature engines, the umbrella source tree now retains only `CodeEditorPlugin.swift` (the 91-LOC root stub), `SwiftUI/` (17 files), `Languages/` (its own SPM target via `path:`), and `Resources/Info.plist`. §6.2.13 carves the `SwiftUI/` slice out. After this, §6.2.14 strips the umbrella to `@_exported import`s, §6.2.15 lifts test fixtures into a real library target, and the package moves to `~/Workspace/packages/`.

**Why this is a clean full extraction (no carve-out):** the audit confirms zero structural coupling between the 17 moving files and the umbrella's residual slice. The historical carve-out trigger — files referencing the umbrella-resident `CodeEditorView` class — was resolved in §6.2.12 when `CodeEditorView` left the umbrella. The only cross-target wiring that mattered (the `CodeEditorBaseCoordinator` open class conforming to `CodeEditorCoordinating`) was already set up by §6.2.12's introduction of the `CodeEditorCoordinating` package protocol. §6.2.13 is the second half of that work.

---

## 1. Goal

Extract `Sources/CodeEditorPlugin/SwiftUI/` (17 files) into a new SPM target `CodeEditorSwiftUI` at `Sources/CodeEditorSwiftUI/`. Productized as `.library(name: "CodeEditorSwiftUI", targets: ["CodeEditorSwiftUI"])` per NEXT.md §6.3 "Probably" tier. Umbrella `CodeEditorPlugin` adds `CodeEditorSwiftUI` as a direct target dependency (matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout / §6.2.12 View precedent — productized + umbrella-coupled).

Net result: 17 files move; the umbrella's `SwiftUI/` directory is deleted; `Sources/CodeEditorPlugin/` shrinks from ~96 files to ~79. The umbrella retains only `CodeEditorPlugin.swift`, the `Languages/` source root (compiled as its own SPM target via `path:`), and `Resources/Info.plist`. The 12 internal target deps of the new target are enumerated in §3.

Public API surface of `import CodeEditorPlugin` is unchanged. External consumers see no breaking change — every previously-public SwiftUI/-slice type remains reachable via the umbrella's new transitive dep on `CodeEditorSwiftUI`. §6.2.14 will harden this with explicit `@_exported import` declarations.

This is import-graph surgery, not feature work. No behavior change.

---

## 2. Scope

### 2.1 Files moving (17)

All 17 files in `Sources/CodeEditorPlugin/SwiftUI/` move to `Sources/CodeEditorSwiftUI/`. The `SwiftUI/` subfolder is flattened at destination per the target-name-is-the-namespace convention (matches §6.2.8c SmartEditing / §6.2.11 Layout / §6.2.12 View).

| From | To |
|---|---|
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` | `Sources/CodeEditorSwiftUI/CodeEditor.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditor+AppKitExtensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditor+DocumentsExtensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+FactoryExtensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditor+FactoryExtensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditor+ModifiersExtensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+RepresentableParameters.swift` | `Sources/CodeEditorSwiftUI/CodeEditor+RepresentableParameters.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditor+UIKitExtensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditorEnvironment+Extensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift` | `Sources/CodeEditorSwiftUI/CodeEditorIntent.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditorPlatformAdapter.swift` | `Sources/CodeEditorSwiftUI/CodeEditorPlatformAdapter.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` | `Sources/CodeEditorSwiftUI/CodeEditorRepresentableHelper.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift` | `Sources/CodeEditorSwiftUI/CodeEditorTheme+Extensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` | `Sources/CodeEditorSwiftUI/EditorController.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift` | `Sources/CodeEditorSwiftUI/EditorController+Completion.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/EditorController+TemporaryAttributesExtensions.swift` | `Sources/CodeEditorSwiftUI/EditorController+TemporaryAttributesExtensions.swift` |
| `Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift` | `Sources/CodeEditorSwiftUI/EditorState+Environment.swift` |

After the move, `Sources/CodeEditorPlugin/SwiftUI/` is empty and gets `rmdir`'d.

### 2.2 Public surface (unchanged)

After the move, every existing public type continues to exist with the same name and the same access level:

- `CodeEditor` (the SwiftUI `View` / `Representable` struct)
- `CodeEditorBaseCoordinator` (open class)
- `EditorController` (class, `@MainActor`)
- `CodeEditorIntent` (struct / enum, per file contents)
- `CodeEditorEnvironment` (struct + `EnvironmentValues` extensions)
- `CodeEditorPlatformAdapter` (protocol / type)
- `CodeEditorRepresentableHelper` (struct / helpers)
- `EditorState` environment key + `EditorState+Environment` reader extensions
- Theme / Completion / TemporaryAttributes / Documents / Factory / Modifiers / RepresentableParameters extensions on `CodeEditor` and `EditorController`

Consumers doing `import CodeEditorPlugin` continue to see all of these via the umbrella's transitive `CodeEditorSwiftUI` dep.

### 2.3 Carve-out: none

Clean full extraction. No `Sources/CodeEditorPlugin/SwiftUI/` residue, no `Core/SwiftUI/` bucket. Confirmed by audit:

- No file in `SwiftUI/` references `CodeEditorPlugin.swift` root symbols.
- No file references the umbrella's remaining `Languages/` source root or `Resources/Info.plist`.
- §6.2.8c closed the `Features/SmartEditing/` slice; the SwiftUI files contain zero references to `SmartEditing*` types.
- §6.2.12 already moved the `CodeEditorView` class to its own target; cross-module wiring is via `import CodeEditorView`.

This is the third clean full extraction in the restructure (after §6.2.8f Workspace and §6.2.8c SmartEditing), and the largest by file count.

### 2.4 Cuts (anything deleted, by audit)

**Baseline assumption: zero deletions.** No dead-code candidates identified in audit. §6.2.9a Debugger and §6.2.12c `TextSystem` cluster + `CompletionAsyncError` already cleared the known dead code in adjacent slices.

If the plan-time per-file audit surfaces dead code (zero in-tree callers + zero tests + zero archived-doc references), it goes in its own commit *before* the bulk move per §6.2.9a / §6.2.12c precedent. The spec carries no name baked-in.

---

## 3. Dependencies

### 3.1 New target's direct deps

`CodeEditorSwiftUI` declares these internal SPM target deps (audit-confirmed via import-grep across the 17 moving files):

- `CodeEditorAnnotations`
- `CodeEditorCommon`
- `CodeEditorCompletion`
- `CodeEditorConfiguration`
- `CodeEditorDiagnostics`
- `CodeEditorLanguages`
- `CodeEditorLayout`
- `CodeEditorLSP`
- `CodeEditorPlatform`
- `CodeEditorTextModel`
- `CodeEditorTheming`
- `CodeEditorView`

12 internal deps total. System / external imports inside the moving set: `SwiftUI` (15 files), `AppKit` (5), `UIKit` (4), `Foundation` (3), `@preconcurrency Combine` (1 — `EditorController.swift`). No PointFree `Dependencies`, no `IssueReporting`, no other third-party.

### 3.2 Dep rationale

Each dep is justified by an actual import in the moving set per the audit:

| Dep | Used by (file count) | What for |
|---|---|---|
| `CodeEditorView` | 17 | `CodeEditorView` class, `TextKitBridge`, `addDelegateParticipant`, `CodeEditorCoordinating` protocol, `applyMarkClean`, public Core/ types |
| `CodeEditorLanguages` | 10 | `Language` enum, `TabModel`, language-related types |
| `CodeEditorConfiguration` | 8 | `EditorConfiguration` + nested types |
| `CodeEditorCompletion` | 8 | `CompletionManager`, `SwiftUICompletionItem`, `SwiftUICompletionContext`, `CompletionKind`, `CompletionStatistics` |
| `CodeEditorTheming` | 7 | Theme types, color helpers |
| `CodeEditorCommon` | 7 | `SelectionState`, `EditorInteractionState`, `SendableError`, `CrossPlatformLogger`, `SourcePosition` |
| `CodeEditorPlatform` | 6 | `PlatformColors`, `PlatformFonts`, AppKit/UIKit shims, `ToolbarItem` typealias |
| `CodeEditorDiagnostics` | 5 | `MemoryMonitor`, instrumentation |
| `CodeEditorTextModel` | 2 | TextKit2 primitives, range storage |
| `CodeEditorLayout` | 2 | `EditorEventBus`, layout / event types |
| `CodeEditorAnnotations` | 1 | Annotation types (single referencing file confirmed by audit; plan-time pre-flight enumerates which one) |
| `CodeEditorLSP` | 1 | LSP types (single referencing file confirmed by audit; plan-time pre-flight enumerates which one) |

The "What for" column is illustrative — derived from the moving files' naming and known usage patterns. Plan-time pre-flight greps every `import` against the actual call sites to confirm. No other deps needed. Specifically NOT depended on:

- `CodeEditorDesignTokens` — reached transitively via Theming.
- `CodeEditorSyntaxHighlighting`, `CodeEditorFolding`, `CodeEditorSymbols`, `CodeEditorSmartEditing`, `CodeEditorSearch`, `CodeEditorWorkspace` — zero imports across the 17 moving files.

### 3.3 NEXT.md §4.1 correction

NEXT.md §4.1 lists `CodeEditorSwiftUI → the Editor target` as the dep claim. Reality: 12 internal deps spanning phase 0 (Common, Platform) through phase 8 (View). Joins the §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.10 / §6.2.11 / §6.2.12 §4.1-correction pattern — record in the §6.2.13 deviations block of NEXT.md.

### 3.4 Build-graph slot

Phase 9. Matches the semantic label in NEXT.md §4.1.

### 3.5 Umbrella `CodeEditorPlugin` target gains `CodeEditorSwiftUI` as a direct dep

Per the productized + umbrella-coupled pattern of §6.2.9 / §6.2.10 / §6.2.11 / §6.2.12. The umbrella's `dependencies:` array adds the new target name; `CodeEditorPlugin.swift` (root entry stub) is unchanged at this chunk (§6.2.14 will hard-wire `@_exported import` declarations).

---

## 4. `CodeEditorBaseCoordinator` cross-target wiring

§10 flagged this as needing careful handling. The audit confirms it's a clean hand-off thanks to §6.2.12 having pre-laid the protocol.

### 4.1 Current state (post-§6.2.12)

- `package protocol CodeEditorCoordinating: AnyObject` lives in `Sources/CodeEditorView/CodeEditorCoordinating.swift`. One requirement: `@MainActor func markClean(view: CodeEditorView)`.
- `open class CodeEditorBaseCoordinator: NSObject, ObservableObject, CodeEditorCoordinating` lives in `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`. The `markClean(view:)` impl is `package`-visible (satisfies the protocol requirement across the umbrella ↔ View boundary).

### 4.2 Plan for §6.2.13

- **`CodeEditorBaseCoordinator` moves with the slice** to `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift`. Access stays `open` (already at the highest level — no promotion needed).
- **`CodeEditorCoordinating` stays in `CodeEditorView`** unchanged. `package` access works across target boundaries within the same SPM package, so the conformance compiles from `CodeEditorSwiftUI`.
- **`markClean(view:)` stays `package`-visible** on the conformer. Cross-module `package` is exactly the mechanism §6.2.12 introduced for this.
- **No protocol promotion to `public`.** No external consumer is known to define its own `CodeEditorCoordinating` conformer in a different SPM package; keeping `package` preserves the boundary.

### 4.3 Concurrency risk (to verify in execution, not now)

Swift's strict-concurrency cross-module check may flag the `markClean(view:)` body's `@MainActor`-isolation differently than same-module did (§6.2.12 saw this with `CodeEditorView`'s `@unchecked Sendable`). If it does, the fix is either `@MainActor` annotation on `markClean(view:)` (preferred) or `@unchecked Sendable` on `CodeEditorBaseCoordinator` (fallback). Plan-time pre-flight does NOT pre-emptively annotate; deviation block captures the actual outcome.

---

## 5. Consumer ripple

### 5.1 Per-target file counts

Audit-confirmed totals for files needing the new `import CodeEditorSwiftUI` line:

| Target | Files | Kind |
|---|---|---|
| `CodeEditorUI` (source) | 15 | `import CodeEditorSwiftUI` |
| `CodeEditorSample` (source) | 58 | `import CodeEditorSwiftUI` |
| `CodeEditorPluginTests` | 130 | `@testable import CodeEditorSwiftUI` |
| `CodeEditorSampleTests` | 37 | `@testable import CodeEditorSwiftUI` |
| `CodeEditorUITests` | 15 | `@testable import CodeEditorSwiftUI` |
| **Total** | **255** | |

Largest ripple in the restructure series (§6.2.12 was 158 = 35 source + 123 test; §6.2.9 / §6.2.11 each landed under 50). The ripple is mechanical (no semantic edits beyond the import line).

### 5.2 Package.swift target-dep additions (6)

Each consumer target's `dependencies:` array gains `"CodeEditorSwiftUI"`:

1. `CodeEditorPlugin` (umbrella) — per §3.5.
2. `CodeEditorUI` — 15 source files import the new target.
3. `CodeEditorSample` — 58 source files import the new target.
4. `CodeEditorPluginTests` — 130 test files `@testable import` the new target.
5. `CodeEditorSampleTests` — 37 test files `@testable import` the new target.
6. `CodeEditorUITests` — 15 test files `@testable import` the new target.

### 5.3 Strategy: blanket-add (§6.2.12 lesson)

Use an awk script to add the import line to every file in each consumer directory that has any existing imports. SwiftLint's `sorted_imports` rule re-orders alphabetically post-`--fix`, so insertion position doesn't matter. Verified-by-build, not by precise grep — the §6.2.8e bare-word-grep correction and §6.2.12 "blanket-add converged faster" experience say this is faster than enumerating consumers per-symbol.

### 5.4 Existing `@testable` qualifiers stay defensively (§6.2.8d lesson)

Every test file's existing `@testable import CodeEditorPlugin` / `@testable import CodeEditorView` stays in place. The new `@testable import CodeEditorSwiftUI` is additive. The §6.2.8d lesson — `EditorController.attach(to:)` is intentionally `internal`, so tests REQUIRE `@testable` to reach the wiring hook — applies directly here.

### 5.5 No public-API removals

Every previously-public umbrella symbol remains reachable. Umbrella `import CodeEditorPlugin` consumers continue to see `CodeEditor`, `EditorController`, `CodeEditorBaseCoordinator`, `CodeEditorIntent`, `CodeEditorEnvironment`, `CodeEditorPlatformAdapter`, `CodeEditorRepresentableHelper`, `EditorState.environmentReader` via the umbrella's new transitive dep on `CodeEditorSwiftUI`. §6.2.14 will harden this with explicit `@_exported import CodeEditorSwiftUI` from `CodeEditorPlugin.swift`.

### 5.6 Spec under-count caveat

Per the §6.2.8e / §6.2.8g pattern, plan execution will likely surface 5–15 more consumer files the audit missed (bare-word `EditorController` / `CodeEditor` greps are noisier than compound names). Plan budgets a final compile-error iteration pass; deviations block captures the actual count.

---

## 6. Access-modifier promotion surface

### 6.1 Audit baseline: zero promotions required

- `CodeEditorBaseCoordinator` is already `open`.
- `markClean(view:)` is already `package` (matches the `CodeEditorCoordinating` protocol requirement).
- All other top-level types in the slice (`EditorController`, `CodeEditor`, `CodeEditorIntent`, `CodeEditorEnvironment`, `CodeEditorPlatformAdapter`, `CodeEditorRepresentableHelper`, `EditorState` env key, `CodeEditorTheme` ext, `CodeEditor+*` ext slices) are already `public` with explicit `public init`s where applicable.
- `EditorController.attach(to:)` is intentionally `internal` (per its doc comment "Internal wiring hook — not for host use"). Stays `internal`. Tests reach it via `@testable import CodeEditorSwiftUI`.

### 6.2 Execution-time budget

Per §6.2.8b / §6.2.8g / §6.2.12c precedent, plan execution typically surfaces 1–3 small promotions the audit missed (most often the synth-init-defaults-to-internal-on-public-struct trap when an init is invoked across a target boundary). Plan-time estimate: **0–5 small promotions**. Actual count recorded in the deviations block.

### 6.3 Two rules from prior chunks if promotions land

- **Don't use `package extension Foo { ... }`** (§6.2.12 lint lesson — SwiftLint's `no_extension_access_modifier` rejects it). Apply `package` per-method.
- **Public actors and structs need explicit `public init()`** when relying on the synthesized init (§6.2.12c `missing_docs` asymmetric-lint behavior; §6.2.8c `SmartEditingConfiguration` precedent).

### 6.4 No `@unchecked Sendable` annotations pre-emptively

Only add if the cross-module strict-concurrency checker complains during commit 2 (per §4.3 / §6.2.12 precedent).

---

## 7. Commit plan

Three commits, mirroring §6.2.12's proven shape (scaffold → bulk move → conditional clean-build fix).

### 7.1 Commit 1: Scaffold `CodeEditorSwiftUI` target

- Create `Sources/CodeEditorSwiftUI/` with `.gitkeep` + `_ScaffoldPlaceholder.swift` (per §6.2.8f lesson — `.library` products require ≥1 `.swift` file).
- Add to `Package.swift`:
  - `.library(name: "CodeEditorSwiftUI", targets: ["CodeEditorSwiftUI"])` in `products:`.
  - `.target(name: "CodeEditorSwiftUI", dependencies: [...12 internal deps from §3.1...], path: "Sources/CodeEditorSwiftUI")`.
  - `CodeEditorSwiftUI` added to the umbrella `CodeEditorPlugin` target's `dependencies:`.
- Run `swift build` — green (umbrella + new empty target both compile; nothing yet consumes the placeholder).
- Commit message: `Scaffold §6.2.13 CodeEditorSwiftUI target`.

### 7.2 Commit 2: Bulk move + ripple

- `git mv` all 17 files from `Sources/CodeEditorPlugin/SwiftUI/` to `Sources/CodeEditorSwiftUI/`. Subfolder flattened at destination.
- Delete the now-empty `Sources/CodeEditorPlugin/SwiftUI/` directory.
- Delete the scaffold placeholder + `.gitkeep`.
- Bulk-add `import CodeEditorSwiftUI` / `@testable import CodeEditorSwiftUI` to all 255 consumer files via awk script (per §5.3).
- Add `CodeEditorSwiftUI` to the 5 consumer-target `dependencies:` in `Package.swift` (`CodeEditorUI`, `CodeEditorSample`, `CodeEditorPluginTests`, `CodeEditorSampleTests`, `CodeEditorUITests`).
- `swiftlint --fix` to normalize import ordering.
- `swift build && swift test --parallel` — green.
- Iterate on any compile errors from under-counted consumers (per §5.6); add missing imports until clean. Stay in one commit.
- Commit message: `Extract §6.2.13 CodeEditorSwiftUI target`.

### 7.3 Commit 3 (conditional): Clean-build fix

- Run `swift package clean && swift build`. If a transitive-dep masking bug surfaces (e.g. an internal target whose `Package.swift` deps list is incomplete and only compiles because incremental builds carry symbols transitively — §6.2.12's TextModel-Platform precedent), fix the one-line Package.swift dep addition.
- If clean-build passes on commit 2, this commit is skipped.
- Commit message: `Fix §6.2.13 clean-build transitive dep` (only if needed).

### 7.4 Total commits

2 or 3, depending on whether the clean-build surprise hits.

---

## 8. Verification

### 8.1 Per-commit gates

| Commit | Gate |
|---|---|
| 1 — Scaffold | `swift build` green. Skip full test suite per `feedback_test_confirmations.md` (additive-only). |
| 2 — Bulk move | `swift build && swiftlint --fix && swiftlint && swift test --parallel` clean. |
| 3 — Clean-build fix (if needed) | `swift package clean && swift build && swift test --parallel` clean. |

### 8.2 End-of-chunk verification

`swift package clean && swift build && swiftlint --fix && swiftlint && swift test --parallel` per CLAUDE.md. Match the §6.2.12c / §6.2.8c verification log: 0 lint violations across ~826 files; 465 tests in 116 suites pass with 1 known pre-existing issue.

### 8.3 Sample-app manual verification

Deferred per §6.2.12 precedent. After commit 2, the user launches CodeEditorSample, opens a file, types a character — confirms the `NSTextView` init invariant (per memory `project_nstextview_init_invariant.md`) and that the SwiftUI Representable wrapper still owns the TextKit2 network end-to-end. The 17-file slice contains the AppKit/UIKit representable bridges, so a regression manifests as silently-broken typing.

---

## 9. Risks

1. **Cross-module strict-concurrency surprise on `CodeEditorBaseCoordinator`** (§4.3). Mitigation: add `@MainActor` to `markClean(view:)` or `@unchecked Sendable` to `CodeEditorBaseCoordinator` if the compiler flags it. Document in deviations.
2. **Under-counted consumers** (§5.6). Mitigation: budget compile-error iteration in commit 2; deviations block records final count.
3. **Synth-init promotion surprises** (§6.2). Mitigation: budget 0–5 small `public init()` promotions; don't use `package extension`.
4. **Clean-build transitive-dep mask** (§7.3). Mitigation: commit 3 reserved slot per §6.2.12 precedent.
5. **Sample-app regression in the SwiftUI representable** (§8.3). Mitigation: explicit manual verification step before merge.

---

## 10. Out of scope

- **§6.2.14 umbrella re-export.** §6.2.13 leaves `Sources/CodeEditorPlugin/CodeEditorPlugin.swift` body unchanged; the explicit `@_exported import CodeEditorSwiftUI` declaration lands in §6.2.14.
- **`CodeEditorPlugin → CodeEditorToolkit` rename** (per NEXT.md §5.2 option 2). Unaffected by §6.2.13. Defer to §6.2.14 if at all.
- **Per-target test split (`CodeEditorSwiftUITests`).** Deferred to §6.2.15 per established precedent (§6.2.7 through §6.2.12 all defer test splits).
- **CodeEditorSample / CodeEditorUI refactors.** Source ripples in those targets are import-line additions only; no behavior or API change.

---

## 11. Closes §6.2.13

After merge, remaining restructure work per NEXT.md §10:

- **§6.2.14** — strip `CodeEditorPlugin.swift` to `@_exported import` declarations.
- **§6.2.15** — extract `Tests/CodeEditorPluginTests/Support/*` into `CodeEditorTestSupport` library target.
- **Move to `~/Workspace/packages/`** — mechanical move after §6.2.15.
