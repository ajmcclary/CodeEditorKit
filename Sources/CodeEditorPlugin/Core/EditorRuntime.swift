import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorPlatform
import Foundation
// swiftlint:disable missing_docs

/// Runtime-only services used by editor instances.
///
/// Keep these dependencies out of `EditorConfiguration` so configuration
/// remains a codable, equatable value model. Host apps inject live services
/// through `EditorSetup` or directly on `CodeEditorView.runtime`.
@MainActor
public struct EditorRuntimeDependencies {
    /// Workspace root for LSP and file-backed editor features.
    public var workspaceRoot: URL?

    /// Event system used for opt-in editor event publication.
    public var eventSystem: UnifiedEventSystem?

    /// Memory monitor shared by performance-sensitive runtime components.
    public var memoryMonitor: MemoryMonitor

    /// Coordinator for editor actors and background work.
    @available(macOS 13.0, iOS 16.0, *)
    public var actorCoordinator: ActorCoordinator

    /// Platform capability detector.
    public var platformCapabilities: PlatformCapabilities

    /// Performance telemetry system.
    public var unifiedPerformanceSystem: UnifiedPerformanceSystem

    /// Paragraph style cache used during layout.
    public var paragraphStyleCache: ParagraphStyleCache

    /// Language metadata source for completion, highlighting, and snippets.
    public var languageMetadataRegistry: LanguageMetadataRegistry

    /// Cross-platform service layer.
    public var platformServiceLayer: PlatformServiceLayer

    /// Platform device service.
    public var platformDeviceService: PlatformDeviceService

    public init(
        workspaceRoot: URL? = nil,
        eventSystem: UnifiedEventSystem? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        actorCoordinator: ActorCoordinator? = nil,
        platformCapabilities: PlatformCapabilities? = nil,
        unifiedPerformanceSystem: UnifiedPerformanceSystem? = nil,
        paragraphStyleCache: ParagraphStyleCache? = nil,
        languageMetadataRegistry: LanguageMetadataRegistry? = nil,
        platformServiceLayer: PlatformServiceLayer? = nil,
        platformDeviceService: PlatformDeviceService? = nil
    ) {
        self.workspaceRoot = workspaceRoot
        self.eventSystem = eventSystem
        self.memoryMonitor = memoryMonitor ?? CodeEditorDependencies.makeMemoryMonitor()
        self.actorCoordinator = actorCoordinator ?? ActorCoordinator.create()
        self.platformCapabilities = platformCapabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        self.unifiedPerformanceSystem = unifiedPerformanceSystem ?? CodeEditorDependencies.makeUnifiedPerformanceSystem()
        self.paragraphStyleCache = paragraphStyleCache ?? CodeEditorDependencies.makeParagraphStyleCache()
        self.languageMetadataRegistry = languageMetadataRegistry ?? CodeEditorDependencies.makeLanguageMetadataRegistry()
        self.platformServiceLayer = platformServiceLayer ?? CodeEditorDependencies.makePlatformServiceLayer()
        self.platformDeviceService = platformDeviceService ?? CodeEditorDependencies.makePlatformDeviceService()
    }

    public static func live(workspaceRoot: URL? = nil, eventSystem: UnifiedEventSystem? = nil) -> Self {
        Self(workspaceRoot: workspaceRoot, eventSystem: eventSystem)
    }
}

/// Complete editor setup: durable value configuration plus live runtime dependencies.
@MainActor
public struct EditorSetup {
    public var configuration: EditorConfiguration
    public var runtimeDependencies: EditorRuntimeDependencies

    public init(
        configuration: EditorConfiguration = .default,
        runtimeDependencies: EditorRuntimeDependencies = .live()
    ) {
        self.configuration = configuration
        self.runtimeDependencies = runtimeDependencies
    }
}

/// Runtime composition root for a `CodeEditorView`.
@MainActor
public final class EditorRuntime {
    public private(set) var dependencies: EditorRuntimeDependencies
    public private(set) var featureDependencies: EditorFeatureRuntimeDependencies

    public init(dependencies: EditorRuntimeDependencies = .live()) {
        self.dependencies = dependencies
        self.featureDependencies = EditorFeatureRuntimeDependencies()
    }

    public func update(dependencies: EditorRuntimeDependencies) {
        self.dependencies = dependencies
        self.featureDependencies = EditorFeatureRuntimeDependencies()
    }

    public func update(featureDependencies: EditorFeatureRuntimeDependencies) {
        self.featureDependencies = featureDependencies
    }

    public func update(workspaceRoot: URL?) {
        dependencies.workspaceRoot = workspaceRoot
    }

    public func update(eventSystem: UnifiedEventSystem?) {
        dependencies.eventSystem = eventSystem
    }

    public func update(memoryMonitor: MemoryMonitor) {
        dependencies.memoryMonitor = memoryMonitor
    }
}

extension EditorSetup {
    /// Applies runtime dependencies first, then value configuration.
    @MainActor
    public func apply(to view: CodeEditorView) throws {
        view.apply(runtimeDependencies: runtimeDependencies)
        try view.apply(configuration: configuration)
    }
}

extension CodeEditorView {
    /// Applies live runtime dependencies to this editor instance.
    @MainActor
    public func apply(runtimeDependencies: EditorRuntimeDependencies) {
        let oldMemoryMonitor = runtime.dependencies.memoryMonitor
        runtime.update(dependencies: runtimeDependencies)

        if runtimeDependencies.memoryMonitor !== oldMemoryMonitor {
            memoryCoordinator.updateMemoryMonitor(runtimeDependencies.memoryMonitor)
        }

        #if canImport(AppKit)
        if lspManager.workspaceRoot != runtimeDependencies.workspaceRoot {
            lspManager.workspaceRoot = runtimeDependencies.workspaceRoot
        }
        #endif
    }
}

/// Layout services used by editor chrome and containers.
@MainActor
public struct EditorLayoutRuntimeDependencies {
    public var lineNumberCalculationService: LineNumberCalculationService
    public var gutterSizingService: GutterSizingService
    public var editorLayoutService: EditorLayoutService

    public init(
        lineNumberCalculationService: LineNumberCalculationService = LineNumberCalculationService(),
        gutterSizingService: GutterSizingService? = nil,
        editorLayoutService: EditorLayoutService? = nil
    ) {
        self.lineNumberCalculationService = lineNumberCalculationService
        let gutterSizingService = gutterSizingService ?? GutterSizingService(lineNumberCalculationService: lineNumberCalculationService)
        self.gutterSizingService = gutterSizingService
        self.editorLayoutService = editorLayoutService ?? EditorLayoutService(gutterSizingService: gutterSizingService)
    }
}

/// Syntax and language services used by live editor behavior.
@MainActor
public struct EditorSyntaxRuntimeDependencies {
    public var syntaxHighlightingService: SyntaxHighlightingService
    public var languageDetectionService: LanguageDetectionService

    public init(
        syntaxHighlightingService: SyntaxHighlightingService = SyntaxHighlightingService(),
        languageDetectionService: LanguageDetectionService = LanguageDetectionService()
    ) {
        self.syntaxHighlightingService = syntaxHighlightingService
        self.languageDetectionService = languageDetectionService
    }
}

/// Editing services used by TextKit interaction paths.
@MainActor
public struct EditorEditingRuntimeDependencies {
    public var textEditingService: TextEditingService

    public init(textEditingService: TextEditingService = TextEditingService()) {
        self.textEditingService = textEditingService
    }
}

/// Folding services that need the editor's folding engine.
@MainActor
public struct EditorFoldingRuntimeDependencies {
    private var codeFoldingEngine: CodeFoldingEngine?
    private var codeFoldingCoordinatorService: CodeFoldingCoordinatorService?
    private let lineNumberCalculationService: LineNumberCalculationService

    public init(
        lineNumberCalculationService: LineNumberCalculationService,
        codeFoldingCoordinatorService: CodeFoldingCoordinatorService? = nil
    ) {
        self.lineNumberCalculationService = lineNumberCalculationService
        self.codeFoldingCoordinatorService = codeFoldingCoordinatorService
    }

    mutating func registerCodeFoldingEngine(_ engine: CodeFoldingEngine) {
        codeFoldingEngine = engine
        codeFoldingCoordinatorService = nil
    }

    mutating func coordinatorService() throws -> CodeFoldingCoordinatorService {
        if let codeFoldingCoordinatorService {
            return codeFoldingCoordinatorService
        }

        guard let engine = codeFoldingEngine else {
            throw CodeEditorError.serviceUnavailable("CodeFoldingEngine")
        }

        let service = CodeFoldingCoordinatorService(
            lineNumberCalculationService: lineNumberCalculationService,
            codeFoldingEngine: engine
        )
        codeFoldingCoordinatorService = service
        return service
    }

    mutating func clearAllFolds() {
        codeFoldingCoordinatorService?.clearAllFolds()
    }
}

/// Explicit feature dependencies for editor view models and live editor behavior.
@MainActor
public final class EditorFeatureRuntimeDependencies {
    public var layout: EditorLayoutRuntimeDependencies
    public var syntax: EditorSyntaxRuntimeDependencies
    public var editing: EditorEditingRuntimeDependencies
    public var folding: EditorFoldingRuntimeDependencies

    public init(
        layout: EditorLayoutRuntimeDependencies = EditorLayoutRuntimeDependencies(),
        syntax: EditorSyntaxRuntimeDependencies = EditorSyntaxRuntimeDependencies(),
        editing: EditorEditingRuntimeDependencies = EditorEditingRuntimeDependencies()
    ) {
        self.layout = layout
        self.syntax = syntax
        self.editing = editing
        self.folding = EditorFoldingRuntimeDependencies(lineNumberCalculationService: layout.lineNumberCalculationService)
    }

    public var lineNumberCalculationService: LineNumberCalculationService {
        layout.lineNumberCalculationService
    }

    public var gutterSizingService: GutterSizingService {
        layout.gutterSizingService
    }

    public var editorLayoutService: EditorLayoutService {
        layout.editorLayoutService
    }

    public var syntaxHighlightingService: SyntaxHighlightingService {
        syntax.syntaxHighlightingService
    }

    public var languageDetectionService: LanguageDetectionService {
        syntax.languageDetectionService
    }

    public var textEditingService: TextEditingService {
        editing.textEditingService
    }

    public func codeFoldingCoordinatorService() throws -> CodeFoldingCoordinatorService {
        try folding.coordinatorService()
    }

    internal func registerCodeFoldingEngine(_ engine: CodeFoldingEngine) {
        folding.registerCodeFoldingEngine(engine)
    }

    public func invalidateCaches(for textView: CodeEditorView) {
        lineNumberCalculationService.invalidateCache(for: textView)
    }

    public func invalidateCaches(for configuration: EditorConfiguration) {
        editorLayoutService.invalidateCache(for: configuration)
    }

    public func clearAllCaches() {
        layout.lineNumberCalculationService.clearCache()
        layout.gutterSizingService.clearCache()
        layout.editorLayoutService.clearCache()
        syntax.syntaxHighlightingService.clearCache()
        syntax.languageDetectionService.clearCache()
        folding.clearAllFolds()
    }
}
// swiftlint:enable missing_docs
