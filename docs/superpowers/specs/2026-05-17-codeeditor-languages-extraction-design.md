# CodeEditorLanguages extraction (phase 3)

**Date:** 2026-05-17
**NEXT.md step:** §6.2.6 (with §6.2.7 SyntaxHighlighting deferred)
**Scope:** Extract a new SPM target `CodeEditorLanguages` containing all of `Sources/CodeEditorPlugin/Languages/`, the `Language` enum (currently in SyntaxHighlighting/), the Completion data-model layer + `CompletionProvider` protocol, and the folding/symbol interface types pushed down from `Features/`. `CodeEditorSyntaxHighlighting` (NEXT.md §6.2.7) is deferred to a separate spec because it has hard back-references to `Performance/` and `Core/` (`MemoryMonitor`, `ProductionPerformanceMetrics`, `CodeEditorDependencies`).

## Goals

1. Make `Languages/` buildable in isolation — adding a 26th language stops triggering a TextKit2 / Layout rebuild.
2. Push the protocol interfaces Languages implementors need (`CodeFoldingProvider`, `DocumentSymbolProvider`) down into Languages, so future `CodeEditorFolding` and `CodeEditorSymbols` engine extractions consume them via dependency rather than co-location.
3. Move the completion data-model layer to its semantic home (Languages owns language-tagged completion types).
4. Preserve the existing public API surface — consumers that `import CodeEditorPlugin` keep working unchanged via umbrella re-exports.

## Non-goals

- Extracting `CodeEditorSyntaxHighlighting`. Deferred — `MemoryMonitor` (ObservableObject) and `ProductionPerformanceMetrics` (actor) type-erasure is non-trivial and is better paired with the `CodeEditorDiagnostics` extraction (§6.2.10).
- Extracting the Completion *engine* (`CompletionManager`, `CompletionDebouncer`, ranking, view controllers, etc.). Stays in umbrella; extracts in §6.2.8.
- Splitting test targets. Tests stay in `CodeEditorPluginTests` per the phase 0–2 pattern; per-target test extraction lands in §6.2.15.
- Exposing new `.library` products. No new entries in `Package.swift` `products:`. New target is reachable via the umbrella's `@_exported import` only. Productization is a future omnibus PR.
- Any rename (`CodeEditorPlugin` → `CodeEditorToolkit`). Out of scope.

## Target shape & dependency edges

```
CodeEditorCommon   ──┐
CodeEditorTextModel─┼──► CodeEditorLanguages ──► (umbrella CodeEditorPlugin)
CodeEditorPlatform ─┘
                      + SwiftSyntax / SwiftParser (moved off umbrella)
```

**`CodeEditorLanguages` dependencies:** `CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`, `SwiftSyntax`, `SwiftParser`.

**`CodeEditorPlugin` (umbrella) gains a dependency on `CodeEditorLanguages` and loses the direct `SwiftSyntax` / `SwiftParser` dependencies** (those move to the new target's dependency list).

**Import whitelist inside `Sources/CodeEditorPlugin/Languages/`:** `Foundation`, `CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`, `SwiftSyntax`, `SwiftParser`, plus the existing one-file `AppKit` and one-file `UIKit` references. No other imports allowed.

**No phase rearrangement.** This is the phase-3 extraction NEXT.md plans, just without 6.2.7.

## File inventory: what lives in `CodeEditorLanguages` after this PR

### (a) All current contents of `Sources/CodeEditorPlugin/Languages/` — 66 files

Includes the 25 `*LanguageDescriptor.swift` files + `PlainTextLanguageDescriptor.swift` in `Data/`, the `*FoldingProvider.swift` / `*SymbolProvider.swift` implementors, `LanguageDescriptor.swift`, `LanguageProviderFactory.swift`, `LanguageMetadataRegistry.swift`, `LanguageStaticMetadata.swift`, `LanguageMemberCompletions.swift`, `CompletionProfile.swift`, `SharedCompletionBuilder.swift`, `LineBasedSymbolProvider.swift` (defines `LineBasedSymbolProvider` + `StatefulLineBasedSymbolProvider`), `SwiftSyntaxHighlighter.swift`, `SwiftSyntaxHighlighter+SharedExtensions.swift`, `DescriptorHighlightRule.swift`, `SQLParsingUtility.swift`, etc. No relocation needed — the new target's `path:` is `Sources/CodeEditorPlugin/Languages`.

### (b) `Language` enum extracted from SyntaxHighlighting

The `public enum Language` currently sits at `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift:239`. Move it into a new dedicated file `Languages/Language.swift`. Keep it `public`. No declaration change.

### (c) Completion model layer pulled into Languages

| Source path | Target path | Contents |
|---|---|---|
| `Completion/CompletionModels.swift` | `Languages/CompletionModels.swift` | `CompletionItemModel`, `CompletionItemKind`, `CompletionTextEdit`, `CompletionContextModel`, `CompletionTriggerKind`, `CompletionResult`, `CompletionRequestError` |
| `Completion/CompletionProtocols+Extensions.swift` | `Languages/CompletionProtocols+Extensions.swift` | `CompletionProvider` protocol + default-impl extension |

Both files are self-contained — verified by reading `CompletionProtocols+Extensions.swift` (only references `Language`, `CompletionContextModel`, `CompletionResult`, all of which now live in Languages).

The rest of `Completion/` (engine, debouncer, ranking, view controllers, legacy `CompletionItem` struct, providers, adapters, code patterns) **stays in the umbrella** and gains `import CodeEditorLanguages` to pick up the moved types. The engine extracts in §6.2.8.

### (d) Folding & Symbol interfaces pushed down from Features/

| Source file | Symbols moved | New home | Access change |
|---|---|---|---|
| `Features/FoldableRegion.swift` | `FoldableRegion` (struct) + `CodeFoldingProvider` (protocol) | `Languages/CodeFoldingInterfaces.swift` | `internal` → `public` |
| `Features/SymbolNavigationTypes.swift` | `DocumentSymbol` + `DocumentSymbolKind` + `DocumentSymbolProvider` | `Languages/DocumentSymbolInterfaces.swift` | stays `public` |

We split these two files; we do not move them wholesale. The engine code that previously co-located with these declarations (folding engine, symbol-navigation orchestration) stays in `Features/` for now and `import CodeEditorLanguages` to consume the protocols. Folding and Symbols engine extractions happen in §6.2.8.

### (e) F3 spill (expected but not pre-specified)

"F3" is the NEXT.md §6.0 term for "files that have to relocate from a domain subdirectory back into an umbrella semantic home because they're cross-target glue and can't sit cleanly in the new leaf target." Phases 0–2 each surfaced a few such files (cross-target glue, type-erasure shims, method-only extensions). Languages is more self-contained than Text/ or Platform/ was, so the spill should be smaller — but a non-zero number is expected. Any such relocation:

- Lands in `Sources/CodeEditorPlugin/Core/Languages/` (or another existing semantic home).
- Gets documented in NEXT.md §6.0 under "Deviations from the original plan" in the same commit.

### Final count

66 (existing Languages/) + 1 (`Language` enum) + 2 (Completion model files) + 2 (Folding/Symbol interface files split out of Features/) = **71 files in `CodeEditorLanguages/` after this PR**.

## Migration order — six commits, build-green at every checkpoint

Each step ends green for `swift build` + a targeted `--filter` run. The full `swift test --parallel` + `swiftlint` runs once at the end (Step 6). Mirrors the phase 0–2 cadence and respects the user's "don't over-run the test suite mid-plan" feedback.

### Step 1 — Access promotion (no target yet)

- Promote `FoldableRegion` and `CodeFoldingProvider` in `Features/FoldableRegion.swift` from `internal` to `public`.
- Verify NEXT.md §6.0 status table file counts still match reality (Languages = 66, SyntaxHighlighting now 43 not 36 — update if needed).
- `swift build && swift test --filter Folding`. Green — internal → public is additive.
- **Commit 1:** `Promote CodeFoldingProvider/FoldableRegion to public for Languages extraction`

### Step 2 — Extract `Language` enum from SyntaxHighlighting

- Create `Sources/CodeEditorPlugin/Languages/Language.swift`.
- Move the `public enum Language` declaration out of `SyntaxHighlighting/SyntaxHighlightingCoordinator.swift` verbatim.
- Grep for `SyntaxHighlightingCoordinator.Language` (qualified) usages and rewrite to bare `Language` if any exist. Expectation: none, but verify.
- `swift build && swift test --filter SyntaxHighlighting`. Green (still single target, pure file move).
- **Commit 2:** `Relocate Language enum to Languages/ (pre-target-split)`

### Step 3 — Split the two interface files out of Features/

- Create `Languages/CodeFoldingInterfaces.swift` with `FoldableRegion` + `CodeFoldingProvider`. Delete these declarations from `Features/FoldableRegion.swift`; leave the engine code that uses them.
- Create `Languages/DocumentSymbolInterfaces.swift` with `DocumentSymbol` + `DocumentSymbolKind` + `DocumentSymbolProvider`. Delete these declarations from `Features/SymbolNavigationTypes.swift`; leave the engine code that uses them.
- `swift build && swift test --filter Folding && swift test --filter Symbol`. Green (still single target).
- **Commit 3:** `Move Languages-facing interfaces (Folding/Symbol) into Languages/`

### Step 4 — Move Completion model layer

- Move `Completion/CompletionModels.swift` → `Languages/CompletionModels.swift`.
- Move `Completion/CompletionProtocols+Extensions.swift` → `Languages/CompletionProtocols+Extensions.swift`.
- `swift build && swift test --filter Completion && swift test --filter Languages`. Green (still single target).
- **Commit 4:** `Relocate Completion model layer into Languages/`

### Step 5 — Create the `CodeEditorLanguages` target

- In `Package.swift`:
  - Add a new `.target(name: "CodeEditorLanguages", dependencies: ["CodeEditorCommon", "CodeEditorTextModel", "CodeEditorPlatform", .product(name: "SwiftSyntax", package: "swift-syntax"), .product(name: "SwiftParser", package: "swift-syntax")], path: "Sources/CodeEditorPlugin/Languages", swiftSettings: swiftSettings)`.
  - Remove `SwiftSyntax` and `SwiftParser` `.product(...)` entries from the umbrella `CodeEditorPlugin` target's `dependencies:` list.
  - Add `"CodeEditorLanguages"` to the umbrella `CodeEditorPlugin` target's `dependencies:` list.
- Audit cross-boundary access modifiers for symbols Languages exposes:
  - Known public surface (already `public`, no change expected): `Language`, `LanguageDescriptor`, `LanguageMetadataRegistry`, `LanguageProviderFactory`, `LanguageStaticMetadata`, `CompletionProfile`, `SharedCompletionBuilder`, `LineBasedSymbolProvider`, `StatefulLineBasedSymbolProvider`, `CompletionItemModel`, `CompletionItemKind`, `CompletionTextEdit`, `CompletionContextModel`, `CompletionTriggerKind`, `CompletionResult`, `CompletionRequestError`, `CompletionProvider`, `DocumentSymbol`, `DocumentSymbolKind`, `DocumentSymbolProvider`. Plus `FoldableRegion` + `CodeFoldingProvider` (promoted in Step 1).
  - `package` symbols continue to work across the umbrella boundary unchanged — `package` access spans all targets in the same SwiftPM package, which is exactly Phase A's premise (the `8bac96cb` commit promoted 116 symbols to `package` for cross-target-same-package use). No re-promotion needed.
  - Any `internal` symbol the umbrella code touches across the new boundary will fail to build. Expectation: rare, because Phase A already swept. When it happens, promote the minimum necessary symbol to `package` (not `public`) — `public` is only required for symbols an external consumer of `CodeEditorPlugin` needs.
- `swift build`. If it fails, F3 surgery: relocate the offending umbrella file into `Sources/CodeEditorPlugin/Core/Languages/` (or another semantic home) and document under NEXT.md §6.0.
- `swift test --filter Languages && swift test --filter Completion && swift test --filter Folding && swift test --filter Symbol && swift test --filter SyntaxHighlighting`.
- **Commit 5:** `Extract CodeEditorLanguages target (phase 3)`

### Step 6 — Full validation + NEXT.md update

- `swift build && swiftlint --fix && swiftlint && swift test --parallel`. Must be green with zero SwiftLint violations.
- Update NEXT.md:
  - §6.0 status table: add the `CodeEditorLanguages` row with commit hash + file counts ("66 files from Languages/ + 1 Language enum + 2 Completion model files + 2 interface files from Features/ = 71 files total").
  - §6.0 "Deviations from the original plan" bullets: list any F3 surgery actually performed in Step 5, and the deferral of §6.2.7 SyntaxHighlighting with the reason (`MemoryMonitor` / `ProductionPerformanceMetrics` back-refs require type-erasure or post-Diagnostics ordering).
  - §10: strike 6.2.6 from the remaining-work list. Note that 6.2.7 needs its own spec after a Diagnostics-or-erasure decision.
- **Commit 6:** `Update NEXT.md for phase 3 (Languages) extraction`

Six commits, no destructive moves, every checkpoint independently buildable.

## Risks & open questions

1. **`Language` enum is widely referenced.** Step 2 is a pure relocation, but any code using qualified `SyntaxHighlightingCoordinator.Language` breaks. Mitigation: grep before the move; rewrite to bare `Language`. Worst case keep a transitional `typealias Language = ...` shim in the original file.

2. **`CompletionProvider`'s `@MainActor`-isolated requirement.** Today the protocol is colocated with its consumers; the actor isolation is invisible to the build. Crossing a target boundary under Swift 6 strict concurrency may flag a conformance differently. Mitigation: Step 5 covers it. If anything trips, document under NEXT.md §6.0 like `UnifiedPerformanceTracking` was.

3. **F3 spill in Step 5.** Phases 0–2 each needed ~3–30 files relocated to umbrella semantic homes because of unanticipated coupling. Languages is more self-contained than Text/ or Platform/ — spill should be small but is not pre-quantifiable.

4. **`LineBasedSymbolProvider` / `StatefulLineBasedSymbolProvider` are already `public` and already live in Languages.** They conform to `DocumentSymbolProvider`, which moves down in Step 3. After Step 3 all three are sibling protocols inside Languages — clean.

5. **LSP target's implementors of `CompletionProvider`.** `LSPCompletionProvider`, `LSPManager`, `LSPProtocol` stay in the umbrella and gain `import CodeEditorLanguages` after Step 5. Should be transparent. If LSP exposes `internal` types via its conformance, conformance-site access tweaks may be needed.

6. **Legacy `CompletionItem` struct in `CompletionViewModels.swift`.** Separate from `CompletionItemModel`. Stays in umbrella with the rest of the engine; not touched by this spec.

7. **No DocC.** Files moving carry `///` Markdown doc comments. Those keep working as comments. No migration step needed.

8. **Tree-sitter scaffolding.** `Sources/CodeEditorTreeSitterLanguages/` is not a Package.swift target. Doesn't interact with this work.

## Testing approach

- Per-step targeted `swift test --filter <Name>` confirms each commit boundary. The filters that matter:
  - `--filter Languages` — `Tests/CodeEditorPluginTests/Languages/` covers descriptors, registry, completion profile.
  - `--filter Completion` — covers the model-type tests that now live one target away from their definitions.
  - `--filter Folding` and `--filter Symbol` — verify the protocol-promotion + interface-move didn't shift behavior.
  - `--filter SyntaxHighlighting` — `Language` enum relocation sanity check (Step 2).
- Final `swift test --parallel` in Step 6 — single full-suite run, mirrors phase 0–2 cadence.
- No new test files written in this spec. Per-target test extraction lands later in §6.2.15 (`CodeEditorTestSupport`).
- Snapshot tests are not affected — none under `Tests/CodeEditorPluginTests/Languages/` or `…/Completion/` produce images.

## Out-of-scope work surfaced for future specs

1. **§6.2.7 `CodeEditorSyntaxHighlighting` extraction.** Six SH files (`AdaptiveColorSystem`, `AsyncSyntaxHighlighter`, `BackgroundSyntaxHighlighter`, `OptimizedSyntaxHighlightingCoordinator`, `SyntaxHighlightingCoordinator+Extensions`, `ViewportSyntaxCoordinator`) hard-reference `MemoryMonitor`, `ProductionPerformanceMetrics`, and `CodeEditorDependencies`. A separate spec must pick: (a) type-erase via Common-level marker protocols (mirrors `UnifiedPerformanceTracking`), (b) extract `CodeEditorDiagnostics` first (reorders phases), or (c) leave SH in umbrella until Diagnostics is ready.

2. **Productization of new targets.** Phases 0–2 left `CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`, `CodeEditorConfiguration`, `CodeEditorTheming` as targets without `.library` products. This spec adds `CodeEditorLanguages` under the same convention. A future omnibus PR — likely paired with §6.2.15 `CodeEditorTestSupport` or the eventual `~/Workspace/packages/` move — productizes all of them at once if a consumer needs them.

3. **Per-target test extraction.** NEXT.md §7 wants `CodeEditorLanguagesTests`, etc. as separate test targets. This spec keeps tests in the existing `CodeEditorPluginTests` per the phase 0–2 pattern. Per-target test extraction is §6.2.15.
