# CodeEditorLayout Extraction (§6.2.11) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a new `CodeEditorLayout` SPM target containing ~22 of the 42 post-split `Sources/CodeEditorPlugin/Layout/` files (41 originals + 1 file split into 2 halves). Productized as a `.library` per NEXT.md §6.3 "Probably" listing. Carve-out shape — 19 `CodeEditorView`-coupled or umbrella-class-extension files + 1 split-out half relocate to a new umbrella `Core/Layout/` bucket via a pre-commit. The umbrella `CodeEditorPlugin` depends on the new target (matches §6.2.9 LSP / §6.2.10 Diagnostics precedent — productized + umbrella-coupled).

**Architecture:** Three commits. (1) Pre-commit relocation of the 19 carve-out files into umbrella `Core/Layout/` plus the in-place split of `ThemeableUIComponent+Conformances.swift` into umbrella + Layout halves (matches §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e pre-commit cadence). (2) Main extraction commit — scaffold target, `Package.swift` edits (target + `.library` product + dep additions), `git mv` 22 files (21 originals + 1 split-out), access-modifier promotions (20–40 expected), import additions across umbrella + sample (verify) + tests. (3) `NEXT.md` SHA back-fill commit. Closes §6.2.11 of the restructure; next is §6.2.12 Core split.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target dependencies (verified by per-file `import` survey): `CodeEditorAnnotations`, `CodeEditorCommon`, `CodeEditorConfiguration`, `CodeEditorDesignTokens`, `CodeEditorPlatform`, `CodeEditorSyntaxHighlighting`, `CodeEditorTheming` (7 deps). Corrects NEXT.md §4.1's speculative `TextModel, Theming, Completion, Annotations, Folding, Platform` claim: actual set adds `Common, Configuration, DesignTokens, SyntaxHighlighting` and drops `TextModel, Completion, Folding`. No new third-party deps.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-layout-extraction-design.md` (commit `459eb6b`).

**Lessons baked in:**

- §6.2.7 SH: pre-commit relocation pattern for carve-out files; compile-driven access-modifier promotions; WIP checkpoint if promotion count exceeds ~30.
- §6.2.8b Symbols: synthesized `init`s on `public` structs default to `internal` — add explicit `package init(...)` or `public init(...)` when promoting cross-target access.
- §6.2.8d Search: do NOT blanket-drop `@testable import CodeEditorPlugin` from tests; internal umbrella symbols may still be required.
- §6.2.8e Annotations: bare-word grep (`\bLayout\b`, `\bGutter\b`, `\bMinimap\b`, `\bGlass\b`, etc.) catches consumers that compound-name grep misses; run the bare-word follow-up before declaring the consumer inventory final.
- §6.2.8f Workspace: SwiftPM resolution between scaffold and `git mv` needs both a `.gitkeep` placeholder AND at least one `.swift` placeholder for a target with a `.library` product (both removed in Task 4 once real files arrive).
- §6.2.9 LSP / §6.2.10 Diagnostics: productized opt-in pattern with the umbrella depending on the new target — `.library` entry exposes a standalone product for external consumers without removing the umbrella's dep.
- §6.2.9 LSP: SwiftLint's `sorted_imports` rule treats uppercase `L` (`LSP`) > lowercase `a` (`Languages`), so import ordering is `CodeEditorLanguages` < `CodeEditorLayout` < `CodeEditorLSP`. Verify SwiftLint sorts the new imports correctly; don't hand-write the order, let `swiftlint --fix` apply it.

---

### Task 1: Pre-flight audit

**Files:** read-only.

- [ ] **Step 1: Confirm carry-set inventory (41 files in `Layout/`) is unchanged since spec**

Run:
```bash
find Sources/CodeEditorPlugin/Layout -name '*.swift' | sort
```

Expected: exactly these 41 paths (alphabetical):
```
Sources/CodeEditorPlugin/Layout/AdaptiveLayoutProvider.swift
Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Configuration.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Keyboard.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Minimap.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift
Sources/CodeEditorPlugin/Layout/CommandClickModifier.swift
Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift
Sources/CodeEditorPlugin/Layout/CompletionPopoverThemeMetrics.swift
Sources/CodeEditorPlugin/Layout/ComponentFrameCalculator.swift
Sources/CodeEditorPlugin/Layout/ConfigurationFormControls.swift
Sources/CodeEditorPlugin/Layout/ContainerLayoutHelper.swift
Sources/CodeEditorPlugin/Layout/ContainerViewHelper.swift
Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift
Sources/CodeEditorPlugin/Layout/ContentView.swift
Sources/CodeEditorPlugin/Layout/EditorEventBus.swift
Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift
Sources/CodeEditorPlugin/Layout/FoldChevronAnimation.swift
Sources/CodeEditorPlugin/Layout/FoldChevronHitTester.swift
Sources/CodeEditorPlugin/Layout/Glass/_GlassSurface.swift
Sources/CodeEditorPlugin/Layout/GutterDebugSupport.swift
Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift
Sources/CodeEditorPlugin/Layout/GutterView+AccessibilityExtensions.swift
Sources/CodeEditorPlugin/Layout/GutterView.swift
Sources/CodeEditorPlugin/Layout/GutterViewModel.swift
Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift
Sources/CodeEditorPlugin/Layout/InsertionPointIndicating.swift
Sources/CodeEditorPlugin/Layout/InsertionPointView.swift
Sources/CodeEditorPlugin/Layout/LayoutCache.swift
Sources/CodeEditorPlugin/Layout/LayoutCoordinator.swift
Sources/CodeEditorPlugin/Layout/LayoutOptimizer.swift
Sources/CodeEditorPlugin/Layout/LineHighlightView.swift
Sources/CodeEditorPlugin/Layout/MinimapStyleDataSource.swift
Sources/CodeEditorPlugin/Layout/MinimapView.swift
Sources/CodeEditorPlugin/Layout/MinimapViewModel.swift
Sources/CodeEditorPlugin/Layout/ResponsiveLayoutProvider.swift
Sources/CodeEditorPlugin/Layout/TextHoverModifier.swift
Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift
Sources/CodeEditorPlugin/Layout/ViewportManager.swift
```

If any file is missing or extras appear, stop and consult the user — the spec is stale.

- [ ] **Step 2: Re-verify the carve-out audit's `CodeEditorView` structural-coupling counts**

Run:
```bash
for f in Sources/CodeEditorPlugin/Layout/*.swift Sources/CodeEditorPlugin/Layout/Glass/*.swift; do n=$(grep -c "CodeEditorView" "$f" 2>/dev/null); echo "$n $(basename "$f")"; done | sort -rn
```

Expected: 14 files with ≥1 ref + 27 files with 0 refs. Specifically:
- 29: ContentView.swift
- 11: ContainerViewHelper.swift
- 5: GutterViewRenderer.swift, GutterView.swift, ContainerViewInitializer.swift, CodeEditorContainerView+AppKitExtensions.swift
- 3: MinimapView.swift, GutterView+AccessibilityExtensions.swift, GutterInteractionHandler.swift
- 2: MinimapViewModel.swift, GutterViewModel.swift, EditorEventBusInstaller.swift
- 1: ViewportManager.swift, ContainerLayoutHelper.swift, CodeEditorContainerView.swift

If counts diverge, the carve-out shape may have shifted. Investigate before proceeding.

- [ ] **Step 3: Verify `ThemeableUIComponent` protocol location**

Run:
```bash
grep -rn "protocol ThemeableUIComponent" Sources/ 2>/dev/null
```

Expected: exactly one hit, in `Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift` line 33, declaring `public protocol ThemeableUIComponent: AnyObject`.

If the protocol is found elsewhere (e.g. in umbrella `Core/`), the split is blocked — stop and re-read spec §10 Risk 1's contingency.

- [ ] **Step 4: Read `ThemeableUIComponent+Conformances.swift` to confirm 7-conformance structure**

Read `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` in full. Expected content (verified by spec author):

```swift
// Empty-extension conformance declarations for the views that already
// expose `appliedTheme` + `apply(theme:)`. Keeping the conformances in a
// dedicated file lets each view's primary file stay focused on its own
// concerns; the shape of the protocol is defined in BaseUIComponents.swift.

import CodeEditorAnnotations
import Foundation

extension GutterView: ThemeableUIComponent {}

extension LineHighlightView: ThemeableUIComponent {}

extension InsertionPointView: ThemeableUIComponent {}

extension AnnotationsContentView: ThemeableUIComponent {}

extension AnnotationView: ThemeableUIComponent {}

#if canImport(AppKit)
extension AppKitMinimapView: ThemeableUIComponent {}
#elseif canImport(UIKit)
extension UIKitMinimapView: ThemeableUIComponent {}
#endif
```

The 7 conformances split as:

- **Stay in umbrella (3 conformances):** `GutterView` (in umbrella stay-set), `AppKitMinimapView` + `UIKitMinimapView` (defined in `MinimapView.swift` — umbrella stay-set).
- **Move to carry-set (4 conformances):** `LineHighlightView` + `InsertionPointView` (carry-set types), `AnnotationsContentView` + `AnnotationView` (`CodeEditorAnnotations` types — accessible from the carry-set target via `import CodeEditorAnnotations`).

If the actual file contents differ from the expected listing above, halt and adjust the Task 2 split work accordingly.

- [ ] **Step 5: Verify `AppKitMinimapView` / `UIKitMinimapView` location**

Run:
```bash
grep -rn "class AppKitMinimapView\|class UIKitMinimapView" Sources/ 2>/dev/null
```

Expected: both classes declared in `Sources/CodeEditorPlugin/Layout/MinimapView.swift`. If located elsewhere, the umbrella half of the split needs adjustment (or those conformances may move to the carry-set after all).

- [ ] **Step 6: Verify carry-set imports match the spec's dep list**

Run:
```bash
for f in Sources/CodeEditorPlugin/Layout/AdaptiveLayoutProvider.swift \
         Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift \
         Sources/CodeEditorPlugin/Layout/CommandClickModifier.swift \
         Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift \
         Sources/CodeEditorPlugin/Layout/CompletionPopoverThemeMetrics.swift \
         Sources/CodeEditorPlugin/Layout/ComponentFrameCalculator.swift \
         Sources/CodeEditorPlugin/Layout/ConfigurationFormControls.swift \
         Sources/CodeEditorPlugin/Layout/EditorEventBus.swift \
         Sources/CodeEditorPlugin/Layout/FoldChevronAnimation.swift \
         Sources/CodeEditorPlugin/Layout/FoldChevronHitTester.swift \
         Sources/CodeEditorPlugin/Layout/Glass/_GlassSurface.swift \
         Sources/CodeEditorPlugin/Layout/GutterDebugSupport.swift \
         Sources/CodeEditorPlugin/Layout/InsertionPointIndicating.swift \
         Sources/CodeEditorPlugin/Layout/InsertionPointView.swift \
         Sources/CodeEditorPlugin/Layout/LayoutCache.swift \
         Sources/CodeEditorPlugin/Layout/LayoutCoordinator.swift \
         Sources/CodeEditorPlugin/Layout/LayoutOptimizer.swift \
         Sources/CodeEditorPlugin/Layout/LineHighlightView.swift \
         Sources/CodeEditorPlugin/Layout/MinimapStyleDataSource.swift \
         Sources/CodeEditorPlugin/Layout/ResponsiveLayoutProvider.swift \
         Sources/CodeEditorPlugin/Layout/TextHoverModifier.swift \
         Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift; do
  echo "=== $(basename "$f") ==="
  grep '^import CodeEditor' "$f"
done
```

Expected target deps (union of `import CodeEditor*` across all carry-set files):
- `CodeEditorAnnotations` (ThemeableUIComponent+Conformances)
- `CodeEditorCommon` (LayoutCache)
- `CodeEditorConfiguration` (AdaptiveLayoutProvider, ComponentFrameCalculator, FoldChevronAnimation, LayoutCache, LayoutCoordinator, LayoutOptimizer, ResponsiveLayoutProvider)
- `CodeEditorDesignTokens` (CompletionCellComponents, CompletionPopoverThemeMetrics, FoldChevronAnimation, _GlassSurface)
- `CodeEditorPlatform` (BaseUIComponents, CompletionCellComponents, CompletionPopoverThemeMetrics, ComponentFrameCalculator, InsertionPointIndicating, InsertionPointView, LayoutCoordinator, LineHighlightView, MinimapStyleDataSource)
- `CodeEditorSyntaxHighlighting` (MinimapStyleDataSource)
- `CodeEditorTheming` (BaseUIComponents, CompletionCellComponents, CompletionPopoverThemeMetrics, _GlassSurface, InsertionPointView, LineHighlightView)

If new `CodeEditor*` imports appear (e.g. `CodeEditorTextModel`, `CodeEditorCompletion`, `CodeEditorFolding`, `CodeEditorDiagnostics`), add them to the Task 3 Step 3 dep list. If any expected import is missing, drop the dep.

- [ ] **Step 7: Survey "pure" files for stay-set type references (§6.2.8e bare-word grep)**

Each carry-set candidate must not reach for umbrella stay-set types either. Run for the stay-set umbrella-resident types:

```bash
for type in GutterView MinimapView CodeEditorContainerView ContentView EditorContentView EditorEventBusInstaller ContainerViewHelper ContainerViewInitializer ContainerLayoutHelper ViewportManager; do
  echo "=== $type ==="
  grep -lnE "\b${type}\b" Sources/CodeEditorPlugin/Layout/*.swift Sources/CodeEditorPlugin/Layout/Glass/*.swift 2>/dev/null
done
```

Expected: each stay-set type is referenced only by other stay-set files (including its own file). If a candidate carry-set file references any stay-set type structurally (i.e. in code, not doc comments), that file must move to the stay-set instead.

Particular attention:
- `GutterDebugSupport.swift` — name suggests it references `GutterView`. If it does, it stays in the umbrella stay-set, and the Task 2 Step 2 move list grows from 19 to 20 (the carry-set drops by 1).
- `MinimapStyleDataSource.swift` — likely consumed by `MinimapView` / `MinimapViewModel` (stay-set → carry-set direction is fine). The protocol must not back-reference `MinimapView` or `MinimapViewModel`. Confirm by reading the file.

If a file shifts class, update the Task 2 Step 2 and Task 4 Step 1 file lists.

- [ ] **Step 8: Enumerate umbrella consumer-ripple via compound-name grep**

Run:
```bash
grep -rlnE "\b(LayoutCache|LayoutCoordinator|LayoutOptimizer|EditorEventBus|MinimapStyleDataSource|FoldChevronAnimation|FoldChevronHitTester|_GlassSurface|InsertionPointView|InsertionPointIndicating|LineHighlightView|BaseUIComponents|ComponentFrameCalculator|ConfigurationFormControls|AdaptiveLayoutProvider|ResponsiveLayoutProvider|CompletionCellComponents|CompletionPopoverThemeMetrics|CommandClickModifier|TextHoverModifier|ThemeableUIComponent|GutterDebugSupport)\b" Sources/CodeEditorPlugin --include='*.swift' 2>/dev/null | grep -v "Sources/CodeEditorPlugin/Layout/" | sort -u
```

Expected: the list of umbrella source files outside `Layout/` that reference carry-set types. After Task 2's relocation, all of these (plus the relocated `Core/Layout/` files) will need `import CodeEditorLayout`. Capture the list — Task 6 needs it.

- [ ] **Step 9: Bare-word grep follow-up for umbrella consumers**

Run:
```bash
grep -rln "\bThemeableUIComponent\b\|\bMinimapStyleRun\b\|\bConfigurableUIComponent\b" Sources/CodeEditorPlugin --include='*.swift' 2>/dev/null | grep -v "Sources/CodeEditorPlugin/Layout/" | sort -u
```

Add any new paths to the Task 6 umbrella import list. `ConfigurableUIComponent` is defined in `BaseUIComponents.swift` and may be more widely consumed than the conformance hits.

- [ ] **Step 10: Confirm sample consumer-ripple inventory**

Run:
```bash
grep -rlnE "\b(LayoutCache|LayoutCoordinator|LayoutOptimizer|EditorEventBus|MinimapStyleDataSource|FoldChevronAnimation|FoldChevronHitTester|_GlassSurface|InsertionPointView|InsertionPointIndicating|LineHighlightView|BaseUIComponents|ComponentFrameCalculator|ConfigurationFormControls|AdaptiveLayoutProvider|ResponsiveLayoutProvider|CompletionCellComponents|CompletionPopoverThemeMetrics|CommandClickModifier|TextHoverModifier|ThemeableUIComponent|MinimapStyleRun|ConfigurableUIComponent|GutterDebugSupport)\b" Sources/CodeEditorSample --include='*.swift' 2>/dev/null | sort -u
```

Expected: no output (spec says sample has zero Layout-resident references). If hits appear:
1. Read each hit's surrounding context — doc-comment-only references can be ignored (§6.2.8d/§6.2.8e/§6.2.8f lesson).
2. Code-level references mean `CodeEditorSample` target needs `CodeEditorLayout` added to its `dependencies:` (Task 3 Step 6 — add a new step) and the consuming sample files need `import CodeEditorLayout` (Task 6 — add to sample list).

If verified clean, sample target requires no change. Document in Task 9's deviations block.

- [ ] **Step 11: Confirm UI target needs no new dep**

Run:
```bash
grep -rlnE "\b(LayoutCache|LayoutCoordinator|EditorEventBus|ThemeableUIComponent|MinimapStyleDataSource|ConfigurableUIComponent|BaseUIComponents)\b" Sources/CodeEditorUI --include='*.swift' 2>/dev/null
```

Expected: **no output**. If any path prints, the `CodeEditorUI` target needs `CodeEditorLayout` added to its `dependencies:` — capture the paths and amend the plan accordingly.

- [ ] **Step 12: Confirm test consumer-ripple inventory**

Run:
```bash
grep -rlnE "\b(LayoutCache|LayoutCoordinator|LayoutOptimizer|EditorEventBus|MinimapStyleDataSource|FoldChevronAnimation|FoldChevronHitTester|InsertionPointView|LineHighlightView|ThemeableUIComponent|MinimapStyleRun|ConfigurableUIComponent|BaseUIComponents|AdaptiveLayoutProvider|ResponsiveLayoutProvider)\b" Tests --include='*.swift' 2>/dev/null | sort -u
```

Expected: 5–10 plugin-test files in `Tests/CodeEditorPluginTests/`. Capture the list — Task 6 Step 7 needs it.

Run the bare-word grep follow-up for stay-set types that tests may reference WITHOUT needing the new import (because the stay-set types are still in umbrella):

```bash
grep -rlnE "\b(GutterView|MinimapView|MinimapViewModel|GutterViewModel|ViewportManager|ContainerViewHelper|ContainerViewInitializer|FoldChevronAnimation|FoldChevronHitTester)\b" Tests --include='*.swift' 2>/dev/null | sort -u
```

Cross-reference: a test file appearing in the second list but NOT the first does NOT need `import CodeEditorLayout` (it only references stay-set types still in umbrella). A test file appearing in both lists DOES need the new import.

- [ ] **Step 13: Verify clean working tree**

Run:
```bash
git status --short
```

Expected: no output (clean tree). If there are uncommitted changes, stop and ask the user.

- [ ] **Step 14: Capture baseline test pass count for affected suites**

Run:
```bash
swift test --filter Layout 2>&1 | tail -5
swift test --filter Gutter 2>&1 | tail -5
swift test --filter Minimap 2>&1 | tail -5
swift test --filter FoldChevron 2>&1 | tail -5
swift test --filter EditorEventBus 2>&1 | tail -5
swift test --filter ThemeableUIComponent 2>&1 | tail -5
```

Note the pass counts for each filter. Task 7 Step 4 verifies the same counts after extraction. If any test is failing on baseline, do NOT proceed — apply memory `feedback_fix_pre_existing_failures.md` and fix the failure(s) first, then re-baseline.

- [ ] **Step 15: Capture starting SHA for the NEXT.md back-reference**

Run:
```bash
git log -1 --format=%h
```

Save the SHA. It gets referenced in NEXT.md §6.0 in Task 9.

---

### Task 2: Pre-commit — relocate the 19 stay-set files and split `ThemeableUIComponent+Conformances.swift`

This is its own commit so the carve-out relocation + split is reviewable in isolation, matching the §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.9 pre-commit cadence.

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/Layout/` (new directory)
- Create: `Sources/CodeEditorPlugin/Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift` (split-out new file)
- Modify: `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` (remove 3 conformances)
- Move (git mv): 19 stay-set files from `Sources/CodeEditorPlugin/Layout/` to `Sources/CodeEditorPlugin/Core/Layout/`

- [ ] **Step 1: Create the destination directory**

Run:
```bash
mkdir -p Sources/CodeEditorPlugin/Core/Layout
```

- [ ] **Step 2: `git mv` the 19 stay-set files**

Run as a single chained command so any individual `mv` failure halts the rest:

```bash
git mv Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift Sources/CodeEditorPlugin/Core/Layout/CodeEditorContainerView.swift && \
git mv Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift Sources/CodeEditorPlugin/Core/Layout/CodeEditorContainerView+AppKitExtensions.swift && \
git mv Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Configuration.swift Sources/CodeEditorPlugin/Core/Layout/CodeEditorContainerView+Configuration.swift && \
git mv Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Keyboard.swift Sources/CodeEditorPlugin/Core/Layout/CodeEditorContainerView+Keyboard.swift && \
git mv Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Minimap.swift Sources/CodeEditorPlugin/Core/Layout/CodeEditorContainerView+Minimap.swift && \
git mv Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift Sources/CodeEditorPlugin/Core/Layout/CodeEditorContainerView+UIKitExtensions.swift && \
git mv Sources/CodeEditorPlugin/Layout/ContainerLayoutHelper.swift Sources/CodeEditorPlugin/Core/Layout/ContainerLayoutHelper.swift && \
git mv Sources/CodeEditorPlugin/Layout/ContainerViewHelper.swift Sources/CodeEditorPlugin/Core/Layout/ContainerViewHelper.swift && \
git mv Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift Sources/CodeEditorPlugin/Core/Layout/ContainerViewInitializer.swift && \
git mv Sources/CodeEditorPlugin/Layout/ContentView.swift Sources/CodeEditorPlugin/Core/Layout/ContentView.swift && \
git mv Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift Sources/CodeEditorPlugin/Core/Layout/EditorEventBusInstaller.swift && \
git mv Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift Sources/CodeEditorPlugin/Core/Layout/GutterInteractionHandler.swift && \
git mv Sources/CodeEditorPlugin/Layout/GutterView.swift Sources/CodeEditorPlugin/Core/Layout/GutterView.swift && \
git mv Sources/CodeEditorPlugin/Layout/GutterView+AccessibilityExtensions.swift Sources/CodeEditorPlugin/Core/Layout/GutterView+AccessibilityExtensions.swift && \
git mv Sources/CodeEditorPlugin/Layout/GutterViewModel.swift Sources/CodeEditorPlugin/Core/Layout/GutterViewModel.swift && \
git mv Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift Sources/CodeEditorPlugin/Core/Layout/GutterViewRenderer.swift && \
git mv Sources/CodeEditorPlugin/Layout/MinimapView.swift Sources/CodeEditorPlugin/Core/Layout/MinimapView.swift && \
git mv Sources/CodeEditorPlugin/Layout/MinimapViewModel.swift Sources/CodeEditorPlugin/Core/Layout/MinimapViewModel.swift && \
git mv Sources/CodeEditorPlugin/Layout/ViewportManager.swift Sources/CodeEditorPlugin/Core/Layout/ViewportManager.swift
```

Verify 19 files moved:
```bash
ls Sources/CodeEditorPlugin/Core/Layout/ | wc -l
```

Expected: `19`.

And the source dir still has the other 22:
```bash
find Sources/CodeEditorPlugin/Layout -name '*.swift' | wc -l
```

Expected: `22` (21 carry-set files in `Layout/` + `Layout/Glass/_GlassSurface.swift` + still-unsplit `ThemeableUIComponent+Conformances.swift`).

Wait — the math is 22 minus the conformance split. Let me clarify: `Layout/` now has 21 carry-set files including `ThemeableUIComponent+Conformances.swift` (unmodified at this point) plus `Glass/_GlassSurface.swift` (1 file under `Glass/`). The `find` count includes the Glass subdir.

Expected: `22` (21 top-level Layout files + 1 Glass file).

If counts diverge, an extra/missing `git mv` happened — diff the `git status --short` output against the expected 19 renames and reconcile before proceeding.

- [ ] **Step 3: Leave `ThemeableUIComponent+Conformances.swift` UNCHANGED in this pre-commit**

The conformance split is deferred to the main commit (Task 4 Steps 3–6). Reason: the umbrella half needs `import CodeEditorLayout`, which doesn't exist as a target until Task 3. Splitting in this pre-commit would require either a stub import or a temporary protocol redefinition — both ugly. Defer.

Verify the file is still in its original location:
```bash
ls Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift
```

Expected: file exists, untouched.

- [ ] **Step 4: Verify build is green after relocation**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!` with no errors. The 19 relocated files compile from their new umbrella location; nothing changed in terms of module membership (all are still in the umbrella `CodeEditorPlugin` target). The `ThemeableUIComponent+Conformances.swift` file is unchanged.

If the build fails, the most likely cause is a path-based assertion in a test or a stale path reference — read the error carefully.

- [ ] **Step 5: Run targeted tests to confirm no behavioral regression**

Run:
```bash
swift test --filter Layout 2>&1 | tail -5 && \
swift test --filter Gutter 2>&1 | tail -5 && \
swift test --filter Minimap 2>&1 | tail -5 && \
swift test --filter ThemeableUIComponent 2>&1 | tail -5
```

Expected: same pass counts as Task 1 Step 14 baseline.

Also re-check `ReviewRemediationRegressionTests` (which §6.2.8e fixed for stale path strings):

```bash
swift test --filter ReviewRemediation 2>&1 | tail -10
```

Expected: pass. If a test asserts on a path containing `Sources/CodeEditorPlugin/Layout/<file>` for any relocated file, update the assertion to `Sources/CodeEditorPlugin/Core/Layout/<file>`. Mirror the §6.2.8e collateral fix and capture the change in this pre-commit.

- [ ] **Step 6: Commit the pre-commit relocation**

Run:
```bash
git add Sources/CodeEditorPlugin/Core/Layout Sources/CodeEditorPlugin/Layout
git status --short
```

Expected: exactly 19 renames (the 19 stay-set files), no other changes (the conformance file remains untouched until Task 4).

Then:
```bash
git commit -m "$(cat <<'EOF'
Relocate Layout carve-out files to Core/Layout/ (pre-commit for §6.2.11)

Move 19 CodeEditorView-coupled or umbrella-class-extension files from
Sources/CodeEditorPlugin/Layout/ to Sources/CodeEditorPlugin/Core/Layout/.
The relocated files either store/parameter CodeEditorView, or are
partial-file extensions of umbrella-resident types (CodeEditorContainerView,
GutterView, MinimapView, EditorContentView). Both forms force them to
stay in the umbrella when the CodeEditorLayout target extracts. This
pre-commit isolates the relocation from the main extraction.

The conformance split (ThemeableUIComponent+Conformances.swift) is
deferred to the main commit, where both targets exist simultaneously
and the umbrella half can import CodeEditorLayout cleanly.

Matches the §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.9
pre-commit cadence.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Capture the pre-commit SHA**

Run:
```bash
git log -1 --format=%h
```

Save the SHA. It gets referenced in NEXT.md §6.0 in Task 9.

---

### Task 3: Scaffold the `CodeEditorLayout` target in `Package.swift`

**Files:**
- Create: `Sources/CodeEditorLayout/` (directory)
- Create: `Sources/CodeEditorLayout/Glass/` (directory)
- Create: `Sources/CodeEditorLayout/.gitkeep`
- Create: `Sources/CodeEditorLayout/_ScaffoldPlaceholder.swift` (required because the target has a `.library` product per spec §6.1 / §6.2.8f lesson)
- Modify: `Package.swift`

- [ ] **Step 1: Create the new source roots with placeholders**

Run:
```bash
mkdir -p Sources/CodeEditorLayout/Glass
touch Sources/CodeEditorLayout/.gitkeep
```

Create `Sources/CodeEditorLayout/_ScaffoldPlaceholder.swift` with content:

```swift
// Placeholder for scaffold; replaced by real sources in Task 4.
// See docs/superpowers/plans/2026-05-18-codeeditor-layout-extraction.md Task 3 / Task 4.
```

Both files get deleted in Task 4 Step 8 once the real `.swift` files arrive.

- [ ] **Step 2: Add the `.library` product entry to `Package.swift`**

In `Package.swift`, locate the `products:` array. The existing products in alphabetical order are: `CodeEditorDesignTokens`, `CodeEditorDiagnostics`, `CodeEditorLSP`, `CodeEditorPlugin`, `CodeEditorSearch`, `CodeEditorUI`, `CodeEditorWorkspace`, `CodeEditorSample` (executable). `CodeEditorLayout` slots alphabetically between `CodeEditorDiagnostics` and `CodeEditorLSP`.

Use `Edit` with `old_string`:

```swift
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorLSP",
            targets: ["CodeEditorLSP"]
        ),
```

and `new_string`:

```swift
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorLayout",
            targets: ["CodeEditorLayout"]
        ),
        .library(
            name: "CodeEditorLSP",
            targets: ["CodeEditorLSP"]
        ),
```

Note: `CodeEditorLayout` (capital L, lowercase a) sorts before `CodeEditorLSP` (capital L, capital S) in case-insensitive lexicographic order — `Layout` < `LSP`. The `.library` array follows that convention.

- [ ] **Step 3: Add the `.target` stanza to `Package.swift`**

In `Package.swift`, locate the `CodeEditorLanguages` target stanza (currently at lines 136–145). The `CodeEditorLayout` target slots alphabetically after `CodeEditorLanguages` and before `CodeEditorDiagnostics`. Wait — alphabetical placement: `CodeEditorLanguages` < `CodeEditorLayout` < `CodeEditorLSP`. The current order of targets in `Package.swift` is roughly by phase (foundational first), not strictly alphabetical. Find a slot where deps are already declared above.

Specifically: `CodeEditorLayout`'s deps include `CodeEditorAnnotations`, `CodeEditorCommon`, `CodeEditorConfiguration`, `CodeEditorDesignTokens`, `CodeEditorPlatform`, `CodeEditorSyntaxHighlighting`, `CodeEditorTheming`. All of these targets are declared above the `CodeEditorPlugin` umbrella target in `Package.swift`. Place `CodeEditorLayout` after `CodeEditorLSP` and before `CodeEditorSearch` (matches phase-7 ordering — comes after all phase-0-through-5 targets including LSP).

Use `Edit` with `old_string`:

```swift
        .target(
            name: "CodeEditorLSP",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSearch",
```

and `new_string`:

```swift
        .target(
            name: "CodeEditorLSP",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLayout",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorPlatform",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTheming"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSearch",
```

Note: no `path:` override (default `Sources/CodeEditorLayout/` is correct). No `exclude:` or `resources:` (the `Glass/` subdir is normal source, not a resource).

- [ ] **Step 4: Add `"CodeEditorLayout"` to the umbrella `CodeEditorPlugin` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorPlugin` umbrella target stanza (currently at lines 232–257). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
```

Use `Edit` to insert `"CodeEditorLayout"` alphabetically (Languages < Layout < LSP, case-insensitive). Wait — verify the existing ordering: the array has `"CodeEditorLSP"` BEFORE `"CodeEditorLanguages"`. That's the §6.2.9 SwiftLint-tolerated case-insensitive ordering where capital-L < capital-l → so uppercase-S `LSP` > lowercase-a `Languages` in case-insensitive sort.

Wait no — that's the OPPOSITE. The current ordering shows `CodeEditorLSP` BEFORE `CodeEditorLanguages`, meaning the actual order is **case-sensitive ASCII** (`L` < `a`, so `LSP` < `Languages`). Confirmed: SwiftLint's `sorted_imports` rule for IMPORTS uses case-insensitive but `Package.swift` dep arrays follow Swift Array literal conventions — ASCII order.

So in this array, alphabetical insertion of `CodeEditorLayout`:
- ASCII order: `CodeEditorLSP` (capital S) < `CodeEditorLanguages` (lowercase a) < `CodeEditorLayout` (lowercase a)
- So `CodeEditorLayout` slots AFTER `CodeEditorLanguages`, before `CodeEditorPlatform`.

Replace `old_string`:

```swift
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
```

with `new_string`:

```swift
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
```

- [ ] **Step 5: Skip the umbrella `exclude:` edit until Task 4 Step 7**

The umbrella's `exclude:` currently reads `["Info.plist", "Languages"]`. Adding `"Layout"` here would hide the still-present `Layout/` source files from the umbrella's build, breaking the package. Defer to Task 4 Step 7 (after the carry-set `git mv` empties the directory).

- [ ] **Step 6: Add `"CodeEditorLayout"` to `CodeEditorPluginTests` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorPluginTests` target stanza (currently at lines 295–322). Its `dependencies:` array reads:

```swift
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSearch",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

Use `Edit` to insert `"CodeEditorLayout"` alphabetically (after `"CodeEditorLanguages"`, before `"CodeEditorPlatform"`). Replace `old_string`:

```swift
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
```

with `new_string`:

```swift
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
```

- [ ] **Step 7: Conditionally add `"CodeEditorLayout"` to `CodeEditorSample` target's `dependencies:`**

If Task 1 Step 10 found ANY code-level (non-doc-comment) Layout-resident references in `Sources/CodeEditorSample/`, add `"CodeEditorLayout"` to the `CodeEditorSample` target's `dependencies:` array, alphabetically between `"CodeEditorLanguages"` and `"CodeEditorPlatform"`. Use the same `Edit` pattern as Step 6.

If Task 1 Step 10 returned no output, **skip this step**. Sample target requires no change.

- [ ] **Step 8: Conditionally add `"CodeEditorLayout"` to `CodeEditorSampleTests` target's `dependencies:`**

Similarly, if Task 1 Step 10's sample audit identified any *test* dependencies (Task 1 didn't survey CodeEditorSampleTests separately — re-run if needed):

```bash
grep -rlnE "\b(LayoutCache|LayoutCoordinator|EditorEventBus|ThemeableUIComponent|MinimapStyleDataSource|ConfigurableUIComponent|BaseUIComponents|FoldChevronAnimation|FoldChevronHitTester|LineHighlightView|InsertionPointView|_GlassSurface|AdaptiveLayoutProvider|ResponsiveLayoutProvider)\b" Tests/CodeEditorSampleTests --include='*.swift' 2>/dev/null | sort -u
```

If output appears, add `"CodeEditorLayout"` to `CodeEditorSampleTests`'s `dependencies:` (alphabetically between `"CodeEditorLanguages"` and `"CodeEditorPlatform"`). Use the same `Edit` pattern.

If no output, skip.

- [ ] **Step 9: Verify Package.swift parses**

Run:
```bash
swift package describe 2>&1 | tail -10
```

Expected: package description prints without errors. If the parser complains about the new product / target, re-check the `Edit` operations — likely a missing comma or duplicated key.

- [ ] **Step 10: Verify everything still builds with placeholder**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. The new target `CodeEditorLayout` compiles with only the `_ScaffoldPlaceholder.swift` file (an empty Swift module is legal). The umbrella + sample + tests gained a new dep but no new imports yet, so they keep compiling against the existing Layout sources (still in `Sources/CodeEditorPlugin/Layout/`).

If the build fails:
- "no such module 'CodeEditorLayout'" anywhere: the target stanza is missing or mis-named. Re-check Step 3.
- "circular dependency detected": the new target's deps reference the umbrella. Check Step 3's dep list against the carry-set imports from Task 1 Step 6.
- Other errors: read carefully, may be unrelated pre-existing — but if so, halt and apply the pre-existing-failure rule.

---

### Task 4: Move carry-set files into `Sources/CodeEditorLayout/` + execute the conformance split

This is the bulk file-move task. The carry-set is 21 originals + 1 split-out half = 22 files in the new target. The conformance split happens in this task because both targets now exist.

**Files:**
- Move (git mv): 21 originals from `Sources/CodeEditorPlugin/Layout/` to `Sources/CodeEditorLayout/` (preserving the `Glass/` subdir)
- Modify in place: `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` (remove 3 umbrella conformances; keep 4 carry-set conformances)
- Move (git mv) + rename: `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` → `Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift`
- Create: `Sources/CodeEditorPlugin/Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift`
- Delete: `Sources/CodeEditorLayout/.gitkeep`
- Delete: `Sources/CodeEditorLayout/_ScaffoldPlaceholder.swift`

- [ ] **Step 1: `git mv` 20 of the 21 carry-set originals (defer the conformance file to Step 4)**

Run as a single chained command:

```bash
git mv Sources/CodeEditorPlugin/Layout/AdaptiveLayoutProvider.swift Sources/CodeEditorLayout/AdaptiveLayoutProvider.swift && \
git mv Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift Sources/CodeEditorLayout/BaseUIComponents.swift && \
git mv Sources/CodeEditorPlugin/Layout/CommandClickModifier.swift Sources/CodeEditorLayout/CommandClickModifier.swift && \
git mv Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift Sources/CodeEditorLayout/CompletionCellComponents.swift && \
git mv Sources/CodeEditorPlugin/Layout/CompletionPopoverThemeMetrics.swift Sources/CodeEditorLayout/CompletionPopoverThemeMetrics.swift && \
git mv Sources/CodeEditorPlugin/Layout/ComponentFrameCalculator.swift Sources/CodeEditorLayout/ComponentFrameCalculator.swift && \
git mv Sources/CodeEditorPlugin/Layout/ConfigurationFormControls.swift Sources/CodeEditorLayout/ConfigurationFormControls.swift && \
git mv Sources/CodeEditorPlugin/Layout/EditorEventBus.swift Sources/CodeEditorLayout/EditorEventBus.swift && \
git mv Sources/CodeEditorPlugin/Layout/FoldChevronAnimation.swift Sources/CodeEditorLayout/FoldChevronAnimation.swift && \
git mv Sources/CodeEditorPlugin/Layout/FoldChevronHitTester.swift Sources/CodeEditorLayout/FoldChevronHitTester.swift && \
git mv Sources/CodeEditorPlugin/Layout/Glass/_GlassSurface.swift Sources/CodeEditorLayout/Glass/_GlassSurface.swift && \
git mv Sources/CodeEditorPlugin/Layout/GutterDebugSupport.swift Sources/CodeEditorLayout/GutterDebugSupport.swift && \
git mv Sources/CodeEditorPlugin/Layout/InsertionPointIndicating.swift Sources/CodeEditorLayout/InsertionPointIndicating.swift && \
git mv Sources/CodeEditorPlugin/Layout/InsertionPointView.swift Sources/CodeEditorLayout/InsertionPointView.swift && \
git mv Sources/CodeEditorPlugin/Layout/LayoutCache.swift Sources/CodeEditorLayout/LayoutCache.swift && \
git mv Sources/CodeEditorPlugin/Layout/LayoutCoordinator.swift Sources/CodeEditorLayout/LayoutCoordinator.swift && \
git mv Sources/CodeEditorPlugin/Layout/LayoutOptimizer.swift Sources/CodeEditorLayout/LayoutOptimizer.swift && \
git mv Sources/CodeEditorPlugin/Layout/LineHighlightView.swift Sources/CodeEditorLayout/LineHighlightView.swift && \
git mv Sources/CodeEditorPlugin/Layout/MinimapStyleDataSource.swift Sources/CodeEditorLayout/MinimapStyleDataSource.swift && \
git mv Sources/CodeEditorPlugin/Layout/ResponsiveLayoutProvider.swift Sources/CodeEditorLayout/ResponsiveLayoutProvider.swift && \
git mv Sources/CodeEditorPlugin/Layout/TextHoverModifier.swift Sources/CodeEditorLayout/TextHoverModifier.swift
```

**Adjustment for Task 1 Step 7 outcome:** if `GutterDebugSupport.swift` was reclassified to the stay-set during Task 1 Step 7, drop its `git mv` line from the command above and add it to Task 2 Step 2's stay-set move (re-run Task 2 if needed, or do an additional `git mv` here from `Layout/` to `Core/Layout/`).

Verify:
```bash
ls Sources/CodeEditorLayout/*.swift Sources/CodeEditorLayout/Glass/*.swift 2>/dev/null | wc -l
```

Expected: `22` (20 top-level originals moved + 1 in `Glass/` moved + `_ScaffoldPlaceholder.swift` still present from Task 3 — removed in Step 8 below).

- [ ] **Step 2: Verify `Layout/` is nearly empty**

Run:
```bash
find Sources/CodeEditorPlugin/Layout -name '*.swift' | sort
```

Expected: exactly `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` (the conformance file, not yet split). If `GutterDebugSupport.swift` was kept in stay-set per Task 1 Step 7 outcome, it should be in `Core/Layout/` not `Layout/`.

If anything else remains, the `git mv` chain missed a file — diagnose and add it.

- [ ] **Step 3: Edit `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift` to remove the 3 umbrella conformances**

Use `Edit` to replace the file's content (read the current file first to confirm exact text). Replace `old_string`:

```swift
extension GutterView: ThemeableUIComponent {}

extension LineHighlightView: ThemeableUIComponent {}

extension InsertionPointView: ThemeableUIComponent {}

extension AnnotationsContentView: ThemeableUIComponent {}

extension AnnotationView: ThemeableUIComponent {}

#if canImport(AppKit)
extension AppKitMinimapView: ThemeableUIComponent {}
#elseif canImport(UIKit)
extension UIKitMinimapView: ThemeableUIComponent {}
#endif
```

with `new_string`:

```swift
extension LineHighlightView: ThemeableUIComponent {}

extension InsertionPointView: ThemeableUIComponent {}

extension AnnotationsContentView: ThemeableUIComponent {}

extension AnnotationView: ThemeableUIComponent {}
```

This removes the `GutterView`, `AppKitMinimapView`, and `UIKitMinimapView` conformances (3 lines + the `#if` block). The remaining 4 conformances reference carry-set types and an imported `CodeEditorAnnotations` target — all reachable from the new `CodeEditorLayout` target.

- [ ] **Step 4: `git mv` + rename the now-edited conformance file into the new target**

Run:
```bash
git mv Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift
```

Verify:
```bash
ls Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift
find Sources/CodeEditorPlugin/Layout -name '*.swift' | wc -l
```

Expected:
- The new file exists at `Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift`.
- The original `Sources/CodeEditorPlugin/Layout/` directory now contains zero `.swift` files.

- [ ] **Step 5: Update the header doc-comment in the renamed conformance file**

Use `Edit` to update the file header. Replace `old_string`:

```swift
// Empty-extension conformance declarations for the views that already
// expose `appliedTheme` + `apply(theme:)`. Keeping the conformances in a
// dedicated file lets each view's primary file stay focused on its own
// concerns; the shape of the protocol is defined in BaseUIComponents.swift.
```

with `new_string`:

```swift
// Empty-extension conformance declarations for CodeEditorLayout-resident
// view types (LineHighlightView, InsertionPointView) and CodeEditorAnnotations
// view types (AnnotationsContentView, AnnotationView). The protocol's shape
// is defined in BaseUIComponents.swift in this target. Conformances for
// umbrella-resident view types (GutterView, AppKitMinimapView,
// UIKitMinimapView) live in
// Sources/CodeEditorPlugin/Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift.
// Split during §6.2.11 (CodeEditorLayout extraction).
```

- [ ] **Step 6: Create the umbrella half of the split**

Create `Sources/CodeEditorPlugin/Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift` with content:

```swift
// Empty-extension conformance declarations for umbrella-resident view
// types (GutterView, AppKitMinimapView, UIKitMinimapView). The protocol
// `ThemeableUIComponent` is defined in CodeEditorLayout's
// BaseUIComponents.swift; the carry-set conformances live in
// Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift.
// Split during §6.2.11 (CodeEditorLayout extraction).

import CodeEditorLayout
import Foundation

extension GutterView: ThemeableUIComponent {}

#if canImport(AppKit)
extension AppKitMinimapView: ThemeableUIComponent {}
#elseif canImport(UIKit)
extension UIKitMinimapView: ThemeableUIComponent {}
#endif
```

- [ ] **Step 7: Add `"Layout"` to the umbrella `CodeEditorPlugin` target's `exclude:` (deferred from Task 3 Step 5)**

Now that `Sources/CodeEditorPlugin/Layout/` is empty of `.swift` files, add the defensive exclude.

In `Package.swift`, use `Edit` with `old_string`:

```swift
            exclude: [
                "Info.plist",
                "Languages"
            ],
```

and `new_string`:

```swift
            exclude: [
                "Info.plist",
                "Languages",
                "Layout"
            ],
```

- [ ] **Step 8: Delete the scaffold placeholders**

Run:
```bash
rm Sources/CodeEditorLayout/.gitkeep Sources/CodeEditorLayout/_ScaffoldPlaceholder.swift
```

(They're untracked from Task 3, so `git rm` isn't needed.)

Verify the new target now has only real sources:

```bash
find Sources/CodeEditorLayout -name '*.swift' | sort
```

Expected (22 files):
```
Sources/CodeEditorLayout/AdaptiveLayoutProvider.swift
Sources/CodeEditorLayout/BaseUIComponents.swift
Sources/CodeEditorLayout/CommandClickModifier.swift
Sources/CodeEditorLayout/CompletionCellComponents.swift
Sources/CodeEditorLayout/CompletionPopoverThemeMetrics.swift
Sources/CodeEditorLayout/ComponentFrameCalculator.swift
Sources/CodeEditorLayout/ConfigurationFormControls.swift
Sources/CodeEditorLayout/EditorEventBus.swift
Sources/CodeEditorLayout/FoldChevronAnimation.swift
Sources/CodeEditorLayout/FoldChevronHitTester.swift
Sources/CodeEditorLayout/Glass/_GlassSurface.swift
Sources/CodeEditorLayout/GutterDebugSupport.swift
Sources/CodeEditorLayout/InsertionPointIndicating.swift
Sources/CodeEditorLayout/InsertionPointView.swift
Sources/CodeEditorLayout/LayoutCache.swift
Sources/CodeEditorLayout/LayoutCoordinator.swift
Sources/CodeEditorLayout/LayoutOptimizer.swift
Sources/CodeEditorLayout/LineHighlightView.swift
Sources/CodeEditorLayout/MinimapStyleDataSource.swift
Sources/CodeEditorLayout/ResponsiveLayoutProvider.swift
Sources/CodeEditorLayout/TextHoverModifier.swift
Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift
```

(Adjust for the GutterDebugSupport contingency if it was reclassified in Task 1 Step 7.)

- [ ] **Step 9: Verify the new target builds in isolation**

Run:
```bash
swift build --target CodeEditorLayout 2>&1 | tail -40
```

Expected: `Build complete!` with the 22 files compiled. If errors appear, they're internal to the new target — likely one of these patterns:

- "cannot find type 'GutterView' / 'MinimapView' / 'CodeEditorContainerView' in scope": a carry-set file references a stay-set type. Audit failed in Task 1 Step 7. Move the offending file to the stay-set and re-run Task 2.
- "cannot find type 'CodeEditorView' in scope": a carry-set file references CodeEditorView. Same — audit failed in Task 1 Step 2.
- "'X' is inaccessible due to 'internal' protection level": a moved file references an internal type in a dependency target. This is expected for some symbols and is fixed by Task 5 (access-modifier promotions) for the *current target*, OR by promoting symbols in *upstream* targets (likely none expected for Layout — verify by checking which target owns the inaccessible symbol).

- [ ] **Step 10: Build the full package to expose the umbrella + sample + test red wavefront**

Run:
```bash
swift build 2>&1 | tee /tmp/codeeditor-layout-build.log | tail -80
```

Expected: build FAILS in umbrella + (possibly) sample + tests. Common error patterns:

- `cannot find 'LayoutCache' in scope` / `cannot find 'EditorEventBus' in scope` / etc. in stay-set Core/Layout/ files
- `cannot find type 'ThemeableUIComponent' in scope` in stay-set Core/Layout/`ThemeableUIComponent+UmbrellaConformances.swift` (the import was added but Swift modules don't link until the new target compiles; this should resolve when Task 5 + Task 6 add the umbrella's own `import CodeEditorLayout`)
- `'LayoutCache' has internal access` / similar — access-level errors fixed by Task 5
- `cannot find type 'GutterView' in scope` from `ThemeableUIComponent+UmbrellaConformances.swift`: this is wrong — `GutterView` is in the umbrella stay-set, same module. If this error appears, the umbrella half of the conformance split is missing.

Capture `/tmp/codeeditor-layout-build.log` for Task 5's iteration.

---

### Task 5: Cross-target access-modifier promotions

Per spec §4: estimated 20–40 promotions (smaller than §6.2.7 SH's ~107, larger than §6.2.9 LSP's ~7). Compile-driven iteration: read the build log, promote `internal → package` (or add explicit `public init`) for any cross-target access error, re-build, repeat.

**Files:**
- Modify (likely): most/all 22 carry-set source files for member-level promotions surfaced by compile errors

- [ ] **Step 1: Read the captured build log to identify access-level errors**

Open `/tmp/codeeditor-layout-build.log` from Task 4 Step 10. Filter:

```bash
grep -E "inaccessible|cannot find|internal protection" /tmp/codeeditor-layout-build.log | sort -u | head -60
```

Identify each unique "X is inaccessible / has internal access" error. For each, note:
- The carry-set file containing the type/method (Sources/CodeEditorLayout/...).
- The consumer file (Sources/CodeEditorPlugin/...).
- The exact symbol name.

Distinguish from "cannot find X in scope" errors — those are resolved by adding imports in Task 6, not by promotions.

- [ ] **Step 2: Promote top-level types via compile-driven iteration**

For each access-level error, open the carry-set file in `Sources/CodeEditorLayout/` and apply one of:

**Pattern A — internal → package (preferred when umbrella's `Core/Layout/` is the only consumer):**
```swift
// before
final class LayoutCache { ... }
// after
package final class LayoutCache { ... }
```

**Pattern B — synthesized init missing (§6.2.8b lesson):**
```swift
// before — synthesized init defaults to internal
public struct MinimapStyleRun { public let range: NSRange; public let color: PlatformColor }
// after — explicit public init
public struct MinimapStyleRun {
    public let range: NSRange
    public let color: PlatformColor
    public init(range: NSRange, color: PlatformColor) {
        self.range = range
        self.color = color
    }
}
```

**Pattern C — explicit `package` on a method called from cross-target:**
```swift
// before
func cachedFrame(for index: Int) -> CGRect? { ... }
// after
package func cachedFrame(for index: Int) -> CGRect? { ... }
```

Don't promote symbols not named in compile errors — they remain internal.

Anticipated candidates (from spec §4):

- `LayoutCache`, `LayoutCoordinator`, `LayoutOptimizer` — `internal → package` (consumed by `GutterViewModel` / `MinimapViewModel` / `CodeEditorContainerView` in umbrella)
- `BaseUIComponents` exports (`ConfigurableUIComponent`, `ThemeableUIComponent` are already `public`; verify `PlatformAccessibilityTraits` typealias visibility)
- `ComponentFrameCalculator` — likely `internal → package`
- `EditorEventBus` (protocol) — likely `internal → package`
- `MinimapStyleDataSource` (protocol) — likely already `public` per file content; verify
- `FoldChevronAnimation`, `FoldChevronHitTester` — `internal → package`
- `InsertionPointIndicating`, `InsertionPointView`, `LineHighlightView` — `internal → package`
- `CompletionCellComponents`, `CompletionPopoverThemeMetrics` — `internal → package`
- `AdaptiveLayoutProvider`, `ResponsiveLayoutProvider` — verify; if already `public`, watch for synthesized-init traps
- `_GlassSurface` — verify; if leading-underscore convention means internal-only, may not need promotion at all

- [ ] **Step 3: Iterate `swift build` until no access-level errors remain**

After each batch of edits, run:

```bash
swift build 2>&1 | tee /tmp/codeeditor-layout-build.log | grep -E "inaccessible|internal protection" | head -20
```

If output is non-empty, return to Step 2 for the next batch. If output is empty, all access-level errors are resolved (remaining errors should be "cannot find X in scope" — addressed in Task 6).

Expected iteration count: 2–5 rounds. Estimated total promotions: 20–40.

- [ ] **Step 4: WIP-checkpoint trigger if promotion count exceeds 50**

If the compile-driven iteration in Step 3 reveals >50 member promotions (substantially more than the §6.2.9 LSP ~7 or §6.2.8b Symbols ~7, but below §6.2.7 SH ~107), halt:

```bash
git add -A
git status --short
echo "WIP: §6.2.11 promotion-count exceeds 50 — stopping for re-evaluation" > /tmp/wip-marker.txt
```

Do NOT commit. Re-read the spec §4 with the discovered scope and consult the user before proceeding. The §6.2.7 SH precedent (107 promotions) has a successful playbook (bulk script + manual revisions); 50+ is not a blocker but worth a checkpoint to confirm scope.

If iterations complete with ≤50 promotions, no checkpoint needed; proceed to Step 5.

- [ ] **Step 5: Verify build state post-promotions**

Run:
```bash
swift build 2>&1 | tail -20
```

Expected: the build remains red, but only on `cannot find 'X' in scope` errors — never on access-level errors anymore. If access-level errors persist, return to Step 3.

- [ ] **Step 6: Record the actual promotion count**

Run:
```bash
git diff --stat | tail -5
```

Note the number of files modified and lines changed. Cross-reference with `git diff` to count distinct symbol-level promotions for Task 9's deviations block.

---

### Task 6: Add `import CodeEditorLayout` to consumer files

This task adds the new import to the umbrella consumers (the relocated `Core/Layout/` files + other umbrella sources outside `Layout/`), and to test files identified by Task 1's surveys. SwiftLint's `sorted_imports` rule enforces case-insensitive alphabetical order: `CodeEditorLanguages` < `CodeEditorLayout` < `CodeEditorLSP`.

**Files (umbrella `Core/Layout/`):**

All 20 files in `Sources/CodeEditorPlugin/Core/Layout/` are candidates. Most likely need the import (they reference carry-set types). Confirm per-file by reading the file's existing imports + checking which carry-set types it references.

**Files (umbrella `Core/` and `SwiftUI/`):**

Per Task 1 Step 8's grep, list captured during pre-flight.

**Files (sample):**

Per Task 1 Step 10's grep — expect zero unless the audit surfaced consumers.

**Files (tests):**

Per Task 1 Step 12's grep — expect 5–10 plugin-test files.

- [ ] **Step 1: Re-survey the umbrella `Core/Layout/` files for required imports**

Run:
```bash
for f in Sources/CodeEditorPlugin/Core/Layout/*.swift; do
  echo "=== $(basename "$f") ==="
  grep -nE "\b(LayoutCache|LayoutCoordinator|LayoutOptimizer|EditorEventBus\b|MinimapStyleDataSource|FoldChevronAnimation|FoldChevronHitTester|_GlassSurface|GlassSurface|InsertionPointView|InsertionPointIndicating|LineHighlightView|BaseUIComponents|ComponentFrameCalculator|ConfigurationFormControls|AdaptiveLayoutProvider|ResponsiveLayoutProvider|CompletionCellComponents|CompletionPopoverThemeMetrics|CommandClickModifier|TextHoverModifier|ThemeableUIComponent|ConfigurableUIComponent|MinimapStyleRun|PlatformAccessibilityTraits)\b" "$f" 2>/dev/null | head -5
done
```

For each file with non-zero output: add `import CodeEditorLayout` to its import block. Files with zero output: skip.

- [ ] **Step 2: Add `import CodeEditorLayout` to each affected `Core/Layout/` file**

For each file identified in Step 1, locate the import block at the top and insert `import CodeEditorLayout` at the alphabetical position (after `CodeEditorLanguages` if present, before `CodeEditorLSP` if present, before any non-CodeEditor import).

Example for `Core/Layout/GutterViewModel.swift`:

If the existing imports are:
```swift
import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorTheming
import Foundation
```

becomes:
```swift
import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorLayout
import CodeEditorTheming
import Foundation
```

Repeat for each of the ~10–15 stay-set files that need the import. Don't pre-emptively add to every file — only those Step 1 confirmed need it.

- [ ] **Step 3: Add `import CodeEditorLayout` to umbrella files outside `Core/Layout/`**

Use the consumer list captured by Task 1 Step 8 + Step 9. Likely candidates include:

- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (and its `+*Extensions.swift` slices that reference layout types)
- `Sources/CodeEditorPlugin/Core/CodeEditorAPI.swift` (if it exposes layout-typed public API)
- `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` and other SwiftUI-slice files (if they reference layout types)
- `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift` (verify)

For each, add the import at the alphabetical position.

- [ ] **Step 4: Build to confirm the umbrella red wavefront is now green**

Run:
```bash
swift build --target CodeEditorPlugin 2>&1 | tail -20
```

Expected: `Build complete!` for the umbrella target. If errors remain in umbrella source files, an import is missing or misplaced. Diagnose by reading the error line — Swift error messages include the source file and line number.

- [ ] **Step 5: Conditionally add `import CodeEditorLayout` to sample sources**

Per Task 1 Step 10's outcome:
- If sample audit returned no output → skip this step. Build the sample to confirm:

  ```bash
  swift build --target CodeEditorSample 2>&1 | tail -10
  ```

  Expected: `Build complete!`. The sample neither imports `CodeEditorLayout` nor depends on it; it works because Layout types are not referenced.

- If sample audit returned code-level references → for each surfaced file, add `import CodeEditorLayout` at the alphabetical position. Build to verify.

- [ ] **Step 6: Verify UI target still builds**

Run:
```bash
swift build --target CodeEditorUI 2>&1 | tail -10
```

Expected: `Build complete!`. CodeEditorUI does not reference Layout types (verified Task 1 Step 11), so no import is needed.

- [ ] **Step 7: Add `import CodeEditorLayout` to plugin-test files**

For each test file identified by Task 1 Step 12 (estimated 5–10 files), use `Edit` to insert `import CodeEditorLayout` at the alphabetical position. **Keep `@testable import CodeEditorPlugin` exactly as it was.** Per §6.2.8d lesson, do NOT blanket-drop it — internal umbrella symbols may still be required.

Common import-block shape:

```swift
import CodeEditorPlugin
@testable import CodeEditorPlugin
import Foundation
import Testing
```

becomes (with Layout addition — alphabetical placement):

```swift
import CodeEditorLayout
import CodeEditorPlugin
@testable import CodeEditorPlugin
import Foundation
import Testing
```

If the test file accesses internal types from the new target (e.g. an internal-only `LayoutCache` helper exposed only via `@testable`), use `@testable import CodeEditorLayout` instead of plain `import`. Likely candidates: tests that exercise `EditorEventBus` mock implementations or low-level layout-cache internals. Per §6.2.9 lesson, both `@testable import CodeEditorPlugin` and `@testable import CodeEditorLayout` may coexist.

- [ ] **Step 8: Verify plugin-tests build**

Run:
```bash
swift build --target CodeEditorPluginTests 2>&1 | tail -20
```

Expected: `Build complete!`. If errors remain, re-survey with the broader grep set (the spec mentions §6.2.8e bare-word grep catching what compound-name grep misses):

```bash
grep -rln "\b(MinimapStyleRun|ConfigurableUIComponent|PlatformAccessibilityTraits)\b" Tests/CodeEditorPluginTests --include='*.swift' 2>/dev/null
```

For any new file, add the import.

- [ ] **Step 9: Conditionally add `import CodeEditorLayout` to sample-test files**

If Task 3 Step 8 added `CodeEditorLayout` to `CodeEditorSampleTests`'s `dependencies:`, also add `import CodeEditorLayout` to the surfaced sample-test files at the alphabetical position. If not, skip.

Verify:
```bash
swift build --target CodeEditorSampleTests 2>&1 | tail -10
```

Expected: `Build complete!`.

- [ ] **Step 10: Run full build**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!` — all targets green.

---

### Task 7: SwiftLint + test verification

- [ ] **Step 1: Run swiftlint --fix to auto-correct import ordering and other auto-fixable violations**

Run:
```bash
swiftlint --fix 2>&1 | tail -20
```

Expected: auto-fixed import orderings + any other auto-fixable violations. Per §6.2.9 LSP lesson, SwiftLint's `sorted_imports` rule may reorder `CodeEditorLayout` between `CodeEditorLanguages` and `CodeEditorLSP`. Don't fight it — accept the auto-fix.

- [ ] **Step 2: Run swiftlint to verify zero violations**

Run:
```bash
swiftlint 2>&1 | tail -20
```

Expected: `Done linting!` with zero errors (and zero warnings, since `strict: true` treats warnings as errors). If violations appear:

- `force_unwrapping`: a moved file uses `!` — replace with safe unwrap.
- `no_print_statements`: a moved file uses `print()` — replace with `CrossPlatformLogger.logger().*`.
- `sorted_imports`: an import was added out of order — let `swiftlint --fix` handle it.
- Other: read the rule documentation and fix.

- [ ] **Step 3: Run targeted tests for affected suites**

Run:
```bash
swift test --filter Layout 2>&1 | tail -5 && \
swift test --filter Gutter 2>&1 | tail -5 && \
swift test --filter Minimap 2>&1 | tail -5 && \
swift test --filter FoldChevron 2>&1 | tail -5 && \
swift test --filter EditorEventBus 2>&1 | tail -5 && \
swift test --filter ThemeableUIComponent 2>&1 | tail -5
```

Expected: same pass counts as Task 1 Step 14 baseline. If any test fails, diagnose — most likely cause is a stale path assertion (cf. §6.2.8e ReviewRemediationRegressionTests fix).

- [ ] **Step 4: Run full test suite**

Run:
```bash
swift test --parallel 2>&1 | tail -20
```

Expected: full suite passes. Note total pass count.

If failures appear:
- Path-assertion failures: update the assertions to point at new paths (`Sources/CodeEditorLayout/...` or `Sources/CodeEditorPlugin/Core/Layout/...` as appropriate). Follow §6.2.8e collateral-fix pattern.
- New-import failures: a test file references a Layout-resident type but lacks `import CodeEditorLayout`. Return to Task 6 Step 7 and add the import.
- Other: diagnose and fix; do NOT proceed to commit with a red test suite.

- [ ] **Step 5: Verify the new target compiles as a standalone product**

Run:
```bash
swift build --target CodeEditorLayout 2>&1 | tail -10
```

Expected: `Build complete!`.

Also verify no accidental upstream imports inside the new target:
```bash
grep -rn "^import CodeEditorPlugin\b" Sources/CodeEditorLayout/
```

Expected: **no output**. If `CodeEditorPlugin` appears as an import in any new-target file, there's a circular-dep escape hatch that breaks the layered architecture — fix by promoting the offending symbol to `package` in its proper home target or restructuring the carry-set boundary.

---

### Task 8: Commit the main extraction

- [ ] **Step 1: Stage all changes**

Run:
```bash
git add -A
git status --short
```

Expected staged changes:
- New files: `Sources/CodeEditorLayout/...` (22 files: 21 originals via `git mv` + 1 split-rename) + `Sources/CodeEditorPlugin/Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift` (1 new file).
- Renames: ~21 `R` entries showing `Sources/CodeEditorPlugin/Layout/<file>.swift → Sources/CodeEditorLayout/<file>.swift` (including the conformance file's rename).
- Modifications: `Package.swift`, ~10–15 `Sources/CodeEditorPlugin/Core/Layout/*.swift` (import additions + access-modifier promotions are in different target — actually no, promotions are inside the new target; only import additions touch `Core/Layout/`), ~10–15 plugin-test files (import additions), other umbrella source files (import additions), possibly sample files (if Task 1 Step 10 surfaced consumers).
- Modified content: ~22 new-target files (access-modifier promotions from Task 5).

No untracked files should remain (the scaffold placeholders were deleted in Task 4 Step 8).

- [ ] **Step 2: Final pre-commit verification**

Run in sequence (NOT parallel):
```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel 2>&1 | tail -30
```

Expected: all green. If anything fails, halt and diagnose. Do NOT commit a red state.

- [ ] **Step 3: Commit the main extraction**

```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorLayout target (§6.2.11)

Carve out ~21 pure files from Sources/CodeEditorPlugin/Layout/ into a
new SPM target Sources/CodeEditorLayout/, plus 1 split-out half of
ThemeableUIComponent+Conformances.swift. The remaining 19 originals
relocated to Sources/CodeEditorPlugin/Core/Layout/ in pre-commit
<PRE-COMMIT-SHA-FROM-TASK-2-STEP-7>, and the 3 umbrella-resident
conformances split out into Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift.

Productized as a .library; the umbrella CodeEditorPlugin depends on the
new target (matches §6.2.9 LSP / §6.2.10 Diagnostics precedent —
productized + umbrella-coupled).

New target deps (verified): CodeEditorAnnotations, CodeEditorCommon,
CodeEditorConfiguration, CodeEditorDesignTokens, CodeEditorPlatform,
CodeEditorSyntaxHighlighting, CodeEditorTheming. Corrects NEXT.md §4.1's
speculative TextModel/Completion/Folding/Platform claim.

Access-modifier promotions: <COUNT> internal→package + <COUNT> explicit
public init additions (record actual from Task 5 Step 6).

Closes the §6.2.11 step of the restructure. Next is §6.2.12 Core split.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Replace `<PRE-COMMIT-SHA-FROM-TASK-2-STEP-7>` and `<COUNT>` with actual values before running.

- [ ] **Step 4: Capture the main-commit SHA**

Run:
```bash
git log -1 --format=%h
```

Save the SHA. It gets referenced in NEXT.md §6.0 in Task 9 and in Task 10's NEXT.md SHA back-reference.

---

### Task 9: Update NEXT.md to record the §6.2.11 landing

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 1: Update the §6.0 status table — add a row for CodeEditorLayout**

In `NEXT.md`, locate the §6.0 status table (around line 250). It currently has rows for each completed target through `CodeEditorLSP`. Add a row for `CodeEditorLayout` immediately after the `CodeEditorLSP` row, using the SHA from Task 8 Step 4. Example shape:

```markdown
| `CodeEditorLayout` | `<MAIN-COMMIT-SHA>` | 22 files moved from umbrella `Layout/` to new target (21 originals + 1 split-out half of `ThemeableUIComponent+Conformances.swift`); pre-commit `<PRE-COMMIT-SHA>` relocated 19 umbrella-coupled files to `Core/Layout/`; main commit also created `Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift` (umbrella half of the split). Productized as opt-in `.library`; umbrella DOES depend on it (matches §6.2.10 Diagnostics / §6.2.9 LSP precedent). <COUNT> access-modifier promotions + <COUNT> explicit `public init` additions. | Annotations, Common, Configuration, DesignTokens, Platform, SyntaxHighlighting, Theming |
```

- [ ] **Step 2: Add a §6.0 deviations block for §6.2.11**

In `NEXT.md`'s §6.0 deviations section, add a new sub-block titled `**Deviations during §6.2.11 CodeEditorLayout (commit `<MAIN-COMMIT-SHA>`):**`. Include:

- The §4.1 dep-claim correction (actual = Annotations + Common + Configuration + DesignTokens + Platform + SyntaxHighlighting + Theming; spec said TextModel/Completion/Folding/Platform).
- The conformance file split — 7 conformances → 4 carry-set + 3 umbrella halves; both halves co-exist.
- Whether `GutterDebugSupport.swift` ended up in carry-set or stay-set (per Task 1 Step 7 outcome).
- The actual access-modifier promotion count and breakdown.
- Whether sample / UI gained `CodeEditorLayout` as a dep (likely no per Task 1 Step 10 audit).
- The new `Core/Layout/` semantic bucket (joins F3 family).
- Any synthesized-init `public init` additions (§6.2.8b lesson).
- Any path-assertion regressions discovered + fixed in `ReviewRemediationRegressionTests` (cf. §6.2.8e).

Follow the format of the §6.2.9 LSP deviations block in `NEXT.md` (around lines 412–425).

- [ ] **Step 3: Update §6.2.11 status line in the §6.2 step-by-step list**

Locate §6.2.11 in `NEXT.md`'s §6.2 step list (around line 454). It currently reads:

```markdown
11. **Extract `CodeEditorLayout`** — move `Layout/`. This depends on most of phase 4.
```

Replace with:

```markdown
11. **[done — carve-out, see §6.0]** **Extract `CodeEditorLayout`** (§6.2.11) — moved 21 of 41 `Layout/` files to `Sources/CodeEditorLayout/` plus 1 split-out half; 19 `CodeEditorView`-coupled or umbrella-class-extension files relocated to `Core/Layout/`. Productized as opt-in `.library`; umbrella DOES depend on it. Final deps: `Annotations, Common, Configuration, DesignTokens, Platform, SyntaxHighlighting, Theming`. (`<MAIN-COMMIT-SHA>` + pre-relocation `<PRE-COMMIT-SHA>`)
```

- [ ] **Step 4: Update §4.1 phase table — reflect actual deps**

Locate the §4.1 phase table row for `CodeEditorLayout` (around line 90). It currently reads `| **7 — Presentation** | `CodeEditorLayout` | `Layout/` | TextModel, Theming, Completion, Annotations, Folding, Platform |`. Replace with:

```markdown
| **7 — Presentation** | `CodeEditorLayout` | `Layout/` (21 of 41 files moved; 19 stayed in umbrella `Core/Layout/`) | Annotations, Common, Configuration, DesignTokens, Platform, SyntaxHighlighting, Theming |
```

- [ ] **Step 5: Update §4.2 Mermaid dependency diagram**

In `NEXT.md`'s §4.2 Mermaid block (around line 100), the existing edges pointing into Layout are `TextModel → Layout`, `Theming → Layout`, `Completion → Layout`, `Annotations → Layout`, `Folding → Layout`, `Platform → Layout`. Update to reflect actual:

- Keep: `Theming → Layout`, `Annotations → Layout`, `Platform → Layout`
- Drop: `TextModel → Layout`, `Completion → Layout`, `Folding → Layout`
- Add: `Common → Layout`, `Configuration → Layout`, `Syntax → Layout`, `Tokens → Layout`

Use `Edit` to update each affected line in the Mermaid block. Verify the edges are still on phase-7 inputs only.

- [ ] **Step 6: Update §3 file-count inventory**

In `NEXT.md` §3 (around line 36), the row `| Layout/ | 40 | Gutter, container view, minimap, popover chrome, event bus |` reflects pre-extraction state. Update to:

```markdown
| Layout/ | 0 | extracted to `CodeEditorLayout` (21 files) + `Core/Layout/` (20 files) in §6.2.11 |
```

Or, depending on how stale similar rows already are after other extractions, follow the established pattern.

- [ ] **Step 7: Update the §6.0 status paragraph**

Locate the paragraph beginning "**Phases 0–4 done; phase 3.5 (SH) carved out.**" in §6.0 (around line 248). Update the file count and target list to reflect §6.2.11:

- The umbrella `Sources/CodeEditorPlugin/` source file count drops by ~21 (the carry-set files).
- The total project source file count grows by ~22 (the carry-set + the new `ThemeableUIComponent+UmbrellaConformances.swift`).
- Add `CodeEditorLayout` to the "X SPM targets now exist" enumeration.

Also update the CLAUDE.md "Other source roots" entry list at the end of the section description to add `CodeEditorLayout`.

- [ ] **Step 8: Update §10 "Suggested next session" to drop §6.2.11 and surface §6.2.12**

In `NEXT.md` §10 (around line 504), the "Remaining work" bullet list mentions `6.2.11 CodeEditorLayout`. Remove that bullet (the work is now done) and elevate `6.2.12 Core split` as the next-session candidate. The list should also be updated to reflect §6.2.11's status in the running tally.

- [ ] **Step 9: Update CLAUDE.md "Other source roots" if needed**

In `CLAUDE.md`, the "Other source roots" section enumerates the sibling SPM targets. Add a bullet:

```markdown
- `Sources/CodeEditorLayout/` — presentation primitives: layout caches, fold chevrons, glass surface, insertion-point/line-highlight views, layout providers, event bus, completion popover chrome, theme conformances (phase 7; new in §6.2.11). 22 files. Productized as opt-in `.library` per NEXT.md §6.3. Umbrella depends on it (matches §6.2.9 LSP / §6.2.10 Diagnostics pattern). The 19 `CodeEditorView`-coupled or umbrella-class-extension files (container/gutter/minimap clusters) stay in umbrella at `Sources/CodeEditorPlugin/Core/Layout/`.
```

Update the umbrella-target file-count claim in `CLAUDE.md`'s `Source Tree` section to reflect post-§6.2.11 count.

- [ ] **Step 10: Run swiftlint to confirm no doc-comment / formatting violations**

Run:
```bash
swiftlint 2>&1 | tail -10
```

Expected: `Done linting!`. NEXT.md and CLAUDE.md are markdown — SwiftLint doesn't lint them — so this is a re-confirmation that the source-code tree is still clean.

- [ ] **Step 11: Commit the NEXT.md + CLAUDE.md updates**

Run:
```bash
git add NEXT.md CLAUDE.md
git status --short
```

Expected: only `NEXT.md` and `CLAUDE.md` staged.

Then:
```bash
git commit -m "$(cat <<'EOF'
Update NEXT.md for §6.2.11 CodeEditorLayout extraction

Add §6.0 status row and deviations block for CodeEditorLayout. Mark
§6.2.11 done in the §6.2 step list. Update §4.1 phase table and §4.2
Mermaid edges to reflect actual deps (Annotations, Common, Configuration,
DesignTokens, Platform, SyntaxHighlighting, Theming — drops the spec's
speculative TextModel/Completion/Folding claims). Update §3 inventory
and §10 next-session pointer to §6.2.12 Core split.

Update CLAUDE.md "Other source roots" to add CodeEditorLayout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Capture the docs-commit SHA**

Run:
```bash
git log -1 --format=%h
```

Save the SHA. Task 10 references this commit's content if a SHA back-reference loop is needed.

---

### Task 10: SHA back-fill (final commit, optional)

If the §6.2.11 commit message in Task 8 Step 3 used a placeholder for the pre-commit SHA (because Task 2 Step 7's SHA wasn't available at write time), and the final SHA differs from the placeholder, this task back-fills it. Otherwise — if Task 8 Step 3 used the actual pre-commit SHA from Task 2 Step 7 — skip this task entirely.

- [ ] **Step 1: Check whether the main commit's message contains a placeholder**

Run:
```bash
git log -1 --pretty=%B HEAD~1 | grep -E "PRE-COMMIT-SHA|<.*-SHA-.*>"
```

(`HEAD~1` because Task 9 added a docs commit on top of the main commit.)

If output is non-empty, the main commit has a placeholder — proceed to Step 2. If empty, skip the rest of this task.

- [ ] **Step 2: Use `git commit --amend` — DO NOT.**

Per CLAUDE.md / harness guidance: never `--amend` a published commit. Instead, write a follow-up commit that references the corrected SHA in `NEXT.md`'s deviations block (the placeholder in the commit message itself is irrecoverable, but the canonical record is in `NEXT.md`).

If the placeholder appears in `NEXT.md` (Task 9 Step 1/Step 3), edit it now with the actual SHA. If the placeholder appears only in the commit message, leave it (commit messages can't be edited without a force-push).

- [ ] **Step 3: Verify NEXT.md SHA references are accurate**

Run:
```bash
grep -E "§6.2.11|\`[a-f0-9]{7}\`" NEXT.md | head -20
```

Cross-reference each SHA in §6.0 status table and the deviations block against actual `git log` history:

```bash
git log --oneline | head -10
```

If any SHA in `NEXT.md` mismatches, use `Edit` to correct it.

- [ ] **Step 4: Commit the SHA back-fill if changes were made**

Run:
```bash
git status --short
```

If `NEXT.md` shows modifications:

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Update NEXT.md SHA back-reference for §6.2.11

Backfill the main-commit SHA in §6.0 status table now that the commit
has landed and the SHA is stable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If no changes, skip.

- [ ] **Step 5: Final verification**

Run:
```bash
git log --oneline | head -5
swift build && swiftlint && swift test --parallel 2>&1 | tail -10
```

Expected:
- The recent commits include the §6.2.11 pre-commit, main commit, NEXT.md commit, and (optionally) the SHA back-fill.
- The full suite passes.

This concludes §6.2.11. The next session targets §6.2.12 (Core split).
