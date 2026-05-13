# Sample App Completion Inspector — Design Spec

**Date:** 2026-05-13
**Status:** Design — ready for implementation plan
**Related:** `NEXT.md` "Code completion — protocol is hidden"; precedents: `docs/superpowers/specs/2026-05-13-sample-app-lsp-integration-design.md`, `docs/superpowers/specs/2026-05-13-sample-app-performance-inspector-design.md`

## Context

The framework ships a rich completion subsystem — `CompletionProvider` protocol, `CompletionManager` (with LRU cache, debouncing, statistics), `CompletionProviderRegistry`, `SmartCompletionEngine`, and ready-made `LanguageMemberCompletions` data for fourteen languages (Python, JavaScript, TypeScript, Swift, Go, Rust, C++, Java, Ruby, PHP, YAML, Markdown, JSON, C). `CodeEditorView.requestCompletion(...)` is public, and a built-in `CompletionViewController` automatically presents the popup as an `NSWindow` (macOS) or `UIPopover` (iOS) when the manager returns items.

Despite all of that, the sample never registers a single provider. The four toggles in `BehaviorKnobsSection.swift` (`isCodeCompletionEnabled`, `isAutomaticTextCompletionEnabled`, `showInlineCompletionSuggestions`, `completionTriggerCharacters`) flip framework flags but nothing fires — `CompletionManager.providers` is empty, so the popup never appears even with `isCodeCompletionEnabled = true`. A consumer reading this codebase has no way to discover how to register a provider, what the popup looks like, or whether their custom provider is being called.

Exploration also surfaced a pre-existing inconsistency in the framework: there are **two parallel provider stores**. `CodeEditorView.requestCompletion()` (which fires the popup) reads `CompletionManager.providers`, while `SmartCompletionEngine` / `CompletionGenerationService` reads `CompletionProviderRegistry` (owned by `EditorRuntime`). Registering to one does not propagate to the other. Bridging or unifying these is **out of scope** for this work; it is documented as a known gap below and tracked as a follow-up.

This spec covers the new sample-side panel **plus** the small public surface needed on `EditorController` to register providers from outside the framework.

## Goals

1. Add a `CompletionInspectorPanel` to the macOS sample's inspector sidebar, between `PerformanceInspectorPanel` and `AnnotationsInspectorPanel`.
2. Make the built-in completion popup actually appear when typing trigger characters in any of the fourteen languages with `LanguageMemberCompletions` data.
3. Surface the public `CompletionProvider` protocol path with a concrete sample-side custom provider, registered through a new minimal `EditorController` API.
4. Mirror the `LSPSampleCoordinator` ⇄ `LSPInspectorPanel` and `PerformanceSampleCoordinator` ⇄ `PerformanceInspectorPanel` pattern so the next NEXT.md item (Event Log panel) has a third precedent to follow.
5. Display live activity — per-provider request count, last request, recent ring of fires, framework-side statistics (requests, cache hit rate, avg processing time).

## Non-goals

- iOS feature parity. Whole feature is macOS-only via `#if canImport(AppKit)`, mirroring LSP and Performance. NEXT.md item 7 (iOS parity) remains a separate refactor.
- Splitting `AppState` into per-feature observable models. NEXT.md item 1 is a deferred refactor; the LSP and Performance work explicitly left `AppState` as a god object and this work follows that precedent.
- Bridging `CompletionManager.providers` and `CompletionProviderRegistry`. The two-store inconsistency is a known framework gap (see "Known gaps & follow-ups" below). This work registers to `CompletionManager` (the popup path) only.
- Type-aware member completion. `BuiltInMemberCompletionProvider` infers the target type heuristically from the token before the trigger character. If the heuristic returns nil, the language's `DefaultMemberCompletions` path kicks in. A real type checker is not in scope.
- A polished popup UI. The framework's existing `CompletionViewController` is used as-is. Restyling it is a separate concern.
- A keyboard-driven completion-trigger override. Manual fire is exposed in the inspector panel as a button (and through the existing public `requestCompletion(...)` on `CodeEditorView`); no new key binding is added.
- Splitting `LanguageMemberCompletions` data into a public-facing factory in the framework. The wrappers live in the sample, demonstrating the consumer-side pattern for "wrap your member data in a `CompletionProvider`". A future framework promotion is left for a follow-up if other consumers want the same wrappers.

## Architecture

```
Sources/CodeEditorSample/
  App/
    AppState.swift                                   ← edit (own coordinator, attach on init)
    Completion/                                      ← new directory
      CompletionSampleCoordinator.swift              ← new
      BuiltInLanguageProviders.swift                 ← new
      DemoCompletionProvider.swift                   ← new
      TelemetryCompletionProvider.swift              ← new
      CompletionActivityEntry.swift                  ← new (small value type)
  Sidebars/
    InspectorSidebar.swift                           ← edit (mount panel)
    CompletionInspectorPanel.swift                   ← new

Sources/CodeEditorPlugin/
  Core/
    EditorController+Completion.swift                ← new
    CodeEditorView.swift                             ← unchanged (completionManager stays `internal`;
                                                              new extension forwards through a
                                                              package-internal accessor on the view)
```

### Ownership

- `AppState` owns one `CompletionSampleCoordinator` instance, constructed eagerly. Coordinator is `@MainActor @Observable`.
- The coordinator owns one `TelemetryCompletionProvider` per wrapped provider. It does not own the framework's `CompletionManager` — that is internal to `CodeEditorView`.
- The coordinator captures a weak reference to `EditorController` via `attach(to:)`, polled on a 1Hz timer for `completionStatistics` and `registeredCompletionProviders` (mirroring `PerformanceSampleCoordinator`).
- `DemoCompletionProvider` is stateless. `BuiltInMemberCompletionProvider` owns a single `LanguageMemberCompletions` value. Both are `Sendable`.

## Components

### Framework: `EditorController+Completion.swift`

Additive surface. Forwards to `editorView.completionManager`, which stays `internal`. Since `EditorController` lives in the same module as `CodeEditorView`, it has direct access — no visibility change to `completionManager` itself is required, and the rest of the manager stays out of the public API.

```swift
@MainActor
extension EditorController {
    /// Registers a completion provider with the active editor's completion manager.
    /// Providers are matched against the current buffer's `Language` and the configured
    /// trigger characters. Re-registering with the same `id` replaces the existing provider.
    ///
    /// - Important: Only effective after `attach(to:)` has been called. No-op otherwise
    ///   (logged via `CrossPlatformLogger`; no `reportIssue` call to avoid noise in samples).
    public func registerCompletionProvider(_ provider: any CompletionProvider)

    public func unregisterCompletionProvider(withId id: String)

    public var registeredCompletionProviders: [any CompletionProvider]

    public var completionStatistics: CompletionStatistics

    /// Mirrors `CodeEditorView.requestCompletion(triggerKind:triggerCharacter:)` for
    /// consumers who only hold an `EditorController`. Convenience only.
    public func requestCompletion(
        triggerKind: CompletionTriggerKind = .manual,
        triggerCharacter: String? = nil
    )
}
```

`CompletionStatistics` is already public (in `CompletionManager.swift`); we are returning the live reference, not a copy. The view-model layer reads it on each panel refresh.

The implementation acquires `editorView.completionManager` and forwards. If `editorView` is nil (controller unattached), each method early-returns; the accessors return `[]` and a zero-stats sentinel.

### Sample: `CompletionActivityEntry`

Tiny `Sendable` value type. Records one provider fire:

```swift
struct CompletionActivityEntry: Sendable, Identifiable {
    let id = UUID()
    let providerId: String
    let language: Language
    let triggerCharacter: String?
    let prefix: String                // truncated to ≤ 32 chars for display
    let itemCount: Int
    let durationMs: Double
    let timestamp: Date
    let error: String?                // nil on success; localized description on failure
}
```

### Sample: `TelemetryCompletionProvider`

Decorator. Wraps any `CompletionProvider`, forwards the call, records timing/count into a callback on the way back. Re-throws errors from the wrapped provider after recording an error entry.

```swift
struct TelemetryCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String]
    let supportsSnippets: Bool
    let wrapped: any CompletionProvider
    let recorder: @Sendable (CompletionActivityEntry) -> Void

    init(
        wrapping provider: any CompletionProvider,
        recorder: @escaping @Sendable (CompletionActivityEntry) -> Void
    )

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let start = Date()
        do {
            let result = try await wrapped.completions(for: context)
            recorder(.init(
                providerId: wrapped.id,
                language: context.language,
                triggerCharacter: context.triggerCharacter,
                prefix: String(context.prefix.prefix(32)),
                itemCount: result.items.count,
                durationMs: Date().timeIntervalSince(start) * 1000,
                timestamp: Date(),
                error: nil
            ))
            return result
        } catch {
            recorder(.init(
                providerId: wrapped.id, language: context.language,
                triggerCharacter: context.triggerCharacter,
                prefix: String(context.prefix.prefix(32)),
                itemCount: 0,
                durationMs: Date().timeIntervalSince(start) * 1000,
                timestamp: Date(),
                error: String(describing: error)
            ))
            throw error
        }
    }
}
```

The recorder is captured `[weak coord]` so a deallocated coordinator does not keep telemetry alive.

### Sample: `BuiltInLanguageProviders`

One generic provider type keyed on `Language`, plus a factory:

```swift
struct BuiltInMemberCompletionProvider: CompletionProvider {
    let id: String                    // "builtin.swift", "builtin.python", …
    let supportedLanguages: [Language]
    let triggerCharacters: [String]   // ["."] for all thirteen
    let supportsSnippets: Bool = false
    private let members: any LanguageMemberCompletions

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let target = TargetTypeInference.infer(from: context, language: supportedLanguages[0])
        let items = members.createMemberCompletions(for: target, filter: context.prefix)
        return CompletionResult(items: items, context: context)
    }
}

enum BuiltInLanguageProviders {
    static func all() -> [BuiltInMemberCompletionProvider] {
        [
            .init(id: "builtin.swift",      supportedLanguages: [.swift],      triggerCharacters: ["."], members: SwiftMemberCompletions()),
            .init(id: "builtin.python",     supportedLanguages: [.python],     triggerCharacters: ["."], members: PythonMemberCompletions()),
            .init(id: "builtin.javascript", supportedLanguages: [.javascript], triggerCharacters: ["."], members: JavaScriptMemberCompletions()),
            .init(id: "builtin.typescript", supportedLanguages: [.typescript], triggerCharacters: ["."], members: TypeScriptMemberCompletions()),
            .init(id: "builtin.go",         supportedLanguages: [.go],         triggerCharacters: ["."], members: GoMemberCompletions()),
            .init(id: "builtin.rust",       supportedLanguages: [.rust],       triggerCharacters: ["."], members: RustMemberCompletions()),
            .init(id: "builtin.cpp",        supportedLanguages: [.cpp],        triggerCharacters: ["."], members: CppMemberCompletions()),
            .init(id: "builtin.java",       supportedLanguages: [.java],       triggerCharacters: ["."], members: JavaMemberCompletions()),
            .init(id: "builtin.ruby",       supportedLanguages: [.ruby],       triggerCharacters: ["."], members: RubyMemberCompletions()),
            .init(id: "builtin.php",        supportedLanguages: [.php],        triggerCharacters: ["."], members: PHPMemberCompletions()),
            .init(id: "builtin.yaml",       supportedLanguages: [.yaml],       triggerCharacters: [":"], members: YAMLMemberCompletions()),
            .init(id: "builtin.markdown",   supportedLanguages: [.markdown],   triggerCharacters: ["["], members: MarkdownMemberCompletions()),
            .init(id: "builtin.json",       supportedLanguages: [.json],       triggerCharacters: ["\""], members: JSONMemberCompletions()),
            .init(id: "builtin.c",          supportedLanguages: [.c],          triggerCharacters: ["."], members: CMemberCompletions()),
        ]
    }
}
```

**Note:** The exact list of available `*MemberCompletions` structs is verified against `Sources/CodeEditorPlugin/Languages/LanguageMemberCompletions.swift` and `Sources/CodeEditorPlugin/Languages/Data/` during implementation. The fourteen entries above are based on a survey of the framework's `Languages/` tree; if any are not actually `public` or are accessed differently (e.g., Markdown / JSON / YAML completion data lives in `Languages/Data/`, not the main file), the factory uses `DefaultMemberCompletions` as a stand-in for that slot and the implementation plan adjusts. The framework-side audit precedes provider wrapping.

`TargetTypeInference` is a tiny utility that looks at the token immediately before the trigger character:

```swift
enum TargetTypeInference {
    static func infer(from context: CompletionContextModel, language: Language) -> String?
}
```

Best-effort. For `"foo.bar".|` it returns `"String"` (for Swift). For unrecognized patterns it returns nil and the underlying `LanguageMemberCompletions` falls back to its common-member set.

### Sample: `DemoCompletionProvider`

The advertised pattern from `CompletionProtocols+Extensions.swift`'s doc-comment, as compilable code:

```swift
/// Demonstrates the `CompletionProvider` protocol. Returns three text-tag snippets
/// (`TODO:`, `MARK:`, `FIXME:`) on every manual trigger, in every language.
///
/// This is the file consumers should crib from when writing their own provider.
struct DemoCompletionProvider: CompletionProvider {
    let id = "sample.demo"
    let supportedLanguages: [Language] = []   // empty == applies to all languages
    let triggerCharacters: [String] = []      // manual ⌃Space only
    let supportsSnippets: Bool = true

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let items: [CompletionItemModel] = [
            CompletionItemModel(label: "TODO:",  kind: .text, detail: "Demo snippet"),
            CompletionItemModel(label: "MARK:",  kind: .text, detail: "Demo snippet"),
            CompletionItemModel(label: "FIXME:", kind: .text, detail: "Demo snippet"),
        ]
        return CompletionResult(items: items, context: context)
    }
}
```

File header comment explicitly invites consumers to copy and modify.

### Sample: `CompletionSampleCoordinator`

```swift
@MainActor
@Observable
final class CompletionSampleCoordinator {
    struct Snapshot: Sendable {
        var registeredProviders: [RegisteredProviderSummary]
        var recentActivity: [CompletionActivityEntry]      // newest-first, max 20
        var lastActivity: CompletionActivityEntry?         // == recentActivity.first
        var requests: Int                                  // mirror of CompletionStatistics
        var cacheHitRate: Double
        var avgProcessingMs: Double

        static let empty = Snapshot(...)
    }

    struct RegisteredProviderSummary: Identifiable, Sendable {
        var id: String { providerId }
        let providerId: String
        let languages: [Language]   // empty == "all"
        let triggerCharacters: [String]
        let supportsSnippets: Bool
    }

    private(set) var snapshot: Snapshot = .empty
    private weak var controller: EditorController?
    private var refreshTimer: Timer?
    private var ring: [CompletionActivityEntry] = []      // capacity 20

    func attach(to controller: EditorController) {
        self.controller = controller
        let builtIns = BuiltInLanguageProviders.all()
        let demo = DemoCompletionProvider()

        for provider in builtIns {
            controller.registerCompletionProvider(
                TelemetryCompletionProvider(wrapping: provider, recorder: { [weak self] in
                    Task { @MainActor in self?.record($0) }
                })
            )
        }
        controller.registerCompletionProvider(
            TelemetryCompletionProvider(wrapping: demo, recorder: { [weak self] in
                Task { @MainActor in self?.record($0) }
            })
        )

        startTimer()
    }

    func detach()
    func resetActivity()
    func fireAtCursor()                                    // controller?.requestCompletion(.manual)

    fileprivate func record(_ entry: CompletionActivityEntry)
}
```

`startTimer()` schedules a 1Hz `Timer.scheduledTimer` (same cadence as `PerformanceSampleCoordinator`) that polls the controller and rebuilds the snapshot. Ring updates push a new snapshot synchronously on `record(_:)`.

### Sample: `CompletionInspectorPanel`

Stateless SwiftUI view. Takes the snapshot fields as parameters — no direct coordinator reference — so it remains snapshot-testable like `PerformanceInspectorPanel`.

Sections, top to bottom (collapsed by default, mirroring the disclosure pattern in `LSPInspectorPanel`):

1. **Status row** — `● N providers registered` plus a `[⌃␣]` button bound to `coordinator.fireAtCursor()`.
2. **Last request** — language, trigger character, prefix, provider id, items returned, ms. Empty state: "No completions fired yet. Type a trigger character or press ⌃␣."
3. **Statistics** — `Requests`, `Cache hits` (count + percentage), `Avg time` (ms).
4. **Recent activity** — last 20 entries, newest-first. Each row: `HH:MM:SS  provider.id  N · X.Xms`. Failed entries get an `exclamationmark.triangle` SF Symbol prefix and the row reveals `error: …` on hover. `[Clear]` button calls `coordinator.resetActivity()`.
5. **Registered providers** — sorted by `providerId`. Each row: id, languages (or "all"), trigger chars (or "—"), `snippets ✓` if supported.

Panel uses existing `KnobSubsection` / disclosure visuals from `BehaviorKnobsSection.swift` and `LSPInspectorPanel.swift` for consistency. No new tokens.

### Mounting

`InspectorSidebar.swift` adds:

```swift
CompletionInspectorPanel(
    providerCount: appState.completion.snapshot.registeredProviders.count,
    lastActivity: appState.completion.snapshot.lastActivity,
    recentActivity: appState.completion.snapshot.recentActivity,
    registered: appState.completion.snapshot.registeredProviders,
    requests: appState.completion.snapshot.requests,
    cacheHitRate: appState.completion.snapshot.cacheHitRate,
    avgProcessingMs: appState.completion.snapshot.avgProcessingMs,
    onFireAtCursor: { appState.completion.fireAtCursor() },
    onClear: { appState.completion.resetActivity() }
)
```

Position: between `PerformanceInspectorPanel` and `AnnotationsInspectorPanel`. The three "framework subsystem inspectors" sit together.

`AppState` adds:

```swift
let completion = CompletionSampleCoordinator()
```

… constructed eagerly. `attach(to:)` is called from `RootWindow.swift` at the same point LSP and Performance attach.

## Data flow

End-to-end for a single fire when the user types `.` in a Swift buffer:

```
CodeEditorView.checkForCompletionTrigger(at:)
  – "." in completionTriggerCharacters
  – calls requestCompletion(.character, ".")
      │
      ▼
CodeEditorView.requestCompletion(...)
  – builds CompletionContextModel(text, cursor, .swift, …)
  – await completionManager.requestCompletions(for: context)
      │
      ▼
CompletionManager.requestCompletions(for:)
  – LRU cache lookup (100 entries, 5-min TTL)
  – on miss: withTaskGroup over applicable providers
      │
      ├─► TelemetryCompletionProvider(wrapping: builtin.swift)
      │     start = Date()
      │     result = try await wrapped.completions(for:)
      │     recorder(CompletionActivityEntry(…))      ← Task @MainActor coord.record(...)
      │     return result
      │
      ├─► TelemetryCompletionProvider(wrapping: sample.demo)
      │     supportedLanguages == [] → applicable to all languages
      │     ... same pattern
      │
      ▼
CompletionManager.processAndCacheResults(...)
  – flatten, dedupe (by label+kind), sort
  – cache if !incomplete && !empty
      │
      ▼
CodeEditorView.showCompletionPopup(with: items, at:)
  – existing CompletionViewController, NSWindow at cursor rect
```

Inspector-panel refresh (1Hz timer in coordinator, parallel to fires):

```
Timer tick
  → snapshot = build from
        controller.registeredCompletionProviders     (for the list)
        controller.completionStatistics              (for requests / cacheHitRate / avgMs)
        ring                                          (for recent + last activity)
  → @Observable change triggers SwiftUI invalidation
  → CompletionInspectorPanel re-renders
```

### Subtlety: cache hits do not invoke telemetry

`CompletionManager.requestCompletions` returns `cachedResult.result` directly on a cache hit, without invoking any provider. Telemetry decorators therefore do **not** fire on cache hits. This is intentional — cache hits are reflected in `completionStatistics.cacheHitRate`, and "Recent activity" honestly reports what providers actually did. The panel's three stat rows + recent activity ring together give the consumer the full picture.

## Error handling

The completion path already swallows provider failures gracefully — `CompletionManager.collectResultsConcurrently` catches per-provider failures and returns `nil` for that batch entry without affecting other providers. The decorator and coordinator inherit this:

- **Provider throws** inside `TelemetryCompletionProvider.completions`: decorator records an activity entry with `error != nil` and re-throws. `CompletionManager` then catches; the popup is not affected. Panel surfaces the failure with an `exclamationmark.triangle` symbol.
- **Coordinator attached before `EditorController` is ready**: `attach(to:)` early-returns if no view is attached yet (mirrors `LSPSampleCoordinator`). Snapshot stays at `.empty` with "Editor not attached" copy.
- **`registerCompletionProvider` called before `attach(to:)` completed** (framework-side): the new method early-returns if `editorView == nil`, logged via `CrossPlatformLogger`. Documented in the method's doc-comment. No `reportIssue` (matches existing completion-path silent-log pattern).
- **Duplicate provider id**: `CompletionManager.providers` is a `[String: CompletionProvider]`, so re-registering with the same id silently replaces. Acceptable — the inspector's "Registered providers" list reflects live state, so re-registration is visible.
- **`DemoCompletionProvider`** is total — no errors possible. Excluded from error tests.

What we explicitly do **not** do:

- No retry on provider failure. One bad fire is the user's problem to debug; the inspector shows the error.
- No timeout on individual provider calls. `withTaskGroup` waits for all. A pathologically slow provider is a known limitation, out of scope.
- No `IssueReporting` calls. The sample mirrors the framework's existing silent-log pattern.

## Testing

Three layers, scaled to risk.

**`CodeEditorPluginTests` — framework-side coverage** (Swift Testing `@Suite`)

- `EditorControllerCompletionTests.swift`:
  - Register a provider, fire `requestCompletion`, assert it ran (provider's `completions(for:)` was invoked exactly once).
  - Register / unregister / register-with-duplicate-id round-trip; assert `registeredCompletionProviders` reflects state and count.
  - `completionStatistics.totalRequests` increments after a request.
  - Methods are no-ops (and return empty sentinels) when called before `attach(to:)`.

**`CodeEditorSampleTests` — coordinator + telemetry behavior** (Swift Testing `@Suite`)

- `CompletionSampleCoordinatorTests.swift`:
  - `attach(to:)` registers 15 providers (14 built-ins + 1 demo).
  - Activity ring is bounded — push 25 entries, assert size = 20, newest-first order.
  - Error in wrapped provider produces a telemetry entry with `error != nil` and re-throws.
  - `resetActivity()` clears the ring and zeroes the snapshot's recent/last fields but does **not** zero `completionStatistics` (those live in the framework manager).
  - `fireAtCursor()` calls through to `controller.requestCompletion(.manual)`.
- `BuiltInLanguageProvidersTests.swift`:
  - `BuiltInLanguageProviders.all()` returns one provider per supported language, each `id` unique, each with at least one trigger character. Expected count is whatever the implementation lands on after the framework-side audit (~14).
  - Fire each against a contrived `CompletionContextModel`, assert non-empty for languages with rich member data (Swift / JS / Python / Rust / Java) and allow empty for those that delegate to `DefaultMemberCompletions`.
- `TelemetryCompletionProviderTests.swift`:
  - Success path records an entry with `error == nil`, correct `itemCount`, plausible `durationMs > 0`.
  - Failure path records an entry with `error != nil` and re-throws the original error.
  - Recorder is invoked on `@MainActor`.

**`CodeEditorSampleTests` — snapshot test for the panel** (XCTest, `pfw-snapshot-testing`, mirroring `PerformanceInspectorPanelSnapshotTests`)

- `CompletionInspectorPanelSnapshotTests.swift`:
  - Empty state.
  - Populated state with 3 recent entries and the full registered-provider list.
  - Error state (most recent entry has `error != nil`).
  - Light + dark themes.

Tests not written:

- No tests for the popup window itself — existing framework behavior, snapshotting an `NSWindow` is unreliable.
- No tests for the two-store inconsistency. That gap is documented, not fixed here.

## Known gaps & follow-ups

1. **Two parallel provider stores** in the framework. `CompletionManager.providers` (popup path) and `CompletionProviderRegistry` (held by `EditorRuntime`, used by `SmartCompletionEngine` / `CompletionGenerationService`) are not bridged. This work registers to `CompletionManager` only; `SmartCompletionEngine` will continue to see an empty registry. **Follow-up ticket recommended:** unify the two stores or have one observe the other. The cleanest end state is a single registry, with the manager pulling from it on demand. Sketched but not implemented here.

2. **No public framework wrapper for `LanguageMemberCompletions → CompletionProvider`.** This spec puts the wrappers in the sample (`BuiltInLanguageProviders.swift`) to demonstrate the consumer-side pattern. Once at least one other consumer wants the wrappers, promote to the framework as `CompletionProvider.builtInMember(for: Language)` or similar.

3. **Target-type inference is heuristic.** Real type-aware completion needs a type checker or LSP. `LSPSampleCoordinator` already wires `sourcekit-lsp` — a natural follow-up is registering an `LSPCompletionProvider` alongside the built-in member providers. Out of scope here; tracked.

4. **`SmartCompletionEngine` and `CompletionDebouncer` are exercised only transitively.** The sample uses `CompletionManager.requestCompletions` directly via the view's auto-trigger path; it does not register a debouncer. Configuring the debouncer is an additional inspector knob that can be added later if useful.
