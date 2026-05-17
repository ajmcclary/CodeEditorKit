# Phase 0–2 Target Extraction Design

Date: 2026-05-17
Status: Approved for implementation planning
Scope: First chunk of the restructuring described in [`NEXT.md`](../../../NEXT.md) §6.2 — steps 6.2.1 → 6.2.5.

## 1. Goal

Extract five new SPM library targets from the monolithic `CodeEditorPlugin` target without renaming the umbrella or changing the public consumer-facing API. After this work:

- `CodeEditorPlugin` umbrella source directories drop from 21 to 14 (~161 of ~480 files relocate, ~33% of the monolith).
- Five new internal-only library targets exist: `CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorTextModel`, `CodeEditorConfiguration`, `CodeEditorTheming`.
- The umbrella remains the sole public SPM product; the new targets are not yet exposed as products.
- Consumers continue to use the single `import CodeEditorPlugin` statement. The only public-API change is the `EditorConfiguration.apply(to:)` call shape: callers switch from `configuration.apply(to: view)` to `view.apply(configuration)` (see §3d). This is a deliberate, accepted break.

Out of scope (deferred to later brainstorms):
- Exposing new targets as SPM `products`.
- Splitting `Languages/`, `SyntaxHighlighting/`, `Completion/`, `Features/*`, `Layout/`, `Core/`, `SwiftUI/`, `Performance/`, `LSP/`, `Annotations/`, `Search/`, `Workspace/`.
- Converting the umbrella into a thin re-export shim.
- Moving the package to `~/Workspace/packages/`.
- Renaming `CodeEditorPlugin` → `CodeEditorToolkit` (decided: keep the existing name).
- Splitting `CodeEditorPluginTests` into per-target test targets.

## 2. Architecture

Five new SPM library targets, all internal-only for now. Naming follows `CodeEditor<Concept>` (umbrella keeps the existing `CodeEditorPlugin` name).

| Target | Owns (source dirs) | Allowed dependencies |
|---|---|---|
| `CodeEditorCommon` | `Extensions/`, `Utilities/`, `Models/`, plus `CodeEditorError.swift` + `CodeEditorDependencies.swift` (relocated from `Core/` in pre-flight) | external pkgs only: `Dependencies`, `IssueReporting` |
| `CodeEditorPlatform` | `Platform/` | external: `GameController`; **not** `CodeEditorCommon` |
| `CodeEditorTextModel` | `Text/` (47 of 51 files — see §3), `Documents/` | `CodeEditorCommon` |
| `CodeEditorConfiguration` | `Configuration/` (7 files, minus one method extracted in pre-flight) | `CodeEditorCommon`, `CodeEditorTextModel` |
| `CodeEditorTheming` | `Theming/` (incl. `SyntaxStyle.swift`), `Resources/Themes/` | `CodeEditorDesignTokens`, `CodeEditorPlatform` |

The umbrella `CodeEditorPlugin` target keeps everything it currently owns minus the dirs above, and adds the five new targets to its `dependencies:`. Swift surfaces transitive public symbols when targets are linked, so `import CodeEditorPlugin` continues to give consumers everything they used to have.

### Dependency graph (phase 0–2 only)

```
DesignTokens   Platform   Common
                 \           |
                  \          v
                   \    TextModel
                    \    /   \
                     v  v     v
                  Theming   Configuration
                            (still depends on Core
                             for `CodeEditorView`,
                             via a Core/-side extension
                             added in pre-flight)
```

Edges are enforced at compile time by SPM. The only "soft" edge is Configuration's continued reach into the umbrella's `Core/CodeEditorView+Configuration.swift` extension, which is intentional: `EditorConfiguration` stays in `CodeEditorConfiguration`, the *view-applying* method moves to the view's side.

## 3. Pre-flight cleanup (Commit 1)

A single commit before any target is created. Purely internal-to-umbrella refactoring; no `Package.swift` changes; nothing visible to external consumers. Build stays green.

### 3a. Relocate shared types out of `Core/`

- `Sources/CodeEditorPlugin/Core/CodeEditorError.swift` → `Sources/CodeEditorPlugin/Common/Errors/CodeEditorError.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorDependencies.swift` → `Sources/CodeEditorPlugin/Common/Dependencies/CodeEditorDependencies.swift`

The new top-level `Common/` directory inside the existing target is a staging area; its files become `CodeEditorCommon` in commit 2. This is a `git mv`; same target, no import changes needed (still all internal to `CodeEditorPlugin`).

### 3b. Push `Text/` view-helpers into `Core/`

Move these 3 files from `Sources/CodeEditorPlugin/Text/` to a new subdir `Sources/CodeEditorPlugin/Core/Text/`:

- `TextKitLineNumberHelper.swift`
- `TextKitBridge.swift`
- `LineGeometryEditHandler.swift`

All three hold `weak var textView: CodeEditorView?` or cast through `CodeEditorView`. They are view-side helpers, not text model. No code changes — just moves.

### 3c. Handle `TextKit2RenderingOptimizer.swift`

This file uses the concrete `MemoryMonitor` type from `Performance/`. Decision: **leave it in the umbrella for now** by moving it to `Sources/CodeEditorPlugin/Core/Text/` alongside the other view-side helpers. The Performance extraction (phase 6 in `NEXT.md`) will revisit this file and decide between a `MemoryMonitoring` protocol or absorbing it into `CodeEditorTextModel` once the surrounding context is clearer.

### 3d. Move `EditorConfiguration.apply(to:)` to the view's side

Currently in `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`:

```swift
@MainActor public func apply(to view: CodeEditorView) throws { ... }
```

Move just this method into a new file `Sources/CodeEditorPlugin/Core/CodeEditorView+Configuration.swift` as an extension on `CodeEditorView`. Public API surface changes from `configuration.apply(to: view)` to `view.apply(configuration)`. Call sites inside the umbrella are updated in the same commit.

### 3e. Pre-flight verification

After commit 1:

- `swift build && swiftlint --fix && swiftlint && swift test --parallel` runs green.
- No public-API symbols renamed or removed except the `apply(to:)` call-site change.
- `Sources/CodeEditorPlugin/Common/` exists as a staging directory with two files.
- `Sources/CodeEditorPlugin/Core/Text/` exists with four view-side files.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+Configuration.swift` exists.

## 4. Commit sequence

Six commits total on `main`. Each leaves `swift build` green. After each commit, `swift test --filter CodeEditorPluginTests` runs as the targeted check; the full parallel suite runs once at the end of the session.

### Commit 1 — Pre-flight cleanup
See §3. No `Package.swift` changes; no new targets.

### Commit 2 — Extract `CodeEditorCommon` (Phase 0)
- `git mv Sources/CodeEditorPlugin/Common Sources/CodeEditorCommon`
- `git mv Sources/CodeEditorPlugin/Extensions Sources/CodeEditorCommon/Extensions`
- `git mv Sources/CodeEditorPlugin/Utilities Sources/CodeEditorCommon/Utilities`
- `git mv Sources/CodeEditorPlugin/Models Sources/CodeEditorCommon/Models`
- `Package.swift`:
  - Add `.target(name: "CodeEditorCommon", dependencies: [.product(name: "Dependencies", package: "swift-dependencies"), .product(name: "IssueReporting", package: "xctest-dynamic-overlay")], swiftSettings: swiftSettings)`.
  - Add `"CodeEditorCommon"` to `CodeEditorPlugin` target's `dependencies:`.
- No `.product` entry — internal-only target.
- Verify: `swift build && swift test --filter CodeEditorPluginTests`.

### Commit 3 — Extract `CodeEditorPlatform` (Phase 0)
- `git mv Sources/CodeEditorPlugin/Platform Sources/CodeEditorPlatform`
- `Package.swift`:
  - Add `.target(name: "CodeEditorPlatform", swiftSettings: swiftSettings)`.
  - Add `"CodeEditorPlatform"` to `CodeEditorPlugin` target's `dependencies:`.
- Verify: build + tests.

### Commit 4 — Extract `CodeEditorTextModel` (Phase 1)
- `git mv Sources/CodeEditorPlugin/Text Sources/CodeEditorTextModel/Text` (47 files; 4 view-coupled files already moved out in commit 1)
- `git mv Sources/CodeEditorPlugin/Documents Sources/CodeEditorTextModel/Documents`
- `Package.swift`:
  - Add `.target(name: "CodeEditorTextModel", dependencies: ["CodeEditorCommon"], swiftSettings: swiftSettings)`.
  - Add `"CodeEditorTextModel"` to `CodeEditorPlugin` target's `dependencies:`.
- This is the largest extraction. Watch for surprise compile errors from internal symbols that were previously reachable inside one target and now cross a boundary.
- Verify: build + tests.

### Commit 5 — Extract `CodeEditorConfiguration` (Phase 1)
- `git mv Sources/CodeEditorPlugin/Configuration Sources/CodeEditorConfiguration`
- `Package.swift`:
  - Add `.target(name: "CodeEditorConfiguration", dependencies: ["CodeEditorCommon", "CodeEditorTextModel"], swiftSettings: swiftSettings)`.
  - Add `"CodeEditorConfiguration"` to `CodeEditorPlugin` target's `dependencies:`.
- Verify: build + tests.

### Commit 6 — Extract `CodeEditorTheming` (Phase 2)
- `git mv Sources/CodeEditorPlugin/Theming Sources/CodeEditorTheming`
- `git mv Sources/CodeEditorPlugin/Resources/Themes Sources/CodeEditorTheming/Resources/Themes`
- `Package.swift`:
  - Add `.target(name: "CodeEditorTheming", dependencies: ["CodeEditorDesignTokens", "CodeEditorPlatform"], resources: [.process("Resources/Themes")], swiftSettings: swiftSettings)`.
  - Remove the `resources: [.process("Resources/Themes")]` entry from `CodeEditorPlugin`.
  - Add `"CodeEditorTheming"` to `CodeEditorPlugin` target's `dependencies:`.
- Run the sample app smoke test: `swift run CodeEditorSample`, load each bundled theme. Confirm theme JSON loads correctly from the new resource bundle.
- Verify: build + tests; pay attention to snapshot tests under `Tests/CodeEditorPluginTests/Theming/__Snapshots__`.

### Exit criteria for the session

- 6 commits on `main`, each leaving `swift build` green.
- `swift test --parallel` succeeds at the end of the session.
- `swiftlint --fix && swiftlint` clean at the end of the session.
- No `.product` exposure for the new targets — consumers still use the existing `CodeEditorPlugin` product.
- `CodeEditorPlugin` umbrella source dirs reduced from 21 to 14.
- The sample app builds and runs identically to before.

## 5. Testing strategy

The mix of XCTest + Swift Testing in the existing `CodeEditorPluginTests` target stays put. We do **not** split tests into per-target test suites in this session — that's deferred along with `CodeEditorTestSupport` (NEXT.md §6.2.15 / §7). All existing tests continue to exercise the umbrella, which transitively links the new targets.

### Per-commit verification

| Commit | What to run | What we're checking |
|---|---|---|
| 1 — Pre-flight | `swift build && swift test --parallel` | Call-site change to `view.apply(config)` didn't break anything; file moves didn't break the build |
| 2 — Common | `swift build && swift test --filter CodeEditorPluginTests` | Symbols from `Extensions/Utilities/Models` still resolve through the umbrella; `CodeEditorError` and `CodeEditorDependencies` still callable from `Core/`, `Languages/`, etc. |
| 3 — Platform | `swift build && swift test --filter CodeEditorPluginTests` | `GameController` still imports cleanly; `#if canImport(AppKit/UIKit)` types in `Platform/` still resolve for callers |
| 4 — TextModel | `swift build && swift test --filter CodeEditorPluginTests` | 47-file move didn't introduce circular imports; `Documents/` types still reachable; the 4 view-coupled files (now in `Core/Text/`) still find their `Text/` collaborators via `import CodeEditorTextModel` from inside the umbrella |
| 5 — Configuration | `swift build && swift test --filter CodeEditorPluginTests` | `EditorConfiguration` still reachable; `view.apply(config)` extension in `Core/` still compiles against the moved `EditorConfiguration` |
| 6 — Theming | `swift build && swift test --filter CodeEditorPluginTests` + `swift run CodeEditorSample` | Snapshot tests under `Theming/__Snapshots__` do not regress; JSON theme bundle loads correctly from the new resource path |

### Snapshot tests

`Tests/CodeEditorPluginTests/Theming/__Snapshots__` and `Tests/CodeEditorPluginTests/Layout/__Snapshots__` stay where they are. The corresponding `exclude:` entries in `Package.swift` for `CodeEditorPluginTests` do not change. Theming-related tests remain in the umbrella test target because they reach into umbrella-internal types as well as the new `CodeEditorTheming` target.

### Full-suite confirmation

Per existing convention, commits 2–5 run targeted filters. The full `swift test --parallel` runs once at the end of the session for a final confidence check, not after each commit.

### SwiftLint

Commits 1 and 6 are the riskiest for lint — file relocations may trip path-based rules. Run `swiftlint --fix && swiftlint` after each before committing. Commits 2–5 are pure `git mv` and shouldn't trigger lint deltas, but a final pass at the end of the session catches anything missed.

## 6. Risks

### R1 — Hidden cross-boundary imports in `Text/`

Only verified that `Text/` references `CodeEditorView`, `MemoryMonitor`, and `CodeEditorDependencies`. Other references to `Core/`-owned types (`ActorCoordinator`, `EditorController`, `CodeEditorAPI`, etc.) may exist.

- **Mitigation:** before commit 4, run a wider grep across `Sources/CodeEditorPlugin/Text/` and `Sources/CodeEditorPlugin/Documents/` and cross-check every capitalized identifier against where it's defined. If a new reverse-dep surfaces, fold the offending file into `Core/Text/` via a new fix-up commit inserted between commit 3 and commit 4 (do not amend the already-pushed commit 1).
- **Exit if hit:** if more than 2–3 surprise files surface, stop the session at commit 3; redo discovery; bring findings back to brainstorm before commit 4.

### R2 — `Configuration/` may have more view coupling than the one method

Only audited `EditorConfiguration.apply(to:)`. Other files in `Configuration/` may reference `CodeEditorView`-owned types.

- **Mitigation:** before commit 5, run the same widened grep on `Configuration/`. If hits surface, add a fix-up commit inserted between commit 4 and commit 5 that extends `Core/CodeEditorView+Configuration.swift` to absorb the additional methods; do not change commit 5's plan and do not amend commit 1.
- **Exit if hit:** if the surgery looks bigger than two methods, defer commit 5 (Configuration extraction) and stop the session.

### R3 — Theme JSON resource path change breaks loading at runtime

Themes are loaded via `Bundle.module`. After commit 6, `Bundle.module` resolves to `CodeEditorTheming`'s bundle, not `CodeEditorPlugin`'s. If anything outside `Theming/` loads themes via the wrong bundle, runtime loading fails silently (no compile error).

- **Mitigation:** explicit smoke test in commit 6 — run `swift run CodeEditorSample`, load each bundled theme, confirm visible rendering.
- **Exit if hit:** roll back commit 6; either pin theme loading to `Bundle.module` calls from within `CodeEditorTheming` only, or add a `Bundle.codeEditorThemes` helper that resolves to the right target's bundle.

### R4 — Custom SwiftLint rule path scope

The custom `no_print_statements` rule scope is configured in `.swiftlint.yml`. If it pins paths to `Sources/CodeEditorPlugin/`, files moved to `Sources/CodeEditorCommon/` etc. fall out of scope.

- **Mitigation:** read `.swiftlint.yml` once before commit 2; update path filters to include the new target source roots.
- **Exit if hit:** lint-config update, not a structural problem — fix in the same commit and continue.

### R5 — Tests reach into `internal` types that cross new target boundaries

`CodeEditorPluginTests` uses `@testable import CodeEditorPlugin`. After extraction, internal symbols inside (e.g.) `CodeEditorCommon` are no longer reachable through that single testable import.

- **Mitigation:** if a test breaks, add `@testable import CodeEditorCommon` (and similar) to the failing test file. This is the only test-side change expected in this session.
- **Exit if hit:** if 10+ test files need this, that's a signal — pause and reassess whether per-target test reorganization should be pulled forward.

### R6 — `Resources/Themes` migration conflicts with umbrella `resources:` declaration

`Package.swift` currently has `resources: [.process("Resources/Themes")]` on `CodeEditorPlugin`. If `Sources/CodeEditorPlugin/Resources/` becomes empty after commit 6, the umbrella declaration must be removed or SwiftPM warns.

- **Mitigation:** commit 6 drops the umbrella's `resources:` entry entirely (if `Resources/` is empty) and adds it to the new `CodeEditorTheming` target. Both edits land in the same commit.

### R7 — Deferred `MemoryMonitor` coupling

Per §3c, `TextKit2RenderingOptimizer.swift` stays in the umbrella (moved to `Core/Text/`) instead of joining `CodeEditorTextModel`. The future Performance extraction (NEXT.md phase 6) must revisit this file and decide whether to extract a `MemoryMonitoring` protocol or absorb the optimizer into TextModel.

- **Forward-reference:** record this decision in the implementation plan for phase 6 when that brainstorm happens.

## 7. References

- [`NEXT.md`](../../../NEXT.md) — Full restructuring strategy (this spec implements steps 6.2.1 → 6.2.5).
- [`CLAUDE.md`](../../../CLAUDE.md) — Project conventions (canImport rules, no-print rule, snapshot test exclusions).
- `Package.swift` — Current SPM manifest; modified across commits 2–6.
- `~/Workspace/packages/MusicToolkit/ARCHITECTURE.md` — Reference layered architecture this restructure aspires to.
