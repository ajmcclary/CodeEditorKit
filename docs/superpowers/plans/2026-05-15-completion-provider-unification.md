# Completion Provider Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the framework's completion-provider system around `CompletionManager` as the single canonical registry, wire the dead `.codeCompletion(provider:)` SwiftUI modifier through a closure-adapter, restore built-in keyword completions via a per-language built-in provider auto-registered on language change, and delete the orphaned `CompletionProviderRegistry` / `CompletionGenerationService` / `CompletionViewModel` / `EditorContainerViewModel` chain.

**Architecture:** Two new internal `CompletionProvider` conformers (`LanguageKeywordCompletionProvider`, `SwiftUIClosureCompletionProvider`) plus a `CompletionManager.ensureBuiltInProvider(for:)` idempotent helper, both feeding into the existing `CompletionManager` registration path. The representable's coordinator owns the closure-adapter and idempotently re-registers on update. The four dead types and their accessors on `EditorRuntime` / `EditorFeatureRuntimeDependencies` are deleted outright; the single internal test that touches them is updated.

**Tech Stack:** Swift 6.3 with `StrictConcurrency`, XCTest + Swift Testing in `Tests/CodeEditorPluginTests/`, SwiftPM. macOS 13.0 / iOS 16.0 minimums. `@MainActor`-isolated completion providers. Project lint commands: `swift build && swiftlint --fix && swiftlint`.

**Spec:** `docs/superpowers/specs/2026-05-15-completion-provider-unification-design.md`.

---

## File Structure

### New files

- `Sources/CodeEditorPlugin/Completion/LanguageKeywordCompletionProvider.swift` — internal `CompletionProvider` conformer; reads `LanguageDescriptor.descriptor(for:)?.keywords` with two-tier fallback; emits items via `SharedCompletionBuilder.createKeywordCompletions`.
- `Sources/CodeEditorPlugin/Completion/SwiftUIClosureCompletionProvider.swift` — internal `CompletionProvider` conformer; mutable closure slot; translates `CompletionContextModel` ↔ `SwiftUICompletionContext` and `SwiftUICompletionItem` → `CompletionItemModel`.
- `Tests/CodeEditorPluginTests/Completion/LanguageKeywordCompletionProviderTests.swift`
- `Tests/CodeEditorPluginTests/Completion/SwiftUIClosureCompletionProviderTests.swift`
- `Tests/CodeEditorPluginTests/Completion/CompletionManagerBuiltInProviderTests.swift`
- `Tests/CodeEditorPluginTests/Completion/SwiftUIClosureLifecycleTests.swift`
- `Tests/CodeEditorPluginTests/Completion/CodeEditorModifierCompletionIntegrationTests.swift`

### Modified files

- `Sources/CodeEditorPlugin/Completion/CompletionManager.swift` — add `ensureBuiltInProvider(for:)`.
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` — `language { didSet }` calls `ensureBuiltInProvider`, plus first-time fire site in init.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` — `body` forwards `codeEditorIntent.completionProvider` into the representable.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift` — `CodeEditorRepresentable` (AppKit) gains `swiftUICompletionProvider` property; threads it through `make`/`update`.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift` — same for UIKit.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` — `ContainerParameters` + `UpdateParameters` gain the closure; threaded into setup/update.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` — `CodeEditorBaseCoordinator` gains `modifierProviderAdapter`, `syncModifierProvider(on:closure:)`; `setupContainer` and `updateContainer` accept the closure and invoke sync.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift` — drop "not yet consumed" disclaimer on `.codeCompletion(provider:)` docstring.
- `Sources/CodeEditorPlugin/Core/EditorRuntime.swift` — remove `completionProviderRegistry` property and accessor.
- `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift` — update line 121 path to use `manager.ensureBuiltInProvider(for:)` + `registeredProviders` assertion.
- `NEXT.md` — mark B.2 done, reference this spec/plan.

### Deleted files

- `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift`
- `Sources/CodeEditorPlugin/Completion/CompletionGenerationService.swift`
- `Sources/CodeEditorPlugin/Completion/CompletionViewModel.swift`
- `Sources/CodeEditorPlugin/Layout/EditorContainerViewModel.swift`

---

## Task 1: LanguageKeywordCompletionProvider — initial implementation + tests

**Files:**
- Create: `Sources/CodeEditorPlugin/Completion/LanguageKeywordCompletionProvider.swift`
- Test: `Tests/CodeEditorPluginTests/Completion/LanguageKeywordCompletionProviderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Completion/LanguageKeywordCompletionProviderTests.swift
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class LanguageKeywordCompletionProviderTests: XCTestCase {

    func testIdEncodesLanguage() {
        let provider = LanguageKeywordCompletionProvider(language: .swift)
        XCTAssertEqual(provider.id, "builtin.keywords.swift")
    }

    func testSupportedLanguagesIsExactlyOneLanguage() {
        let provider = LanguageKeywordCompletionProvider(language: .python)
        XCTAssertEqual(provider.supportedLanguages, [.python])
    }

    func testTriggerCharactersIsEmpty() {
        let provider = LanguageKeywordCompletionProvider(language: .javascript)
        XCTAssertTrue(provider.triggerCharacters.isEmpty)
    }

    func testCompletionsForDescriptorBackedLanguageReturnsKeywords() async throws {
        let provider = LanguageKeywordCompletionProvider(language: .swift)
        let context = CompletionContextModel(
            text: "func ",
            cursorPosition: 5,
            language: .swift,
            lineText: ""
        )

        let result = try await provider.completions(for: context)

        XCTAssertFalse(result.items.isEmpty, "Swift keyword completions should not be empty")
        XCTAssertTrue(result.items.allSatisfy { $0.kind == .keyword },
                      "Every item should be of kind .keyword")
        XCTAssertTrue(result.items.allSatisfy { $0.priority == 80 },
                      "Every item should land at the SharedCompletionBuilder priority of 80 — pins the contract against drift")
    }

    func testCompletionsForUnknownLanguageFallsBackToGenericKeywords() async throws {
        let provider = LanguageKeywordCompletionProvider(language: .plainText)
        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .plainText,
            lineText: ""
        )

        let result = try await provider.completions(for: context)
        let labels = Set(result.items.map(\.label))

        XCTAssertTrue(labels.contains("if"), "Generic fallback should include 'if'")
        XCTAssertTrue(labels.contains("return"), "Generic fallback should include 'return'")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LanguageKeywordCompletionProviderTests`
Expected: FAIL — `LanguageKeywordCompletionProvider` doesn't exist yet.

- [ ] **Step 3: Implement `LanguageKeywordCompletionProvider`**

```swift
// Sources/CodeEditorPlugin/Completion/LanguageKeywordCompletionProvider.swift
import Foundation

/// Built-in completion provider that emits language keywords pulled from
/// `LanguageDescriptor.keywords`, falling back to an embedded keyword
/// table for languages without a descriptor entry and finally to a
/// generic seven-keyword list for unknown languages.
///
/// Auto-registered per-editor by `CompletionManager.ensureBuiltInProvider(for:)`
/// whenever `CodeEditorView.language` changes. Replaces the equivalent
/// "basic completions" logic previously buried inside the now-deleted
/// `CompletionGenerationService`.
///
/// - id: `"builtin.keywords.<language.identifier>"` — the language is
///   embedded in the id so a language switch produces a clean
///   unregister/register on the manager.
/// - supportedLanguages: `[language]` — scoped to a single language; the
///   manager's filter routes correctly when other editors are using
///   different languages.
/// - triggerCharacters: `[]` — manual trigger only. Built-in keyword
///   completions piggy-back on whatever else triggers the popup.
/// - priority: items inherit `SharedCompletionBuilder.createKeywordCompletions`'s
///   `priority: 80`. The accompanying tests pin this value.
@MainActor
internal final class LanguageKeywordCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false

    private let language: Language
    private let keywords: [String]

    init(language: Language) {
        self.language = language
        self.id = "builtin.keywords.\(language.identifier)"
        self.supportedLanguages = [language]
        self.keywords = Self.resolveKeywords(for: language)
    }

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let items = SharedCompletionBuilder.createKeywordCompletions(
            from: keywords,
            filter: context.lineText,
            languageName: language.name
        )
        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: 0
        )
    }

    // MARK: - Keyword resolution

    private static func resolveKeywords(for language: Language) -> [String] {
        if let descriptor = LanguageDescriptor.descriptor(for: language),
           !descriptor.keywords.isEmpty {
            return descriptor.keywords
        }
        return fallbackKeywords(for: language)
    }

    /// Copied verbatim from the now-deleted `CompletionGenerationService.fallbackKeywords(for:)`
    /// so we don't lose behavior when that file goes. Languages with a
    /// `LanguageDescriptor` entry never reach here.
    private static func fallbackKeywords(for language: Language) -> [String] {
        switch language {
        case .swift:
            return [
                "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
                "import", "if", "else", "for", "while", "switch", "case", "default",
                "return", "break", "continue", "guard", "defer", "do", "try", "catch",
                "throws", "async", "await", "actor", "typealias", "associatedtype"
            ]

        case .python:
            return [
                "def", "class", "import", "from", "if", "elif", "else", "for", "while",
                "break", "continue", "return", "yield", "lambda", "with", "as", "try",
                "except", "finally", "raise", "assert", "pass", "del", "global", "nonlocal"
            ]

        case .javascript, .typescript:
            return [
                "function", "const", "let", "var", "class", "extends", "import", "export",
                "if", "else", "for", "while", "do", "switch", "case", "default", "break",
                "continue", "return", "throw", "try", "catch", "finally", "async", "await"
            ]

        default:
            return ["if", "else", "for", "while", "return", "break", "continue"]
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LanguageKeywordCompletionProviderTests`
Expected: PASS, four tests green.

- [ ] **Step 5: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/Completion/LanguageKeywordCompletionProvider.swift \
        Tests/CodeEditorPluginTests/Completion/LanguageKeywordCompletionProviderTests.swift
git commit -m "$(cat <<'EOF'
Completion: LanguageKeywordCompletionProvider built-in

Replaces the dead-path keyword fabrication that lived in the
now-orphaned CompletionGenerationService. id encodes language
("builtin.keywords.<lang>") so the manager can swap on language
change. Items emit at SharedCompletionBuilder's priority of 80;
the test suite pins this value.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: CompletionManager.ensureBuiltInProvider(for:) + tests

**Files:**
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`
- Test: `Tests/CodeEditorPluginTests/Completion/CompletionManagerBuiltInProviderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Completion/CompletionManagerBuiltInProviderTests.swift
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class CompletionManagerBuiltInProviderTests: XCTestCase {

    private func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor())
    }

    func testEnsureBuiltInProviderRegistersOneProvider() {
        let manager = makeManager()
        manager.ensureBuiltInProvider(for: .swift)

        let ids = manager.registeredProviders.map(\.id)
        XCTAssertEqual(ids, ["builtin.keywords.swift"])
    }

    func testEnsureBuiltInProviderIsIdempotent() {
        let manager = makeManager()
        manager.ensureBuiltInProvider(for: .swift)
        manager.ensureBuiltInProvider(for: .swift)
        manager.ensureBuiltInProvider(for: .swift)

        XCTAssertEqual(manager.registeredProviders.count, 1)
        XCTAssertEqual(manager.registeredProviders.first?.id, "builtin.keywords.swift")
    }

    func testLanguageSwitchSweepsPriorBuiltIn() {
        let manager = makeManager()
        manager.ensureBuiltInProvider(for: .swift)
        manager.ensureBuiltInProvider(for: .python)

        let ids = manager.registeredProviders.map(\.id)
        XCTAssertEqual(ids, ["builtin.keywords.python"])
    }

    func testHostCollisionOnBuiltInIdWins() {
        let manager = makeManager()

        // Host registers a stub at the canonical built-in id first.
        let stub = StubCompletionProvider(id: "builtin.keywords.swift",
                                          supportedLanguages: [.swift])
        manager.registerProvider(stub)
        manager.ensureBuiltInProvider(for: .swift)

        // Host stub still wins.
        XCTAssertEqual(manager.registeredProviders.count, 1)
        XCTAssertTrue(manager.registeredProviders.first as AnyObject === stub,
                      "Host-supplied provider should not be replaced by built-in")
    }
}

/// Minimal CompletionProvider for tests that need a placeholder with a
/// specific id.
@MainActor
private final class StubCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false

    init(id: String, supportedLanguages: [Language]) {
        self.id = id
        self.supportedLanguages = supportedLanguages
    }

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        CompletionResult(items: [], context: context, isIncomplete: false, processingTime: 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CompletionManagerBuiltInProviderTests`
Expected: FAIL — `ensureBuiltInProvider(for:)` doesn't exist.

- [ ] **Step 3: Add `ensureBuiltInProvider(for:)` to `CompletionManager`**

Insert into `Sources/CodeEditorPlugin/Completion/CompletionManager.swift` right after the existing `unregisterProvider(withId:)` method:

```swift
    /// Ensures a `LanguageKeywordCompletionProvider` is registered for
    /// the given language. Idempotent. Sweeps any prior built-in for a
    /// different language, then registers the new one. Host-supplied
    /// providers at the canonical id win (collision check). Called by
    /// `CodeEditorView` on language change; safe to call from hosts
    /// using `CompletionManager` standalone.
    public func ensureBuiltInProvider(for language: Language) {
        let newId = "builtin.keywords.\(language.identifier)"

        // Already installed (built-in or host-supplied at this id).
        if providers[newId] != nil { return }

        // Sweep any prior built-in providers for other languages.
        let staleIds = providers.keys.filter {
            $0.hasPrefix("builtin.keywords.") && $0 != newId
        }
        for staleId in staleIds {
            providers.removeValue(forKey: staleId)
        }

        registerProvider(LanguageKeywordCompletionProvider(language: language))
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CompletionManagerBuiltInProviderTests`
Expected: PASS, four tests green.

- [ ] **Step 5: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/Completion/CompletionManager.swift \
        Tests/CodeEditorPluginTests/Completion/CompletionManagerBuiltInProviderTests.swift
git commit -m "$(cat <<'EOF'
CompletionManager: ensureBuiltInProvider(for:)

Idempotent. Sweeps any prior built-in for a different language,
then registers the new one. Host-supplied providers at the
canonical id win.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire ensureBuiltInProvider into CodeEditorView's language lifecycle

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:393-403` and the init/`commonInit` chain.
- (No new test file — covered by integration test in Task 8 and by manual verification below.)

- [ ] **Step 1: Inspect the existing language `didSet` and init chain**

Run: `grep -n "language\|commonInit\|init" Sources/CodeEditorPlugin/Core/CodeEditorView.swift | head -40`

Expected: confirm `public var language: Language = .plainText { didSet { … } }` near line 393 and locate the editor's primary init (look for `init(frame:textContainer:)` or similar — search for `super.init` if needed).

- [ ] **Step 2: Add `ensureBuiltInProvider` call inside `language { didSet }`**

In `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` around line 393, modify the `didSet` body:

```swift
    public var language: Language = .plainText {
        didSet {
            let languageService = featureDependencies.languageDetectionService
            let validation = languageService.validateLanguageChange(from: oldValue, to: language)

            if validation != .noChange {
                applySyntaxHighlighting()
                updateCompletionTriggerCharacters()
            }

            // Built-in keyword provider tracks the current language. The
            // call is idempotent — safe even if the language change was a
            // no-op or the manager hasn't been forced yet (the lazy var is
            // forced by `.completionManager` access here).
            completionManager.ensureBuiltInProvider(for: language)
        }
    }
```

- [ ] **Step 3: Add `ensureBuiltInProvider` to the first-time configure path**

The `didSet` body does not fire for the initial value (`.plainText`). Locate the primary `CodeEditorView` init/`commonInit` (search `func commonInit` or the body after `super.init`) and append:

```swift
        // First-time wakeup: language hasn't gone through didSet for its
        // initial value. Register the built-in provider explicitly so a
        // fresh editor gets keyword completions for free.
        completionManager.ensureBuiltInProvider(for: language)
```

If the init chain is structured as `init(frame:) → super.init(...) → setup()`, place the call at the end of `setup()` — after `completionManager` is touched anywhere (forcing the lazy) and before the editor is handed back to the caller.

If you cannot locate a single canonical `commonInit`, place the call at the end of every public init that ends with `self` fully constructed. Grep for `public init` in the file; today there are typically two (`init(frame:)` and `init(coder:)`-style for AppKit, and similar for UIKit). Both must call `ensureBuiltInProvider(for: language)` after `super.init` completes.

- [ ] **Step 4: Manually verify the wakeup path with a one-shot Swift Testing case**

Add to `Tests/CodeEditorPluginTests/Completion/CompletionManagerBuiltInProviderTests.swift` (the file from Task 2):

```swift
    func testCodeEditorViewRegistersBuiltInForInitialLanguage() {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        editor.language = .swift  // also triggers didSet, idempotent

        let ids = editor.completionManager.registeredProviders.map(\.id)
        XCTAssertTrue(ids.contains("builtin.keywords.swift"),
                      "First-time language set should register the built-in keyword provider")
    }

    func testCodeEditorViewSwapsBuiltInOnLanguageChange() {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        editor.language = .swift
        editor.language = .python

        let ids = Set(editor.completionManager.registeredProviders.map(\.id))
        XCTAssertTrue(ids.contains("builtin.keywords.python"))
        XCTAssertFalse(ids.contains("builtin.keywords.swift"))
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter CompletionManagerBuiltInProviderTests`
Expected: PASS, all six tests green (four from Task 2 + two added above).

- [ ] **Step 6: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/Core/CodeEditorView.swift \
        Tests/CodeEditorPluginTests/Completion/CompletionManagerBuiltInProviderTests.swift
git commit -m "$(cat <<'EOF'
CodeEditorView: register built-in keyword provider on language change

didSet calls ensureBuiltInProvider(for:); initial language is
covered by an explicit call in the init/setup chain so .plainText
gets keyword completions without a manual language assignment.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: SwiftUIClosureCompletionProvider + tests

**Files:**
- Create: `Sources/CodeEditorPlugin/Completion/SwiftUIClosureCompletionProvider.swift`
- Test: `Tests/CodeEditorPluginTests/Completion/SwiftUIClosureCompletionProviderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Completion/SwiftUIClosureCompletionProviderTests.swift
#if canImport(SwiftUI)
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class SwiftUIClosureCompletionProviderTests: XCTestCase {

    func testInitialIdentityAndShape() {
        let provider = SwiftUIClosureCompletionProvider()
        XCTAssertEqual(provider.id, "swiftui-modifier")
        XCTAssertEqual(provider.supportedLanguages, [],
                       "Empty array means 'applies to every language' in CompletionManager")
        XCTAssertEqual(provider.triggerCharacters, [],
                       "Manual trigger only — hosts wanting trigger chars register their own provider")
        XCTAssertTrue(provider.supportsSnippets,
                      "SwiftUICompletionItem.insertText may contain ${…} snippet syntax")
    }

    func testNilClosureReturnsEmptyResult() async throws {
        let provider = SwiftUIClosureCompletionProvider()
        provider.closure = nil

        let context = CompletionContextModel(
            text: "let x = ",
            cursorPosition: 8,
            language: .swift,
            lineText: "let x = "
        )

        let result = try await provider.completions(for: context)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testClosureReceivesBridgedContext() async throws {
        let provider = SwiftUIClosureCompletionProvider()

        var capturedText: String?
        var capturedPosition: Int?
        var capturedLanguage: Language?

        provider.closure = { ctx in
            capturedText = ctx.text
            capturedPosition = ctx.cursorPosition
            capturedLanguage = ctx.language
            return []
        }

        let context = CompletionContextModel(
            text: "func greet() {}",
            cursorPosition: 12,
            language: .swift,
            lineText: "func greet() {}"
        )

        _ = try await provider.completions(for: context)

        XCTAssertEqual(capturedText, "func greet() {}")
        XCTAssertEqual(capturedPosition, 12)
        XCTAssertEqual(capturedLanguage, .swift)
    }

    func testItemsTranslateFromSwiftUIToModel() async throws {
        let provider = SwiftUIClosureCompletionProvider()
        provider.closure = { _ in
            [
                SwiftUICompletionItem(
                    label: "forEach",
                    kind: .method,
                    detail: "Iterate over elements",
                    insertText: "forEach { <#element#> in\n    <#code#>\n}",
                    documentation: "Calls a closure on every element"
                )
            ]
        }

        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .swift,
            lineText: ""
        )

        let result = try await provider.completions(for: context)
        XCTAssertEqual(result.items.count, 1)
        let item = try XCTUnwrap(result.items.first)
        XCTAssertEqual(item.label, "forEach")
        XCTAssertEqual(item.kind, .method)
        XCTAssertEqual(item.detail, "Iterate over elements")
        XCTAssertTrue(item.insertText.contains("forEach"))
        XCTAssertEqual(item.documentation, "Calls a closure on every element")
    }

    func testAllFifteenCompletionKindsRoundTrip() async throws {
        let provider = SwiftUIClosureCompletionProvider()

        let pairs: [(CompletionKind, CompletionItemKind)] = [
            (.keyword, .keyword),
            (.function, .function),
            (.method, .method),
            (.variable, .variable),
            (.constant, .constant),
            (.class, .class),
            (.struct, .struct),
            (.enum, .enum),
            (.interface, .interface),
            (.module, .module),
            (.property, .property),
            (.value, .value),
            (.reference, .reference),
            (.snippet, .snippet),
            (.text, .text)
        ]

        for (swiftUIKind, modelKind) in pairs {
            provider.closure = { _ in
                [SwiftUICompletionItem(label: "x", kind: swiftUIKind)]
            }

            let context = CompletionContextModel(
                text: "", cursorPosition: 0, language: .swift, lineText: ""
            )
            let result = try await provider.completions(for: context)
            XCTAssertEqual(result.items.first?.kind, modelKind,
                           "SwiftUI \(swiftUIKind) should map to model \(modelKind)")
        }
    }

    func testInsertTextDefaultsToLabelWhenNil() async throws {
        let provider = SwiftUIClosureCompletionProvider()
        provider.closure = { _ in
            [SwiftUICompletionItem(label: "ifLet", kind: .snippet, insertText: nil)]
        }

        let context = CompletionContextModel(
            text: "", cursorPosition: 0, language: .swift, lineText: ""
        )
        let result = try await provider.completions(for: context)
        XCTAssertEqual(result.items.first?.insertText, "ifLet")
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SwiftUIClosureCompletionProviderTests`
Expected: FAIL — `SwiftUIClosureCompletionProvider` doesn't exist.

- [ ] **Step 3: Implement `SwiftUIClosureCompletionProvider`**

```swift
// Sources/CodeEditorPlugin/Completion/SwiftUIClosureCompletionProvider.swift
#if canImport(SwiftUI)
import Foundation

/// Adapter that wraps the closure attached via the `.codeCompletion(provider:)`
/// SwiftUI modifier as a `CompletionProvider`, so the closure can join
/// the rest of the per-editor provider registry without the modifier
/// API needing to know about `CompletionProvider`'s richer surface.
///
/// Owned by `CodeEditorCoordinator`. The coordinator swaps the
/// `closure` slot on every representable update (idempotent — no
/// register/unregister churn) and unregisters the adapter only when
/// the host removes the modifier.
///
/// - id: constant `"swiftui-modifier"` — at most one adapter per editor;
///   re-renders are dictionary-key replacements that leave the manager
///   undisturbed.
/// - supportedLanguages: `[]` — applies to every language; the host
///   inspects `ctx.language` inside the closure and early-returns for
///   unsupported langs. (`CompletionManager` interprets an empty array
///   as "matches any language" via the existing filter.)
/// - triggerCharacters: `[]` — manual trigger only. Hosts wanting
///   trigger-driven firing register a full `CompletionProvider` via
///   `EditorController.registerCompletionProvider(_:)`.
@MainActor
internal final class SwiftUIClosureCompletionProvider: CompletionProvider {
    let id: String = "swiftui-modifier"
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = true

    /// Mutable slot the coordinator swaps on every representable update.
    /// `nil` indicates "no modifier attached this update" — `completions`
    /// returns an empty result rather than throwing or crashing.
    var closure: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        guard let closure else {
            return CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            )
        }

        let bridged = SwiftUICompletionContext(
            text: context.text,
            cursorPosition: context.cursorPosition,
            language: context.language
        )

        let start = Date()
        let swiftUIItems = await closure(bridged)
        let elapsed = Date().timeIntervalSince(start)

        let modelItems = swiftUIItems.map { CompletionItemModel(swiftUI: $0) }

        return CompletionResult(
            items: modelItems,
            context: context,
            isIncomplete: false,
            processingTime: elapsed
        )
    }
}

// MARK: - SwiftUICompletionItem → CompletionItemModel

private extension CompletionItemModel {
    /// Translates a `SwiftUICompletionItem` (the modifier API's surface
    /// type) into the framework's richer `CompletionItemModel`. Lives
    /// here so the conversion table sits next to the adapter that uses
    /// it.
    init(swiftUI item: SwiftUICompletionItem) {
        self.init(
            label: item.label,
            insertText: item.insertText,
            kind: CompletionItemKind(swiftUI: item.kind),
            detail: item.detail,
            documentation: item.documentation
        )
    }
}

private extension CompletionItemKind {
    init(swiftUI kind: CompletionKind) {
        switch kind {
        case .keyword:   self = .keyword
        case .function:  self = .function
        case .method:    self = .method
        case .variable:  self = .variable
        case .constant:  self = .constant
        case .class:     self = .class
        case .struct:    self = .struct
        case .enum:      self = .enum
        case .interface: self = .interface
        case .module:    self = .module
        case .property:  self = .property
        case .value:     self = .value
        case .reference: self = .reference
        case .snippet:   self = .snippet
        case .text:      self = .text
        }
    }
}
#endif
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SwiftUIClosureCompletionProviderTests`
Expected: PASS, six tests green.

- [ ] **Step 5: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/Completion/SwiftUIClosureCompletionProvider.swift \
        Tests/CodeEditorPluginTests/Completion/SwiftUIClosureCompletionProviderTests.swift
git commit -m "$(cat <<'EOF'
Completion: SwiftUIClosureCompletionProvider adapter

Wraps the .codeCompletion(provider:) modifier closure as a
CompletionProvider so it can join the editor's manager registry
alongside built-ins and host-registered providers. Stable id
("swiftui-modifier"), supportedLanguages: [] (matches any),
triggerCharacters: [] (manual). 15-case translation table from
SwiftUI CompletionKind to model CompletionItemKind.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Thread the closure through the representable layer

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` (body, around line 396)
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`

- [ ] **Step 1: Add `swiftUICompletionProvider` field to `CodeEditorRepresentable` on macOS**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift`, after the existing `let onSelectionChange: ((NSRange) -> Void)?` line:

```swift
    let swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
```

Then thread it into both `ContainerParameters` and `UpdateParameters` construction (Step 3).

- [ ] **Step 2: Add the same field to the UIKit branch**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift`, mirror the same property addition. The two struct definitions must match in field order so the call site can construct either uniformly.

- [ ] **Step 3: Update `CodeEditorRepresentableHelper.ContainerParameters` and `UpdateParameters`**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`:

For each `Parameters` struct (search `ContainerParameters` and `UpdateParameters`), add the closure property:

```swift
        let swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
```

For each call site that builds these structs (the AppKit and UIKit `makeNSView`/`makeUIView`/`updateNSView`/`updateUIView` methods), pass `swiftUICompletionProvider: swiftUICompletionProvider`.

- [ ] **Step 4: Update `CodeEditor.body` to read and forward the closure**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` around line 396 where the representable is constructed, add:

```swift
        return CodeEditorRepresentable(
            text: effectiveTextBinding,
            language: effectiveLanguage,
            theme: effectiveTheme,
            // ... existing fields ...
            onSelectionChange: selectionCallback,
            swiftUICompletionProvider: codeEditorIntent.completionProvider
        )
```

(Exact placement depends on the existing constructor argument list. Add it as the final argument.)

- [ ] **Step 5: Build (no new tests this step — wiring only)**

Run: `swift build`
Expected: SUCCESS. Build catches any missing call site for the new parameter.

- [ ] **Step 6: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift
git commit -m "$(cat <<'EOF'
CodeEditorRepresentable: forward .codeCompletion closure

Thread the SwiftUI modifier's completion closure from CodeEditor.body
through the representable and into the coordinator's setup/update
hooks. No behavior change yet — Task 6 reads the closure in the
coordinator and registers an adapter.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Coordinator syncModifierProvider + lifecycle tests

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`
- Test: `Tests/CodeEditorPluginTests/Completion/SwiftUIClosureLifecycleTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Completion/SwiftUIClosureLifecycleTests.swift
#if canImport(SwiftUI)
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class SwiftUIClosureLifecycleTests: XCTestCase {

    private func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor())
    }

    func testFirstNonNilClosureRegistersAdapter() {
        let manager = makeManager()
        let coordinator = TestCoordinator()
        coordinator.syncModifierProvider(on: manager, closure: { _ in [] })

        let ids = manager.registeredProviders.map(\.id)
        XCTAssertEqual(ids, ["swiftui-modifier"])
    }

    func testReRenderWithSameClosureKeepsSingleRegistration() {
        let manager = makeManager()
        let coordinator = TestCoordinator()
        let closure: @Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem] = { _ in [] }

        coordinator.syncModifierProvider(on: manager, closure: closure)
        coordinator.syncModifierProvider(on: manager, closure: closure)
        coordinator.syncModifierProvider(on: manager, closure: closure)

        XCTAssertEqual(manager.registeredProviders.count, 1,
                       "Re-renders should not churn the registry")
    }

    func testReRenderWithDifferentClosureSwapsSlotNotProvider() async throws {
        let manager = makeManager()
        let coordinator = TestCoordinator()

        coordinator.syncModifierProvider(on: manager, closure: { _ in
            [SwiftUICompletionItem(label: "A", kind: .keyword)]
        })

        let firstAdapter = manager.registeredProviders.first as? SwiftUIClosureCompletionProvider
        XCTAssertNotNil(firstAdapter)

        coordinator.syncModifierProvider(on: manager, closure: { _ in
            [SwiftUICompletionItem(label: "B", kind: .keyword)]
        })

        let secondAdapter = manager.registeredProviders.first as? SwiftUIClosureCompletionProvider
        XCTAssertTrue(firstAdapter === secondAdapter,
                      "Adapter identity should be stable; only the closure slot swaps")

        // Verify the closure actually swapped.
        let context = CompletionContextModel(text: "", cursorPosition: 0, language: .swift, lineText: "")
        let result = try await secondAdapter?.completions(for: context)
        XCTAssertEqual(result?.items.first?.label, "B")
    }

    func testTransitionToNilUnregistersAdapter() {
        let manager = makeManager()
        let coordinator = TestCoordinator()
        coordinator.syncModifierProvider(on: manager, closure: { _ in [] })
        coordinator.syncModifierProvider(on: manager, closure: nil)

        XCTAssertTrue(manager.registeredProviders.isEmpty)
    }
}

/// Minimal `CodeEditorBaseCoordinator` subclass that doesn't require
/// SwiftUI bindings — pure unit testing of syncModifierProvider.
@MainActor
private final class TestCoordinator: CodeEditorBaseCoordinator {
    override init() {
        super.init()
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SwiftUIClosureLifecycleTests`
Expected: FAIL — `syncModifierProvider(on:closure:)` doesn't exist.

- [ ] **Step 3: Add `modifierProviderAdapter` + `syncModifierProvider` to `CodeEditorBaseCoordinator`**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`, inside `CodeEditorBaseCoordinator` (search for "MARK: - Shared Properties") add:

```swift
    /// Adapter that wraps the host's `.codeCompletion { … }` modifier
    /// closure as a `CompletionProvider`. Lazy: allocated on first
    /// non-nil closure, kept alive for the coordinator's lifetime.
    /// Holds a closure slot the coordinator swaps on every update —
    /// adapter identity stays stable, so the manager's provider
    /// dictionary is touched only on transitions (nil ↔ non-nil).
    #if canImport(SwiftUI)
    private var modifierProviderAdapter: SwiftUIClosureCompletionProvider?
    #endif
```

Then at file scope (or inside a `#if canImport(SwiftUI)` extension at the end of the file), add:

```swift
#if canImport(SwiftUI)
extension CodeEditorBaseCoordinator {
    /// Reconciles the host's `.codeCompletion { … }` closure with the
    /// manager's provider registry. Idempotent across renders:
    /// - `(closure, nil)`     → allocate adapter, set slot, register.
    /// - `(closure, adapter)` → swap slot (manager untouched).
    /// - `(nil, adapter)`     → unregister, drop adapter.
    /// - `(nil, nil)`         → no-op.
    func syncModifierProvider(
        on manager: CompletionManager,
        closure: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
    ) {
        switch (closure, modifierProviderAdapter) {
        case let (.some(new), .some(adapter)):
            adapter.closure = new
        case let (.some(new), .none):
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
}
#endif
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SwiftUIClosureLifecycleTests`
Expected: PASS, four tests green.

- [ ] **Step 5: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift \
        Tests/CodeEditorPluginTests/Completion/SwiftUIClosureLifecycleTests.swift
git commit -m "$(cat <<'EOF'
Coordinator: syncModifierProvider(on:closure:)

Idempotent four-state reconciler that owns the
SwiftUIClosureCompletionProvider adapter. Slot-swap on re-render
keeps the manager's dictionary undisturbed; transitions to/from
nil register/unregister exactly once.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Invoke syncModifierProvider from setup/update paths

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` (the `setupContainer` and `updateContainer` extension methods on `CodeEditorBaseCoordinator`)
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` (the `createAndSetupContainer` and `updateContainer` static helpers — pass the closure into the coordinator calls)

- [ ] **Step 1: Extend `setupContainer` to accept the closure**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`, modify the `setupContainer(_:text:language:theme:configuration:runtimeDependencies:onTextChange:onSelectionChange:)` method signature and body:

```swift
    func setupContainer(
        _ container: CodeEditorContainerView,
        text: String,
        language: Language,
        theme: Theme,
        configuration: EditorConfiguration,
        runtimeDependencies: EditorRuntimeDependencies,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil,
        swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])? = nil
    ) {
        // ... existing body unchanged ...

        // After existing setup, reconcile the modifier-supplied provider.
        #if canImport(SwiftUI)
        syncModifierProvider(
            on: container.textView.completionManager,
            closure: swiftUICompletionProvider
        )
        #endif
    }
```

(The exact accessor for `completionManager` from the container is `container.textView.completionManager` — `CodeEditorView` is `internal lazy var completionManager`. Verify by checking `container.textView` is a `CodeEditorView` in `CodeEditorContainerView`.)

- [ ] **Step 2: Extend `updateContainer` to accept the closure**

Same file, `updateContainer(_:text:language:theme:configuration:runtimeDependencies:)`:

```swift
    func updateContainer(
        _ container: CodeEditorContainerView,
        text: String,
        language: Language,
        theme: Theme,
        configuration: EditorConfiguration,
        runtimeDependencies: EditorRuntimeDependencies,
        swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])? = nil
    ) {
        // ... existing guard + body unchanged ...

        #if canImport(SwiftUI)
        syncModifierProvider(
            on: container.textView.completionManager,
            closure: swiftUICompletionProvider
        )
        #endif
    }
```

- [ ] **Step 3: Update the helper call sites**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`, locate the two static helpers (around line 53 `createAndSetupContainer` and line 87 `updateContainer`). Each one calls `coordinator.setupContainer(...)` or `coordinator.updateContainer(...)`. Add the closure pass-through:

```swift
        coordinator.setupContainer(
            // ... existing args ...
            onSelectionChange: parameters.onSelectionChange,
            swiftUICompletionProvider: parameters.swiftUICompletionProvider
        )
```

```swift
        coordinator.updateContainer(
            // ... existing args ...
            runtimeDependencies: parameters.runtimeDependencies,
            swiftUICompletionProvider: parameters.swiftUICompletionProvider
        )
```

- [ ] **Step 4: Build to confirm wiring is complete**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 5: Run focused completion-related tests**

Run: `swift test --filter SwiftUIClosureLifecycleTests && swift test --filter SwiftUIClosureCompletionProviderTests && swift test --filter LanguageKeywordCompletionProviderTests && swift test --filter CompletionManagerBuiltInProviderTests`
Expected: ALL PASS.

- [ ] **Step 6: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift
git commit -m "$(cat <<'EOF'
Coordinator: invoke syncModifierProvider on setup/update

The closure now flows: .codeCompletion modifier → env → body →
representable → helper → coordinator.setupContainer/updateContainer
→ syncModifierProvider → CompletionManager.registerProvider.
End-to-end wiring complete.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: End-to-end integration test (manager-level)

**Files:**
- Test: `Tests/CodeEditorPluginTests/Completion/CodeEditorModifierCompletionIntegrationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Completion/CodeEditorModifierCompletionIntegrationTests.swift
#if canImport(SwiftUI)
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class CodeEditorModifierCompletionIntegrationTests: XCTestCase {

    /// Simulates the body→representable→coordinator→manager wiring at
    /// the seam below SwiftUI's view tree. We construct a real
    /// CompletionManager, a coordinator subclass, and call the same
    /// sync hook the representable's update path calls.
    func testModifierClosureAndBuiltInProviderStack() async throws {
        let manager = CompletionManager(memoryMonitor: MemoryMonitor())

        // Built-in keyword provider is auto-registered by CodeEditorView,
        // but we exercise the registry surface directly here.
        manager.ensureBuiltInProvider(for: .swift)

        // Modifier-supplied closure plumbed via the coordinator.
        let coordinator = IntegrationCoordinator()
        coordinator.syncModifierProvider(on: manager) { _ in
            [SwiftUICompletionItem(label: "myCustomSnippet", kind: .snippet)]
        }

        // The manager should now have both providers.
        let ids = Set(manager.registeredProviders.map(\.id))
        XCTAssertEqual(ids, ["builtin.keywords.swift", "swiftui-modifier"])

        // Trigger a real request and inspect the merged result.
        let context = CompletionContextModel(
            text: "func ",
            cursorPosition: 5,
            language: .swift,
            lineText: ""
        )
        let result = try await manager.requestCompletions(for: context)

        let labels = Set(result.items.map(\.label))
        XCTAssertTrue(labels.contains("myCustomSnippet"),
                      "Modifier-supplied item should appear in merged results")
        XCTAssertTrue(labels.contains("func") || labels.contains("var"),
                      "Built-in Swift keyword(s) should appear alongside the host's item")
    }
}

@MainActor
private final class IntegrationCoordinator: CodeEditorBaseCoordinator {
    override init() {
        super.init()
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --filter CodeEditorModifierCompletionIntegrationTests`
Expected: PASS. (No new code needed — this exercises everything from Tasks 1-7.)

If FAIL, the failure points at one of the earlier tasks; debug accordingly before continuing.

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorPluginTests/Completion/CodeEditorModifierCompletionIntegrationTests.swift
git commit -m "$(cat <<'EOF'
Tests: end-to-end modifier + built-in completion stacking

Drives the manager through the same seam the representable uses
in production. Confirms both the .codeCompletion modifier closure
and the auto-registered keyword provider feed merged results.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update .codeCompletion modifier docstring

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift:226-228`

- [ ] **Step 1: Remove the "not yet consumed" disclaimer**

Open `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift`. Around line 226-228 there's a `///` `- Note:` block that says:

```swift
    /// - Note: As of 2026-05-14 the SwiftUI provider closure is stored
    ///   on `CodeEditorIntent` but not yet consumed by the editor. A
    ///   separate follow-up wires it through the completion pipeline.
```

Replace with:

```swift
    /// The provider is automatically registered as a `CompletionProvider`
    /// with id `"swiftui-modifier"` for the editor's lifetime. It stacks
    /// additively with built-in keyword completions and any provider
    /// the host has registered via `EditorController.registerCompletionProvider(_:)`.
    /// The closure runs on manual completion triggers; for trigger-character
    /// firing, register a `CompletionProvider` directly via `EditorController`
    /// instead.
```

- [ ] **Step 2: Build to confirm doc-only edit compiles**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 3: Lint + commit**

```bash
swiftlint --fix
swiftlint
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift
git commit -m "$(cat <<'EOF'
.codeCompletion: refresh docstring now that the closure is live

Drop the "not yet consumed" disclaimer. Document the additive
composition semantic and the manual-trigger-only contract.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Update MemoryMonitorDITests for the new path

**Files:**
- Modify: `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift:121`

- [ ] **Step 1: Read the existing assertion to understand intent**

Run: `sed -n '110,135p' Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift`
Expected: confirm the test's intent — verifying that DI flows through to provider creation. The line uses `editor.featureDependencies.completionProviderRegistry.ensureProvider(for: .python)`.

- [ ] **Step 2: Rewrite the assertion to drive through CompletionManager**

Replace the line that calls `editor.featureDependencies.completionProviderRegistry.ensureProvider(for: .python)` with:

```swift
        editor.completionManager.ensureBuiltInProvider(for: .python)
        let providerIds = editor.completionManager.registeredProviders.map(\.id)
        XCTAssertTrue(providerIds.contains("builtin.keywords.python"),
                      "DI path should result in a per-language built-in being registered")
```

Adjust the variable `provider` references in surrounding lines if any — read 5 lines above and below to make sure the test still does what it set out to do (memory-monitor DI verification). The original test's purpose was confirming the registry-build path uses the injected `MemoryMonitor`; the new equivalent is that `CompletionManager` (which the test already has via DI) registers a provider successfully — the memory-monitor injection is exercised by the manager's existing init wiring.

- [ ] **Step 3: Run the updated test**

Run: `swift test --filter MemoryMonitorDITests`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift
git commit -m "$(cat <<'EOF'
Tests: MemoryMonitorDITests via CompletionManager built-in path

Move the DI verification off the soon-to-be-deleted
CompletionProviderRegistry to CompletionManager.ensureBuiltInProvider,
which is the canonical surface going forward.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Delete CompletionViewModel.swift and EditorContainerViewModel.swift

**Files:**
- Delete: `Sources/CodeEditorPlugin/Completion/CompletionViewModel.swift`
- Delete: `Sources/CodeEditorPlugin/Layout/EditorContainerViewModel.swift`

- [ ] **Step 1: Confirm zero callers in `Sources/`**

Run: `grep -rn "CompletionViewModel\b\|EditorContainerViewModel\b" Sources/ Tests/ 2>/dev/null`
Expected: ONLY the two files themselves. If any other callers turn up, stop and investigate before deleting.

- [ ] **Step 2: Delete the files**

```bash
rm Sources/CodeEditorPlugin/Completion/CompletionViewModel.swift
rm Sources/CodeEditorPlugin/Layout/EditorContainerViewModel.swift
```

- [ ] **Step 3: Build to confirm nothing else referenced them**

Run: `swift build`
Expected: SUCCESS.

If FAIL with "cannot find type": there's a dangling reference somewhere. Grep for the missing symbol and delete or fix the reference.

- [ ] **Step 4: Commit**

```bash
git add -u Sources/CodeEditorPlugin/Completion/CompletionViewModel.swift \
            Sources/CodeEditorPlugin/Layout/EditorContainerViewModel.swift
git commit -m "$(cat <<'EOF'
Delete CompletionViewModel and EditorContainerViewModel

Both classes are dead code — never instantiated anywhere in
Sources/ or Tests/. EditorContainerViewModel was the only
constructor for CompletionViewModel; both die together.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Delete CompletionGenerationService.swift

**Files:**
- Delete: `Sources/CodeEditorPlugin/Completion/CompletionGenerationService.swift`

- [ ] **Step 1: Confirm zero callers**

Run: `grep -rn "CompletionGenerationService\b" Sources/ Tests/ 2>/dev/null`
Expected: only the file itself (the sole prior caller, `CompletionViewModel`, is already gone from Task 11).

- [ ] **Step 2: Delete the file**

```bash
rm Sources/CodeEditorPlugin/Completion/CompletionGenerationService.swift
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 4: Commit**

```bash
git add -u Sources/CodeEditorPlugin/Completion/CompletionGenerationService.swift
git commit -m "$(cat <<'EOF'
Delete CompletionGenerationService

Salvageable logic (LanguageDescriptor.keywords lookup + fallback
table) is now in LanguageKeywordCompletionProvider. No remaining
callers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Delete CompletionProviderRegistry.swift and EditorRuntime accessors

**Files:**
- Delete: `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift`
- Modify: `Sources/CodeEditorPlugin/Core/EditorRuntime.swift` (drop the property at line ~194, the init parameter, and the accessor at line ~294)
- Modify: `Sources/CodeEditorPlugin/Core/EditorRuntime.swift` — find `EditorFeatureRuntimeDependencies` (~line 249) and drop any `completionProviderRegistry` property or initializer parameter.

- [ ] **Step 1: Confirm no remaining callers**

Run: `grep -rn "CompletionProviderRegistry\b\|completionProviderRegistry\b" Sources/ Tests/ 2>/dev/null`
Expected: only `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift` itself, and `Sources/CodeEditorPlugin/Core/EditorRuntime.swift`'s property/accessor that this task is about to remove. Any other hits — stop and investigate.

- [ ] **Step 2: Remove the property and accessor from EditorRuntime**

In `Sources/CodeEditorPlugin/Core/EditorRuntime.swift`:

Locate (around line 194):

```swift
    public var completionProviderRegistry: CompletionProviderRegistry

    public init(...) {
        // ...
        self.completionProviderRegistry = CompletionProviderRegistry(languageMetadataRegistry: languageMetadataRegistry)
    }

    public init(completionProviderRegistry: CompletionProviderRegistry) {
        self.completionProviderRegistry = completionProviderRegistry
    }
```

Delete all four lines (the property declaration, both inits' lines that set it, and the convenience init that takes only the registry). Adjust the surrounding inits' bodies accordingly.

Locate (around line 294):

```swift
    public var completionProviderRegistry: CompletionProviderRegistry {
        completion.completionProviderRegistry
    }
```

Delete this accessor.

If `EditorFeatureRuntimeDependencies` (around line 249) has a `completionProviderRegistry` property or init parameter, remove those too.

- [ ] **Step 3: Delete the registry file**

```bash
rm Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: SUCCESS.

If FAIL: a caller was missed. Grep for the type name again with `-rn` and fix the dangling references.

- [ ] **Step 5: Run the full test suite (significant slice boundary)**

Run: `swift test --parallel`
Expected: all tests PASS. The previously-flaky tests listed in NEXT.md D may still be flaky — re-run any that fail in isolation to distinguish flakes from regressions.

- [ ] **Step 6: Commit**

```bash
git add -u Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift \
            Sources/CodeEditorPlugin/Core/EditorRuntime.swift
git commit -m "$(cat <<'EOF'
Delete CompletionProviderRegistry + EditorRuntime accessor

Final piece of the parallel completion-provider system retirement.
CompletionManager is now the only registration surface; built-in
language providers auto-register via ensureBuiltInProvider(for:).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Final verification, lint sweep, NEXT.md update

**Files:**
- Modify: `NEXT.md`

- [ ] **Step 1: Run the full quality pipeline one more time**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`
Expected: build SUCCESS, lint clean, all tests PASS (excepting pre-existing flakes documented in NEXT.md D).

- [ ] **Step 2: Update `NEXT.md` to mark B.2 done**

In `NEXT.md`, locate the **B.2** entry (around line 80-82):

```markdown
### B.2 `.codeCompletion(provider:)` modifier is unread
After the SwiftUI modifier return-types migration, `CodeEditorIntent.completionProvider` is set by the modifier but never read anywhere in `Sources/CodeEditorPlugin/`. The pre-existing bug was preserved — fixing it requires deciding how a host-supplied SwiftUI-shape provider should compose with `CompletionManager`'s provider registry.
```

Replace with:

```markdown
### ~~B.2 `.codeCompletion(provider:)` modifier is unread~~ — done
The modifier's closure is now wrapped as a `SwiftUIClosureCompletionProvider` and registered with the editor's `CompletionManager` from the representable coordinator on every update (idempotent — only registers on transitions). Built-in keyword completions were also restored via a new auto-registered `LanguageKeywordCompletionProvider` per language. The dead parallel `CompletionProviderRegistry` / `CompletionGenerationService` / `CompletionViewModel` / `EditorContainerViewModel` chain is gone. Spec: `docs/superpowers/specs/2026-05-15-completion-provider-unification-design.md`; plan: `docs/superpowers/plans/2026-05-15-completion-provider-unification.md`.
```

- [ ] **Step 3: Commit**

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
NEXT.md: mark B.2 (.codeCompletion modifier) done

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Final check**

Run: `git log --oneline -16`
Expected: 14 commits in order (Tasks 1-14), starting with the spec and ending with the NEXT.md update.

Run: `git status`
Expected: clean working tree.

---

## Self-Review

**Spec coverage:**
- "Architecture: 4-quadrant registry diagram" → Tasks 1, 2, 4, 6 (the 4 actors).
- "Public API changes: keep / new `ensureBuiltInProvider` / remove `completionProviderRegistry`" → Tasks 2, 13.
- "New internal types: LanguageKeywordCompletionProvider + SwiftUIClosureCompletionProvider" → Tasks 1, 4.
- "Data flow: modifier registration, built-in registration, request" → Tasks 3, 5-7.
- "Deletions: 4 files + 2 accessors" → Tasks 11, 12, 13.
- "Error handling: closure errors / cancellation / re-renders / mid-session removal / language switch / host collision / no-descriptor language / empty closure / coordinator-view lifetime" → covered by tests in Tasks 1, 2, 4, 6.
- "Testing: 5 new test files + 1 update + 0 deletions" → Tasks 1, 2, 4, 6, 8, 10.
- "Migration / breaking changes" → Tasks 10 (test update), 13 (accessor removal).
- "Risks: built-in priority drift / first-time fire site / latent paths" → Task 1 pins priority; Task 3 explicitly addresses first-time fire site with manual test cases; Tasks 11/12/13 each grep for callers before deleting.

**Placeholder scan:** No "TBD", "TODO", "implement later", or "fill in details" in any task. The first-time-fire-site step has explicit fallback language ("If you cannot locate a single canonical `commonInit`…") — that's an empirical-resolution instruction, not a placeholder.

**Type consistency:**
- `LanguageKeywordCompletionProvider(language:)` init signature consistent across Tasks 1, 2, 3.
- `SwiftUIClosureCompletionProvider` no-arg init, `.closure` mutable property — consistent across Tasks 4, 6, 8.
- `CompletionManager.ensureBuiltInProvider(for:)` signature consistent across Tasks 2, 3, 8, 10.
- Coordinator method `syncModifierProvider(on:closure:)` signature consistent across Tasks 6, 7, 8.
- Adapter id constant `"swiftui-modifier"` consistent across Tasks 4, 6, 8.
- Built-in id pattern `"builtin.keywords.\(language.identifier)"` consistent across Tasks 1, 2, 3, 8, 10.

No issues found.
