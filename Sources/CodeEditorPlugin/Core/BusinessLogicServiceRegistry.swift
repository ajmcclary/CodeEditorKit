import Foundation

// MARK: - Business Logic Service Registry

/// Centralized registry for all business logic services
/// Provides dependency injection and service lifecycle management
@MainActor
public final class BusinessLogicServiceRegistry {
    // MARK: - Singleton

    // MARK: - Services

    private var _lineNumberCalculationService: LineNumberCalculationService?
    private var _gutterSizingService: GutterSizingService?
    private var _codeFoldingCoordinatorService: CodeFoldingCoordinatorService?
    private var _editorLayoutService: EditorLayoutService?
    private var _syntaxHighlightingService: SyntaxHighlightingService?
    private var _languageDetectionService: LanguageDetectionService?
    private var _textEditingService: TextEditingService?
    private var _completionProviderRegistry: CompletionProviderRegistry?

    // Service dependencies
    private weak var codeFoldingEngine: CodeFoldingEngine?

    // Injectable dependencies
    private let languageMetadataRegistry: LanguageMetadataRegistry?

    // MARK: - Initialization

    /// Creates a new service registry instance
    /// - Parameters:
    ///   - lineNumberCalculationService: Optional pre-configured line number service
    ///   - gutterSizingService: Optional pre-configured gutter sizing service
    ///   - codeFoldingCoordinatorService: Optional pre-configured code folding service
    ///   - editorLayoutService: Optional pre-configured editor layout service
    ///   - syntaxHighlightingService: Optional pre-configured syntax highlighting service
    ///   - languageDetectionService: Optional pre-configured language detection service
    ///   - textEditingService: Optional pre-configured text editing service
    ///   - completionProviderRegistry: Optional pre-configured completion provider registry
    ///   - languageMetadataRegistry: Optional language metadata registry for DI
    public init(
        lineNumberCalculationService: LineNumberCalculationService? = nil,
        gutterSizingService: GutterSizingService? = nil,
        codeFoldingCoordinatorService: CodeFoldingCoordinatorService? = nil,
        editorLayoutService: EditorLayoutService? = nil,
        syntaxHighlightingService: SyntaxHighlightingService? = nil,
        languageDetectionService: LanguageDetectionService? = nil,
        textEditingService: TextEditingService? = nil,
        completionProviderRegistry: CompletionProviderRegistry? = nil,
        languageMetadataRegistry: LanguageMetadataRegistry? = nil
    ) {
        self._lineNumberCalculationService = lineNumberCalculationService
        self._gutterSizingService = gutterSizingService
        self._codeFoldingCoordinatorService = codeFoldingCoordinatorService
        self._editorLayoutService = editorLayoutService
        self._syntaxHighlightingService = syntaxHighlightingService
        self._languageDetectionService = languageDetectionService
        self._textEditingService = textEditingService
        self._completionProviderRegistry = completionProviderRegistry
        self.languageMetadataRegistry = languageMetadataRegistry
    }

    // MARK: - Service Access

    /// Gets or creates the line number calculation service
    public var lineNumberCalculationService: LineNumberCalculationService {
        if let service = _lineNumberCalculationService {
            return service
        }

        let service = LineNumberCalculationService()
        _lineNumberCalculationService = service
        return service
    }

    /// Gets or creates the gutter sizing service
    public var gutterSizingService: GutterSizingService {
        if let service = _gutterSizingService {
            return service
        }

        let service = GutterSizingService(lineNumberCalculationService: lineNumberCalculationService)
        _gutterSizingService = service
        return service
    }

    /// Gets or creates the code folding coordinator service
    public var codeFoldingCoordinatorService: CodeFoldingCoordinatorService {
        if let service = _codeFoldingCoordinatorService {
            return service
        }

        // Ensure we have a code folding engine
        guard let engine = codeFoldingEngine else {
            fatalError("CodeFoldingEngine must be registered before accessing CodeFoldingCoordinatorService")
        }

        let service = CodeFoldingCoordinatorService(
            lineNumberCalculationService: lineNumberCalculationService,
            codeFoldingEngine: engine
        )
        _codeFoldingCoordinatorService = service
        return service
    }

    /// Gets or creates the editor layout service
    public var editorLayoutService: EditorLayoutService {
        if let service = _editorLayoutService {
            return service
        }

        let service = EditorLayoutService(gutterSizingService: gutterSizingService)
        _editorLayoutService = service
        return service
    }

    /// Gets or creates the syntax highlighting service
    public var syntaxHighlightingService: SyntaxHighlightingService {
        if let service = _syntaxHighlightingService {
            return service
        }

        let service = SyntaxHighlightingService()
        _syntaxHighlightingService = service
        return service
    }

    /// Gets or creates the language detection service
    public var languageDetectionService: LanguageDetectionService {
        if let service = _languageDetectionService {
            return service
        }

        let service = LanguageDetectionService()
        _languageDetectionService = service
        return service
    }

    /// Gets or creates the text editing service
    public var textEditingService: TextEditingService {
        if let service = _textEditingService {
            return service
        }

        let service = TextEditingService()
        _textEditingService = service
        return service
    }

    /// Gets or creates the completion provider registry
    public var completionProviderRegistry: CompletionProviderRegistry {
        if let registry = _completionProviderRegistry {
            return registry
        }

        let registry = CompletionProviderRegistry(languageMetadataRegistry: languageMetadataRegistry)
        _completionProviderRegistry = registry
        return registry
    }

    // MARK: - Service Registration

    /// Registers the code folding engine dependency
    internal func registerCodeFoldingEngine(_ engine: CodeFoldingEngine) {
        self.codeFoldingEngine = engine

        // Invalidate code folding coordinator if it was already created
        _codeFoldingCoordinatorService = nil
    }

    // MARK: - Service Management

    /// Clears all service caches
    public func clearAllCaches() {
        _lineNumberCalculationService?.clearCache()
        _gutterSizingService?.clearCache()
        _codeFoldingCoordinatorService?.clearAllFolds()
        _editorLayoutService?.clearCache()
        _syntaxHighlightingService?.clearCache()
        _languageDetectionService?.clearCache()
        // TextEditingService doesn't have caches to clear
    }

    /// Resets all services (useful for testing)
    public func resetAllServices() {
        _lineNumberCalculationService = nil
        _gutterSizingService = nil
        _codeFoldingCoordinatorService = nil
        _editorLayoutService = nil
        _syntaxHighlightingService = nil
        _languageDetectionService = nil
        _textEditingService = nil
        codeFoldingEngine = nil
    }

    /// Gets service status for debugging
    public func getServiceStatus() -> [String: Bool] {
        [
            "lineNumberCalculationService": _lineNumberCalculationService != nil,
            "gutterSizingService": _gutterSizingService != nil,
            "codeFoldingCoordinatorService": _codeFoldingCoordinatorService != nil,
            "editorLayoutService": _editorLayoutService != nil,
            "syntaxHighlightingService": _syntaxHighlightingService != nil,
            "languageDetectionService": _languageDetectionService != nil,
            "textEditingService": _textEditingService != nil,
            "codeFoldingEngine": codeFoldingEngine != nil
        ]
    }
}

// MARK: - Service Protocol Extensions

/// Protocol for services that support cache management
@MainActor
public protocol CacheableService {
    /// Clears all cached data to free up memory
    func clearCache()
}

/// Protocol for services that support state persistence
@MainActor
public protocol PersistentService {
    /// Saves the current service state to a dictionary
    /// - Returns: Dictionary containing the serialized state
    func saveState() -> [String: Any]
    /// Restores service state from a dictionary
    /// - Parameter data: Dictionary containing the serialized state
    func restoreState(from data: [String: Any])
}

// MARK: - Service Extensions

@MainActor
extension LineNumberCalculationService: CacheableService {
    // Already implements clearCache()
}

@MainActor
extension GutterSizingService: CacheableService {
    // Already implements clearCache()
}

@MainActor
extension EditorLayoutService: CacheableService {
    // Already implements clearCache()
}

@MainActor
extension CodeFoldingCoordinatorService: CacheableService, PersistentService {
    // Already implements clearCache() (via clearAllFolds())
    // Already implements saveState() and restoreState()

    public func clearCache() {
        clearAllFolds()
    }

    public func saveState() -> [String: Any] {
        saveFoldingState()
    }

    public func restoreState(from _: [String: Any]) {
        // This would need a textView parameter, so it's handled separately
        // in the actual implementation
    }
}

// MARK: - Convenience Extensions

extension BusinessLogicServiceRegistry {
    /// Configures services for a specific editor instance
    internal func configureForEditor(
        textView: CodeEditorView,
        configuration: EditorConfiguration,
        codeFoldingEngine: CodeFoldingEngine? = nil
    ) {
        // Register code folding engine if provided
        if let engine = codeFoldingEngine {
            registerCodeFoldingEngine(engine)
        }

        // Update folding state if code folding is enabled
        if configuration.display.enableCodeFolding {
            self.codeFoldingCoordinatorService.updateFoldingState(
                for: textView,
                configuration: configuration
            )
        }

        // Warm up caches with initial calculations
        let lineCount = (textView.text ?? "").components(separatedBy: .newlines).count
        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize)

        _ = gutterSizingService.calculateOptimalWidth(
            lineCount: lineCount,
            font: font,
            configuration: configuration
        )

        _ = lineNumberCalculationService.calculateVisibleLineRanges(
            for: textView,
            configuration: configuration
        )
    }

    /// Invalidates caches related to a specific text view
    public func invalidateCaches(for textView: CodeEditorView) {
        lineNumberCalculationService.invalidateCache(for: textView)
    }

    /// Invalidates caches related to a specific configuration
    public func invalidateCaches(for configuration: EditorConfiguration) {
        editorLayoutService.invalidateCache(for: configuration)
    }
}

// MARK: - Global Service Access

// MARK: - Dependency Injection Helper

/// Helper enum for creating configured service registries
@MainActor
public enum ServiceRegistryBuilder {
    /// Creates a default service registry with all services pre-configured
    /// - Parameter languageMetadataRegistry: Optional language metadata registry for DI
    public static func makeDefault(languageMetadataRegistry: LanguageMetadataRegistry? = nil) -> BusinessLogicServiceRegistry {
        BusinessLogicServiceRegistry(languageMetadataRegistry: languageMetadataRegistry)
    }

    /// Creates a minimal service registry with only essential services
    /// - Parameter languageMetadataRegistry: Optional language metadata registry for DI
    public static func makeMinimal(languageMetadataRegistry: LanguageMetadataRegistry? = nil) -> BusinessLogicServiceRegistry {
        BusinessLogicServiceRegistry(
            lineNumberCalculationService: LineNumberCalculationService(),
            textEditingService: TextEditingService(),
            languageMetadataRegistry: languageMetadataRegistry
        )
    }

    /// Creates a service registry for testing with mock services
    public static func makeForTesting(
        lineNumberCalculationService: LineNumberCalculationService? = nil,
        gutterSizingService: GutterSizingService? = nil,
        codeFoldingCoordinatorService: CodeFoldingCoordinatorService? = nil,
        editorLayoutService: EditorLayoutService? = nil,
        syntaxHighlightingService: SyntaxHighlightingService? = nil,
        languageDetectionService: LanguageDetectionService? = nil,
        textEditingService: TextEditingService? = nil,
        languageMetadataRegistry: LanguageMetadataRegistry? = nil
    ) -> BusinessLogicServiceRegistry {
        BusinessLogicServiceRegistry(
            lineNumberCalculationService: lineNumberCalculationService,
            gutterSizingService: gutterSizingService,
            codeFoldingCoordinatorService: codeFoldingCoordinatorService,
            editorLayoutService: editorLayoutService,
            syntaxHighlightingService: syntaxHighlightingService,
            languageDetectionService: languageDetectionService,
            textEditingService: textEditingService,
            languageMetadataRegistry: languageMetadataRegistry
        )
    }
}
