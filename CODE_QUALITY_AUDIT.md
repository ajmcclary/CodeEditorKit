# Code Quality Audit

Senior Software Architect structural design and maintainability review for `CodeEditorPlugin`.

Line numbers refer to the working tree at the time of this audit.

## Executive Summary

The codebase has a coherent high-level product boundary: a TextKit2 editor core, optional SwiftUI chrome, language services, LSP support, and platform abstraction layers. The strongest structural choices are the feature-based source tree, the descriptor-backed language metadata direction, and the consistent preference for `canImport(...)` platform gates.

Overall structural health is moderate. The system is functional, but maintainability is being diluted by partially completed migrations. Several newer abstractions exist beside older implementations instead of replacing them. This creates duplicate behavior, stale code paths, and uncertainty about which layer is authoritative.

Key metrics from the audit:

- `Sources/CodeEditorPlugin`: 453 Swift files, 100,821 lines.
- Large-file pressure: 48 files are >= 500 lines, 21 files are >= 600 lines.
- Largest hotspots: `LanguageDescriptor.swift` at 1,023 lines, `LineGeometryStore.swift` at 998 lines, and multiple language completion providers at 500 to 730 lines.
- Exact clone scan: 255 normalized duplicate 10-line block groups.
- Completion provider drift: 18 language-specific completion provider classes, 8,802 lines total, have no construction sites in `Sources` or `Tests` outside their own definitions. The live path is descriptor-backed `UniversalCompletionProvider`.

The main architectural risk is not a lack of abstractions. It is abstraction sprawl: service registries, dependency factories, utility hubs, feature coordinators, and legacy providers overlap. The highest return refactors are to finish the descriptor-backed language migration, collapse duplicated range and syntax-color utilities, split runtime dependencies out of `EditorConfiguration`, and remove dead parallel implementations.

## Abstraction Analysis

### A1. Completion Has Two Abstraction Layers, But Only One Is Active

**Evidence**

The active completion path is descriptor-backed:

- `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift:117` loads common languages by calling `ensureProvider(for:)`.
- `Sources/CodeEditorPlugin/Languages/CompletionProviderRegistry.swift:95` delegates provider creation to `languageMetadataRegistry.createProvider(for:)`.
- `Sources/CodeEditorPlugin/Languages/LanguageMetadataRegistry.swift:46` delegates to `LanguageProviderFactory.createProvider(for:)`.
- `Sources/CodeEditorPlugin/Languages/LanguageProviderFactory.swift:17` creates providers from `LanguageDescriptor`.
- `Sources/CodeEditorPlugin/Languages/LanguageProviderFactory.swift:72` defines the descriptor-backed `UniversalCompletionProvider`.

In parallel, these language-specific providers exist but have no construction sites:

| File | Declaration | Lines |
|---|---:|---:|
| `Sources/CodeEditorPlugin/Languages/SwiftCompletionProvider.swift` | line 7 | 245 |
| `Sources/CodeEditorPlugin/Languages/PythonCompletionProvider.swift` | line 7 | 246 |
| `Sources/CodeEditorPlugin/Languages/GoCompletionProvider.swift` | line 7 | 270 |
| `Sources/CodeEditorPlugin/Languages/JavaCompletionProvider.swift` | line 7 | 332 |
| `Sources/CodeEditorPlugin/Languages/JavaScriptCompletionProvider.swift` | line 7 | 397 |
| `Sources/CodeEditorPlugin/Languages/RustCompletionProvider.swift` | line 7 | 407 |
| `Sources/CodeEditorPlugin/Languages/SQLCompletionProvider.swift` | line 7 | 473 |
| `Sources/CodeEditorPlugin/Languages/HTMLCompletionProvider.swift` | line 7 | 510 |
| `Sources/CodeEditorPlugin/Languages/MarkdownCompletionProvider.swift` | line 7 | 513 |
| `Sources/CodeEditorPlugin/Languages/YAMLCompletionProvider.swift` | line 7 | 517 |
| `Sources/CodeEditorPlugin/Languages/CCompletionProvider.swift` | line 7 | 535 |
| `Sources/CodeEditorPlugin/Languages/JSONCompletionProvider.swift` | line 7 | 545 |
| `Sources/CodeEditorPlugin/Languages/TypeScriptCompletionProvider.swift` | line 7 | 561 |
| `Sources/CodeEditorPlugin/Languages/CSSCompletionProvider.swift` | line 7 | 614 |
| `Sources/CodeEditorPlugin/Languages/PHPCompletionProvider.swift` | line 7 | 623 |
| `Sources/CodeEditorPlugin/Languages/XMLCompletionProvider.swift` | line 7 | 634 |
| `Sources/CodeEditorPlugin/Languages/RubyCompletionProvider.swift` | line 7 | 648 |
| `Sources/CodeEditorPlugin/Languages/ShellCompletionProvider.swift` | line 7 | 732 |

**Impact**

The project pays for two completion architectures:

- New data goes into `LanguageDescriptor`, but older providers still contain keyword lists, snippets, member logic, and context parsing.
- Developers cannot tell whether to add a new language by editing a provider class, the descriptor, `LanguageMemberCompletions`, or all of them.
- Tests can accidentally validate inactive classes while production uses `UniversalCompletionProvider`.
- 8,802 lines of unused completion code increase search noise and review surface.

**Recommendation**

Finish the descriptor-backed migration. Move any valuable snippets, import suggestions, or member-completion details from inactive providers into descriptor data or explicit strategy hooks, then delete the provider classes.

Illustrative refactor:

```swift
struct CompletionProfile: Sendable {
    let metadata: LanguageMetadata
    let contextAnalyzer: any CompletionContextAnalyzing
    let extraItems: @Sendable (CompletionContextModel) async -> [CompletionItemModel]
}

extension LanguageDescriptor {
    var completionProfile: CompletionProfile {
        CompletionProfile(
            metadata: LanguageMetadata(
                keywords: keywords,
                types: types,
                functions: functions,
                literals: literals,
                triggerCharacters: triggerCharacters,
                memberCompletions: memberCompletions ?? DefaultMemberCompletions()
            ),
            contextAnalyzer: CompletionContextAnalyzer.for(language),
            extraItems: { _ in snippets.map(CompletionItemModel.snippet) }
        )
    }
}

enum CompletionProviderCatalog {
    @MainActor
    static func provider(for language: Language) -> CompletionProvider? {
        guard let descriptor = LanguageDescriptor.descriptor(for: language) else {
            return nil
        }
        return UniversalCompletionProvider(
            language: language,
            profile: descriptor.completionProfile
        )
    }
}
```

### A2. `LanguageDescriptor` Is the Right Abstraction, But It Is Becoming a God Catalog

**Evidence**

- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift:11` defines a descriptor that owns identity, highlighting, completion, snippets, member completions, module lists, tree-sitter names, shebangs, and aliases.
- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift:55` starts a 950+ line static dictionary containing every language.
- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift:1012` exposes lookup helpers after the massive static catalog.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift:32` builds a second language definition table.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift:200` begins another JavaScript keyword definition; `LanguageDescriptor.swift:104` already defines JavaScript metadata.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:193` starts legacy built-in providers despite `DescriptorLanguageProvider` at line 155.

**Impact**

`LanguageDescriptor` is positioned as the single source of truth, but that contract is not yet true. Language data is still repeated across descriptors, regex definitions, legacy providers, completion providers, and tree-sitter facades. Adding a language or correcting metadata requires multiple edits and creates a high likelihood of drift.

The descriptor file itself is also hard to review. A small data correction produces a large diff in a 1,023-line file, and code review cannot easily distinguish schema changes from data changes.

**Recommendation**

Keep `LanguageDescriptor` as the canonical schema, but split the data from the schema. Use one file per language or generated data files. Derive regex definitions and completion metadata from the descriptor where possible.

Illustrative split:

```swift
// Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift
internal struct LanguageDescriptor: Sendable {
    let language: Language
    let identity: LanguageIdentity
    let comments: CommentSyntax
    let highlighting: HighlightingDescriptor
    let completion: CompletionDescriptor
    let detection: LanguageDetectionDescriptor
}

// Sources/CodeEditorPlugin/Languages/Data/SwiftLanguageDescriptor.swift
extension LanguageDescriptor {
    static let swift = Self(
        language: .swift,
        identity: .init(displayName: "Swift", extensions: ["swift"], lspIdentifier: "swift"),
        comments: .init(line: "//", blockStart: "/*", blockEnd: "*/"),
        highlighting: .swiftSyntax(identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*"),
        completion: .init(
            keywords: SwiftLanguageData.keywords,
            snippets: SwiftSnippets.all,
            memberCompletions: SwiftMemberCompletions()
        ),
        detection: .init(treeSitterName: nil, shebangs: [], aliases: ["swift"])
    )
}
```

### A3. `CodeEditorView` Is a Stored-Property Hub for Too Many Subsystems

**Evidence**

- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:117` declares `CodeEditorView` as the editor view, TextKit delegate, public API, and completion delegate.
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:180` through line 242 stores syntax highlighting, async highlighting, rendering optimization, LSP, folding, search, services, adaptive performance, line geometry, edit events, and range-based highlighting.
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:287` adds language mutation with syntax and completion side effects.
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:341` through line 361 stores completion state and memory coordination.
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:488` through line 523 performs lifecycle cleanup across highlighting, memory, layout, completion, folding, LSP, gutter, and delegate state.

**Impact**

Methods have been moved into focused extension files, which helps navigation, but the core object still owns nearly every subsystem. That means:

- Feature changes often require touching shared editor state.
- Initialization and teardown order is fragile because multiple coordinators depend on each other through the view.
- The view becomes the integration test boundary for services that could be tested independently.
- New contributors must understand the entire editor surface before making local changes.

**Recommendation**

Introduce a runtime composition object that owns feature coordinators and exposes a narrow facade to `CodeEditorView`. The view should be a UI host and TextKit adapter. Subsystems should own their own lifecycles.

Illustrative refactor:

```swift
@MainActor
final class EditorRuntime {
    let syntax: SyntaxRuntime
    let completion: CompletionRuntime
    let folding: FoldingRuntime
    let lsp: LSPRuntime?
    let layout: EditorLayoutRuntime

    init(view: CodeEditorView, configuration: EditorConfiguration, dependencies: EditorRuntimeDependencies) {
        self.syntax = SyntaxRuntime(view: view, dependencies: dependencies.syntax)
        self.completion = CompletionRuntime(view: view, registry: dependencies.completionRegistry)
        self.folding = FoldingRuntime(view: view, engine: dependencies.codeFoldingEngine)
        self.lsp = LSPRuntime.makeIfAvailable(view: view, configuration: configuration)
        self.layout = EditorLayoutRuntime(view: view)
    }

    func apply(_ configuration: EditorConfiguration) {
        syntax.apply(configuration)
        completion.apply(configuration)
        folding.apply(configuration)
        layout.apply(configuration)
    }

    func detach() {
        lsp?.detach()
        syntax.detach()
        completion.detach()
        folding.detach()
        layout.detach()
    }
}
```

### A4. Service Location and Dependency Factories Overlap

**Evidence**

- `Sources/CodeEditorPlugin/Core/BusinessLogicServiceRegistry.swift:13` through line 20 stores optional cached services for line numbers, gutter sizing, folding, layout, highlighting, detection, editing, and completion.
- `Sources/CodeEditorPlugin/Core/BusinessLogicServiceRegistry.swift:65` through line 161 lazily creates services through computed properties.
- `Sources/CodeEditorPlugin/Core/BusinessLogicServiceRegistry.swift:271` through line 309 configures editor-specific state, warms caches, and updates folding.
- `Sources/CodeEditorPlugin/Core/CodeEditorDependencies.swift:6` through line 44 defines a separate global factory layer backed by `swift-dependencies`.
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:218` creates a `BusinessLogicServiceRegistry` directly.

**Impact**

The registry works as a service locator rather than a clearly scoped dependency bundle. Call sites ask for a broad registry and pull services as needed, so dependencies are not visible in initializers. Meanwhile, `CodeEditorDependencies` offers a second dependency mechanism. The result is double indirection: some services come from a registry, some from global dependency values, and some from `EditorConfiguration` injection slots.

**Recommendation**

Prefer small feature-specific dependency structs. Keep `swift-dependencies` as the construction mechanism, but pass explicit bundles into feature runtimes.

Illustrative refactor:

```swift
struct GutterDependencies {
    var lineNumbers: LineNumberCalculationService
    var sizing: GutterSizingService
    var folding: CodeFoldingCoordinatorService?
}

@MainActor
final class GutterRuntime {
    private let dependencies: GutterDependencies

    init(textView: CodeEditorView, dependencies: GutterDependencies) {
        self.dependencies = dependencies
    }
}
```

This keeps tests precise:

```swift
let runtime = GutterRuntime(
    textView: textView,
    dependencies: .init(
        lineNumbers: MockLineNumberService(),
        sizing: MockGutterSizingService(),
        folding: nil
    )
)
```

### A5. Range Utilities Are Duplicated Across Three Surfaces

**Evidence**

- `Sources/CodeEditorPlugin/Utilities/Range+Extensions.swift:8` defines `RangeUtilities`.
- `Sources/CodeEditorPlugin/Utilities/Range+Extensions.swift:55` through line 123 implements validation, clamping, merging, intersections, overlaps, containment, and subtraction.
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:5` declares `TextRangeUtilities` as a consolidated range-processing utility.
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:77` through line 127 implements validation and clamping again.
- `Sources/CodeEditorPlugin/Extensions/NSRange+Extensions.swift:34` through line 64 adds direct `NSRange` mutation and clamping helpers.
- `Sources/CodeEditorPlugin/Models/RangeMutation.swift:30` through line 74 contains another range transform implementation.

**Impact**

The project has no single range policy. Some APIs operate on `String.count`, others explicitly use UTF-16 lengths for TextKit correctness. This is especially risky in an editor that already has tests around emoji and UTF-16 offsets. A developer choosing the wrong helper can introduce subtle selection, highlighting, and annotation offset bugs.

**Recommendation**

Make `TextRangeUtilities` the canonical TextKit-facing utility and deprecate the broader `RangeUtilities` APIs. Keep direct `NSRange` extensions only for trivial convenience wrappers that call the canonical implementation.

Illustrative refactor:

```swift
public enum TextRangeUtilities {
    public static func contains(_ outer: NSRange, _ inner: NSRange) -> Bool {
        inner.location >= outer.location && NSMaxRange(inner) <= NSMaxRange(outer)
    }

    public static func clampedUTF16Range(_ range: NSRange, in text: String) -> NSRange {
        clampRange(range, toTextLength: text.utf16.count)
    }
}

@available(*, deprecated, message: "Use TextRangeUtilities for TextKit UTF-16 ranges.")
public enum RangeUtilities {
    public static func contains(_ outer: NSRange, _ inner: NSRange) -> Bool {
        TextRangeUtilities.contains(outer, inner)
    }
}
```

### A6. Public Text Processing Abstractions Are Under-Utilized

**Evidence**

- `Sources/CodeEditorPlugin/Text/TextProcessingPipeline.swift:5` through line 7 declares a public framework for chaining text processing operations.
- `Sources/CodeEditorPlugin/Text/TextProcessingPipeline.swift:84` through line 90 stores operations, validators, transformers, configuration, and caches.
- `Sources/CodeEditorPlugin/Text/TextProcessingUtilities.swift:5` through line 7 declares a utility hub that says it consolidates duplicate implementations.
- `Sources/CodeEditorPlugin/Text/AsyncTextProcessor.swift:45` defines an actor with priority queues, adaptive settings, memory monitoring, and caching.
- Production references are minimal: `TextProcessingPipeline` is only referenced by its own file, and `AsyncTextProcessor` is referenced by tests and extracted helper modules, not by editor runtime paths.

**Impact**

These abstractions look production-grade but do not appear to be part of the live editor pipeline. That increases API surface without reducing product complexity. Future work may integrate with the wrong abstraction, or keep adding parallel processors for highlighting, completion, symbols, and folding.

**Recommendation**

Decide whether these are product architecture or experimental scaffolding. If they are product architecture, route an actual feature through them and remove local duplicates. If not, make them internal test scaffolding or archive them outside the public source surface.

Illustrative decision point:

```swift
protocol TextProcessingEngine: Sendable {
    func process(_ request: TextProcessingRequest) async throws -> TextProcessingResult
}

struct SyntaxHighlightingProcessingEngine: TextProcessingEngine {
    func process(_ request: TextProcessingRequest) async throws -> TextProcessingResult {
        // The live syntax path goes here, or the abstraction should not be public.
    }
}
```

## Pattern Consistency Review

### P1. `EditorConfiguration` Mixes Value Configuration With Runtime Dependencies

**Evidence**

- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:86` declares `EditorConfiguration` as `Codable` and `Sendable`.
- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:108` through line 175 embeds runtime dependencies such as `UnifiedEventSystem`, `ActorCoordinator`, `PlatformCapabilities`, `UnifiedPerformanceSystem`, `LanguageMetadataRegistry`, and `PlatformServiceLayer`.
- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:217` through line 240 implements `with(...)` methods that rebuild `Self` using only layout, display, behavior, performance, and event system.
- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:366` through line 374 excludes runtime dependencies from equality.
- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:391` through line 404 decodes persisted configurations and explicitly sets runtime dependencies to nil.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CoreExtensions.swift:89` through line 156 uses `configuration.with(...)` in public convenience setters.

**Impact**

This creates a hidden footgun: a configuration can contain injected runtime dependencies, but any `with(display:)`, `with(behavior:)`, or similar update silently drops most of them. The public convenience setters in `CodeEditorView` use those methods, so a caller can lose injected platform services by toggling line numbers or code completion.

Equality and serialization exclusions are defensible for runtime-only dependencies, but those dependencies should not live inside the value configuration if common value updates discard them.

**Recommendation**

Split stable editor settings from runtime dependencies. Keep `EditorConfiguration` as a pure value type and pass runtime dependencies separately.

Illustrative refactor:

```swift
public struct EditorConfiguration: Codable, Equatable, Sendable {
    public var layout = Layout()
    public var display = Display()
    public var behavior = Behavior()
    public var performance = Performance()
}

@MainActor
public struct EditorRuntimeDependencies {
    public var eventSystem: UnifiedEventSystem?
    public var actorCoordinator: ActorCoordinator?
    public var platformCapabilities: PlatformCapabilities
    public var languageMetadataRegistry: LanguageMetadataRegistry
    public var platformServiceLayer: PlatformServiceLayer
}

@MainActor
public struct EditorSetup {
    public var configuration: EditorConfiguration
    public var dependencies: EditorRuntimeDependencies
}
```

If the runtime slots remain inside `EditorConfiguration`, every `with(...)` method must preserve them:

```swift
@MainActor
public func with(display: Display) -> Self {
    var copy = self
    copy.display = display
    return copy
}
```

### P2. TextKit2-Only Documentation Conflicts With Fallback-Oriented Code

**Evidence**

- `Sources/CodeEditorPlugin/Text/TextKitBridge.swift:11` through line 16 says the framework is TextKit2-only and no longer chooses between TextKit1 and TextKit2.
- `Sources/CodeEditorPlugin/Text/ModernTextKitHelper.swift:57` through line 63 logs "TextKit2 not active, using TextKit1 fallback" and returns `false`.
- `Sources/CodeEditorPlugin/Platform/PlatformCapabilities+TextKitExtensions.swift:80` through line 101 still models "whether TextKit2 is preferred over TextKit1".
- `Sources/CodeEditorPlugin/Platform/PlatformCapabilities+TextKitExtensions.swift:168` through line 170 defines `useTextKit2` as "whether to use TextKit2 instead of TextKit1".
- `Tests/CodeEditorPluginTests/AnnotationTests.swift:371` through line 374 still tests a TextKit1 fallback branch.
- `Tests/CodeEditorPluginTests/CodeEditorViewTests.swift:333` names a test `testAnnotationWithTextKit1`.

**Impact**

The source sends mixed signals about a major platform decision. Developers may add fallback branches to satisfy older helper semantics even though project guidance says TextKit1 and Catalyst are retired. Tests that allow TextKit1 behavior can also mask regressions in the intended TextKit2-only path.

**Recommendation**

Make TextKit2 the invariant in source and tests. Replace "prefer TextKit2" with "supports required TextKit2 surface" or remove it where platform minimums guarantee support.

Illustrative refactor:

```swift
extension PlatformCapabilities {
    public var supportsRequiredTextKit2Surface: Bool {
        #if canImport(AppKit) || canImport(UIKit)
        true
        #else
        false
        #endif
    }
}

@MainActor
enum ModernTextKitHelper {
    static func validateTextKit2(for textView: PlatformTextView) throws {
        guard textView.textLayoutManager != nil else {
            throw CodeEditorError.textKitUnavailable("TextKit2 layout manager is required")
        }
    }
}
```

### P3. Platform Abstraction Is Consistent in Principle, But Mixed in Granularity

**Evidence**

- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift:64` through line 76 branches focus behavior with `canImport(AppKit)`.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift:250` through line 294 branches notification setup.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift:329` through line 337 branches text assignment.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift:478` through line 602 contains platform-specific extensions and coordinator classes in the same file as shared coordination logic.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift:20` through line 80 and `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift:20` through line 80 are nearly identical representable wrappers, with protocol method names as the main difference.

**Impact**

The `canImport(...)` convention is followed, which is good. The maintainability issue is granularity. Shared coordinator behavior and platform behavior are interleaved, so platform-specific changes require reading a large mixed file. The repeated representable wrappers are understandable because SwiftUI uses different protocols, but the coordinator file should have clearer platform seams.

**Recommendation**

Extract platform adapter operations from the shared coordinator. Keep AppKit and UIKit representables separate, but push duplicated parameters and lifecycle logic into shared helper types.

Illustrative refactor:

```swift
@MainActor
protocol CodeEditorPlatformAdapter {
    func text(from view: CodeEditorView) -> String
    func setText(_ text: String, on view: CodeEditorView)
    func observeTextChanges(
        in view: CodeEditorView,
        onText: @escaping (String) -> Void,
        onSelection: @escaping (NSRange) -> Void
    ) -> [NSObjectProtocol]
    func requestFocus(container: CodeEditorContainerView)
}

@MainActor
final class CodeEditorBaseCoordinator: NSObject, ObservableObject {
    private let platform: any CodeEditorPlatformAdapter

    init(platform: any CodeEditorPlatformAdapter) {
        self.platform = platform
    }
}
```

### P4. Symbol Navigation Has a Parallel Optimized Implementation That Has Drifted

**Evidence**

- `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift:50` through line 92 registers default providers, including `TreeSitterSymbolProvider` for `.csharp`, `.kotlin`, `.dart`, `.dockerfile`, `.toml`, and `.lua`.
- `Sources/CodeEditorPlugin/Features/OptimizedSymbolNavigator.swift:121` through line 145 repeats most of the same registration list, but omits those newer languages.
- `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift:55` instantiates `SymbolNavigator`, not `OptimizedSymbolNavigator`.
- No production source references `OptimizedSymbolNavigator()`.

**Impact**

This is classic parallel implementation drift. The optimized navigator has cache and interval-tree logic, but it is not the live path and already lacks provider coverage present in the main navigator. Keeping both increases confusion and encourages bug fixes to land in one path only.

**Recommendation**

Merge the optimized internals into `SymbolNavigator` or delete the optimized class. Extract provider registration to a single catalog used by any navigator implementation.

Illustrative refactor:

```swift
enum SymbolProviderCatalog {
    @MainActor
    static func builtIns() -> [(Language, DocumentSymbolProvider)] {
        let cStyle = CStyleSymbolProvider()
        return [
            (.swift, SwiftSymbolProvider()),
            (.javascript, JavaScriptSymbolProvider()),
            (.typescript, JavaScriptSymbolProvider()),
            (.c, cStyle),
            (.cpp, cStyle),
            (.java, cStyle),
            (.go, cStyle),
            (.rust, cStyle),
            (.csharp, TreeSitterSymbolProvider(language: .csharp)),
            (.kotlin, TreeSitterSymbolProvider(language: .kotlin)),
            (.dart, TreeSitterSymbolProvider(language: .dart)),
            (.dockerfile, TreeSitterSymbolProvider(language: .dockerfile)),
            (.toml, TreeSitterSymbolProvider(language: .toml)),
            (.lua, TreeSitterSymbolProvider(language: .lua))
        ]
    }
}
```

### P5. Tree-Sitter Naming Outruns the Implementation

**Evidence**

- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterSymbolProvider.swift:5` through line 11 describes a tree-sitter-backed provider, then says it currently delegates to heuristic providers.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterSymbolProvider.swift:19` through line 68 switches by language and calls existing heuristic providers.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterRangeHighlightProvider.swift:330` through line 333 says the parser backend is still regex-backed until real C grammar loading exists.

**Impact**

Names like `TreeSitterSymbolProvider` and `TreeSitterRangeHighlightProvider` imply a stronger implementation than exists. This increases cognitive load because readers must inspect internals to learn that the current behavior is heuristic or regex-backed. It also risks design decisions being made around assumed parser capabilities.

**Recommendation**

Rename the current layer to reflect its implementation, or wrap the spike in an explicit feature flag. Reserve `TreeSitter...` names for code that is actually backed by grammar loading and queries.

Illustrative refactor:

```swift
internal struct HeuristicSymbolProviderFacade: DocumentSymbolProvider {
    let language: Language

    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        await SymbolProviderCatalog.provider(for: language)?.detectSymbols(in: text) ?? []
    }
}

internal struct TreeSitterSymbolProvider: DocumentSymbolProvider {
    let parser: TreeSitterParser
    let query: TreeSitterTagsQuery
}
```

## Duplication and Reuse Audit

### D1. Exact Duplicate Block Count Is Concentrated in Language Completion Code

**Evidence**

A normalized scan of non-comment Swift blocks found 255 duplicate 10-line block groups in `Sources/CodeEditorPlugin`.

Top clone groups include:

- Completion result assembly duplicated in 8 files:
  - `Sources/CodeEditorPlugin/Languages/RubyCompletionProvider.swift:352`
  - `Sources/CodeEditorPlugin/Languages/HTMLCompletionProvider.swift:228`
  - `Sources/CodeEditorPlugin/Languages/CCompletionProvider.swift:217`
  - `Sources/CodeEditorPlugin/Languages/MarkdownCompletionProvider.swift:79`
  - `Sources/CodeEditorPlugin/Languages/PHPCompletionProvider.swift:334`
  - `Sources/CodeEditorPlugin/Languages/YAMLCompletionProvider.swift:64`
  - `Sources/CodeEditorPlugin/Languages/ShellCompletionProvider.swift:372`
  - `Sources/CodeEditorPlugin/Languages/XMLCompletionProvider.swift:220`
- Snippet completion filtering duplicated in:
  - `Sources/CodeEditorPlugin/Completion/BaseCompletionProvider.swift:244`
  - `Sources/CodeEditorPlugin/Languages/RubyCompletionProvider.swift:607`
  - `Sources/CodeEditorPlugin/Languages/YAMLCompletionProvider.swift:467`
  - `Sources/CodeEditorPlugin/Languages/JavaScriptCompletionProvider.swift:334`
  - `Sources/CodeEditorPlugin/Languages/ShellCompletionProvider.swift:693`
- Parameter completion filtering duplicated in:
  - `Sources/CodeEditorPlugin/Languages/GoCompletionProvider.swift:256`
  - `Sources/CodeEditorPlugin/Languages/JavaScriptCompletionProvider.swift:360`
  - `Sources/CodeEditorPlugin/Languages/PythonCompletionProvider.swift:231`
  - `Sources/CodeEditorPlugin/Languages/SwiftCompletionProvider.swift:171`

**Impact**

This duplication is not harmless repetition. It exists inside inactive providers and competes with `BaseCompletionProvider` and `SharedCompletionBuilder`, both of which were explicitly created to reduce duplication. Any scoring, filtering, sorting, or snippet behavior fix must be repeated or will produce inconsistent completion behavior.

**Recommendation**

Delete inactive providers after extracting unique language facts. Keep completion item construction in one builder and context analysis in one strategy family.

Illustrative refactor:

```swift
protocol CompletionItemBuilding {
    func keywords(_ keywords: [String], filter: String, language: Language) -> [CompletionItemModel]
    func snippets(_ snippets: [SnippetTemplate], filter: String) -> [CompletionItemModel]
}

struct StandardCompletionItemBuilder: CompletionItemBuilding {
    func snippets(_ snippets: [SnippetTemplate], filter: String) -> [CompletionItemModel] {
        snippets
            .filter { filter.isEmpty || $0.label.localizedCaseInsensitiveContains(filter) }
            .map(CompletionItemModel.snippet)
    }
}
```

### D2. Language Metadata Is Repeated Across Descriptor, Regex, Registry, and Completion Layers

**Evidence**

- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift:68` through line 76 defines Swift keywords.
- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift:116` through line 136 defines JavaScript keywords, types, functions, literals, and triggers.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift:200` through line 215 defines JavaScript keywords and file extensions again.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:210` through line 212 defines Swift completion keywords again.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:221` through line 240 defines a Python regex highlighter provider even though descriptor-backed providers exist.

**Impact**

The same language facts have multiple owners. This makes language support hard to scale and causes stale metadata. For example, adding a new file extension might update language detection but not highlighting, or completion keywords but not regex rules.

**Recommendation**

Define language facts once, then generate or derive consumer-specific formats.

Illustrative refactor:

```swift
extension RegexLanguageDefinition {
    init(descriptor: LanguageDescriptor) {
        var builder = LanguageDefinitionBuilder()
        if let line = descriptor.comments.line {
            builder = builder.addComments(singleLine: line)
        }
        builder = builder
            .addStrings(delimiters: descriptor.highlighting.stringDelimiters)
            .addKeywords(descriptor.completion.keywords)
            .addFunctionCalls()
        self = builder.build(
            name: descriptor.identity.displayName,
            fileExtensions: descriptor.identity.fileExtensions
        )
    }
}
```

### D3. Syntax Token Colors Are Mapped in Several Places

**Evidence**

- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxColorScheme.swift:65` through line 100 defines the default token color scheme.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/AdaptiveColorSystem.swift:87` through line 120 maps `TokenType` to traditional colors.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+TypesExtensions.swift:59` through line 95 maps `RegexSyntaxTokenType` to colors.
- `Sources/CodeEditorPlugin/Languages/SwiftSyntaxHighlighter.swift:30` through line 68 maps `SwiftTokenType` to colors.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift:437` through line 455 maps `TokenType` to iOS default colors.

**Impact**

The system has a `SyntaxColorScheme`, but token types still hard-code colors in multiple layers. This makes theming harder and risks inconsistent highlighting between Swift syntax, regex syntax, adaptive colors, and platform defaults.

**Recommendation**

Use token classification as the abstraction and resolve colors through a single `SyntaxColorScheme`.

Illustrative refactor:

```swift
protocol SyntaxTokenClassifiable {
    var tokenClass: SyntaxTokenClass { get }
}

enum SyntaxTokenClass {
    case keyword
    case identifier
    case string
    case number
    case comment
    case type
    case function
    case property
    case `operator`
    case punctuation
    case preprocessor
    case plain
}

extension SyntaxColorScheme {
    func color(for tokenClass: SyntaxTokenClass) -> PlatformColor {
        switch tokenClass {
        case .keyword: keyword
        case .identifier: identifier
        case .string: string
        case .number: number
        case .comment: comment
        case .type: type
        case .function: function
        case .property: property
        case .operator: `operator`
        case .punctuation: punctuation
        case .preprocessor: preprocessor
        case .plain: plain
        }
    }
}
```

### D4. Symbol Provider Registration Is Duplicated and Already Diverged

**Evidence**

- `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift:50` through line 92 contains provider registration for current symbol navigation.
- `Sources/CodeEditorPlugin/Features/OptimizedSymbolNavigator.swift:121` through line 145 repeats much of the same provider registration.
- The optimized variant omits newer languages registered by `SymbolNavigator.swift:85` through line 92.

**Impact**

This is genuine redundancy because the two lists serve the same architectural purpose. Divergence has already occurred, so future language work will likely continue to update one list and miss the other.

**Recommendation**

Centralize provider registration with `SymbolProviderCatalog` as shown in P4. If only one navigator is live, remove the other.

### D5. AppKit and UIKit Representable Duplication Is Acceptable Repetition

**Evidence**

- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift:20` through line 80 implements `NSViewRepresentable`.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift:20` through line 80 implements the equivalent `UIViewRepresentable`.
- Both route shared work through `CodeEditorRepresentableHelper`, including `createAndSetupContainer`, `updateContainer`, `dismantle`, `calculateSize`, and `makeCoordinator`.

**Impact**

This is acceptable repetition. SwiftUI requires separate protocol entry points, and the project already moved behavior into a helper. Further abstraction would likely make protocol conformance harder to read without reducing meaningful duplication.

**Recommendation**

Keep the files separate. Only extract additional shared code when behavior, not protocol shape, is duplicated.

### D6. Range Transformation Logic Is Repeated With Different Semantics

**Evidence**

- `Sources/CodeEditorPlugin/Models/RangeMutation.swift:30` through line 74 transforms ranges around insertions and deletions.
- `Sources/CodeEditorPlugin/Extensions/NSRange+Extensions.swift:34` through line 51 applies a `RangeMutation` but returns nil for overlap cases.
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:244` through line 257 applies mutations through `TextRangeUtilities`.
- `Sources/CodeEditorPlugin/Utilities/Range+Extensions.swift:179` through line 237 adjusts ranges after deletion.

**Impact**

These implementations answer similar questions but differ in behavior. Some preserve partial overlaps, some invalidate them, and some clamp. That creates bug risk in highlights, folding, annotations, and range-store updates.

**Recommendation**

Model mutation policy explicitly. Callers should choose a named policy instead of implicitly getting different behavior from different helper locations.

Illustrative refactor:

```swift
enum RangeMutationPolicy {
    case invalidateOnOverlap
    case preserveSurvivingSegments
    case expandForInsertions
}

struct RangeMutationEngine {
    static func transform(_ range: NSRange, by mutation: RangeMutation, policy: RangeMutationPolicy) -> [NSRange] {
        switch policy {
        case .invalidateOnOverlap:
            return range.intersects(mutation.range) ? [] : [shiftIfNeeded(range, by: mutation)]
        case .preserveSurvivingSegments:
            return survivingSegments(of: range, after: mutation)
        case .expandForInsertions:
            return [expandIfInsertionInside(range, mutation: mutation)]
        }
    }
}
```

## Prioritized Refactoring Roadmap

### Priority 1: Complete the Completion Provider Migration

**Impact:** Very high maintainability and developer-productivity gain.

**Scope**

- Delete or quarantine the 18 inactive language-specific completion providers.
- Move any unique snippets/member completions into `LanguageDescriptor`, `LanguageMemberCompletions`, or a typed `CompletionProfile`.
- Add tests that assert `CompletionProviderRegistry` uses the descriptor-backed provider path for all supported languages.

**Primary files**

- `Sources/CodeEditorPlugin/Languages/*CompletionProvider.swift`
- `Sources/CodeEditorPlugin/Languages/LanguageProviderFactory.swift`
- `Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift`
- `Sources/CodeEditorPlugin/Languages/LanguageMemberCompletions.swift`

### Priority 2: Split Runtime Dependencies Out of `EditorConfiguration`

**Impact:** High correctness and API clarity gain.

**Scope**

- Introduce `EditorRuntimeDependencies` or `EditorSetup`.
- Keep `EditorConfiguration` pure value settings.
- Update `with(...)` call sites so configuration updates cannot drop injected dependencies.
- Add a regression test for dependency preservation or, preferably, dependency separation.

**Primary files**

- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CoreExtensions.swift`
- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift`

### Priority 3: Consolidate Range Utilities Around UTF-16 TextKit Semantics

**Impact:** High correctness gain for editor features.

**Scope**

- Make `TextRangeUtilities` canonical for text ranges.
- Deprecate or remove overlapping `RangeUtilities` methods.
- Centralize `RangeMutation` behavior with explicit policies.
- Audit call sites for `String.count` on editor offsets and replace with UTF-16 utilities where relevant.

**Primary files**

- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift`
- `Sources/CodeEditorPlugin/Utilities/Range+Extensions.swift`
- `Sources/CodeEditorPlugin/Extensions/NSRange+Extensions.swift`
- `Sources/CodeEditorPlugin/Models/RangeMutation.swift`

### Priority 4: Remove Parallel Symbol Navigation Implementations

**Impact:** Medium-high maintainability gain.

**Scope**

- Merge useful caches from `OptimizedSymbolNavigator` into `SymbolNavigator`, or delete `OptimizedSymbolNavigator`.
- Extract provider registration into `SymbolProviderCatalog`.
- Ensure new language provider coverage is driven from one catalog.

**Primary files**

- `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift`
- `Sources/CodeEditorPlugin/Features/OptimizedSymbolNavigator.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterSymbolProvider.swift`

### Priority 5: Normalize TextKit2-Only Source Truth

**Impact:** Medium maintainability and onboarding gain.

**Scope**

- Remove TextKit1 fallback wording and branches from source.
- Rename capability APIs that still frame TextKit2 as optional.
- Update tests that assert or name TextKit1 behavior.

**Primary files**

- `Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
- `Sources/CodeEditorPlugin/Text/ModernTextKitHelper.swift`
- `Sources/CodeEditorPlugin/Platform/PlatformCapabilities+TextKitExtensions.swift`
- `Tests/CodeEditorPluginTests/AnnotationTests.swift`
- `Tests/CodeEditorPluginTests/CodeEditorViewTests.swift`

### Priority 6: Centralize Syntax Color Resolution

**Impact:** Medium theming scalability gain.

**Scope**

- Route Swift, regex, adaptive, and platform token colors through `SyntaxColorScheme`.
- Keep token enums as classifiers only.
- Add snapshot or unit tests proving Swift and regex token classes resolve through the same scheme.

**Primary files**

- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxColorScheme.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/AdaptiveColorSystem.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+TypesExtensions.swift`
- `Sources/CodeEditorPlugin/Languages/SwiftSyntaxHighlighter.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift`

### Priority 7: Reduce `CodeEditorView` Ownership Over Time

**Impact:** High long-term scalability gain, but larger blast radius.

**Scope**

- Introduce `EditorRuntime` as a composition root.
- Move feature lifecycle ownership out of the view incrementally.
- Start with lower-risk subsystems: completion runtime, syntax runtime, and folding runtime.
- Keep `CodeEditorView` as the UI and TextKit host.

**Primary files**

- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CompletionExtensions.swift`

## Closing Assessment

The project is not suffering from too little architecture. It is suffering from transitional architecture that has not been retired. The fastest path to better maintainability is to remove inactive layers, establish a small number of canonical data and utility surfaces, and separate runtime dependencies from value configuration. Once those seams are clarified, the existing feature-based directory structure and descriptor-backed language direction can scale much more cleanly.
