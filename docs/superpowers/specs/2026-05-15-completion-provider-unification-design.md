# Completion Provider Unification — Design

**Status:** Draft (brainstorming complete; awaiting user review)
**Date:** 2026-05-15
**Closes:** NEXT.md B.2 (".codeCompletion(provider:) modifier is unread"). Also resolves a previously-unflagged latent bug: built-in keyword completions are dead in any editor that doesn't manually register a provider, because the parallel `CompletionProviderRegistry` / `CompletionGenerationService` / `CompletionViewModel` chain is not on the live popup path.
**Scope:** Framework only. No sample changes. Cross-platform (macOS + iOS).

## Context

NEXT.md B.2 reads:

> After the SwiftUI modifier return-types migration, `CodeEditorIntent.completionProvider` is set by the modifier but never read anywhere in `Sources/CodeEditorPlugin/`. The pre-existing bug was preserved — fixing it requires deciding how a host-supplied SwiftUI-shape provider should compose with `CompletionManager`'s provider registry.

A read of the completion subsystem during brainstorming revealed the situation is broader than the entry implies:

1. The **live completion popup** is driven by `CodeEditorView.completionManager` (`CompletionManager`, per-`CodeEditorView`, lazy via `MemoryManagementCoordinator.createCompletionManager()`). The entry point is `CodeEditorView+CompletionExtensions.swift:108`: `try await completionManager.requestCompletions(for: context)`.
2. The **canonical host-side registration API** is `EditorController.registerCompletionProvider(_:)` (`Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`), which proxies to `completionManager.registerProvider(_:)`. The sample's `LSPSampleCoordinator` uses exactly this path.
3. A **parallel completion subsystem** exists in `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift` and `Sources/CodeEditorPlugin/Completion/{CompletionViewModel,CompletionGenerationService}.swift`, reached only through `Sources/CodeEditorPlugin/Layout/EditorContainerViewModel.swift`. `EditorContainerViewModel` is never instantiated anywhere in `Sources/` or `Tests/`. Confirmed by `grep -rn "EditorContainerViewModel\b" Sources/CodeEditorPlugin/{Core,Layout,SwiftUI}/ | grep -v EditorContainerViewModel.swift` — zero matches.
4. The `.codeCompletion { ctx in [items] }` SwiftUI modifier writes its closure into `CodeEditorIntent.completionProvider` via `transformEnvironment(\.codeEditorIntent)` but no code reads it.

The combined effect: a fresh `CodeEditor(text: …).codeLanguage(.swift)` produces zero completions even at manual trigger, unless the host registers a `CompletionProvider` via `EditorController`. The dead parallel system was meant to provide built-in keyword completions; it doesn't, because nothing constructs `EditorContainerViewModel`.

This spec unifies the system around `CompletionManager` as the single canonical registry, salvages the parallel system's useful behavior (`LanguageDescriptor.keywords`-driven keyword completions) into a small built-in provider, wires the dead SwiftUI modifier into the canonical registry through a closure-adapter provider, and deletes the parallel system.

## Goals

- The `.codeCompletion(provider:)` SwiftUI modifier produces working completions, scoped per `CodeEditor` view.
- Every editor automatically gets keyword completions for its current language without host action.
- Host-supplied providers (`.codeCompletion { … }`, `EditorController.registerCompletionProvider(_:)`, LSP) stack additively — none crowds out the others.
- One canonical provider registry: `CompletionManager.providers`. No parallel pretender.
- Re-renders are idempotent — SwiftUI's per-update `transformEnvironment` write does not churn the manager.
- All four dead types (`CompletionProviderRegistry`, `CompletionGenerationService`, `CompletionViewModel`, `EditorContainerViewModel`) are deleted, along with their accessors on `EditorRuntime` / `EditorFeatureRuntimeDependencies`.
- The single test that touches the dead registry (`MemoryMonitorDITests.swift:121`) is updated.

## Non-goals

- No persistence of frequency/recency data (`CompletionManager`'s existing in-memory LRU is unchanged).
- No new public `CompletionProvider` protocol method — the existing surface is sufficient.
- No iOS-specific work; the modifier closure is already cross-platform.
- No changes to `EditorController`'s public completion surface beyond what's described under "Public API changes".
- No deprecation cycle. The deleted types have no live consumers and no external users beyond a single internal test. The project's prior precedent (MacCatalyst retirement, TextKit1 fallback retirement) is delete-and-update, not deprecate.
- No new trigger-character configuration on the SwiftUI modifier (`triggerCharacters = []`, manual trigger only — see "Error handling & edge cases").
- No salvage of `CompletionViewModel`'s frequency/learning code — `CompletionManager` already has its own LRU.
- No work on NEXT.md B.3 (`EditorState.isDirty` / `hardwareAccelerationActive`).
- No work on the "missing custom syntax highlighter example" entry from NEXT.md A.1.

## Strategic decisions (from brainstorming)

| Question | Decision |
|---|---|
| Scope of unification | Unify around `CompletionManager` as canonical. Delete the parallel system. |
| Composition semantics for modifier | Stack additively. Modifier provider joins built-in + LSP + host-registered providers via the manager's existing concurrent-fetch + merge + priority sort. |
| Language scope for modifier closure | All languages. Adapter's `supportedLanguages = []` — the manager already interprets this as "applies to every language". Host inspects `ctx.language` to early-return when unsupported. |
| Dead parallel system disposition | Delete outright. Salvage `LanguageDescriptor.keywords` lookup + fallback table into a new built-in provider. |

## Architecture

### Canonical model

```
CodeEditorView
  └── completionManager : CompletionManager (per-view, lazy)
        └── providers : [String: any CompletionProvider]
              ├── "builtin.keywords.<lang>"  ← LanguageKeywordCompletionProvider
              │                                (auto-registered; swapped on language change)
              ├── "swiftui-modifier"          ← SwiftUIClosureCompletionProvider
              │                                (registered when .codeCompletion modifier is attached)
              ├── "lsp-completion-provider"   ← LSPCompletionProvider
              │                                (registered by host via EditorController, when LSP is on)
              └── "<host-id>"                 ← any other host-registered provider
```

All registration goes through `CompletionManager.registerProvider(_:)`. The four families above are distinguished only by their `id` strings; the manager treats them uniformly.

### New internal types

#### `LanguageKeywordCompletionProvider`

`Sources/CodeEditorPlugin/Completion/LanguageKeywordCompletionProvider.swift` — framework-internal.

```swift
@MainActor
internal final class LanguageKeywordCompletionProvider: CompletionProvider {
    let id: String                           // "builtin.keywords.<language.identifier>"
    let supportedLanguages: [Language]       // [language]
    let triggerCharacters: [String]          // [] — manual trigger only
    let supportsSnippets: Bool               // false

    private let language: Language
    private let keywords: [String]           // resolved at init time

    init(language: Language) {
        self.language = language
        self.id = "builtin.keywords.\(language.identifier)"
        self.supportedLanguages = [language]
        self.keywords = Self.resolveKeywords(for: language)
    }

    func completions(for context: CompletionContextModel) async throws -> CompletionResult { … }
}
```

`resolveKeywords(for:)` mirrors the dead `CompletionGenerationService.generateBasicCompletions` logic:

1. If `LanguageDescriptor.descriptor(for: language)?.keywords` is non-empty, use that.
2. Else use the `fallbackKeywords(for:)` table (Swift / Python / JS+TS verbatim copy).
3. Else `["if", "else", "for", "while", "return", "break", "continue"]`.

`completions(for:)` calls `SharedCompletionBuilder.createKeywordCompletions(from:filter:languageName:)` with `filter: context.lineText`, returns a `CompletionResult`. Items inherit the builder's existing `priority: 80`. The manager sorts by `priority > priority` (higher first), so keywords land middle-tier — above functions (`75`), types (`70`), modules (`65`), literals (`60`), parameters (`50`); below members (`85`) and snippets (`90`). The spec does not propose changing this priority; LSP and host items that want to sort above keywords must emit `> 80`.

#### `SwiftUIClosureCompletionProvider`

`Sources/CodeEditorPlugin/Completion/SwiftUIClosureCompletionProvider.swift` — framework-internal.

```swift
@MainActor
internal final class SwiftUIClosureCompletionProvider: CompletionProvider {
    let id: String = "swiftui-modifier"
    let supportedLanguages: [Language] = []          // applies to all
    let triggerCharacters: [String] = []             // manual trigger only
    let supportsSnippets: Bool = true                // SwiftUICompletionItem.insertText may contain ${…}

    /// Slot the representable's coordinator swaps on every update.
    var closure: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        guard let closure else {
            return CompletionResult(items: [], context: context, isIncomplete: false, processingTime: 0)
        }
        let bridged = SwiftUICompletionContext(
            text: context.text,
            cursorPosition: context.cursorPosition,
            language: context.language
        )
        let start = Date()
        let items = await closure(bridged)
        let elapsed = Date().timeIntervalSince(start)
        return CompletionResult(
            items: items.map { CompletionItemModel($0, language: context.language) },
            context: context,
            isIncomplete: false,
            processingTime: elapsed
        )
    }
}
```

The `CompletionItemModel(_ swiftUI:language:)` translating init lives next to the adapter (private extension) and maps `SwiftUICompletionItem` fields:

| `SwiftUICompletionItem` | `CompletionItemModel` |
|---|---|
| `label` | `label` |
| `kind: CompletionKind` | `kind: CompletionItemKind` (1:1 mapping table below) |
| `detail` | `detail` |
| `insertText` | `insertText` |
| `documentation` | `documentation` |

`SwiftUICompletionKind` → `CompletionItemKind` translation table (all 15 cases map cleanly, no information loss):

```
.keyword   → .keyword     .function  → .function    .method    → .method
.variable  → .variable    .constant  → .constant    .class     → .class
.struct    → .struct      .enum      → .enum        .interface → .interface
.module    → .module      .property  → .property    .value     → .value
.reference → .reference   .snippet   → .snippet     .text      → .text
```

### `CompletionManager.ensureBuiltInProvider(for:)`

New method on `CompletionManager`:

```swift
public func ensureBuiltInProvider(for language: Language) {
    let newId = "builtin.keywords.\(language.identifier)"

    // Already installed — nothing to do.
    if providers[newId] != nil { return }

    // Sweep out any prior built-in provider for a different language.
    let staleIds = providers.keys.filter {
        $0.hasPrefix("builtin.keywords.") && $0 != newId
    }
    for staleId in staleIds {
        providers.removeValue(forKey: staleId)
    }

    // Host-supplied collision wins — only register if the slot is still open.
    if providers[newId] == nil {
        registerProvider(LanguageKeywordCompletionProvider(language: language))
    }
}
```

Note: the second `providers[newId] != nil` check is redundant with the early-return — kept here as a defense if the sweep step is ever rewritten to do more than `removeValue`.

Wiring: `CodeEditorView.language` (which already has a `didSet`) calls `completionManager.ensureBuiltInProvider(for: language)` after `updateCompletionTriggerCharacters()`. First-time editor wake-up is handled by an `ensureBuiltInProvider(for: language)` call at the end of the existing initial-configure path (typically in `CodeEditorView`'s init/`commonInit` chain — exact site to be confirmed during implementation).

### `CodeEditorRepresentable` + `Coordinator` changes

`CodeEditorRepresentable` gains a property:

```swift
let swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
```

`CodeEditor.body` (`Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`) reads `codeEditorIntent.completionProvider` and passes it into `CodeEditorRepresentable(…, swiftUICompletionProvider: codeEditorIntent.completionProvider, …)`.

`Coordinator` gains:

```swift
private var modifierProviderAdapter: SwiftUIClosureCompletionProvider?
```

In the representable's `updateNSView`/`updateUIView` (whichever path applies per platform), after the existing update steps:

```swift
syncModifierProvider(
    on: codeEditorView,
    closure: swiftUICompletionProvider
)
```

Where `syncModifierProvider` is:

```swift
@MainActor
private func syncModifierProvider(
    on codeEditorView: CodeEditorView,
    closure: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
) {
    let manager = codeEditorView.completionManager

    switch (closure, modifierProviderAdapter) {
    case (.some(let new), .some(let adapter)):
        // Just swap the slot; the adapter is already in the manager.
        adapter.closure = new
    case (.some(let new), .none):
        let adapter = SwiftUIClosureCompletionProvider()
        adapter.closure = new
        modifierProviderAdapter = adapter
        manager.registerProvider(adapter)
    case (.none, .some):
        manager.unregisterProvider(withId: "swiftui-modifier")
        modifierProviderAdapter = nil
    case (.none, .none):
        break
    }
}
```

This is the only churn-control point: a re-render with the same closure is a single property assignment on the adapter; the manager's dictionary is untouched.

## Data flow

### Modifier registration

```
View body
  └── .codeCompletion { ctx in [items] }   →   transformEnvironment(\.codeEditorIntent)
                                                  └── intent.completionProvider = closure

CodeEditor.body
  └── reads codeEditorIntent.completionProvider
        └── CodeEditorRepresentable(swiftUICompletionProvider: closure, …)

Coordinator.update{NS,UI}View
  └── syncModifierProvider(on:, closure:)
        ├── first non-nil:  alloc adapter, slot ← closure, registerProvider(adapter)
        ├── subsequent:     slot ← closure  (no manager touch)
        └── transition to nil: unregisterProvider("swiftui-modifier"), drop adapter
```

### Built-in keyword registration

```
CodeEditorView.language { didSet }
  ├── applySyntaxHighlighting()                 (existing)
  ├── updateCompletionTriggerCharacters()       (existing)
  └── completionManager.ensureBuiltInProvider(for: language)
        ├── prior "builtin.keywords.*" present? remove it
        └── new id slot open?                   register(LanguageKeywordCompletionProvider)
```

### Request at trigger time

Unchanged from today. `CodeEditorView+CompletionExtensions.requestCompletion` builds a `CompletionContextModel`, calls `manager.requestCompletions(for:)`. The manager's `fetchResultsFromProviders` filters by `supportedLanguages.contains(language) || isEmpty`, runs all matching providers concurrently, merges, deduplicates, sorts by priority. The popup is shown via `showCompletionPopup` exactly as today.

The three new actors fit the existing pipeline without it knowing about them:

- `LanguageKeywordCompletionProvider`: passes the `contains` arm.
- `SwiftUIClosureCompletionProvider`: passes the `isEmpty` arm.
- `LSPCompletionProvider`: behavior unchanged (`supportedLanguages: []` since 0c7a; passes the `isEmpty` arm).

## Public API changes

### Unchanged

- `.codeCompletion(provider:)` — same signature. Docstring updated to drop the "not yet consumed" disclaimer.
- `EditorController.registerCompletionProvider(_:)`, `.unregisterCompletionProvider(withId:)`, `.registeredCompletionProviders`, `.completionStatistics`, `.completionEvents()`, `.recordCompletionSelection(_:)`, `.requestCompletion(triggerKind:triggerCharacter:)`.
- `CompletionManager.registerProvider(_:)`, `.unregisterProvider(withId:)`, `.registeredProviders`.
- `CompletionProvider` protocol (no new requirements).

### New

- `CompletionManager.ensureBuiltInProvider(for: Language)` — `public`, `@MainActor`. Idempotent. Documented as automatically invoked by `CodeEditorView` on language change; exposed publicly so hosts running `CompletionManager` standalone (rare but supported by the public init) can install built-ins themselves.

### Removed (breaking, no deprecation cycle)

- `EditorRuntime.completionProviderRegistry: CompletionProviderRegistry` — public accessor removed.
- `EditorFeatureRuntimeDependencies.completionProviderRegistry` — removed.
- `EditorRuntime.completion.completionProviderRegistry` — removed.
- `class CompletionProviderRegistry` — file deleted.
- `class CompletionGenerationService` — file deleted (internal already).
- `class CompletionViewModel` — file deleted (public; no callers).
- `class EditorContainerViewModel` — file deleted (public; no callers).

If `EditorRuntime` or `EditorFeatureRuntimeDependencies` references break compile elsewhere during the work, the fix is to remove the reference — no shim is introduced.

## Deletions in detail

| Path | Reason |
|---|---|
| `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift` | Parallel registry; canonical now lives in `CompletionManager`. |
| `Sources/CodeEditorPlugin/Completion/CompletionGenerationService.swift` | Logic salvaged into `LanguageKeywordCompletionProvider.resolveKeywords` and the existing `SharedCompletionBuilder.createKeywordCompletions`. |
| `Sources/CodeEditorPlugin/Completion/CompletionViewModel.swift` | Dead — constructed only by `EditorContainerViewModel`, which is itself dead. |
| `Sources/CodeEditorPlugin/Layout/EditorContainerViewModel.swift` | Never instantiated anywhere in `Sources/` or `Tests/`. |

Property removals on surviving types:

- `EditorRuntime.completion.completionProviderRegistry` — drop the stored property; drop the public accessor at file scope.
- `EditorFeatureRuntimeDependencies.completionProviderRegistry` — drop the property; drop any helpers that build it.

## Error handling & edge cases

**Closure errors.** The modifier closure isn't `throws` and returns `[SwiftUICompletionItem]` (non-optional). Nothing can fail at the closure invocation site. The adapter wraps the result in `CompletionResult` and returns success. The manager's existing `.failed(SendableError)` broadcast path is unreachable from this provider — documented in the adapter's docstring.

**Cancellation.** `CompletionManager.requestCompletions` already cancels in-flight `currentRequest` on a new call. The closure runs inside `withTaskGroup`, so cancellation propagates if the host's closure checks `Task.isCancelled`. If the host ignores cancellation, the work completes but the result is dropped — same contract as for any other provider.

**Re-entrancy / concurrent re-renders.** `syncModifierProvider` is `@MainActor`. The slot swap is a single property assignment; `registerProvider` is a `@MainActor` dictionary write. No data race.

**Modifier removed mid-session.** If `.codeCompletion(...)` is conditionally applied (e.g., `if condition { … }`), the nil branch propagates through `intent.completionProvider`. The next coordinator update unregisters the adapter. Built-in keyword provider continues firing.

**Language switch.** `ensureBuiltInProvider` sweeps any `"builtin.keywords.*"` other than the new one, then registers the new built-in. Net effect: exactly one built-in provider in the registry at all times.

**Host collision on built-in id.** If a host registers a provider with id `"builtin.keywords.swift"`, `ensureBuiltInProvider` checks for slot presence before registering (the early `if providers[newId] != nil { return }`) — host wins. The host can effectively disable built-ins by registering a no-op provider with the canonical id.

**No-`LanguageDescriptor` languages.** `LanguageKeywordCompletionProvider.resolveKeywords` falls through three tiers (descriptor → fallback table → generic seven-keyword list) and never returns empty. Matches the dead path's behavior verbatim.

**Empty closure return.** Closure may return `[]`; `CompletionResult.items` is `[]`; manager's merge handles empty lists already (`isIncomplete` stays `false`). Popup is suppressed by the existing `if !result.items.isEmpty` guard if no other provider returned items.

**Coordinator outlives view (or vice versa).** The adapter is owned by the coordinator. When the coordinator is torn down (representable removed from hierarchy), the adapter goes with it. The manager's reference to the adapter is by `id` in a dictionary; when SwiftUI tears down the `CodeEditorView`, the manager dies with it. No dangling references.

## Testing

### New test files (`Tests/CodeEditorPluginTests/Completion/`)

1. **`LanguageKeywordCompletionProviderTests.swift`**
   - Descriptor-backed keyword sourcing for Swift / Python / JS / TS.
   - Fallback-table sourcing for a language without a `LanguageDescriptor`.
   - Generic seven-keyword last-resort for unknown language.
   - `kind == .keyword` for every produced item.
   - Returned `priority` is `80` (inherited from `SharedCompletionBuilder`). Pinning this catches accidental retunes; spec's risk section names this test as the canary.
   - `supportedLanguages == [language]` exactly (single-element, scoped).

2. **`SwiftUIClosureCompletionProviderTests.swift`**
   - Closure receives a `SwiftUICompletionContext` with `text`, `cursorPosition`, `language` matching the input `CompletionContextModel`.
   - All 15 `CompletionKind` cases round-trip to `CompletionItemKind` (parametrized).
   - `insertText` defaults to `label` when `nil` (existing `SwiftUICompletionItem.init` contract — assert it's preserved through translation).
   - `supportedLanguages == []`, `triggerCharacters == []`, `supportsSnippets == true`.
   - Slot swap: alloc, set closure A, invoke → results from A; set closure B, invoke → results from B; same adapter instance.

3. **`CompletionManagerBuiltInProviderTests.swift`**
   - `ensureBuiltInProvider(for: .swift)` registers exactly one provider with id `"builtin.keywords.swift"`.
   - Idempotent: calling twice keeps one provider.
   - Language switch: after `ensureBuiltInProvider(for: .swift)` then `ensureBuiltInProvider(for: .python)`, exactly one built-in is registered (`"builtin.keywords.python"`) — the Swift one is gone.
   - Host collision: after `manager.registerProvider(stubProviderWithId("builtin.keywords.swift"))` then `ensureBuiltInProvider(for: .swift)`, the stub stays — built-in does not clobber.

4. **`SwiftUIClosureLifecycleTests.swift`**
   - First non-nil closure registers the adapter; manager has exactly one `"swiftui-modifier"` provider.
   - Re-render with same closure: adapter identity stable; `registerProvider` is not called twice for that id (verified by mocking the manager's register hook or by observing the count of `registeredProviders` stays at 1 across N updates).
   - Re-render with new closure: adapter slot now returns new closure's result on next `completions(for:)`; manager still has exactly one provider.
   - Transition to nil: provider is unregistered; manager's `registeredProviders` no longer contains the id.

5. **`CodeEditorModifierCompletionIntegrationTests.swift`**
   - End-to-end harness: build a `CodeEditor` with `.codeCompletion { _ in [SwiftUICompletionItem(label: "foo", kind: .function)] }` and `.editorController(controller)`. After the first body pass (driven by a host helper similar to existing integration tests), `controller.registeredCompletionProviders` contains both `"swiftui-modifier"` and `"builtin.keywords.<lang>"`.
   - Drive `controller.requestCompletion()`; capture the popup's items via the existing test hook (or via the `completionEvents()` stream). Assert results contain both the modifier item (`"foo"`) and at least one keyword from the language's `LanguageDescriptor`.

### Updates

- `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift:121` — rewrite to call `manager.ensureBuiltInProvider(for: .python)` and assert via `controller.registeredCompletionProviders` (or `manager.registeredProviders`) that a provider with id `"builtin.keywords.python"` is present.

### Deletions

No existing tests reference any of the four to-be-deleted classes (verified by `grep -rln "CompletionViewModel\b\|CompletionGenerationService\b\|CompletionProviderRegistry\b\|EditorContainerViewModel\b" Tests/` — zero matches), so no test deletions are required beyond the registry-accessor update above.

### Verification commands (before commit)

```
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Per project memory: full parallel test runs are skipped between purely additive steps; targeted `swift test --filter` is preferred. The full suite runs after each meaningful slice and once at the end.

## Migration / breaking changes

This is a breaking change for any consumer of `EditorRuntime.completionProviderRegistry` or the four deleted types. Known external consumers:

- None inside this repository's `Sources/` or `Sources/CodeEditorSample/`.
- One internal test (`MemoryMonitorDITests.swift:121`), updated as part of the work.

External hosts using `EditorRuntime.completionProviderRegistry`, `CompletionViewModel`, `CompletionGenerationService`, or `EditorContainerViewModel` (if any exist outside this repo) need to migrate to `EditorController.registerCompletionProvider(_:)` or `CompletionManager.registerProvider(_:)`. The migration story:

- Manual provider registration: `editorRuntime.completionProviderRegistry.register(p)` → `editorController.registerCompletionProvider(p)`.
- Reading provider statistics: gone (the dead `ProviderStatistics` type goes with the registry). `CompletionManager.statistics` covers request-level stats; per-provider stats can be reconstructed from `completionEvents()` if a host actually needs them.

Documented in the spec; no shim provided.

## Risks

**Latent paths.** The audit found no consumers of the four dead classes outside one test, but the codebase has 469 Swift files in the main target and external hosts are out of view. Mitigation: implementation plan will run `grep -r` against the deleted symbols across `Sources/`, `Tests/`, and `docs/` before each file is removed.

**Built-in priority drift.** `LanguageKeywordCompletionProvider` items get `priority: 80` (inherited from `SharedCompletionBuilder.createKeywordCompletions`). If `SharedCompletionBuilder` is later retuned, keywords could leapfrog or sink unexpectedly relative to members/snippets/LSP. Mitigation: a unit test in `LanguageKeywordCompletionProviderTests` pins the emitted value at `80`, so any retune surfaces as a test failure that forces a deliberate decision.

**Coordinator-update timing.** SwiftUI guarantees `update{NS,UI}View` runs after env changes, but the *exact* sequence (env propagation → body → representable update) has been a source of subtle bugs in the broader codebase (see `2026-05-14-swiftui-modifier-return-types-design.md`). Mitigation: the slot-swap design is idempotent — a missed or duplicated update produces the same end state.

**`ensureBuiltInProvider` first-time fire site.** `CodeEditorView.language` has a `didSet`, but the first-time configure path may set the property before the `completionManager` lazy var has been touched. Implementation must verify the manager exists at the call site (the `lazy var` is forced on first access; making the call in `didSet` is sufficient). If the property's initial value (`.plainText`) doesn't go through `didSet`, an explicit call in `CodeEditorView`'s init/`commonInit` is required. The implementation plan resolves this empirically.

## Follow-ups (deliberately deferred)

- **NEXT.md B.3** (`EditorState.isDirty`, `hardwareAccelerationActive` writers) — out of scope.
- **NEXT.md A.1** ("Custom syntax highlighter example in sample") — out of scope. A future sample task can plug a closure-driven `SyntaxHighlighter` through the existing public registration, mirroring this round's modifier-adapter pattern.
- **`.codeCompletion(for: [Language])` modifier variant** — not added. If a host has a meaningful per-language gate need that early-return doesn't satisfy, revisit.
- **`.codeCompletionTriggers(_:)` modifier** — not added. Hosts wanting trigger-driven firing register a real `CompletionProvider` via `EditorController`.
- **Frequency/learning persistence** — `CompletionManager` already documents this as deferred in its existing `FrequencyEntry` comment block. Unchanged.

## Open questions

None. All four strategic forks were resolved during brainstorming. Remaining detail (the `CodeEditorView.language` first-time-fire site) is empirical and resolved during implementation, not design.

## References

- `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`
- `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift:229`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CompletionExtensions.swift`
- `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift` (to be deleted)
- `Sources/CodeEditorPlugin/Completion/CompletionGenerationService.swift` (to be deleted)
- `Sources/CodeEditorPlugin/Completion/CompletionViewModel.swift` (to be deleted)
- `Sources/CodeEditorPlugin/Layout/EditorContainerViewModel.swift` (to be deleted)
- `docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md` (prior modifier return-types migration; sets context for `CodeEditorIntent`)
- NEXT.md B.2
