# §6.2.12 CodeEditorView extraction — design

**Status:** spec for the next session.

**Position in the restructure:** the editor-surface extraction. With §6.2.11 Layout (`3a2aba83`) and the three §6.2.12a/b/c Core/ prep rounds complete (`d129070`...`62ec4e7`), `Core/` is at 118 files (down from 138). §6.2.12 is the riskiest single step per NEXT.md §8.1 and §10 ("dedicated half-day, don't combine with anything else"). After this, §6.2.13 SwiftUI / §6.2.14 umbrella re-export / §6.2.15 TestSupport / the workspace move finish the restructure.

**Precedents this builds on:**

- §6.2.9 `CodeEditorLSP` (`d50fc04`) — 22:2 carve-out; productized + umbrella-coupled. Closest precedent for the umbrella-relationship pattern.
- §6.2.10 `CodeEditorDiagnostics` (`e60f7857`) — productized + umbrella-coupled.
- §6.2.11 `CodeEditorLayout` (`3a2aba83`) — productized + umbrella-coupled; cross-target relocation of `SourcePosition` and an `EditorConfiguration: Hashable` conformance during execution; ~10 promotions.
- §6.2.12a (`d129070`, `7f498a8`, `f3b89fc`, `280b82e`) — first Core/ prep round; 9 files moved out + audit tables recorded.
- §6.2.12b (`7cd4421`, `29e4a70`+`5bbb5b7`, `d26527e`) — second Core/ prep round; 3 files moved.
- §6.2.12c (`8d47cb6`, `dadf8e7`, `bf29f9b`, `13df305`, `62ec4e7`) — third Core/ prep round; 4 files moved + 4-file `TextSystem` cluster + `CompletionAsyncError` deleted; `ErrorRecoveryCoordinator` soft-relocated.

**Why this is a clean full extraction (no carve-out):** every previous extraction had to leave a carve-out residue inside the umbrella because at least one target type referenced the umbrella-resident `CodeEditorView` class. §6.2.12 IS the extraction of that class. There is nothing above phase 8 in `Sources/CodeEditorPlugin/Core/` to constrain it; the umbrella's only remaining residents (`SwiftUI/`, `Languages/` via `path:`, `CodeEditorPlugin.swift`, `Resources/Info.plist`) are downstream consumers or unrelated. Every previously stay-set sub-bucket file (`Core/Folding/CodeFoldingEngine.swift`, `Core/LSP/LSPContentCoordinator.swift`, the 9 `Core/SyntaxHighlighting/` `CodeEditorView`-coupled files, the 11 `Core/Platform/` files with `CodeEditorView` refs, etc.) comes home in the move.

---

## 1. Goal

Extract all of `Sources/CodeEditorPlugin/Core/` into a new SPM target `CodeEditorView` at `Sources/CodeEditorView/`. Productized as `.library(name: "CodeEditorView", targets: ["CodeEditorView"])` per NEXT.md §6.3. Umbrella `CodeEditorPlugin` adds `CodeEditorView` as a direct dependency (matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout pattern — productized + umbrella-coupled, not §6.2.8d Search / §6.2.8f Workspace umbrella-decoupled opt-out).

Net result: 118 files move from `Sources/CodeEditorPlugin/Core/` to `Sources/CodeEditorView/` preserving sub-directory structure (per `find Sources/CodeEditorPlugin/Core -name "*.swift" | wc -l` at spec time). The umbrella `CodeEditorPlugin` target retains `CodeEditorPlugin.swift` (91 LOC root), `SwiftUI/` (17 files, still in umbrella, waits for §6.2.13), `Languages/` (its own SPM target via `path:`, unchanged), `Resources/Info.plist`. The 17 umbrella SwiftUI/ slice files gain `import CodeEditorView`. Plugin-test files (176 total in `Tests/CodeEditorPluginTests/`) gain `@testable import CodeEditorView` alongside their existing `@testable import CodeEditorPlugin` (kept defensively per §6.2.8d lesson) — estimated 60–120 affected based on the Core/ surface size; exact count enumerated at plan time. `CodeEditorUI` / `CodeEditorSample` likely gain `CodeEditorView` as direct deps in `Package.swift`. Access-modifier promotions: moderate; estimated 10–50, enumerated at plan time.

Public API surface of `import CodeEditorPlugin` is unchanged. External consumers see no breaking change (all previously-public Core/ types remain reachable via the umbrella's new transitive dep on CodeEditorView).

---

## 2. Scope

### 2.1 Files that move to `Sources/CodeEditorView/`

**All of `Sources/CodeEditorPlugin/Core/`** — operationally a `git mv Sources/CodeEditorPlugin/Core Sources/CodeEditorView`. Preserves sub-directory structure under the new target root.

**Root-level files (51 total):**

29 stay-set per §6.2.12a triage table:

- `CodeEditorView.swift` (the class)
- 24 `CodeEditorView+*Extensions.swift` slices (`+AccessibilityExtensions`, `+AnnotationsExtensions`, `+CodeEditorAPIExtensions`, `+CodeFoldingExtensions`, `+CompletionExtensions`, `+Configuration`, `+ConfigurationExtensions`, `+CoreExtensions`, `+EdgeInsets`, `+EnclosingScrollView`, `+Extensions`, `+LayoutExtensions`, `+LineNumbersExtensions`, `+PerformanceExtensions`, `+PlatformCapabilities`, `+PlatformSpecificExtensions`, `+RangeBasedHighlightingExtensions`, `+Responder`, `+SetupExtensions`, `+SyntaxHighlightingExtensions`, `+TextInputFeatureTarget`, `+TextKitExtensions`, `+Theme`, `+TrackPerformance`)
- `CodeEditorViewDelegate.swift`, `CodeEditorViewDelegateProxy.swift`, `CodeEditorViewProtocol.swift`
- `UnifiedTextView+Extensions.swift`

22 Bucket 3 Defer per §6.2.12a triage:

- `ActorCoordinator.swift`
- `CodeEditorAPI.swift`
- `CodeEditorDependencies.swift`
- `CodeEditorRenderingDiagnostics.swift`
- `CodeFoldingCoordinatorService.swift`
- `EditorEvent.swift`, `EditorEventHandler.swift`, `EditorEventPublisher.swift`, `EditorEventTypes.swift` (event-system cluster, 4)
- `EditorLayoutService.swift`
- `EditorRuntime.swift`
- `EditorState.swift`, `EditorStateBridge.swift` (state cluster, 2)
- `GutterSizingService.swift`, `LineNumberCalculationService.swift`
- `IOSLargeFileOptimizer.swift`
- `MemoryManagementCoordinator.swift`
- `SyntaxHighlightingService.swift`
- `TextEditingService.swift`, `TextKitSetupHelper.swift` (TextKit2 orchestration, 2)
- `TextViewDelegateMultiplexer.swift`, `TextViewDelegateParticipant.swift` (delegate companions, 2)
- `UnifiedEventSystem.swift`

**Sub-directory files (~66 total):**

| Sub-dir | Files | Notes |
|---|---|---|
| `Actors/` | 6 | `CacheCoordinatorActor`, `CacheProtocol`, `DocumentStateActor`, `FileSystemActor`, `PerformanceMetricsActor`, `TextProcessingActor` |
| `Annotations/` | 1 | `AnnotationsDataSource` (§6.2.8e stay-set) |
| `Configuration/` | 1 | `EditorConfiguration+CodeFolding` (§6.2.12a Keep) |
| `Documents/` | 2 | `EditorDocument`, `EditorDocuments` (§6.2.12a Keep) |
| `Folding/` | 4 | `CodeFoldingConfiguration`, `CodeFoldingEngine`, `FoldingOperationsService`, `FoldPresentationStrategy` (§6.2.8a stay-set) |
| `Layout/` | 21 | §6.2.11 stay-set (container cluster, gutter cluster, minimap cluster, ContentView, ContainerView*, ViewportManager, EditorEventBusInstaller, ThemeableUIComponent+UmbrellaConformances, ComponentFrameCalculator) |
| `LSP/` | 2 | `LSPContentCoordinator`, `LSPSemanticTokenProvider` (§6.2.9 stay-set) |
| `Platform/` | 11 | View-coupled platform files per §6.2.12a Keep list (ContextMenuAction/Builder/Coordinator, CrossPlatformCoordinator + AppKit/UIKit exts, InputCoordinator, PlatformCapabilities+RecommendedConfiguration, PlatformConfigurations, ToolbarCoordinator, UnifiedDrawingCoordinator) |
| `Search/` | 1 | `SearchReplaceEngine` (§6.2.8d Keep) |
| `Symbols/` | 1 | `SymbolNavigator` (§6.2.8b Keep) |
| `SyntaxHighlighting/` | 9 + nested `RegexQuery/` | §6.2.7 stay-set (`RangeAttributeApplier`, `VisibleRangeProvider`, `HighlightProviderState`, `RangeBasedHighlightingController`, `RangeHighlightProviding` + 2 conformers, `AsyncSyntaxHighlighter`, `StreamingHighlighter`, plus nested `RegexQuery/RegexRangeHighlightProvider`) |
| `Text/` | 7 | View-coupled or downstream-dep text files (`LineGeometryEditHandler`, `ModernTextKitHelper`, `TextEditEventHub`, `TextKit2PerformanceHelper`, `TextKit2RenderingOptimizer`, `TextKitBridge`, `TextKitLineNumberHelper`) |

**Total carry-set: 118 files** (52 root + 66 sub-bucket per `find` at spec time; the 51-vs-52 discrepancy with the §6.2.12a triage table reflects post-§6.2.12c file deletions and the as-of-spec snapshot — plan Task 1 re-confirms exact counts).

### 2.2 Files that DO NOT move

- `Sources/CodeEditorPlugin/CodeEditorPlugin.swift` — stays in umbrella as the public-facing entry file. §6.2.14 will strip this to `@_exported import` declarations; §6.2.12 leaves its body unchanged.
- `Sources/CodeEditorPlugin/SwiftUI/` (17 files per `find` at spec time) — stays in umbrella; migrates in §6.2.13.
- `Sources/CodeEditorPlugin/Languages/` — its own SPM target via `path:`; unchanged.
- `Sources/CodeEditorPlugin/Resources/Info.plist` — umbrella's resource exclude; unchanged.

### 2.3 Cuts (anything deleted, by audit)

**Baseline assumption: zero deletions.** §6.2.12c already cleared the known dead code (`TextSystem` cluster + `CompletionAsyncError`).

If the plan-time per-file audit surfaces additional dead code (zero in-tree callers + zero tests + zero archived-doc references), it goes in its own commit *before* the bulk move, per §6.2.9a Debugger / §6.2.12c precedent. The spec carries no name baked-in; this is a writing-plans-time audit task.

### 2.4 Sub-target factoring (not in this chunk)

NEXT.md §10 flagged the event-system cluster (`EditorEvent*`, `UnifiedEventSystem`) as a "Possible sub-target candidate" and asked whether F3 glue files might get a dedicated "glue" target. **Both are deferred** per the user decision during brainstorming: this chunk produces one new target. Sub-target factoring can be revisited as a separate session if and when motivated by build-time or coupling pressure.

---

## 3. Dependencies

### 3.1 New target's direct deps

`CodeEditorView` declares these internal SPM target deps (subject to plan-time grep verification):

- `CodeEditorAnnotations`
- `CodeEditorCommon`
- `CodeEditorCompletion`
- `CodeEditorConfiguration`
- `CodeEditorDesignTokens`
- `CodeEditorDiagnostics`
- `CodeEditorFolding`
- `CodeEditorLanguages`
- `CodeEditorLayout`
- `CodeEditorLSP`
- `CodeEditorPlatform`
- `CodeEditorSymbols`
- `CodeEditorSyntaxHighlighting`
- `CodeEditorTextModel`
- `CodeEditorTheming`

Plus external products:

- `IssueReporting` (used by `CodeEditorRenderingDiagnostics`, `ActorCoordinator`, others — verify at plan time)
- `SwiftSyntax`, `SwiftParser` (used by `Core/SyntaxHighlighting/` stay-set files — verify at plan time)

**Final count: ~15 internal target deps + 2–3 external products.** The largest of any restructure target. Joins the §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.10 / §6.2.11 §4.1-dep-claim-correction pattern: NEXT.md §4.1 said "Everything in phases 1–7"; reality is the concrete list above *minus* the opt-in `CodeEditorWorkspace` / `CodeEditorSearch` targets.

### 3.2 Umbrella's dep changes

Umbrella `CodeEditorPlugin` target's `dependencies:` array:

- **Gains:** `CodeEditorView`.
- **Drops:** Most of the existing transitive deps (`CodeEditorAnnotations`, `CodeEditorCommon`, `CodeEditorCompletion`, `CodeEditorConfiguration`, `CodeEditorDesignTokens`, `CodeEditorDiagnostics`, `CodeEditorFolding`, `CodeEditorLanguages`, `CodeEditorLayout`, `CodeEditorLSP`, `CodeEditorPlatform`, `CodeEditorSymbols`, `CodeEditorSyntaxHighlighting`, `CodeEditorTextModel`, `CodeEditorTheming`) become reachable transitively via `CodeEditorView`. Plan Task 1 confirms which the umbrella's residual `SwiftUI/` slice still needs as *direct* deps (likely several — anything the SwiftUI slice imports must still be declared on the umbrella). Conservative default: keep the existing list; only drop entries verified unused by `Sources/CodeEditorPlugin/SwiftUI/` and `Sources/CodeEditorPlugin/CodeEditorPlugin.swift`.
- **Drops:** `SwiftSyntax`, `SwiftParser` *if* `Sources/CodeEditorPlugin/SwiftUI/` doesn't reference them (likely doesn't — SwiftSyntax/SwiftParser moved to `CodeEditorSyntaxHighlighting` per §6.2.7 deviation).

Umbrella's `exclude:` array drops `"Core"` (the directory no longer physically exists under `Sources/CodeEditorPlugin/`).

### 3.3 Test target dep changes

- `CodeEditorPluginTests` gains `CodeEditorView` as a direct dep.
- `CodeEditorSampleTests`, `CodeEditorUITests` likely gain `CodeEditorView` — confirm at plan time via `grep -l 'CodeEditorView\.' Tests/`.

### 3.4 Other consumer targets

- `CodeEditorUI`: likely gains `CodeEditorView` as a direct dep (audit pre-flight: does `CodeEditorUI` reference any type currently in `Core/`?).
- `CodeEditorSample`: likely gains `CodeEditorView` as a direct dep.

---

## 4. Productization (Approach A)

Add to `Package.swift` `products:`:

```swift
.library(name: "CodeEditorView", targets: ["CodeEditorView"]),
```

This places `CodeEditorView` in NEXT.md §6.3's "Probably" tier alongside `CodeEditorTextModel`, `CodeEditorLanguages`, `CodeEditorTheming`, `CodeEditorSyntaxHighlighting`, `CodeEditorSwiftUI`. External consumers that want finer-grained linking can `import CodeEditorView` directly; the default path stays `import CodeEditorPlugin`.

Public API surface of `import CodeEditorPlugin` is unchanged. Any external consumer of `import CodeEditorPlugin` continues to see every previously-public symbol from `Core/` because the umbrella's new dep on `CodeEditorView` provides transitive access. `@_exported import` is NOT added to the umbrella in this chunk — that's §6.2.14's job.

---

## 5. Consumer ripple

### 5.1 Umbrella source files

The umbrella's residual sources fall into three buckets:

1. **`Sources/CodeEditorPlugin/CodeEditorPlugin.swift` (root)** — references umbrella types. Body is unchanged in §6.2.12. If it currently has any `import` statements for symbols that moved, those become `import CodeEditorView`. Best guess: needs zero or one new import; verify at plan time.
2. **`Sources/CodeEditorPlugin/SwiftUI/` (17 files per `find` at spec time)** — heavily consume `CodeEditorView`, `EditorController`, `EditorConfiguration`, `EditorEvent*`, `Annotation*`, etc. Every file likely gains `import CodeEditorView` (plus retains its existing imports of leaf targets like `CodeEditorLanguages`, `CodeEditorCompletion`).
3. **`Sources/CodeEditorPlugin/Languages/`** — its own SPM target. No umbrella visibility into it.

Total umbrella import additions: 17 SwiftUI/ files + 0–1 root file = 17–18 files.

### 5.2 Same-package siblings

- `CodeEditorUI`: gains `import CodeEditorView` on any file that references types currently public in `Core/`. Plan Task 1 audit. Estimate: 0–5 files based on the §6.2.11 Layout precedent (Layout's UI ripple was zero).
- `CodeEditorSample`: gains `import CodeEditorView` on any file referencing former-Core/ types. Estimate: 5–15 files.
- `CodeEditorDesignTokens`, `CodeEditorCommon`, `CodeEditorPlatform`, etc.: no changes (they're upstream of CodeEditorView; nothing in them references Core/).
- `CodeEditorWorkspace`, `CodeEditorSearch`: no changes (opt-in, decoupled from umbrella).
- All other leaf targets (`CodeEditorConfiguration`, `CodeEditorTheming`, `CodeEditorLanguages`, `CodeEditorSyntaxHighlighting`, `CodeEditorDiagnostics`, `CodeEditorFolding`, `CodeEditorSymbols`, `CodeEditorAnnotations`, `CodeEditorCompletion`, `CodeEditorLSP`, `CodeEditorLayout`, `CodeEditorTextModel`): unchanged — they're upstream.

### 5.3 Tests

- `CodeEditorPluginTests` (176 files at spec time, mixed XCTest + Swift Testing): files that previously used `@testable import CodeEditorPlugin` to reach `Core/` internals add `@testable import CodeEditorView` alongside. Per §6.2.8d lesson, keep `@testable import CodeEditorPlugin` defensively; don't blanket-drop. Estimated 60–120 affected files.
- `CodeEditorSampleTests`: 0–5 files gain `import CodeEditorView` if they reference former-Core/ public symbols.
- `CodeEditorUITests`: same — minimal ripple expected.
- `CodeEditorDesignTokensTests`: no changes.

Estimated test-file ripple: 60–130 files across all test targets (driven by `CodeEditorPluginTests`'s 176-file size). Confirmed at plan time via `grep -rl 'Core/' Tests/` plus per-symbol greps.

---

## 6. Access-modifier promotions

### 6.1 Estimated size

Estimated 10–50 promotions, between §6.2.11 Layout (10) and §6.2.7 SH (~107). Exact count enumerated at plan time. The driver categories:

1. **Symbols consumed by umbrella's residual `SwiftUI/` slice** — must be `package` (cross-target same-package access). Includes any `internal` type in former-Core/ that the SwiftUI slice constructs or references.
2. **Symbols consumed by `CodeEditorUI` / `CodeEditorSample`** — must be `public`. Most are already public because they were umbrella-public APIs.
3. **Synth-init asymmetry** (per §6.2.8b/§6.2.8g/§6.2.12c precedent): public structs/actors/classes that have implicit inits and are now cross-target-constructed need explicit `public init(…)`. Pre-flight grep at plan time. SwiftLint `missing_docs` may bite on actor inits per the §6.2.12c lesson.

### 6.2 Pre-flight surface to audit

Plan Task 1 enumerates:

- Every `internal` (or unmodified, defaulting to `internal`) top-level type in moving files that the umbrella's `SwiftUI/` slice references.
- Every implicit init on a public type that any cross-target consumer constructs.
- The 6 `Core/Actors/` files (actors have the synth-init-defaults-to-internal-on-public-actor pattern that bit §6.2.12c).

---

## 7. Mid-execution relocations (anticipated)

§6.2.7 / §6.2.8g / §6.2.11 each surfaced mid-execution cross-target type relocations that the spec didn't anticipate (RangeStore → TextModel, SendableError → Common, SourcePosition → Common, EditorConfiguration: Hashable → Configuration). §6.2.12 is the largest move and is likely to surface more.

**Anticipated candidates** (verify at plan time; not pre-committed):

- **`SendableTypes`** is already in `CodeEditorCommon` per §6.2.12b. No relocation needed.
- **`SelectionState`, `EditorInteractionState`, `DirtyTracker`, `ErrorRecoveryCoordinator`** are already in `CodeEditorCommon` per §6.2.12c. No relocation needed.
- **Possible new relocations:** any small type in moving files that is needed by both `CodeEditorView` and a sibling-target upstream of it. Pattern from precedents: when the type is small and its sibling-target home is obvious, relocate during execution as a separate commit before or after the bulk move.

The plan should explicitly call out: if a mid-execution relocation is required, do it as a separate commit (commit-1-style scaffold + relocation, then bulk move). Don't bundle relocations into the bulk-move commit.

---

## 8. Commit / PR structure

Per the §6.2.12a/b/c precedent (multiple intermediate commits within one chunk, each building green standalone — the §6.2.12b broken-rename lesson):

1. **Commit 1 — scaffold (`§6.2.12 scaffold CodeEditorView target`):** Add `.library` product + new target to `Package.swift` with full dep list. Create `Sources/CodeEditorView/_ScaffoldPlaceholder.swift` (per the §6.2.8f Workspace lesson: SwiftPM requires at least one `.swift` file for a target with a `.library` product). Add umbrella's new dep on `CodeEditorView`. Build green; `swift build` succeeds with the placeholder. Tests not run.
2. **Commit 2 — pre-flight mid-execution relocations (if any, optional):** Per the §6.2.7 / §6.2.11 precedent. Only if Task 1 audit surfaces a cross-target relocation that must happen first. Skip if not needed.
3. **Commit 3 — bulk move (`§6.2.12 move Core/ to CodeEditorView`):** `git mv Sources/CodeEditorPlugin/Core/* Sources/CodeEditorView/` followed by deletion of placeholder. Update umbrella's `exclude:` (drop `"Core"`). Update all consumer imports (umbrella SwiftUI/, CodeEditorUI, CodeEditorSample, tests). Apply all access-modifier promotions. Build green; `swift build && swiftlint --fix && swiftlint` clean.
4. **Commit 4 — end-of-chunk verification:** Run `swift test --parallel`; expect 100% green. If a pre-existing test was broken pre-chunk and remains broken, document explicitly. (Per the memory: "Fix pre-existing failures, don't document them" — if the fix is one-line, fix it; if it's structural, surface it as a separate session.)
5. **Commit 5 — docs (`§6.2.12 documentation`):** Append a "Deviations during §6.2.12" block to NEXT.md §6.0. Update NEXT.md §10 to mark §6.2.12 done. Update NEXT.md §6.2.12 step row. Update CLAUDE.md "Source Tree" section to add `Sources/CodeEditorView/` as a real SPM target. Update CLAUDE.md "What Will Go Wrong" with any cross-cutting gotchas surfaced (synth-init quirks, test-import shifts, etc.). Update `docs/Diagrams/` if any reference the old `Sources/CodeEditorPlugin/Core/` path.

**5 commits target.** Plan-writing decides whether the bulk move (commit 3) is splittable into sub-bucket-by-sub-bucket commits. The §6.2.12b lesson (broken-rename intermediates) discourages this — atomic-move-plus-fix is safer than rename-only-then-fix.

**One PR.** Single PR / single chunk. Not combined with §6.2.13 or §6.2.14.

---

## 9. Verification

**Per-commit verification:**

- `swift build` green.
- `swiftlint --fix && swiftlint` clean.
- Targeted `swift test --filter <Suite>` for any suite affected by that commit's moves.

Skip full `swift test --parallel` between additive-only commits in the same session per memory.

**End-of-chunk verification (Commit 4):**

- `swift build && swiftlint --fix && swiftlint && swift test --parallel` clean.
- Sample app launches and types a character (NSTextView-init-invariant memory).
- Build green on every commit when bisected (per §6.2.12b lesson).
- `swift package describe` shows the new `CodeEditorView` target with the expected dep list.

**Pre-flight verification (in writing-plans Task 1):**

- Enumerate every file in `Sources/CodeEditorPlugin/Core/**/*.swift` and confirm count.
- `grep -l "import CodeEditorPlugin" Sources/CodeEditorPlugin/SwiftUI/` — survey SwiftUI slice's umbrella imports (expect zero since they're same-target).
- `grep -rln "Core/" Sources/CodeEditorPlugin/SwiftUI/ Sources/CodeEditorUI/ Sources/CodeEditorSample/ Tests/` — survey consumer references.
- `grep -rln "@testable import CodeEditorPlugin" Tests/` — survey `@testable` adoption baseline.
- `grep -rln "<type>" Sources/ Tests/` per moving public type — enumerate consumer ripple per file.
- Audit `internal` modifiers in `Core/` against the consumer-survey result — every consumed `internal` symbol needs `package` or `public`.

---

## 10. Risks & mitigations

1. **Target name collides with class name (`CodeEditorView`).** Cosmetic only — Swift namespaces modules and types separately. The umbrella file `Sources/CodeEditorView/CodeEditorView.swift` defining `public class CodeEditorView` is unusual but valid. Mitigation: document in `CLAUDE.md` "What Will Go Wrong"; no code change required.
2. **Promotion surface unknown until plan-time grep.** §6.2.7 SH had ~107; §6.2.11 Layout had 10. The spread is wide. Mitigation: writing-plans Task 1 explicitly enumerates each promotion; bulk script handles `internal → package` for routine cases; manual edits for protocol-conformance and synth-init artifacts.
3. **One-PR size / reviewer fatigue.** ~117 file moves + Package.swift + ~30–50 import additions + ~10–50 promotions = a very large diff. Mitigation: 5-commit structure where each commit has focused scope; commit messages describe the per-commit slice precisely; spec document linked in PR description.
4. **`@testable import` shifts on ~50 test files.** Mistakes here are silent — a test that was reaching internal symbols via `@testable import CodeEditorPlugin` may compile after the move if the symbol is still internal-in-the-umbrella (i.e., the move didn't include it) but for the wrong reason. Mitigation: per the §6.2.8d "don't blanket-drop @testable" lesson, keep `@testable import CodeEditorPlugin` defensively on every test file that has it today; only ADD `@testable import CodeEditorView` where needed.
5. **`Core/Layout/` is the densest sub-bucket (21 files) with the most cross-target interactions** — risk of import-graph surprise. Mitigation: if Task 1 audit surfaces a layout-specific surprise, handle it as a separate commit before the bulk move (precedent: §6.2.7 split `RangeQueryParser` out as its own commit; §6.2.11 split `EditorLayoutTypes` out).
6. **SwiftUI/ slice (~19 files in umbrella) is the largest in-tree consumer.** If any file references an `internal` Core/ symbol that the move doesn't promote, the umbrella stops compiling. Mitigation: explicit grep pre-flight; SwiftUI slice import update is part of Commit 3, same commit as the bulk move.
7. **Bisectability.** §6.2.12b had a broken-rename intermediate (commit `29e4a70` didn't build standalone). Mitigation: the plan explicitly mandates `git add` destination paths before deletions; verify each commit builds standalone before pushing.
8. **`CodeEditorSyntaxHighlighting` adds `SwiftSyntax`/`SwiftParser` to CodeEditorView's deps.** The 9 `Core/SyntaxHighlighting/` stay-set files (`AsyncSyntaxHighlighter`, etc.) may consume `SwiftSyntax` symbols. Verify at plan time; if so, CodeEditorView declares the external products as direct deps (umbrella drops them).
9. **`IOSLargeFileOptimizer.swift` is iOS-specific.** Verify `#if canImport(UIKit)` is preserved end-to-end. No new convention work required (per the §6.2.10 deviation block, this file was relocated mid-extraction precisely because it casts to `CodeEditorView`).

---

## 11. Non-goals (this chunk only)

- **Not** stripping the umbrella `CodeEditorPlugin` to `@_exported import` only. That's §6.2.14. The umbrella target retains its current sources (root file + SwiftUI/ + Languages/ path-target + Resources).
- **Not** moving `SwiftUI/` out of the umbrella. That's §6.2.13.
- **Not** renaming `CodeEditorPlugin` → `CodeEditorToolkit`. Deferred to the workspace move (§6.2.16) per NEXT.md §8.3 risk advice.
- **Not** introducing sub-targets for the event-system / state-cluster / glue files. They all go into one `CodeEditorView` target. Sub-target factoring deferred.
- **Not** adding `CodeEditorTestSupport` (that's §6.2.15).
- **Not** rewriting any feature code. Per NEXT.md §9: "import-graph surgery, not feature work."
- **Not** changing supported platforms or reintroducing TextKit1 fallbacks.
- **Not** auditing the F3 sub-buckets to re-classify Stay → Move (any such re-classification was the job of §6.2.12a/b/c; this chunk takes the §6.2.12c audit table as authoritative).
- **Not** addressing the SmartEditing deferral (§6.2.8c). SmartEditing's `CodeEditorView`-coupling is precisely what §6.2.12 resolves; a separate §6.2.8c extraction (or merger into `CodeEditorView`'s scope) is a follow-up session.

---

## 12. Open questions for plan-writing

These are not blockers for the spec, but the plan should resolve them in Task 1:

1. **`Core/SyntaxHighlighting/`'s SwiftSyntax/SwiftParser usage.** Does the stay-set actually use these? If yes, CodeEditorView declares them; umbrella drops them. If no, the umbrella retains the dep until §6.2.14.
2. **`Core/Layout/`'s ComponentFrameCalculator transitive reach.** Per §6.2.11 deviation, this file consumes `GutterSizingService` which transitively reaches `LineNumberCalculationService` (umbrella-resident, 14 `CodeEditorView` refs). All three now coexist in `CodeEditorView`; verify no further surprises.
3. **Whether `CodeEditorPlugin.swift` (the root file) references any moving Core/ types.** Probably zero — it's likely a near-empty file today. Quick `cat`/grep at plan time.
4. **The `+Theme` extension.** `Core/CodeEditorView+Theme.swift` is one of the 24 +Extensions slices. Verify it doesn't accidentally need `import CodeEditorTheming` as a *direct* dep beyond what the umbrella has set up.
5. **`CodeFoldingCoordinatorService.swift`** orchestrates `Core/Folding/`. Verify its public API surface — if anything is currently `package`-visible only and now needs cross-target access from the umbrella SwiftUI/ slice, it needs `public`.
6. **`MemoryManagementCoordinator.createLSPManager`** is public API per the §6.2.9 deviation block. Verify it still compiles after the move (it should — both `MemoryManagementCoordinator` and the LSP types are now in the same target boundary or transitively reachable).

---

## 13. Estimated effort

- Spec writing: done.
- Plan writing: 1–2 hours (one large pre-flight Task 1 audit + 4–5 Move tasks + verification).
- Implementation: half-day per NEXT.md §10. Most of the time is the per-commit verification loop, not the moves themselves.

---

## 14. Success criteria

This chunk is done when:

1. `Sources/CodeEditorView/` exists as a real SPM target with `.library` product.
2. `Sources/CodeEditorPlugin/Core/` no longer exists.
3. Umbrella `CodeEditorPlugin` target's `dependencies:` includes `CodeEditorView`; `exclude:` no longer mentions `"Core"`.
4. `swift build && swiftlint --fix && swiftlint && swift test --parallel` green.
5. Sample app launches and types a character.
6. Public API surface of `import CodeEditorPlugin` is unchanged (no breaking changes for external consumers).
7. NEXT.md / CLAUDE.md / `docs/Diagrams/` updated to reflect the new target.
8. §6.2.13 SwiftUI extraction is unblocked (the SwiftUI/ slice now sees `CodeEditorView` as a separate target it can depend on).
9. §6.2.14 umbrella re-export is unblocked (the umbrella's source tree is reduced to root + SwiftUI/ + Languages/-path + Resources/; the path to a single `@_exported import` file is clear).
