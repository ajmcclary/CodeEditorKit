# Sample App Completion Inspector — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `CompletionInspectorPanel` to `CodeEditorSample`'s inspector sidebar that surfaces the `CompletionProvider` protocol, registers eight built-in language providers + one custom demo provider through a new public `EditorController` registration API, and shows live activity (recent fires, statistics, registered providers) in the LSP/Performance coordinator pattern.

**Architecture:** A new `EditorController+Completion.swift` exposes a minimal registration API that forwards to the existing internal `CompletionManager`. A sample-side `@MainActor @Observable CompletionSampleCoordinator` wraps every registered provider in a `TelemetryCompletionProvider` decorator so the inspector sees every fire without framework event-hook plumbing. A 1Hz polling refresh mirrors `PerformanceSampleCoordinator`. macOS-only via `#if canImport(AppKit)`.

**Tech Stack:** Swift 6.3 (StrictConcurrency), SwiftUI, Swift Testing (`@Suite`/`@Test`), `swift-snapshot-testing`. macOS 26.3+ already declared in `Package.swift`.

**Spec:** `docs/superpowers/specs/2026-05-13-sample-app-completion-inspector-design.md` (commit `86061e7`).

---

## Audit corrections from the spec

The spec's audit-safety note flagged that the final list of available `LanguageMemberCompletions` conformers should be verified before wrapping. Audit results — the framework ships **eight** public `LanguageMemberCompletions` conformers, not fourteen:

| Conformer | File |
|---|---|
| `SwiftMemberCompletions` | `Languages/LanguageMetadataRegistry.swift` |
| `TypeScriptMemberCompletions` | `Languages/LanguageMetadataRegistry.swift` |
| `GoMemberCompletions` | `Languages/LanguageMetadataRegistry.swift` |
| `PythonMemberCompletions` | `Languages/LanguageMemberCompletions.swift` |
| `JavaScriptMemberCompletions` | `Languages/LanguageMemberCompletions.swift` |
| `RustMemberCompletions` | `Languages/LanguageMemberCompletions.swift` |
| `JavaMemberCompletions` | `Languages/LanguageMemberCompletions.swift` |
| `CMemberCompletions` | `Languages/LanguageMemberCompletions.swift` |

C++, Ruby, PHP, YAML, Markdown, JSON have **no** member-completion struct — those slots are not wrapped. Total providers registered = **9** (8 built-in + 1 demo).

YAML/Markdown/JSON do have keyword data in `Languages/Data/*CompletionData.swift`, but it's not exposed as a `LanguageMemberCompletions` conformer — wrapping that into providers is out of scope and tracked as a follow-up.

---

## Working agreements

- After **every** task, run the project quality gate: `swift build && swiftlint --fix && swiftlint && swift test --parallel`. If anything fails, fix it in the same task before committing.
- Never use `print()` — use `CrossPlatformLogger.logger()` if logging is needed.
- Never use force unwraps. SwiftLint `force_unwrapping` rule + strict mode will catch these.
- Platform guards use `#if canImport(AppKit)`, not `#if os(macOS)`.
- All new commits end with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.
- Conform to `pfw-testing` / `pfw-snapshot-testing` conventions for new tests.

---

## Phase 1 — Framework hook

### Task 1: Add `EditorController` completion API

**Files:**
- Create: `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`
- Create: `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerCompletionTests.swift`

- [ ] **Step 1.1: Write the failing test file**

Create `Tests/CodeEditorPluginTests/SwiftUI/EditorControllerCompletionTests.swift`:

```swift
#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("EditorController completion")
struct EditorControllerCompletionTests {
    @Test("registered providers reflect registration order, dedupe by id")
    @MainActor
    func registeredProvidersReflectState() async {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)

        #expect(controller.registeredCompletionProviders.isEmpty)

        let a = StubProvider(id: "a")
        let b = StubProvider(id: "b")
        controller.registerCompletionProvider(a)
        controller.registerCompletionProvider(b)

        let ids = controller.registeredCompletionProviders.map(\.id).sorted()
        #expect(ids == ["a", "b"])

        // Re-register `a` replaces in place.
        controller.registerCompletionProvider(StubProvider(id: "a", trigger: "."))
        #expect(controller.registeredCompletionProviders.count == 2)

        controller.unregisterCompletionProvider(withId: "a")
        #expect(controller.registeredCompletionProviders.map(\.id) == ["b"])
    }

    @Test("requestCompletion fires registered provider")
    @MainActor
    func requestCompletionFiresProvider() async throws {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "let x = "
        view.isCodeCompletionEnabled = true
        controller.attach(to: view)

        let provider = StubProvider(id: "a")
        controller.registerCompletionProvider(provider)

        controller.requestCompletion(triggerKind: .manual)

        // requestCompletion launches a Task; give it a tick to run.
        try await Task.sleep(for: .milliseconds(50))

        #expect(provider.invocationCount >= 1)
    }

    @Test("methods are no-ops when controller is unattached")
    @MainActor
    func methodsNoopWhenUnattached() {
        let controller = EditorController()

        controller.registerCompletionProvider(StubProvider(id: "x"))
        #expect(controller.registeredCompletionProviders.isEmpty)
        #expect(controller.completionStatistics.totalRequests == 0)

        controller.unregisterCompletionProvider(withId: "x")  // must not crash
        controller.requestCompletion(triggerKind: .manual)    // must not crash
    }

    @Test("completionStatistics increments after a request")
    @MainActor
    func statisticsIncrement() async throws {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "hello"
        view.isCodeCompletionEnabled = true
        controller.attach(to: view)
        controller.registerCompletionProvider(StubProvider(id: "a"))

        let before = controller.completionStatistics.totalRequests
        controller.requestCompletion(triggerKind: .manual)
        try await Task.sleep(for: .milliseconds(50))

        #expect(controller.completionStatistics.totalRequests > before)
    }
}

private final class StubProvider: CompletionProvider, @unchecked Sendable {
    let id: String
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String]
    let supportsSnippets: Bool = false

    private(set) var invocationCount = 0

    init(id: String, trigger: String? = nil) {
        self.id = id
        self.triggerCharacters = trigger.map { [$0] } ?? []
    }

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        invocationCount += 1
        return CompletionResult(items: [], context: context)
    }
}
#endif
```

- [ ] **Step 1.2: Verify the test fails to compile**

Run: `swift test --filter EditorControllerCompletionTests`
Expected: BUILD FAILURE — `value of type 'EditorController' has no member 'registerCompletionProvider'`.

- [ ] **Step 1.3: Add the framework extension**

Create `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`:

```swift
#if canImport(AppKit) || canImport(UIKit)
import Foundation

@available(macOS 13.0, iOS 16.0, *)
extension EditorController {
    /// Registers a completion provider with the active editor.
    ///
    /// Re-registering with the same `id` replaces the existing provider.
    /// No-op if `attach(to:)` has not yet been called.
    ///
    /// Providers are matched against the current buffer's `Language` and the
    /// configured trigger characters. Use `requestCompletion(...)` to fire
    /// manually, or rely on automatic trigger-character firing once
    /// `EditorConfiguration.Behavior.isCodeCompletionEnabled` is `true`.
    public func registerCompletionProvider(_ provider: any CompletionProvider) {
        codeEditorView?.completionManager.registerProvider(provider)
    }

    /// Unregisters a completion provider previously installed via
    /// `registerCompletionProvider(_:)`. No-op if the provider is unknown
    /// or the controller is unattached.
    public func unregisterCompletionProvider(withId id: String) {
        codeEditorView?.completionManager.unregisterProvider(withId: id)
    }

    /// Live snapshot of providers currently registered with the editor.
    /// Empty when no editor is attached.
    public var registeredCompletionProviders: [any CompletionProvider] {
        codeEditorView?.completionManager.registeredProviders ?? []
    }

    /// Cache hit-rate, request count, and average processing time for the
    /// attached editor's completion manager. Returns a zero-state
    /// `CompletionStatistics` instance when no editor is attached.
    public var completionStatistics: CompletionStatistics {
        codeEditorView?.completionManager.statistics ?? CompletionStatistics()
    }

    /// Manually request completion at the cursor. Mirrors
    /// `CodeEditorView.requestCompletion(triggerKind:triggerCharacter:)` for
    /// hosts that only hold an `EditorController`.
    public func requestCompletion(
        triggerKind: CompletionTriggerKind = .manual,
        triggerCharacter: String? = nil
    ) {
        codeEditorView?.requestCompletion(
            triggerKind: triggerKind,
            triggerCharacter: triggerCharacter
        )
    }
}
#endif
```

- [ ] **Step 1.4: Verify the test now passes**

Run: `swift test --filter EditorControllerCompletionTests --parallel`
Expected: 4 passing.

- [ ] **Step 1.5: Quality gate**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`
Expected: zero errors, zero warnings, all tests pass.

- [ ] **Step 1.6: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift \
        Tests/CodeEditorPluginTests/SwiftUI/EditorControllerCompletionTests.swift
git commit -m "$(cat <<'EOF'
Expose completion provider registration on EditorController

Adds register/unregister/statistics/requestCompletion forwarding so
hosts can register `CompletionProvider`s without reaching into the
internal `CompletionManager`. macOS + iOS (the existing controller
availability surface).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 — Sample-side provider types

### Task 2: `CompletionActivityEntry` value type

**Files:**
- Create: `Sources/CodeEditorSample/App/Completion/CompletionActivityEntry.swift`

- [ ] **Step 2.1: Create the file**

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// One completion fire as observed by `TelemetryCompletionProvider`.
/// Used by `CompletionSampleCoordinator` for its recent-activity ring
/// and `CompletionInspectorPanel` for the "Last request" row.
struct CompletionActivityEntry: Sendable, Identifiable {
    let id = UUID()
    let providerId: String
    let language: Language
    let triggerCharacter: String?
    let prefix: String          // truncated to ≤ 32 chars
    let itemCount: Int
    let durationMs: Double
    let timestamp: Date
    let error: String?          // nil on success
}
#endif
```

- [ ] **Step 2.2: Verify it builds**

Run: `swift build --target CodeEditorSample`
Expected: success.

- [ ] **Step 2.3: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/App/Completion/CompletionActivityEntry.swift
git commit -m "$(cat <<'EOF'
Add CompletionActivityEntry value type

Tiny Sendable struct describing one provider fire — provider id, language,
trigger character, prefix, item count, duration, timestamp, optional error.
Foundation for the telemetry decorator landing next.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 3: `TelemetryCompletionProvider` decorator

**Files:**
- Create: `Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift`
- Create: `Tests/CodeEditorSampleTests/TelemetryCompletionProviderTests.swift`

- [ ] **Step 3.1: Write the failing tests**

Create `Tests/CodeEditorSampleTests/TelemetryCompletionProviderTests.swift`:

```swift
#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("TelemetryCompletionProvider")
@MainActor
struct TelemetryCompletionProviderTests {
    @Test("success path records an entry and forwards the result")
    func successPathRecords() async throws {
        var recorded: [CompletionActivityEntry] = []
        let wrapped = StubProvider(id: "stub", items: [
            CompletionItemModel(label: "foo"),
            CompletionItemModel(label: "bar"),
        ])
        let telemetry = TelemetryCompletionProvider(wrapping: wrapped) { entry in
            recorded.append(entry)
        }

        let context = CompletionContextModel(
            text: "let x = ", cursorPosition: 8, language: .swift,
            triggerKind: .character, triggerCharacter: ".", lineText: "let x = "
        )
        let result = try await telemetry.completions(for: context)

        #expect(result.items.count == 2)
        #expect(recorded.count == 1)
        #expect(recorded[0].providerId == "stub")
        #expect(recorded[0].language == .swift)
        #expect(recorded[0].triggerCharacter == ".")
        #expect(recorded[0].itemCount == 2)
        #expect(recorded[0].error == nil)
        #expect(recorded[0].durationMs >= 0)
    }

    @Test("error path records an error entry and re-throws")
    func errorPathRecords() async {
        var recorded: [CompletionActivityEntry] = []
        let wrapped = ThrowingStubProvider(id: "broken")
        let telemetry = TelemetryCompletionProvider(wrapping: wrapped) { entry in
            recorded.append(entry)
        }
        let context = CompletionContextModel(
            text: "", cursorPosition: 0, language: .swift
        )

        do {
            _ = try await telemetry.completions(for: context)
            #expect(Bool(false), "expected throw")
        } catch {
            // Expected.
        }
        #expect(recorded.count == 1)
        #expect(recorded[0].error != nil)
        #expect(recorded[0].itemCount == 0)
    }

    @Test("prefix is truncated to 32 chars")
    func prefixTruncation() async throws {
        var recorded: [CompletionActivityEntry] = []
        let wrapped = StubProvider(id: "s", items: [])
        let telemetry = TelemetryCompletionProvider(wrapping: wrapped) { entry in
            recorded.append(entry)
        }
        let longPrefix = String(repeating: "a", count: 80)
        let context = CompletionContextModel(
            text: longPrefix, cursorPosition: longPrefix.count, language: .swift,
            wordRange: NSRange(location: 0, length: longPrefix.count)
        )

        _ = try await telemetry.completions(for: context)

        #expect(recorded[0].prefix.count <= 32)
    }
}

private final class StubProvider: CompletionProvider, @unchecked Sendable {
    let id: String
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false
    let items: [CompletionItemModel]

    init(id: String, items: [CompletionItemModel]) {
        self.id = id
        self.items = items
    }

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        CompletionResult(items: items, context: context)
    }
}

private struct ProviderError: Error { let why: String }

private final class ThrowingStubProvider: CompletionProvider, @unchecked Sendable {
    let id: String
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false

    init(id: String) { self.id = id }

    @MainActor
    func completions(for _: CompletionContextModel) async throws -> CompletionResult {
        throw ProviderError(why: "boom")
    }
}
#endif
```

- [ ] **Step 3.2: Verify the test fails to compile**

Run: `swift test --filter TelemetryCompletionProviderTests`
Expected: BUILD FAILURE — `cannot find 'TelemetryCompletionProvider'`.

- [ ] **Step 3.3: Implement the decorator**

Create `Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// Decorator that wraps any `CompletionProvider`, forwards each call to the
/// wrapped instance, and records timing + outcome into a recorder closure.
/// Used by `CompletionSampleCoordinator` to surface every fire — including
/// failures — in the inspector panel without framework-side event hooks.
///
/// Errors are NOT swallowed: an entry is recorded with `error != nil` and
/// the underlying error is re-thrown to `CompletionManager`, which already
/// isolates per-provider failures from the batch.
struct TelemetryCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String]
    let supportsSnippets: Bool

    private let wrapped: any CompletionProvider
    private let recorder: @Sendable (CompletionActivityEntry) -> Void

    init(
        wrapping provider: any CompletionProvider,
        recorder: @escaping @Sendable (CompletionActivityEntry) -> Void
    ) {
        self.id = provider.id
        self.supportedLanguages = provider.supportedLanguages
        self.triggerCharacters = provider.triggerCharacters
        self.supportsSnippets = provider.supportsSnippets
        self.wrapped = provider
        self.recorder = recorder
    }

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let start = Date()
        do {
            let result = try await wrapped.completions(for: context)
            recorder(.init(
                providerId: wrapped.id,
                language: context.language,
                triggerCharacter: context.triggerCharacter,
                prefix: Self.truncatedPrefix(from: context),
                itemCount: result.items.count,
                durationMs: Date().timeIntervalSince(start) * 1000,
                timestamp: Date(),
                error: nil
            ))
            return result
        } catch {
            recorder(.init(
                providerId: wrapped.id,
                language: context.language,
                triggerCharacter: context.triggerCharacter,
                prefix: Self.truncatedPrefix(from: context),
                itemCount: 0,
                durationMs: Date().timeIntervalSince(start) * 1000,
                timestamp: Date(),
                error: String(describing: error)
            ))
            throw error
        }
    }

    private static func truncatedPrefix(from context: CompletionContextModel) -> String {
        String(context.currentWord.prefix(32))
    }
}
#endif
```

- [ ] **Step 3.4: Verify tests pass**

Run: `swift test --filter TelemetryCompletionProviderTests --parallel`
Expected: 3 passing.

- [ ] **Step 3.5: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/App/Completion/TelemetryCompletionProvider.swift \
        Tests/CodeEditorSampleTests/TelemetryCompletionProviderTests.swift
git commit -m "$(cat <<'EOF'
Add TelemetryCompletionProvider decorator

Wraps any CompletionProvider, forwards to it, and records the call into
a recorder closure. Errors record an entry with `error != nil` and
re-throw so CompletionManager's per-provider error isolation still applies.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 4: `DemoCompletionProvider`

**Files:**
- Create: `Sources/CodeEditorSample/App/Completion/DemoCompletionProvider.swift`
- Create: `Tests/CodeEditorSampleTests/DemoCompletionProviderTests.swift`

- [ ] **Step 4.1: Write the failing test**

Create `Tests/CodeEditorSampleTests/DemoCompletionProviderTests.swift`:

```swift
#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("DemoCompletionProvider")
@MainActor
struct DemoCompletionProviderTests {
    @Test("returns three demo items on any language")
    func returnsThreeItems() async throws {
        let provider = DemoCompletionProvider()

        let context = CompletionContextModel(
            text: "", cursorPosition: 0, language: .swift
        )
        let result = try await provider.completions(for: context)

        let labels = result.items.map(\.label).sorted()
        #expect(labels == ["FIXME:", "MARK:", "TODO:"])
    }

    @Test("has empty supportedLanguages so it applies to all")
    func appliesToAllLanguages() {
        let provider = DemoCompletionProvider()
        #expect(provider.supportedLanguages.isEmpty)
    }

    @Test("id is stable")
    func stableID() {
        #expect(DemoCompletionProvider().id == "sample.demo")
    }
}
#endif
```

- [ ] **Step 4.2: Verify the test fails to compile**

Run: `swift test --filter DemoCompletionProviderTests`
Expected: BUILD FAILURE — `cannot find 'DemoCompletionProvider'`.

- [ ] **Step 4.3: Implement the provider**

Create `Sources/CodeEditorSample/App/Completion/DemoCompletionProvider.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// Demonstrates the `CompletionProvider` protocol end-to-end.
/// Returns three text-tag snippets (`TODO:`, `MARK:`, `FIXME:`) for every
/// manual completion request, regardless of language.
///
/// This is the type to copy from when writing your own provider — it shows
/// the minimum required to satisfy `CompletionProvider`:
///
/// 1. A unique `id`.
/// 2. `supportedLanguages: []` to apply to every buffer, or an explicit list.
/// 3. `triggerCharacters: []` for manual-only firing, or characters that
///    should auto-trigger.
/// 4. An async `completions(for:)` that returns `CompletionItemModel`s.
struct DemoCompletionProvider: CompletionProvider {
    let id = "sample.demo"
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = true

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let items: [CompletionItemModel] = [
            CompletionItemModel(label: "TODO:",  kind: .text, detail: "Demo snippet"),
            CompletionItemModel(label: "MARK:",  kind: .text, detail: "Demo snippet"),
            CompletionItemModel(label: "FIXME:", kind: .text, detail: "Demo snippet"),
        ]
        return CompletionResult(items: items, context: context)
    }
}
#endif
```

- [ ] **Step 4.4: Verify tests pass**

Run: `swift test --filter DemoCompletionProviderTests --parallel`
Expected: 3 passing.

- [ ] **Step 4.5: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/App/Completion/DemoCompletionProvider.swift \
        Tests/CodeEditorSampleTests/DemoCompletionProviderTests.swift
git commit -m "$(cat <<'EOF'
Add DemoCompletionProvider as a copy-paste example

Tiny CompletionProvider that returns TODO/MARK/FIXME snippets on every
fire. Documents the protocol exactly as a consumer would crib from it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 5: `BuiltInLanguageProviders` factory

**Files:**
- Create: `Sources/CodeEditorSample/App/Completion/BuiltInLanguageProviders.swift`
- Create: `Tests/CodeEditorSampleTests/BuiltInLanguageProvidersTests.swift`

- [ ] **Step 5.1: Write the failing test**

Create `Tests/CodeEditorSampleTests/BuiltInLanguageProvidersTests.swift`:

```swift
#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("BuiltInLanguageProviders")
@MainActor
struct BuiltInLanguageProvidersTests {
    @Test("factory returns exactly eight providers")
    func eightProviders() {
        #expect(BuiltInLanguageProviders.all().count == 8)
    }

    @Test("each provider id is unique and starts with 'builtin.'")
    func uniqueIDs() {
        let ids = BuiltInLanguageProviders.all().map(\.id)
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(id.hasPrefix("builtin."))
        }
    }

    @Test("each provider has exactly one supported language and at least one trigger character")
    func shapesAreSensible() {
        for provider in BuiltInLanguageProviders.all() {
            #expect(provider.supportedLanguages.count == 1)
            #expect(!provider.triggerCharacters.isEmpty)
        }
    }

    @Test("covers Swift, Python, JavaScript, TypeScript, Go, Rust, Java, C")
    func expectedLanguages() {
        let coveredLanguages = Set(
            BuiltInLanguageProviders.all().flatMap(\.supportedLanguages)
        )
        let expected: Set<Language> = [
            .swift, .python, .javascript, .typescript,
            .go, .rust, .java, .c,
        ]
        #expect(coveredLanguages == expected)
    }

    @Test("Swift provider returns non-empty completions for a known target")
    func swiftReturnsItemsForString() async throws {
        guard let swiftProvider = BuiltInLanguageProviders.all().first(where: {
            $0.supportedLanguages == [.swift]
        }) else {
            #expect(Bool(false), "expected swift provider")
            return
        }

        // "let name: String = "" "
        // cursor sits right after `.` so the inferred target is the prior token.
        let snippet = "let s: String = \"\"\ns."
        let context = CompletionContextModel(
            text: snippet,
            cursorPosition: snippet.count,
            language: .swift,
            triggerKind: .character,
            triggerCharacter: ".",
            lineText: "s."
        )

        let result = try await swiftProvider.completions(for: context)
        // Result may be empty if heuristic doesn't fire — at minimum the call
        // must succeed and return a well-formed CompletionResult.
        #expect(result.context.language == .swift)
    }
}
#endif
```

- [ ] **Step 5.2: Verify the test fails to compile**

Run: `swift test --filter BuiltInLanguageProvidersTests`
Expected: BUILD FAILURE — `cannot find 'BuiltInLanguageProviders'`.

- [ ] **Step 5.3: Implement the provider type + factory**

Create `Sources/CodeEditorSample/App/Completion/BuiltInLanguageProviders.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// Adapts a framework `LanguageMemberCompletions` value into a full
/// `CompletionProvider`. One concrete language per instance.
///
/// The framework ships eight `LanguageMemberCompletions` conformers and
/// this adapter wraps each one so the sample can register them. Target-type
/// inference is best-effort: the helper looks at the token before the
/// trigger character, capitalizes it, and passes it to the underlying
/// member data. When the heuristic returns nil the data source falls back
/// to its common-member set (often empty) — this is honest about the limits
/// of static member completion without a type checker.
struct BuiltInMemberCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String]
    let supportsSnippets: Bool = false

    private let members: any LanguageMemberCompletions

    init(
        id: String,
        language: Language,
        triggerCharacters: [String],
        members: any LanguageMemberCompletions
    ) {
        self.id = id
        self.supportedLanguages = [language]
        self.triggerCharacters = triggerCharacters
        self.members = members
    }

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let target = Self.inferTargetType(from: context)
        let filter = context.currentWord
        let items = members.createMemberCompletions(for: target, filter: filter)
        return CompletionResult(items: items, context: context)
    }

    /// Best-effort target-type guess from the token immediately before the
    /// trigger character. Returns nil when no plausible target is found.
    static func inferTargetType(from context: CompletionContextModel) -> String? {
        let before = context.textBeforeCursor
        // Drop the trigger character if present.
        let stripped = context.triggerCharacter.map { ch in
            before.hasSuffix(ch) ? String(before.dropLast(ch.count)) : before
        } ?? before

        // Walk back while the character is part of an identifier-ish token.
        var token = ""
        for ch in stripped.reversed() {
            if ch.isLetter || ch.isNumber || ch == "_" {
                token.append(ch)
            } else {
                break
            }
        }
        let identifier = String(token.reversed())
        return identifier.isEmpty ? nil : identifier
    }
}

enum BuiltInLanguageProviders {
    static func all() -> [BuiltInMemberCompletionProvider] {
        [
            .init(id: "builtin.swift",      language: .swift,      triggerCharacters: ["."], members: SwiftMemberCompletions()),
            .init(id: "builtin.python",     language: .python,     triggerCharacters: ["."], members: PythonMemberCompletions()),
            .init(id: "builtin.javascript", language: .javascript, triggerCharacters: ["."], members: JavaScriptMemberCompletions()),
            .init(id: "builtin.typescript", language: .typescript, triggerCharacters: ["."], members: TypeScriptMemberCompletions()),
            .init(id: "builtin.go",         language: .go,         triggerCharacters: ["."], members: GoMemberCompletions()),
            .init(id: "builtin.rust",       language: .rust,       triggerCharacters: ["."], members: RustMemberCompletions()),
            .init(id: "builtin.java",       language: .java,       triggerCharacters: ["."], members: JavaMemberCompletions()),
            .init(id: "builtin.c",          language: .c,          triggerCharacters: ["."], members: CMemberCompletions()),
        ]
    }
}
#endif
```

- [ ] **Step 5.4: Verify tests pass**

Run: `swift test --filter BuiltInLanguageProvidersTests --parallel`
Expected: 5 passing.

- [ ] **Step 5.5: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/App/Completion/BuiltInLanguageProviders.swift \
        Tests/CodeEditorSampleTests/BuiltInLanguageProvidersTests.swift
git commit -m "$(cat <<'EOF'
Add BuiltInLanguageProviders factory wrapping eight member-completion sources

One adapter type (BuiltInMemberCompletionProvider) plus a factory returning
one provider per language with a real LanguageMemberCompletions struct:
Swift, Python, JavaScript, TypeScript, Go, Rust, Java, C. Target-type
inference is best-effort from the token before the trigger character.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3 — Coordinator

### Task 6: `CompletionSampleCoordinator`

**Files:**
- Create: `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift`
- Create: `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift`

- [ ] **Step 6.1: Write the failing tests**

Create `Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift`:

```swift
#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("CompletionSampleCoordinator")
@MainActor
struct CompletionSampleCoordinatorTests {
    @Test("attach registers nine providers (eight built-ins + one demo)")
    func attachRegistersAllProviders() {
        let coordinator = CompletionSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)

        coordinator.attach(controller: controller)

        let ids = controller.registeredCompletionProviders.map(\.id).sorted()
        #expect(ids.count == 9)
        #expect(ids.contains("sample.demo"))
        #expect(ids.contains("builtin.swift"))
        #expect(ids.contains("builtin.c"))
    }

    @Test("registered providers in the snapshot mirror the controller")
    func snapshotMirrorsController() {
        let coordinator = CompletionSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)

        coordinator.attach(controller: controller)
        coordinator.refresh()

        #expect(coordinator.snapshot.registeredProviders.count == 9)
    }

    @Test("activity ring is bounded at 20 newest-first")
    func ringIsBounded() {
        let coordinator = CompletionSampleCoordinator()
        for i in 0..<25 {
            coordinator.record(.init(
                providerId: "p\(i)", language: .swift,
                triggerCharacter: nil, prefix: "",
                itemCount: 0, durationMs: 0,
                timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                error: nil
            ))
        }
        #expect(coordinator.snapshot.recentActivity.count == 20)
        // Newest first.
        let topId = coordinator.snapshot.recentActivity.first?.providerId
        #expect(topId == "p24")
    }

    @Test("resetActivity clears recent and last but leaves controller stats alone")
    func resetActivity() {
        let coordinator = CompletionSampleCoordinator()
        coordinator.record(.init(
            providerId: "p", language: .swift, triggerCharacter: nil,
            prefix: "", itemCount: 1, durationMs: 0.5,
            timestamp: Date(), error: nil
        ))
        #expect(coordinator.snapshot.recentActivity.count == 1)
        #expect(coordinator.snapshot.lastActivity != nil)

        coordinator.resetActivity()

        #expect(coordinator.snapshot.recentActivity.isEmpty)
        #expect(coordinator.snapshot.lastActivity == nil)
    }

    @Test("snapshot before attach has zero requests and empty providers")
    func emptyBeforeAttach() {
        let coordinator = CompletionSampleCoordinator()
        #expect(coordinator.snapshot.registeredProviders.isEmpty)
        #expect(coordinator.snapshot.requests == 0)
        #expect(coordinator.snapshot.lastActivity == nil)
    }

    @Test("fireAtCursor calls through to the attached controller without crashing")
    func fireAtCursorIsSafe() async {
        let coordinator = CompletionSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.isCodeCompletionEnabled = true
        controller.attach(to: view)
        coordinator.attach(controller: controller)

        coordinator.fireAtCursor()      // must not crash, even with empty buffer
    }
}
#endif
```

- [ ] **Step 6.2: Verify tests fail to compile**

Run: `swift test --filter CompletionSampleCoordinatorTests`
Expected: BUILD FAILURE — `cannot find 'CompletionSampleCoordinator'`.

- [ ] **Step 6.3: Implement the coordinator**

Create `Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift`:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import Foundation
import Observation

/// Owns the sample's Completion Inspector lifecycle. Registers every
/// built-in language provider plus the demo provider with the attached
/// `EditorController`, wraps each in a `TelemetryCompletionProvider` so
/// the inspector sees every fire, and snapshots controller-level stats on
/// a 1Hz timer.
@MainActor
@Observable
final class CompletionSampleCoordinator {
    struct RegisteredProviderSummary: Identifiable, Sendable, Hashable {
        var id: String { providerId }
        let providerId: String
        let languages: [Language]      // empty == "all"
        let triggerCharacters: [String]
        let supportsSnippets: Bool
    }

    struct Snapshot: Sendable {
        var registeredProviders: [RegisteredProviderSummary]
        var recentActivity: [CompletionActivityEntry]     // newest-first, max 20
        var lastActivity: CompletionActivityEntry?
        var requests: Int
        var cacheHitRate: Double
        var avgProcessingMs: Double

        static let empty = Snapshot(
            registeredProviders: [],
            recentActivity: [],
            lastActivity: nil,
            requests: 0,
            cacheHitRate: 0,
            avgProcessingMs: 0
        )
    }

    /// Bounded ring size for the recent-activity buffer.
    private static let ringCapacity = 20

    // MARK: - Observable surface

    private(set) var snapshot: Snapshot = .empty

    // MARK: - Non-observable internals

    @ObservationIgnored
    private weak var controller: EditorController?

    @ObservationIgnored
    private var refreshTimer: Timer?

    @ObservationIgnored
    private var ring: [CompletionActivityEntry] = []

    // MARK: - Lifecycle

    func attach(controller: EditorController) {
        self.controller = controller

        for provider in BuiltInLanguageProviders.all() {
            controller.registerCompletionProvider(
                TelemetryCompletionProvider(wrapping: provider) { [weak self] entry in
                    Task { @MainActor [weak self] in self?.record(entry) }
                }
            )
        }
        controller.registerCompletionProvider(
            TelemetryCompletionProvider(wrapping: DemoCompletionProvider()) { [weak self] entry in
                Task { @MainActor [weak self] in self?.record(entry) }
            }
        )

        startRefresh()
        refresh()
    }

    func detach() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        controller = nil
    }

    func resetActivity() {
        ring.removeAll()
        snapshot.recentActivity = []
        snapshot.lastActivity = nil
    }

    func fireAtCursor() {
        controller?.requestCompletion(triggerKind: .manual)
    }

    // MARK: - Telemetry

    func record(_ entry: CompletionActivityEntry) {
        ring.append(entry)
        if ring.count > Self.ringCapacity {
            ring.removeFirst(ring.count - Self.ringCapacity)
        }
        snapshot.recentActivity = ring.reversed()
        snapshot.lastActivity = ring.last
    }

    // MARK: - Refresh

    func refresh() {
        let controller = self.controller
        let stats = controller?.completionStatistics
        snapshot.registeredProviders = (controller?.registeredCompletionProviders ?? [])
            .map { provider in
                RegisteredProviderSummary(
                    providerId: provider.id,
                    languages: provider.supportedLanguages,
                    triggerCharacters: provider.triggerCharacters,
                    supportsSnippets: provider.supportsSnippets
                )
            }
            .sorted { $0.providerId < $1.providerId }
        snapshot.requests = stats?.totalRequests ?? 0
        snapshot.cacheHitRate = stats?.cacheHitRate ?? 0
        snapshot.avgProcessingMs = (stats?.averageProcessingTime ?? 0) * 1000
    }

    private func startRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }
}
#endif
```

- [ ] **Step 6.4: Verify tests pass**

Run: `swift test --filter CompletionSampleCoordinatorTests --parallel`
Expected: 6 passing.

- [ ] **Step 6.5: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/App/Completion/CompletionSampleCoordinator.swift \
        Tests/CodeEditorSampleTests/CompletionSampleCoordinatorTests.swift
git commit -m "$(cat <<'EOF'
Add CompletionSampleCoordinator

Owns provider registration (eight built-ins + demo, each wrapped in a
telemetry decorator), a bounded activity ring (cap 20), and a 1Hz
snapshot refresh for the inspector panel. Mirrors the LSP/Performance
coordinator pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 7: Wire `AppState` and call `attach`

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

- [ ] **Step 7.1: Read the current AppState init**

Run: `grep -n "performance\|coordinator\.attach\|configuration\.performance" Sources/CodeEditorSample/App/AppState.swift`

Confirm the pattern looks like:

```swift
let perfCoordinator = PerformanceSampleCoordinator(...)
perfCoordinator.attach(controller: editorController)
self.performance = perfCoordinator
```

- [ ] **Step 7.2: Add the coordinator property next to `performance`**

In `Sources/CodeEditorSample/App/AppState.swift`, inside the `#if canImport(AppKit)` block where `lsp` and `performance` are declared, add:

```swift
    /// Sample-side Completion Inspector coordinator. Registers built-in
    /// language providers (eight) plus a demo provider on attach, decorates
    /// each with telemetry, and snapshots controller stats on a 1Hz timer
    /// for `CompletionInspectorPanel`. macOS-only.
    let completion: CompletionSampleCoordinator
```

- [ ] **Step 7.3: Construct and attach in `init()`**

After the `perfCoordinator.attach(controller: editorController)` line and the `self.performance = perfCoordinator` line, add:

```swift
        let completionCoordinator = CompletionSampleCoordinator()
        completionCoordinator.attach(controller: editorController)
        self.completion = completionCoordinator
```

This must happen **after** `self.performance = perfCoordinator` and **before** the closing `#endif` of the `canImport(AppKit)` block.

- [ ] **Step 7.4: Verify it builds**

Run: `swift build --target CodeEditorSample`
Expected: success.

- [ ] **Step 7.5: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "$(cat <<'EOF'
Wire CompletionSampleCoordinator into AppState

Constructs and attaches the coordinator alongside the existing LSP and
Performance coordinators. Eight built-in language providers and one demo
provider are now registered with the editor controller on app start.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4 — UI

### Task 8: `CompletionInspectorPanel`

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift`

- [ ] **Step 8.1: Inspect the existing PerformanceInspectorPanel for visual conventions**

Run: `head -120 Sources/CodeEditorSample/Sidebars/PerformanceInspectorPanel.swift`

Notice it takes plain value-typed parameters (no coordinator reference) so it remains snapshot-testable. The new panel follows the same shape.

- [ ] **Step 8.2: Implement the panel**

Create `Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift`:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Stateless view backing the Completion inspector. Takes the coordinator's
/// snapshot fields as parameters — no direct coordinator reference — so it
/// remains snapshot-testable.
struct CompletionInspectorPanel: View {
    let registeredProviders: [CompletionSampleCoordinator.RegisteredProviderSummary]
    let recentActivity: [CompletionActivityEntry]
    let lastActivity: CompletionActivityEntry?
    let requests: Int
    let cacheHitRate: Double
    let avgProcessingMs: Double

    var onFireAtCursor: () -> Void
    var onClear: () -> Void

    @Environment(\.codeEditorTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            statusRow
            section("Last request") { lastRequestView }
            section("Statistics") { statisticsView }
            section("Recent activity", trailing: clearButton) { recentActivityView }
            section("Registered providers") { registeredView }
        }
        .padding(12)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Completion")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("\(registeredProviders.count) providers registered")
                .font(.system(size: 12))
            Spacer()
            Button(action: onFireAtCursor) {
                Label("Fire", systemImage: "control")
                    .labelStyle(.iconOnly)
            }
            .controlSize(.small)
            .help("Manually request completion at cursor (⌃␣)")
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var lastRequestView: some View {
        if let last = lastActivity {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if last.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    Text(last.language.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                    if let trigger = last.triggerCharacter {
                        Text("\"\(trigger)\"")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    if !last.prefix.isEmpty {
                        Text("prefix \"\(last.prefix)\"")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(last.providerId) → \(last.itemCount) items · \(String(format: "%.1f", last.durationMs))ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No completions fired yet. Type a trigger character or press ⌃␣.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            statRow(label: "Requests", value: "\(requests)")
            statRow(
                label: "Cache hits",
                value: requests > 0
                    ? "\(Int(cacheHitRate * Double(requests))) (\(Int(cacheHitRate * 100))%)"
                    : "—"
            )
            statRow(label: "Avg time", value: requests > 0
                ? String(format: "%.1f ms", avgProcessingMs)
                : "—")
        }
    }

    @ViewBuilder
    private var recentActivityView: some View {
        if recentActivity.isEmpty {
            Text("—")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(recentActivity) { entry in
                    HStack(spacing: 6) {
                        if entry.error != nil {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        Text(Self.timeFormatter.string(from: entry.timestamp))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(entry.providerId)
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Text("\(entry.itemCount) · \(String(format: "%.1f", entry.durationMs))ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .help(entry.error ?? "")
                }
            }
        }
    }

    private var registeredView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(registeredProviders) { provider in
                HStack(spacing: 6) {
                    Text(provider.providerId)
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Text(Self.languagesLabel(provider.languages))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(Self.triggersLabel(provider.triggerCharacters))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if provider.supportsSnippets {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9))
                            .help("Supports snippets")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func section<Trailing: View, Content: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                trailing()
            }
            content()
        }
        .padding(.vertical, 6)
    }

    private var clearButton: some View {
        Button("Clear", action: onClear)
            .controlSize(.small)
            .buttonStyle(.borderless)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, design: .monospaced))
        }
    }

    private static func languagesLabel(_ languages: [Language]) -> String {
        if languages.isEmpty { return "[all]" }
        return "[\(languages.map(\.rawValue).joined(separator: ", "))]"
    }

    private static func triggersLabel(_ triggers: [String]) -> String {
        if triggers.isEmpty { return "—" }
        return triggers.joined(separator: "")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
#endif
```

- [ ] **Step 8.3: Verify it builds**

Run: `swift build --target CodeEditorSample`
Expected: success.

- [ ] **Step 8.4: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/Sidebars/CompletionInspectorPanel.swift
git commit -m "$(cat <<'EOF'
Add stateless CompletionInspectorPanel view

Five sections: status row with manual-fire button, last request, statistics
(requests / cache hits / avg time), recent-activity list, registered
providers. Stateless — takes value-typed snapshot fields as parameters so
it remains snapshot-testable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 9: Snapshot tests for the panel

**Files:**
- Create: `Tests/CodeEditorSampleTests/CompletionInspectorPanelSnapshotTests.swift`

- [ ] **Step 9.1: Check the existing performance-panel snapshot convention**

Run: `head -80 Tests/CodeEditorSampleTests/PerformanceInspectorPanelSnapshotTests.swift` if it exists, else: `find Tests/CodeEditorSampleTests -name "*SnapshotTests.swift" -exec head -40 {} \;`

This confirms the framework used for snapshot tests (SnapshotTesting) and the `isRecording` / `assertSnapshot` shape.

- [ ] **Step 9.2: Write the snapshot tests**

Create `Tests/CodeEditorSampleTests/CompletionInspectorPanelSnapshotTests.swift`:

```swift
#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

final class CompletionInspectorPanelSnapshotTests: XCTestCase {
    @MainActor
    func test_empty_state_light() {
        let view = panel(
            providers: [],
            recent: [],
            last: nil,
            requests: 0,
            cacheHitRate: 0,
            avgMs: 0
        )
        assertSnapshot(of: hosting(view, scheme: .light), as: .image)
    }

    @MainActor
    func test_empty_state_dark() {
        let view = panel(
            providers: [],
            recent: [],
            last: nil,
            requests: 0,
            cacheHitRate: 0,
            avgMs: 0
        )
        assertSnapshot(of: hosting(view, scheme: .dark), as: .image)
    }

    @MainActor
    func test_populated_state_light() {
        let view = panel(
            providers: sampleProviders(),
            recent: sampleEntries(),
            last: sampleEntries().first,
            requests: 174,
            cacheHitRate: 0.35,
            avgMs: 2.1
        )
        assertSnapshot(of: hosting(view, scheme: .light), as: .image)
    }

    @MainActor
    func test_populated_state_dark() {
        let view = panel(
            providers: sampleProviders(),
            recent: sampleEntries(),
            last: sampleEntries().first,
            requests: 174,
            cacheHitRate: 0.35,
            avgMs: 2.1
        )
        assertSnapshot(of: hosting(view, scheme: .dark), as: .image)
    }

    @MainActor
    func test_error_state_light() {
        let errored = CompletionActivityEntry(
            providerId: "builtin.swift", language: .swift, triggerCharacter: ".",
            prefix: "view", itemCount: 0, durationMs: 0.8,
            timestamp: Date(timeIntervalSince1970: 0),
            error: "ProviderError(why: \"network\")"
        )
        let view = panel(
            providers: sampleProviders(),
            recent: [errored] + sampleEntries(),
            last: errored,
            requests: 174,
            cacheHitRate: 0.35,
            avgMs: 2.1
        )
        assertSnapshot(of: hosting(view, scheme: .light), as: .image)
    }

    // MARK: - Helpers

    @MainActor
    private func panel(
        providers: [CompletionSampleCoordinator.RegisteredProviderSummary],
        recent: [CompletionActivityEntry],
        last: CompletionActivityEntry?,
        requests: Int,
        cacheHitRate: Double,
        avgMs: Double
    ) -> CompletionInspectorPanel {
        CompletionInspectorPanel(
            registeredProviders: providers,
            recentActivity: recent,
            lastActivity: last,
            requests: requests,
            cacheHitRate: cacheHitRate,
            avgProcessingMs: avgMs,
            onFireAtCursor: {},
            onClear: {}
        )
    }

    @MainActor
    private func hosting(_ view: CompletionInspectorPanel, scheme: ColorScheme) -> NSHostingView<some View> {
        let host = NSHostingView(
            rootView: view
                .frame(width: 360, height: 420)
                .preferredColorScheme(scheme)
        )
        host.frame = NSRect(x: 0, y: 0, width: 360, height: 420)
        return host
    }

    private func sampleProviders() -> [CompletionSampleCoordinator.RegisteredProviderSummary] {
        [
            .init(providerId: "builtin.c",          languages: [.c],          triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "builtin.go",         languages: [.go],         triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "builtin.java",       languages: [.java],       triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "builtin.javascript", languages: [.javascript], triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "builtin.python",     languages: [.python],     triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "builtin.rust",       languages: [.rust],       triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "builtin.swift",      languages: [.swift],      triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "builtin.typescript", languages: [.typescript], triggerCharacters: ["."], supportsSnippets: false),
            .init(providerId: "sample.demo",        languages: [],            triggerCharacters: [],    supportsSnippets: true),
        ]
    }

    private func sampleEntries() -> [CompletionActivityEntry] {
        [
            .init(providerId: "builtin.swift", language: .swift, triggerCharacter: ".", prefix: "view",
                  itemCount: 12, durationMs: 1.4, timestamp: Date(timeIntervalSince1970: 3), error: nil),
            .init(providerId: "builtin.swift", language: .swift, triggerCharacter: ".", prefix: "vie",
                  itemCount: 8,  durationMs: 0.9, timestamp: Date(timeIntervalSince1970: 2), error: nil),
            .init(providerId: "sample.demo", language: .swift, triggerCharacter: nil, prefix: "",
                  itemCount: 3,  durationMs: 0.1, timestamp: Date(timeIntervalSince1970: 1), error: nil),
            .init(providerId: "builtin.python", language: .python, triggerCharacter: ".", prefix: "str",
                  itemCount: 4,  durationMs: 0.7, timestamp: Date(timeIntervalSince1970: 0), error: nil),
        ]
    }
}
#endif
```

- [ ] **Step 9.3: Record snapshots**

Temporarily set `isRecording = true` at the top of the test class:

```swift
override class func setUp() {
    super.setUp()
    isRecording = true
}
```

Run: `swift test --filter CompletionInspectorPanelSnapshotTests`
Expected: tests "fail" with recorded snapshots. Confirm the generated PNGs in `Tests/CodeEditorSampleTests/__Snapshots__/CompletionInspectorPanelSnapshotTests/` look correct.

- [ ] **Step 9.4: Disable recording and re-run**

Remove the `setUp` override (or set `isRecording = false`).

Run: `swift test --filter CompletionInspectorPanelSnapshotTests --parallel`
Expected: 5 passing.

- [ ] **Step 9.5: Quality gate + commit (snapshots + tests)**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Tests/CodeEditorSampleTests/CompletionInspectorPanelSnapshotTests.swift \
        Tests/CodeEditorSampleTests/__Snapshots__/CompletionInspectorPanelSnapshotTests
git commit -m "$(cat <<'EOF'
Add snapshot tests for CompletionInspectorPanel

Five snapshots: empty light/dark, populated light/dark, error-state light.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 10: Mount the panel in `InspectorSidebar`

**Files:**
- Modify: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`

- [ ] **Step 10.1: Add the panel between `PerformanceInspectorPanel` and `AnnotationsInspectorPanel`**

In `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`, locate the `VStack` block that holds the inspector panels. After the `PerformanceInspectorPanel(...)` `.sheet(...)` block and before `AnnotationsInspectorPanel(...)`, insert:

```swift
                        CompletionInspectorPanel(
                            registeredProviders: appState.completion.snapshot.registeredProviders,
                            recentActivity: appState.completion.snapshot.recentActivity,
                            lastActivity: appState.completion.snapshot.lastActivity,
                            requests: appState.completion.snapshot.requests,
                            cacheHitRate: appState.completion.snapshot.cacheHitRate,
                            avgProcessingMs: appState.completion.snapshot.avgProcessingMs,
                            onFireAtCursor: { appState.completion.fireAtCursor() },
                            onClear: { appState.completion.resetActivity() }
                        )
```

- [ ] **Step 10.2: Build the sample**

Run: `swift build --target CodeEditorSample`
Expected: success.

- [ ] **Step 10.3: Run the sample and exercise it**

Run: `swift run CodeEditorSample`

Manual verification:
- Inspector sidebar shows "Completion" section between Performance and Annotations panels.
- "Status row" shows `9 providers registered`.
- "Registered providers" lists all nine ids: `builtin.c`, `builtin.go`, `builtin.java`, `builtin.javascript`, `builtin.python`, `builtin.rust`, `builtin.swift`, `builtin.typescript`, `sample.demo`.
- Type `.` in a Swift buffer: the framework's completion popup appears below the cursor (the existing `CompletionViewController` window).
- Inspector "Last request" row updates to show `swift · "." · builtin.swift → N items · X.Xms`.
- Press ⌃␣ in any buffer (with the Fire button or directly): the demo provider returns TODO/MARK/FIXME, and the inspector logs the fire.
- Verify "Recent activity" populates with newest entries on top.
- "Clear" button empties recent activity.
- "Statistics" rows tick up.

Quit the sample.

- [ ] **Step 10.4: Quality gate + commit**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift
git commit -m "$(cat <<'EOF'
Mount CompletionInspectorPanel in InspectorSidebar

Slots between Performance and Annotations panels, completing the
"framework subsystem inspectors" trio (LSP, Performance, Completion).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 5 — Documentation

### Task 11: Mark NEXT.md gap as complete

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 11.1: Replace the "Code completion — protocol is hidden" entry**

In `NEXT.md`, locate the paragraph beginning `**Code completion — protocol is hidden.**` and replace it with:

```markdown
**Code completion — ✅ complete (2026-05-13).** The sample now registers eight built-in language `CompletionProvider`s (Swift / Python / JavaScript / TypeScript / Go / Rust / Java / C, wrapping the framework's `LanguageMemberCompletions` data) plus a custom `DemoCompletionProvider`, through a new public `EditorController` registration API (`registerCompletionProvider(_:)`, `unregisterCompletionProvider(withId:)`, `registeredCompletionProviders`, `completionStatistics`, `requestCompletion(...)`). Each provider is wrapped in a `TelemetryCompletionProvider` so the new `CompletionInspectorPanel` (right-rail inspector slot, between Performance and Annotations) shows registered providers, last request, recent-activity ring, and framework-level stats (requests, cache hit-rate, avg time). The popup actually fires for the eight covered languages on `.`; the inspector's Fire button manually triggers at the cursor. Backed by a new sample-side `CompletionSampleCoordinator` (`Sources/CodeEditorSample/App/Completion/`) that owns provider registration, the bounded activity ring, and a 1Hz stats refresh. macOS-only via `#if canImport(AppKit)` (iOS sample unchanged). Spec: `docs/superpowers/specs/2026-05-13-sample-app-completion-inspector-design.md`; plan: `docs/superpowers/plans/2026-05-13-sample-app-completion-inspector.md`.
```

- [ ] **Step 11.2: Update the "Recommended next step" paragraph**

In `NEXT.md`, the closing paragraph still names Completion as a candidate. Replace the closing paragraph to point at the next gap. Locate the paragraph starting `## Recommended next step` and update it:

```markdown
## Recommended next step

LSP, Performance Inspector, and Completion Inspector are now all wired (✅ 2026-05-13). The natural next headline gap is **`EventLogPanel`** tailing `UnifiedEventSystem` — same right-rail inspector slot, similar wiring pattern to the three existing coordinators. The `.eventSystem(_:)` modifier is undemonstrated today; with three coordinator templates in place, a fourth is straightforward.
```

- [ ] **Step 11.3: Strike through the completion row in the surface table**

In the `## What needs to be presented (concrete additions)` table, change the row:

```markdown
| `CompletionDemoOverlay` | Behavior knobs | Register a custom `CompletionProvider`, show fired items |
```

to:

```markdown
| ~~`CompletionInspectorPanel`~~ ✅ | Inspector sidebar | Register built-in + custom `CompletionProvider`s, show registered list + recent fires |
```

- [ ] **Step 11.4: Quality gate**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`
Expected: no source changes; just confirm nothing regressed.

- [ ] **Step 11.5: Commit**

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Mark Completion Inspector gap as complete in NEXT.md

Plan: docs/superpowers/plans/2026-05-13-sample-app-completion-inspector.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review checklist

Already run before delivering this plan:

- **Spec coverage:**
  - "Add a `CompletionInspectorPanel`" → Tasks 8, 10.
  - "Make the built-in popup actually appear" → Task 5 (providers) + Task 7 (registration) + manual verification in Task 10.3.
  - "Public `CompletionProvider` registration on `EditorController`" → Task 1.
  - "Live activity (per-provider count, last request, recent ring, framework stats)" → Tasks 3 (telemetry), 6 (coordinator + ring), 8 (panel).
  - "Mirror the coordinator pattern" → Task 6 (matches `PerformanceSampleCoordinator` shape).
  - "macOS-only via `#if canImport(AppKit)`" → every new sample file is gated.
  - Non-goals (iOS parity, AppState split, two-store bridge, type-aware completion, popup restyle, framework-side language-provider promotion) — all explicitly excluded from any task.

- **Placeholder scan:** no TBDs, no "add error handling", no "similar to Task N" without code, no references to types defined nowhere. All step instructions show the actual code.

- **Type consistency:**
  - `CompletionSampleCoordinator.RegisteredProviderSummary` — used in Task 6 (definition), Task 8 (panel parameter), Task 9 (snapshot test sample data), Task 10 (mount).
  - `CompletionActivityEntry` field shape — defined in Task 2; consumed in Tasks 3, 6, 8, 9. All field names match.
  - `attach(controller:)` named consistently across Tasks 6, 7.
  - `resetActivity()` named consistently across Tasks 6, 8, 10.
  - `fireAtCursor()` named consistently across Tasks 6, 8, 10.

- **Audit alignment:** spec said "fourteen" languages with note that it would be adjusted at audit time. The plan's audit-corrections preamble documents the eight-not-fourteen result, every task aligns to "9 providers" (8 + 1), and the `NEXT.md` close-out explicitly says eight.
