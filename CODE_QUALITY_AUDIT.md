# Code Quality Audit

## Executive Summary

The codebase has a sound architectural direction: dependency injection is present through `EditorRuntimeDependencies`, TextKit2 access is intentionally mediated through `TextKitBridge`, platform checks generally follow the repository's `canImport(...)` convention, and several feature seams exist for layout, completion, syntax highlighting, folding, memory, and rendering.

The structural risk is not lack of abstraction. The risk is abstraction drift. Several newer services coexist beside older direct implementations without becoming the single execution path. This creates parallel sources of truth for completion ranking, folding state, language providers, edge insets, performance tracking, and platform drawing. In practice, this means future maintainers must know which abstraction is authoritative before making a change.

Measured scope:

- 797 Swift files across source and tests.
- 564 Swift files under `Sources/`.
- 134,540 total Swift lines across the repository.
- 112 exact multi-file duplicate blocks of 8 normalized non-comment Swift lines in `Sources/`.
- Largest maintainability hot spots include `LineGeometryStore.swift` at 998 lines, `CompletionManager.swift` at 711 lines, `RangeUtilities.swift` at 707 lines, `CodeEditorView.swift` at 666 lines, and `CoordinateSystemHelper.swift` at 557 lines.

Overall structural health: moderate. The project is not disorganized, but it carries accumulating technical debt from partially completed migrations and broad utility modules. The highest-value refactors are to remove dead/parallel abstractions, make completion and folding use one authoritative pipeline each, and split the largest helper objects along existing domain boundaries.

## Abstraction Analysis

### A1. `CodeEditorView` Remains a High-Fan-In Composition and State Object

Files:

- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:117`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:182`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:271`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:303`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:345`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:461`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:610`

Issue:

`CodeEditorView` is framed as the core view and has many method extensions, but the stored state still spans delegate ownership, event publication, runtime dependencies, syntax highlighters, LSP, folding, search, line geometry, TextKit bridge, edit hub, range-based highlighting, annotations, completion UI, and memory coordination. The extension split reduces file navigation cost but does not reduce the class's responsibility.

Impact:

Feature changes frequently require touching the core view or relying on internal mutable state. This raises coupling and makes lifecycle bugs more likely, especially because teardown at `removeFromSuperview()` must remember every subsystem.

Recommendation:

Keep `CodeEditorView` as the platform view, but move subsystem storage and lifecycle into a single internal aggregate that owns attach/detach semantics.

Illustrative refactor:

```swift
@MainActor
final class EditorSubsystems {
    let syntax: SyntaxHighlightingCoordinator
    let completion: CompletionManager
    let folding: CodeFoldingEngine
    let textKit: TextKitBridge
    let edits: TextEditEventHub

    init(view: CodeEditorView, runtime: EditorRuntime) {
        self.syntax = SyntaxHighlightingCoordinator()
        self.completion = CompletionManager(memoryMonitor: runtime.dependencies.memoryMonitor)
        self.folding = CodeFoldingEngine(memoryMonitor: runtime.dependencies.memoryMonitor)
        self.textKit = TextKitBridge(textView: view)
        self.edits = TextEditEventHub()
    }

    func attach(to view: CodeEditorView) {
        folding.attach(to: view)
    }

    func detach() {
        syntax.cancelHighlighting()
        completion.cancelCurrentRequest()
    }
}
```

Then `CodeEditorView.removeFromSuperview()` becomes `subsystems.detach()` plus platform cleanup.

### A2. `LineGeometryStore` Is a God Object Around Tree Storage, Parsing, Mutation, Lookup, and Validation

Files:

- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:71`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:120`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:159`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:727`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:774`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:821`
- `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:902`

Issue:

`LineGeometryStore` owns an internal red-black tree, UTF-16 line enumeration from `NSTextStorage`, edit application, index insertion/deletion, measured height state, fold state metadata, lookup caches, and invariant validation. The class is performance-sensitive, so centralization is understandable, but its responsibilities are broad enough that any change to line parsing, tree balancing, or edit projection is risky.

Impact:

The class is hard to reason about in isolation. Tree invariants, TextKit string enumeration, and editor-specific concepts such as folded height are mixed. This makes correctness regressions more likely when optimizing line updates.

Recommendation:

Split by volatility rather than by method visibility:

- `LineGeometryTree`: red-black tree operations and metadata invariants.
- `LineGeometryBuilder`: build `LineGeometry` arrays from TextKit storage or strings.
- `LineGeometryEditProjector`: translate text edits into insert/delete/update operations.
- `LineGeometryStore`: small facade used by UI callers.

Illustrative refactor:

```swift
@MainActor
final class LineGeometryStore {
    private var tree = LineGeometryTree()
    private let builder: LineGeometryBuilding
    private let projector: LineGeometryEditProjecting

    func build(from storage: NSTextStorage) {
        tree.replaceAll(builder.geometries(from: storage))
    }

    func apply(_ edit: TextEditEvent) {
        for operation in projector.operations(for: edit) {
            tree.apply(operation)
        }
    }
}
```

### A3. Completion Has Helper Services, but `CompletionManager` Still Owns the Pipeline

Files:

- `Sources/CodeEditorPlugin/Completion/CompletionManager.swift:61`
- `Sources/CodeEditorPlugin/Completion/CompletionManager.swift:207`
- `Sources/CodeEditorPlugin/Completion/CompletionManager.swift:438`
- `Sources/CodeEditorPlugin/Completion/CompletionManager.swift:529`
- `Sources/CodeEditorPlugin/Completion/CompletionFilteringService.swift:7`
- `Sources/CodeEditorPlugin/Completion/CompletionCacheManager.swift:7`
- `Sources/CodeEditorPlugin/Completion/CompletionContextExtractor.swift:7`
- `Sources/CodeEditorPlugin/Completion/CompletionRankingModel.swift:8`

Issue:

The completion package contains abstractions for filtering, cache management, context extraction, and ranking, but production usage does not consistently route through them. `CompletionManager` owns provider management, async request orchestration, cache checks, event broadcasting, frequency learning, deduplication, ranking, relevance scoring, and memory cleanup. The comment at `CompletionManager.swift:529` explicitly notes duplicated constants from `CompletionRankingModel`.

Impact:

Ranking behavior can drift between the sample app, the manager, and future callers. The helper classes look like extension points but are not the authoritative completion pipeline.

Recommendation:

Promote the helper concepts into one injected `CompletionPipeline`, and make `CompletionManager` responsible only for provider registration, cancellation, and delegation.

Illustrative refactor:

```swift
@MainActor
struct CompletionPipeline {
    var cache: CompletionResultCaching
    var ranker: CompletionRanking
    var filter: CompletionFiltering

    func process(
        _ providerResults: [CompletionResult],
        context: CompletionContextModel,
        limit: Int
    ) -> CompletionResult {
        let items = providerResults.flatMap(\.items)
        let ranked = ranker.rank(items, context: context)
        return CompletionResult(
            items: Array(ranked.prefix(limit)),
            context: context,
            isIncomplete: providerResults.contains { $0.isIncomplete },
            processingTime: 0
        )
    }
}
```

### A4. Code Folding Has Two Competing State Models

Files:

- `Sources/CodeEditorPlugin/Core/CodeFoldingCoordinatorService.swift:13`
- `Sources/CodeEditorPlugin/Core/CodeFoldingCoordinatorService.swift:145`
- `Sources/CodeEditorPlugin/Core/CodeFoldingCoordinatorService.swift:147`
- `Sources/CodeEditorPlugin/Core/CodeFoldingCoordinatorService.swift:333`
- `Sources/CodeEditorPlugin/Core/CodeFoldingCoordinatorService.swift:490`
- `Sources/CodeEditorPlugin/Core/CodeFoldingCoordinatorService.swift:505`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeFoldingExtensions.swift:28`
- `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift:21`
- `Sources/CodeEditorPlugin/Layout/GutterViewModel.swift:159`
- `Sources/CodeEditorPlugin/Layout/GutterViewModel.swift:492`

Issue:

`CodeFoldingCoordinatorService` injects `CodeFoldingEngine`, but it stores its own `foldedRegions`, `foldableRegions`, and `controlLayouts`, and it detects brace/indentation folds itself. The actual public editor API calls `codeFoldingEngine` directly. The gutter view model asks for `CodeFoldingCoordinatorService`, but registration of the engine into `EditorFeatureRuntimeDependencies` is not called from normal setup. The service also contains comments saying engine integration is still to be implemented.

Impact:

The gutter can render fold controls from a different model than the editor API uses for folding behavior. This is a high cognitive-load pattern because developers must know whether folding truth lives in `CodeFoldingEngine` or `CodeFoldingCoordinatorService`.

Recommendation:

Make `CodeFoldingCoordinatorService` a facade over `CodeFoldingEngine`, or delete it and move fold-control layout into a focused `FoldControlLayoutService`.

Illustrative facade:

```swift
@MainActor
final class FoldControlLayoutService {
    private let engine: CodeFoldingEngine
    private let lineNumbers: LineNumberCalculationService

    func layout(for line: Int, in gutter: CGRect, textView: CodeEditorView) -> FoldControlLayout? {
        guard engine.isStartOfFoldableRegion(line) else { return nil }
        let type: FoldControlType = engine.isLineFolded(line) ? .collapsed : .expandable
        return makeLayout(line: line, type: type, gutter: gutter, textView: textView)
    }
}
```

### A5. `CoordinateSystemHelper` Is Large, Apparently Unused, and Violates TextKit2 Safety if Adopted

Files:

- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:11`
- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:142`
- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:180`
- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:408`
- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:444`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:206`

Issue:

`CoordinateSystemHelper` is 557 lines and no production code instantiates `CoordinateSystemHelper`. The file also contains the public `EdgeInsets` type, so it cannot simply be ignored. The helper's text methods read `textView.layoutManager`, while `CodeEditorView` documents that reading `self.layoutManager` on TextKit2-initialized AppKit views can coerce the view into TextKit1 compatibility.

Impact:

The file is both dead abstraction and a future footgun. A developer looking for coordinate conversion may adopt it and accidentally bypass the TextKit2 access rules.

Recommendation:

Move `EdgeInsets` into its own file, then either delete `CoordinateSystemHelper` or rewrite it against `TextKitLineNumberHelper`, `TextKitBridge`, and `NSTextLayoutManager` surfaces.

Illustrative split:

```swift
// Platform/EditorEdgeInsets.swift
public struct EditorEdgeInsets: Sendable, Equatable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat
}

// Text/TextCoordinateMapper.swift
@MainActor
protocol TextCoordinateMapping {
    func textRangeRect(_ range: NSRange, in view: CodeEditorView) -> CGRect?
}
```

### A6. `RangeUtilities` Is a Useful Facade That Has Grown Past One Abstraction Level

Files:

- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:14`
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:84`
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:120`
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:196`
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:300`
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:421`
- `Sources/CodeEditorPlugin/Text/RangeUtilities.swift:572`

Issue:

`TextRangeUtilities` covers TextKit conversion, validation, UTF-16 substring extraction, identifier parsing, line ranges, mutation application, overlap math, batch sizing, viewport ranges, and private batching heuristics. It is widely used and valuable, but it is now more of a namespace than a cohesive abstraction.

Impact:

The API surface makes it easy to add unrelated helper functions, which increases discoverability cost and makes range policy harder to audit.

Recommendation:

Keep source compatibility through the facade, but move implementation to focused types:

- `UTF16RangeConverter`
- `RangeValidationPolicy`
- `LineRangeIndex`
- `RangeSetOperations`
- `RangeBatchPlanner`

Illustrative compatibility layer:

```swift
public enum TextRangeUtilities {
    public static func lineRanges(in string: String) -> [NSRange] {
        LineRangeIndex(string: string).ranges
    }

    public static func merge(_ ranges: [NSRange]) -> [NSRange] {
        RangeSetOperations.merge(ranges)
    }
}
```

## Pattern Consistency Review

### P1. Runtime Dependency Injection Is Bypassed for Performance Tracking

Files:

- `Sources/CodeEditorPlugin/Core/EditorRuntime.swift:27`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:182`
- `Sources/CodeEditorPlugin/Performance/UnifiedPerformanceSystem.swift:617`

Issue:

`EditorRuntimeDependencies` contains `unifiedPerformanceSystem`, and `CodeEditorView` has a runtime composition root. However, `CodeEditorView.trackPerformance` creates a fresh performance system through `CodeEditorDependencies.makeUnifiedPerformanceSystem()` for every call.

Impact:

Tracked metrics are not accumulated on the editor's injected performance system. Host-provided telemetry or test overrides can be silently bypassed.

Recommendation:

Route through `runtime.dependencies.unifiedPerformanceSystem`.

Illustrative refactor:

```swift
extension CodeEditorView {
    public func trackPerformance<T>(
        _ metric: PerformanceMetricType,
        operation: () async throws -> T
    ) async throws -> T {
        try await runtime.dependencies.unifiedPerformanceSystem.track(metric, operation: operation)
    }
}
```

### P2. Descriptor-Backed Language Registration Coexists With Dead Legacy Providers

Files:

- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:144`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:155`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:193`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:216`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:244`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:432`

Issue:

Built-in registration now iterates `Language.allCases` and wraps `LanguageDescriptor` in `DescriptorLanguageProvider`. The same file still contains legacy concrete providers for Swift, Python, JavaScript, JSON, HTML, CSS, Markdown, XML, YAML, and plain text. Repository search found no production or test references to those concrete provider types outside their declarations.

Impact:

The file communicates two competing extension patterns. A maintainer adding a language may copy a dead provider instead of adding a descriptor, increasing drift.

Recommendation:

Delete the legacy provider structs or move them to test fixtures if they still serve test value. Keep `DescriptorLanguageProvider` as the single built-in-provider path.

Illustrative target:

```swift
private func registerBuiltInLanguages() {
    Language.allCases
        .compactMap(LanguageDescriptor.descriptor(for:))
        .map(DescriptorLanguageProvider.init(descriptor:))
        .forEach(register)
}
```

### P3. TextKit2 Access Rules Are Documented, but Not Encapsulated Strongly Enough

Files:

- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:206`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:212`
- `Sources/CodeEditorPlugin/Text/TextKitBridge.swift:86`
- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:148`
- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:185`

Issue:

The project clearly documents that AppKit `textStorage` and `layoutManager` are dangerous TextKit1 compatibility accessors. The convention is followed in many places through `TextKitBridge`, but `CoordinateSystemHelper` still directly uses `textView.layoutManager`.

Impact:

Because the rule is convention-based rather than enforced by an API boundary, utility code can regress the editor into TextKit1 mode.

Recommendation:

Add a lint rule or code review check for direct `CodeEditorView.layoutManager` and `CodeEditorView.textStorage` access outside narrowly approved files. Move approved low-level access behind `TextKitBridge` APIs.

Illustrative API:

```swift
extension TextKitBridge {
    func rects(forUTF16Range range: NSRange) -> [CGRect] {
        // Use TextKit2 layout fragments here.
    }
}
```

### P4. Platform-Specific SwiftUI Representables Are Nearly Identical

Files:

- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift:8`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift:22`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift:43`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift:8`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift:22`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift:43`

Issue:

The AppKit and UIKit representables have unavoidable protocol method-name differences, but the stored properties and make/update/dismantle/size/coordinator logic are effectively identical.

Impact:

Every new representable parameter must be added twice. The risk is not runtime behavior; it is incomplete platform parity during feature changes.

Recommendation:

Keep separate protocol conformances but move repeated parameter assembly into a shared helper.

Illustrative refactor:

```swift
private extension CodeEditorRepresentable {
    var containerParameters: CodeEditorRepresentableHelper.ContainerParameters {
        .init(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            runtimeDependencies: runtimeDependencies,
            interactionState: interactionState,
            editorController: editorController,
            hostEditorState: hostEditorState,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            swiftUICompletionProvider: swiftUICompletionProvider
        )
    }
}
```

### P5. Multiple `EdgeInsets` Concepts Create Type Ambiguity

Files:

- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:444`
- `Sources/CodeEditorPlugin/Extensions/EdgeInsets+Extensions.swift:17`
- `Sources/CodeEditorPlugin/Core/EditorLayoutService.swift:60`
- `Sources/CodeEditorPlugin/Layout/LayoutCoordinator.swift:170`

Issue:

The package exposes a public `EdgeInsets`, a nested `EditorLayoutService.EdgeInsets`, and a platform typealias inside `LayoutContext`. Each is structurally similar but not interchangeable.

Impact:

Developers must remember which edge-inset type a layout API expects. This encourages adapters and ad hoc conversions.

Recommendation:

Adopt one canonical public editor inset type, then make platform conversions explicit extensions on that type.

Illustrative refactor:

```swift
public struct EditorEdgeInsets: Sendable, Equatable {
    public static let zero = Self()
    public var top = CGFloat.zero
    public var left = CGFloat.zero
    public var bottom = CGFloat.zero
    public var right = CGFloat.zero
}

public typealias EdgeInsets = EditorEdgeInsets
```

## Duplication and Reuse Audit

### Duplication Scan Summary

An exact duplicate scan over `Sources/` using normalized non-comment 8-line blocks found 112 multi-file duplicate blocks. The highest-signal categories were:

- SwiftUI AppKit/UIKit representable parameter assembly.
- Platform minimap drawing paths.
- Completion cell platform implementations and an older unused configurator.
- Language descriptor families such as JavaScript/TypeScript and C/C++.
- Line-based symbol and folding providers.
- Debouncing implementations in `AsyncOperationManager`.
- Repeated theme palette decoding for status/VCS colors.

Some repetition is acceptable because AppKit/UIKit protocols and language grammars differ. The duplication that should be removed first is duplication that creates competing behavior or an illusion of reuse: completion ranking/cache helpers, folding services, dead language providers, and unused completion cell abstractions.

### D1. Platform Minimap Views Duplicate Rendering Logic

Files:

- `Sources/CodeEditorPlugin/Layout/MinimapView.swift:200`
- `Sources/CodeEditorPlugin/Layout/MinimapView.swift:296`
- `Sources/CodeEditorPlugin/Layout/MinimapView.swift:336`
- `Sources/CodeEditorPlugin/Layout/MinimapView.swift:415`
- `Sources/CodeEditorPlugin/Layout/MinimapView.swift:475`
- `Sources/CodeEditorPlugin/Layout/MinimapView.swift:516`

Issue:

`AppKitMinimapView` and `UIKitMinimapView` both own theme state, background fill, border drawing, placeholder text, text-line iteration, and viewport drawing. The platform differences are mostly drawing primitives and y-axis handling.

Impact:

Theme, truncation, placeholder, and viewport changes must be made twice. Visual parity can drift.

Recommendation:

Extract a platform-neutral renderer that computes draw commands from `MinimapData`, `MinimapConfiguration`, theme state, and bounds. Platform views should only execute commands.

Illustrative refactor:

```swift
struct MinimapRenderCommand {
    enum Kind { case fill(CGColor), stroke(CGColor), text(String, CGPoint), viewport(CGRect) }
    let kind: Kind
}

struct MinimapRenderer {
    func commands(data: MinimapData?, bounds: CGRect, theme: MinimapThemeState) -> [MinimapRenderCommand] {
        // Shared background, placeholder, lines, and viewport logic.
    }
}
```

### D2. Line-Based Symbol Providers Reimplement Existing Boilerplate

Files:

- `Sources/CodeEditorPlugin/Languages/LineBasedSymbolProvider.swift:31`
- `Sources/CodeEditorPlugin/Languages/LineBasedSymbolProvider.swift:47`
- `Sources/CodeEditorPlugin/Languages/CSSSymbolProvider.swift:5`
- `Sources/CodeEditorPlugin/Languages/RubySymbolProvider.swift:5`
- `Sources/CodeEditorPlugin/Languages/PHPSymbolProvider.swift:5`

Issue:

`LineBasedSymbolProvider` already provides line iteration and UTF-16 offset tracking, but many providers still implement the same loop manually. A targeted search found 16 manual `currentLocation += TextRangeUtilities.utf16Length(of: line) + 1` occurrences and 29 repeated `NSRange(location: location, length: TextRangeUtilities.utf16Length(of: fullLine))` constructions in language providers.

Impact:

UTF-16 offset behavior can drift per language, especially for trailing-newline and composed-character cases.

Recommendation:

Migrate simple providers to `LineBasedSymbolProvider`. For providers needing state, add a stateful variant.

Illustrative refactor:

```swift
protocol StatefulLineBasedSymbolProvider: DocumentSymbolProvider {
    associatedtype State
    func makeState() -> State
    func detectSymbol(
        in line: String,
        at location: Int,
        lineIndex: Int,
        fullLine: String,
        state: inout State
    ) -> DocumentSymbol?
}
```

### D3. Language Descriptor Families Repeat Base Data

Files:

- `Sources/CodeEditorPlugin/Languages/Data/JavascriptLanguageDescriptor.swift:5`
- `Sources/CodeEditorPlugin/Languages/Data/JavascriptLanguageDescriptor.swift:11`
- `Sources/CodeEditorPlugin/Languages/Data/TypescriptLanguageDescriptor.swift:5`
- `Sources/CodeEditorPlugin/Languages/Data/TypescriptLanguageDescriptor.swift:11`
- `Sources/CodeEditorPlugin/Languages/Data/CLanguageDescriptor.swift:12`
- `Sources/CodeEditorPlugin/Languages/Data/CppLanguageDescriptor.swift:12`

Issue:

JavaScript and TypeScript descriptors duplicate comment syntax, identifier patterns, string delimiters, many keywords, and common functions. C and C++ also share comment/string/highlighting base rules.

Impact:

Language data changes require manual synchronization. This is lower risk than behavioral duplication, but it scales poorly as descriptor counts grow.

Recommendation:

Introduce descriptor composition helpers for language families.

Illustrative refactor:

```swift
enum ECMAScriptDescriptorBase {
    static let comments = CommentSyntax(line: "//", blockStart: "/*", blockEnd: "*/")
    static let identifierPattern = "[a-zA-Z_$][a-zA-Z0-9_$]*"
    static let stringDelimiters = ["\"", "'", "`"]
    static let keywords = ["const", "let", "var", "function", "class"]
}

static let typescriptDescriptor = LanguageDescriptor(
    language: .typescript,
    comments: ECMAScriptDescriptorBase.comments,
    identifierPattern: ECMAScriptDescriptorBase.identifierPattern,
    keywords: ECMAScriptDescriptorBase.keywords + TypeScriptOnly.keywords
)
```

### D4. `AsyncOperationManager` Has Parallel Debouncing Implementations

Files:

- `Sources/CodeEditorPlugin/Utilities/AsyncOperationManager.swift:99`
- `Sources/CodeEditorPlugin/Utilities/AsyncOperationManager+DebouncingExtensions.swift:41`
- `Sources/CodeEditorPlugin/Utilities/AsyncOperationManager+OptimizedDebouncing.swift:21`
- `Sources/CodeEditorPlugin/Utilities/AsyncOperationManager+OptimizedDebouncing.swift:82`
- `Sources/CodeEditorPlugin/Utilities/AsyncOperationManager.swift:328`

Issue:

The standard debounce and optimized debounce paths duplicate cancellation, sleep, task storage, result storage, error storage, cleanup, and return handling. The top-level `debouncedAsync` helper constructs an `AsyncOperationManager` and discards it, which suggests historical layering rather than active design.

Impact:

Bug fixes to debounce cancellation or result cleanup must be applied to multiple paths. The naming also makes it unclear when callers should use `debounce` versus `debounceOptimized`.

Recommendation:

Create one internal primitive with policy flags.

Illustrative refactor:

```swift
private enum DebounceMode {
    case awaitingResult
    case fireAndForget
}

private func runDebounced<T: Sendable>(
    key: String,
    delay: TimeInterval,
    mode: DebounceMode,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T?
```

### D5. Completion Cell Abstractions Duplicate and Obscure the Current UI Path

Files:

- `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift:12`
- `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift:90`
- `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift:268`
- `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift:399`
- `Sources/CodeEditorPlugin/Completion/CompletionCellConfigurator.swift:12`
- `Sources/CodeEditorPlugin/Completion/CompletionCellConfigurator.swift:150`
- `Sources/CodeEditorPlugin/Completion/CompletionCellConfigurator.swift:188`

Issue:

`CompletionCellComponents.swift` appears to be the active cross-platform cell implementation. `CompletionCellConfigurator.swift` defines a second public configuration system, base view, and constraints helper, but repository search found no external usage beyond its own declarations.

Impact:

Public but unused UI abstractions increase API surface and confuse maintainers about the endorsed completion-cell path.

Recommendation:

Delete `CompletionCellConfigurator.swift` if it is not public API that must be preserved. If public compatibility is required, mark it deprecated and forward into `CompletionCellConfiguration` and `CompletionCellTheme`.

Illustrative compatibility shim:

```swift
@available(*, deprecated, message: "Use CompletionCellConfiguration and CompletionCellTheme")
public enum CompletionCellConfigurator {
    public typealias CellConfiguration = CompletionCellConfiguration
}
```

### D6. `EdgeInsets` Duplication Should Be Collapsed Before More Layout APIs Are Added

Files:

- `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift:444`
- `Sources/CodeEditorPlugin/Core/EditorLayoutService.swift:64`
- `Sources/CodeEditorPlugin/Layout/LayoutCoordinator.swift:170`
- `Sources/CodeEditorPlugin/Extensions/EdgeInsets+Extensions.swift:17`

Issue:

Insets are represented by at least three concepts. The public extension file extends one of them, while layout services use others.

Impact:

Code reuse is limited because APIs use incompatible inset types for the same concept.

Recommendation:

Canonicalize on one type and provide conversion helpers.

### D7. Legacy Language Providers Duplicate Descriptor Data and Should Be Removed

Files:

- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:193`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:216`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:244`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:271`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:296`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift:405`

Issue:

The unused concrete providers repeat keyword and regex data that now belongs in `LanguageDescriptor` files.

Impact:

These providers are duplicate reference material that can become stale and misleading.

Recommendation:

Remove the concrete provider declarations after confirming they are not part of the public API. If binary/source compatibility matters, hide them behind deprecation annotations and route through descriptors.

## Prioritized Refactoring Roadmap

### 1. Remove or Deprecate Dead Parallel Abstractions

Impact: high maintainability, low implementation risk.

Targets:

- Delete or deprecate `CompletionCellConfigurator.swift`.
- Delete unused legacy language providers in `LanguageRegistry.swift`.
- Move `EdgeInsets` out of `CoordinateSystemHelper.swift`, then delete or quarantine `CoordinateSystemHelper`.
- Fix `CodeEditorView.trackPerformance` to use `runtime.dependencies.unifiedPerformanceSystem`.

Rationale:

These changes reduce cognitive load immediately and avoid changing core editor behavior.

### 2. Make Code Folding Use One Source of Truth

Impact: high maintainability and correctness.

Targets:

- Replace `CodeFoldingCoordinatorService`'s fold detection and state with calls into `CodeFoldingEngine`.
- Move fold-control layout into a dedicated layout service.
- Ensure `EditorFeatureRuntimeDependencies.configureForEditor(...)` is either called from setup or removed if obsolete.

Rationale:

Folding currently has the highest risk of user-visible divergence because the API and gutter can consult different models.

### 3. Consolidate the Completion Pipeline

Impact: high developer productivity and feature scalability.

Targets:

- Promote ranking, filtering, cache, and learning into injected pipeline collaborators.
- Remove duplicated relevance constants between `CompletionManager` and `CompletionRankingModel`.
- Decide whether `CompletionContextExtractor` is production API or test-only support.

Rationale:

Completion is a central extension point. One authoritative pipeline will make future LSP, local, and SwiftUI providers easier to reason about.

### 4. Split `LineGeometryStore` Internals

Impact: high correctness confidence, moderate implementation risk.

Targets:

- Extract tree mechanics into `LineGeometryTree`.
- Extract TextKit/string enumeration into `LineGeometryBuilder`.
- Extract edit translation into `LineGeometryEditProjector`.
- Keep existing public `LineGeometryStore` API as a facade.

Rationale:

This is the largest single object in the core text path. Splitting it should be done after lower-risk cleanup so test failures are easier to attribute.

### 5. Reduce Platform Rendering Duplication

Impact: medium maintainability, medium risk.

Targets:

- Extract shared minimap renderer commands.
- Extract shared SwiftUI representable parameter assembly.
- Keep platform-specific shells thin and explicit.

Rationale:

This reduces parity drift without fighting AppKit/UIKit protocol differences.

### 6. Migrate Repeated Language Providers to Shared Line-Based Helpers

Impact: medium maintainability, low-to-medium risk.

Targets:

- Convert simple symbol providers to `LineBasedSymbolProvider`.
- Add `StatefulLineBasedSymbolProvider` for providers such as PHP that need contextual state.
- Reuse shared range constructors for `DocumentSymbol`.

Rationale:

This removes repeated UTF-16 offset math and decreases the chance of language-specific range bugs.

### 7. Decompose Broad Utility Namespaces

Impact: medium long-term scalability, moderate risk.

Targets:

- Keep `TextRangeUtilities` as a compatibility facade.
- Move implementation into focused range conversion, validation, line indexing, and batching helpers.
- Normalize public docs to steer new code toward focused modules.

Rationale:

This prevents utility namespaces from continuing to absorb unrelated responsibilities while preserving source compatibility.
