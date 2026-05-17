# CodeEditorDiagnostics extraction (Performance/ → SPM target)

**Date:** 2026-05-17
**NEXT.md step:** §6.2.10 (reordered ahead of §6.2.7 to unblock SyntaxHighlighting)
**Scope:** Extract a new SPM target `CodeEditorDiagnostics` containing the legitimately-diagnostics portion of `Sources/CodeEditorPlugin/Performance/` (14 files). Delete two dead files in the same directory. Relocate one misfiled file to its semantic home in umbrella `Layout/`. Split a single hybrid extension file in `SyntaxHighlighting/` so the `MemoryMonitor` extension travels with `MemoryMonitor`.

This spec exists because NEXT.md §6.0 explicitly deferred §6.2.7 `CodeEditorSyntaxHighlighting` pending a choice between three approaches to its `Performance/` and `Core/` back-references. The chosen approach is **(b/c): extract `CodeEditorDiagnostics` first**, then SH becomes a near-mechanical move with no new marker protocols.

## Goals

1. Remove the structural blocker stalling `CodeEditorSyntaxHighlighting` (§6.2.7) — the back-references in the six SH files documented in NEXT.md §6.0 become routine `import CodeEditorDiagnostics` statements after this lands.
2. Make `Performance/` buildable in isolation — instrumentation churn stops triggering rebuilds of Languages/Layout/SwiftUI surface.
3. Set up `CodeEditorDiagnostics` as a separate SPM **product** (per NEXT.md §6.3) so consumers can omit diagnostics from release builds.
4. Preserve the existing public API surface — consumers that `import CodeEditorPlugin` keep working unchanged via umbrella re-export.
5. Drop dead code en route (`IncrementalSyntaxHighlighter.swift`, `OptimizedLineIndexCache.swift`) rather than carrying it into the new target.

## Non-goals

- **Extracting `CodeEditorSyntaxHighlighting`.** §6.2.7 gets its own spec written against post-Diagnostics state. The SH back-references are *unblocked* by this extraction, not *resolved* by it.
- **Introducing `CodeEditorDiagnosticsTests`.** Established phase 0–3 pattern is "extract source target now, keep tests in umbrella, split tests later." Per NEXT.md §7's eventual goal, per-target test targets make sense as a future omnibus PR across all extracted targets at once, not piecemeal.
- **Touching `CodeEditorDependencies` factory implementations.** Adding `import CodeEditorDiagnostics` to `Core/CodeEditorDependencies.swift` is the only edit; factory bodies stay as-is. `makePlatformCapabilities()` and `makeProductionPerformanceMetrics()` keep returning concrete types.
- **Removing the `UnifiedPerformanceTracking` marker protocol** that NEXT.md §6.0 added to Common. Removing it would force Configuration → Diagnostics, pushing Configuration to phase 4+ and undoing its phase-1 placement. The marker pays its keep.
- **Relocating `Core/MemoryManagementCoordinator.swift`** out of `Core/`. It stores `AsyncSyntaxHighlighter`, `TextKit2RenderingOptimizer`, `CompletionManager`, `LSPManager` — all umbrella types. It belongs in the eventual editor-surface target (§6.2.12), not Diagnostics.
- **Renaming the package or any target.** §5.2's `CodeEditorPlugin` → `CodeEditorToolkit` rename is tied to the move to `~/Workspace/packages/`. Out of scope.
- **Touching tree-sitter or LSP code paths.**
- **Bumping the platform floor.** Mac Catalyst stays retired; platforms stay macOS 26.3 / iOS 26.3 per CLAUDE.md.

## Target shape & dependency edges

```
CodeEditorCommon       ──┐
CodeEditorPlatform     ──┤
CodeEditorConfiguration──┼──► CodeEditorDiagnostics ──► (umbrella CodeEditorPlugin)
CodeEditorLanguages    ──┘
                          + IssueReporting (xctest-dynamic-overlay)
```

**`CodeEditorDiagnostics` dependencies:** `CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorConfiguration`, `CodeEditorLanguages`, plus the `IssueReporting` product (used by `PerformanceInsights.swift`).

**Correction vs. NEXT.md §4.1.** The original plan placed `CodeEditorDiagnostics` at phase 6 with only `Common` as a dependency. Reality, after auditing the 14 moving files:

- `AdaptivePerformanceMode.swift` extends `EditorConfiguration.Performance` → requires `CodeEditorConfiguration`.
- `AdaptivePerformanceMode.swift` and `ProductionPerformanceMetrics.swift` bucket metrics/modes by `Language` → require `CodeEditorLanguages`.
- `MemoryMonitor.swift`, `HardwareAcceleration.swift`, `PerformanceInsights.swift`, `PerformanceViews.swift` use Platform types → require `CodeEditorPlatform`.

That places `CodeEditorDiagnostics` at **phase 4** (alongside the feature engines), not phase 6. Same kind of correction NEXT.md §6.0 already documented for Theming and Configuration's actual deps. Flow stays strictly downward — no circular risk.

**Umbrella `CodeEditorPlugin` gains** `CodeEditorDiagnostics` as a direct dependency. The umbrella's `exclude:` list gains `"Performance"` (mirrors how `"Languages"` was added in `14921a61`).

**Import whitelist inside `Sources/CodeEditorDiagnostics/`:** `Foundation`, `CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorConfiguration`, `CodeEditorLanguages`, `IssueReporting`, `Combine`, `Observation`, `SwiftUI`, `QuartzCore`, `os.log`, plus AppKit/UIKit references inside `#if canImport(...)` blocks per the existing files. No other imports.

**Productization.** Unlike `CodeEditorLanguages` (no separate product), this extraction **does** expose a `.library(name: "CodeEditorDiagnostics", targets: ["CodeEditorDiagnostics"])` product — that's the NEXT.md §6.3 commitment to make instrumentation opt-in. Consumers who don't want diagnostics in release builds can link the umbrella without Diagnostics down the road. (The umbrella still links it for the everyday `import CodeEditorPlugin` flow.)

## What stays unchanged

- **`UnifiedPerformanceTracking` marker** in `CodeEditorCommon`. Stays exactly as-is. Configuration continues to hold `(any UnifiedPerformanceTracking)?`; `AsyncSyntaxHighlighter` continues to cast back via `as? UnifiedPerformanceSystem`. The cast now resolves through the umbrella's `import CodeEditorDiagnostics`.
- **`Core/CodeEditorDependencies.swift`** factory bodies. The file gains `import CodeEditorDiagnostics` so its `makeProductionPerformanceMetrics()` return type resolves. Nothing else moves.
- **The existing public API surface.** Every consumer that did `import CodeEditorPlugin` keeps working — the umbrella declares `CodeEditorDiagnostics` as a dep and re-exports its types through the same surface. No `@_exported` changes are required for consumers because the moved symbols (`MemoryMonitor`, `ProductionPerformanceMetrics`, etc.) were already accessed through `CodeEditorPlugin` namespacing.

## File inventory

### (a) Moves into `Sources/CodeEditorDiagnostics/` — 14 files

| Source path | Target path | Notes |
|---|---|---|
| `Performance/AdaptivePerformanceMode.swift` | `Diagnostics/AdaptivePerformanceMode.swift` | Imports `Common + Configuration + Languages`; extends `EditorConfiguration.Performance` |
| `Performance/FrameRateMonitor.swift` | `Diagnostics/FrameRateMonitor.swift` | AppKit/UIKit, QuartzCore |
| `Performance/HardwareAcceleration.swift` | `Diagnostics/HardwareAcceleration.swift` | `internal enum`; uses Platform |
| `Performance/IOSLargeFileOptimizer.swift` | `Diagnostics/IOSLargeFileOptimizer.swift` | UIKit + SwiftUI, `@available(iOS 13.0, *)` |
| `Performance/LRUCache.swift` | `Diagnostics/LRUCache.swift` | Drops stale `import CodeEditorLanguages` (no Language symbols actually referenced) |
| `Performance/MemoryMonitor.swift` | `Diagnostics/MemoryMonitor.swift` | Imports `Common + Platform` |
| `Performance/PerformanceBudget.swift` | `Diagnostics/PerformanceBudget.swift` | Imports `Common` |
| `Performance/PerformanceInsights.swift` | `Diagnostics/PerformanceInsights.swift` | Imports `Common + Platform + IssueReporting + SwiftUI + Combine` |
| `Performance/PerformanceMonitor.swift` | `Diagnostics/PerformanceMonitor.swift` | Imports `Common` |
| `Performance/PerformanceObservation.swift` | `Diagnostics/PerformanceObservation.swift` | Imports `Observation` |
| `Performance/PerformanceTypes.swift` | `Diagnostics/PerformanceTypes.swift` | SwiftUI |
| `Performance/PerformanceViews.swift` | `Diagnostics/PerformanceViews.swift` | `PerformanceStatusView: View`; uses Platform + SwiftUI |
| `Performance/ProductionPerformanceMetrics.swift` | `Diagnostics/ProductionPerformanceMetrics.swift` | Imports `Languages`, `os.log`; per-language metrics |
| `Performance/UnifiedPerformanceSystem.swift` | `Diagnostics/UnifiedPerformanceSystem.swift` | Imports `Common`; conforms to `UnifiedPerformanceTracking` marker |

### (b) New file split out of SH and carried in

| Source | Target | Contents |
|---|---|---|
| `SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift` lines 39–67 | `Diagnostics/MemoryMonitor+AvailableMemory.swift` | The `extension MemoryMonitor` with `availableMemoryMB` computed property |

Today that file hosts two unrelated extensions: lines 1–38 are an `extension SyntaxHighlightingCoordinator` for language-support helpers (stays in place); lines 39–67 are an `extension MemoryMonitor` (moves). The split is mechanical and ships in commit 1 before the directory move in commit 2.

### (c) Deletions — dead code, zero callers in Sources or Tests

| File | Reason |
|---|---|
| `Performance/IncrementalSyntaxHighlighter.swift` | `@MainActor public final class`. Zero consumers in `Sources/` or `Tests/`. Imports `CodeEditorLanguages + CodeEditorTextModel`, so carrying it into Diagnostics would force Diagnostics → those deps for no value. |
| `Performance/OptimizedLineIndexCache.swift` | `@available(*, deprecated, message: "Use LineGeometryStore instead")`. Zero consumers. Replacement already lives in `CodeEditorTextModel`. |

### (d) Relocation — stays in umbrella, moves directory

| File | From | To |
|---|---|---|
| `ViewportManager.swift` | `Sources/CodeEditorPlugin/Performance/` | `Sources/CodeEditorPlugin/Layout/` |

`ViewportManager` is `@MainActor public final class ObservableObject`, imports `CodeEditorPlatform + Combine + AppKit/UIKit`. Only referenced by two test files (`IntegrationTests.swift`, `LargeFilePerformanceTests.swift`). Structurally a viewport/layout helper that should travel with the future §6.2.11 `CodeEditorLayout` target. Same pattern as the §6.0 F3 relocations (e.g., `BackgroundProcessor.swift` ending up in `Core/Text/`).

### (e) Sweep — files gaining `import CodeEditorDiagnostics`

28 umbrella source files reference `MemoryMonitor`, `ProductionPerformanceMetrics`, or `UnifiedPerformanceSystem`. Each gains `import CodeEditorDiagnostics`. The compiler drives the exhaustive sweep — let the build fail and add imports until it greens.

Plus the test target: `CodeEditorPluginTests` Package.swift `dependencies:` block gains `"CodeEditorDiagnostics"`, and the ~20+ Performance-touching test files (`FrameRateMonitorTests.swift`, `MemoryMonitorResetPeakTests.swift`, `MemoryMonitorDITests.swift`, `PerformanceInsightsRealMetricsTests.swift`, `UnifiedPerformanceSystemNonThrowingTrackTests.swift`, `EditorConfigurationPerformanceUnifiedSystemTests.swift`, `AsyncSyntaxHighlighterInstrumentationTests.swift`, `XCTestCase+PerformanceBudget.swift`, etc.) gain the import.

Plus `Core/CodeEditorDependencies.swift` gains `import CodeEditorDiagnostics` so `makeProductionPerformanceMetrics()` resolves.

Plus: `CodeEditorUI`, `CodeEditorSample` targets — check during commit 2 whether they reference Performance symbols. If so, add Package.swift entries + imports.

## Three-commit sequence

Each commit lands on `main` (per the auto-memory "Default to working on main"). Each commit independently green under `swift build && swiftlint --fix && swiftlint && swift test --parallel`.

### Commit 1 — Cleanup (additive/subtractive in umbrella only)

- `git rm Sources/CodeEditorPlugin/Performance/IncrementalSyntaxHighlighter.swift`
- `git rm Sources/CodeEditorPlugin/Performance/OptimizedLineIndexCache.swift`
- `git mv Sources/CodeEditorPlugin/Performance/ViewportManager.swift Sources/CodeEditorPlugin/Layout/ViewportManager.swift`
- Split `SyntaxHighlighting/SyntaxHighlightingCoordinator+Extensions.swift`: keep lines 1–38 (the `SyntaxHighlightingCoordinator` extension), extract lines 39–67 into a new umbrella file `Performance/MemoryMonitor+AvailableMemory.swift` (it'll get carried into Diagnostics in commit 2 by virtue of sitting inside `Performance/` at extraction time).
- Drop the unused `import CodeEditorLanguages` from `Performance/LRUCache.swift` (verified: zero `Language` references in the file).
- Audit `HardwareAcceleration.swift` for actual consumers before commit 2; if it joins `IncrementalSyntaxHighlighter`/`OptimizedLineIndexCache` as dead code, fold its deletion into this commit.

**Acceptance.** Full quality pipeline green. No `Package.swift` changes yet.

### Commit 2 — Extract `CodeEditorDiagnostics`

- `Package.swift` changes:
  - Declare `.library(name: "CodeEditorDiagnostics", targets: ["CodeEditorDiagnostics"])` in `products:`.
  - Declare `.target(name: "CodeEditorDiagnostics", dependencies: ["CodeEditorCommon", "CodeEditorPlatform", "CodeEditorConfiguration", "CodeEditorLanguages", .product(name: "IssueReporting", package: "xctest-dynamic-overlay")], path: "Sources/CodeEditorDiagnostics")`.
  - Add `"CodeEditorDiagnostics"` to the umbrella `CodeEditorPlugin` target's `dependencies`.
  - Add `"Performance"` to the umbrella's `exclude:` list (mirrors the existing `"Languages"` exclude added in `14921a61`).
  - Add `"CodeEditorDiagnostics"` to `CodeEditorPluginTests`'s `dependencies`.
- `git mv Sources/CodeEditorPlugin/Performance Sources/CodeEditorDiagnostics` (carries 14 source files including the `MemoryMonitor+AvailableMemory.swift` introduced in commit 1).
- Sweep the umbrella: add `import CodeEditorDiagnostics` to the ~28 source files that reference moved symbols. Let the compiler drive the list — don't try to enumerate exhaustively up-front.
- Sweep the test target: add `import CodeEditorDiagnostics` to the ~20+ test files that reference moved symbols.
- Add `import CodeEditorDiagnostics` to `Core/CodeEditorDependencies.swift`.
- Audit access modifiers on the 14 moved files: `grep -rn 'internal ' Sources/CodeEditorDiagnostics/*.swift` and promote anything the umbrella consumes to `package` (not `public` — match the phase 0–3 pattern from `8bac96cb`).
- Check `Sources/CodeEditorUI/` and `Sources/CodeEditorSample/` for Performance references; if any exist, wire them through Package.swift dependencies + imports.

**Acceptance.** Full quality pipeline green. `swift package describe` shows `CodeEditorDiagnostics` as a library target and product. SwiftLint strict mode passes (no warnings escalated to errors).

### Commit 3 — Polish (only if needed)

- Resolve any access-modifier promotions or doc-comment fixups surfaced by commit 2's review.
- Update `NEXT.md` §6.0: add a row for `CodeEditorDiagnostics` to the status table with commit hash and "Deviations during §6.2.10" subsection (the `Diagnostics → 4 deps not 1` correction, the `IncrementalSyntaxHighlighter`/`OptimizedLineIndexCache` deletions, `ViewportManager` relocation, MemoryMonitor extension split).
- Update `CLAUDE.md` Source Tree section: remove the `Performance/` row from the umbrella's directory listing and add a note that diagnostics now live in a separate SPM target, parallel to how `Languages/` is treated post-§6.2.6.

If commit 3 has no code changes (only NEXT.md + CLAUDE.md updates), keep it as a separate docs-only commit; the auto-memory "Default to working on main" pattern handles this fine.

**Acceptance.** Full quality pipeline green. If genuinely nothing is left after commit 2, skip commit 3 entirely and roll its doc updates into a follow-up.

## Risks

1. **R1 — Access modifier surprises across the new target boundary.** Phase 0–3's `8bac96cb` baseline promoted 116 internal symbols to `package`. Diagnostics will likely surface a small follow-up set — internal symbols on `MemoryMonitor` / `ProductionPerformanceMetrics` / `UnifiedPerformanceSystem` the umbrella consumes implicitly today via same-target relaxation. Mitigation: deliberate audit step inside commit 2; promote to `package` only, never `public`.
2. **R2 — SwiftLint strict mode on the new target.** Project-level rules apply (no `print()`, no force unwrap, `#if canImport` not `#if os()`). The 14 moving files already pass; don't regress during the `MemoryMonitor+AvailableMemory.swift` split.
3. **R3 — Performance-test churn.** ~20+ test files reference Performance symbols. The `import CodeEditorDiagnostics` sweep must cover them. Mitigation: let the build fail and follow the errors rather than enumerating.
4. **R4 — Snapshot tests touching `PerformanceViews`.** If any UI snapshot test renders `PerformanceStatusView`, that test needs the import. Quick guard: `grep -rn 'PerformanceStatusView' Tests/` during commit 2.
5. **R5 — `CodeEditorUI` / `CodeEditorSample` consumers.** Both products are declared in `Package.swift`. If either references Performance symbols directly, they get matching Package.swift dependencies and `import CodeEditorDiagnostics`.
6. **R6 — `MemoryManagementCoordinator` cross-target surface.** Lives in `Core/`; stores a `MemoryMonitor`. After extraction it `import`s `CodeEditorDiagnostics` and consumes the public `MemoryMonitor` surface. No relocation needed. Flagged only to confirm we don't try to move it during commit 2.

## Open questions resolved in this spec

- **Q: One spec or two (Diagnostics + SH together)?** → One. SH gets a follow-up spec written against post-Diagnostics state.
- **Q: How to handle the three misfiled/dead Performance files?** → Delete `IncrementalSyntaxHighlighter.swift` + `OptimizedLineIndexCache.swift` (both have zero callers). Relocate `ViewportManager.swift` to umbrella `Layout/`.
- **Q: Per-target test target now (`CodeEditorDiagnosticsTests`) or later?** → Later. Match phases 0–3 pattern; defer per-target test extraction to a future omnibus PR.
- **Q: Commit sequencing — one big PR or split?** → Three commits on one branch (`main` per the auto-memory default): cleanup → extract → polish (optional).
- **Q: Does `HardwareAcceleration` survive the extraction?** → Decided inside commit 1 via grep; if zero consumers, fold its deletion into commit 1's cleanup. If used, carries into Diagnostics as `internal`.

## Validation plan

After commit 2:

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
swift package describe | rg 'CodeEditorDiagnostics'   # confirm target + product visible
swift build --target CodeEditorDiagnostics            # confirm builds in isolation
swift build --target CodeEditorPlugin                 # confirm umbrella still builds
swift build --target CodeEditorSample                 # confirm sample app still builds
```

Targeted test verification (per the auto-memory "skip full swift test --parallel after additive-only steps"):

```bash
swift test --filter MemoryMonitorResetPeakTests
swift test --filter FrameRateMonitorTests
swift test --filter PerformanceInsightsRealMetricsTests
swift test --filter UnifiedPerformanceSystemNonThrowingTrackTests
swift test --filter EditorConfigurationPerformanceUnifiedSystemTests
```

Manual sample-app smoke: `swift run CodeEditorSample`, open a file, confirm performance overlay still renders (if enabled), confirm syntax highlighting still works on the umbrella's `AsyncSyntaxHighlighter` path. No regression in the typing path (per the auto-memory "NSTextView init invariant" — Diagnostics extraction doesn't touch the AppKit text-system wiring, so this is a sanity check, not a risk).

## Follow-up: what becomes possible after this lands

The §6.2.7 `CodeEditorSyntaxHighlighting` spec, written against post-Diagnostics state, has these properties absent today:

- The back-references in the six SH files (`SyntaxHighlightingCoordinator+Extensions.swift`, `AdaptiveColorSystem.swift`, `OptimizedSyntaxHighlightingCoordinator.swift`, `AsyncSyntaxHighlighter.swift`, `BackgroundSyntaxHighlighter.swift`, `ViewportSyntaxCoordinator.swift`) become routine `import CodeEditorDiagnostics` lines.
- No `AnyMemoryMonitor` / `AnyProductionPerformanceMetrics` marker protocols need inventing in Common.
- `CodeEditorSyntaxHighlighting` declares `CodeEditorDiagnostics` as a direct dep, alongside `CodeEditorLanguages` + `CodeEditorTextModel` + `CodeEditorTheming`. SH ends up at phase 5.
- SH's extraction becomes a near-mechanical `git mv` of `Sources/CodeEditorPlugin/SyntaxHighlighting/` minus a few files that need to stay in umbrella (the `SwiftSyntaxHighlighter*.swift` already moved out per §6.2.6's deviations; the SH-coordinator portion of `SyntaxHighlightingCoordinator+Extensions.swift` survives that split).
