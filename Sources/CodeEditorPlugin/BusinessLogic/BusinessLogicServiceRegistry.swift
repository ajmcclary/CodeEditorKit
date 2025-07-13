import Foundation

// MARK: - Business Logic Service Registry

/// Centralized registry for all business logic services
/// Provides dependency injection and service lifecycle management
@MainActor
public final class BusinessLogicServiceRegistry {
    // MARK: - Singleton
    
    public static let shared = BusinessLogicServiceRegistry()
    
    // MARK: - Services
    
    private var _lineNumberCalculationService: LineNumberCalculationService?
    private var _gutterSizingService: GutterSizingService?
    private var _codeFoldingCoordinatorService: CodeFoldingCoordinatorService?
    private var _editorLayoutService: EditorLayoutService?
    
    // Service dependencies
    private weak var codeFoldingEngine: CodeFoldingEngine?
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
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
    }
    
    /// Resets all services (useful for testing)
    public func resetAllServices() {
        _lineNumberCalculationService = nil
        _gutterSizingService = nil
        _codeFoldingCoordinatorService = nil
        _editorLayoutService = nil
        codeFoldingEngine = nil
    }
    
    /// Gets service status for debugging
    public func getServiceStatus() -> [String: Bool] {
        [
            "lineNumberCalculationService": _lineNumberCalculationService != nil,
            "gutterSizingService": _gutterSizingService != nil,
            "codeFoldingCoordinatorService": _codeFoldingCoordinatorService != nil,
            "editorLayoutService": _editorLayoutService != nil,
            "codeFoldingEngine": codeFoldingEngine != nil
        ]
    }
}

// MARK: - Service Protocol Extensions

/// Protocol for services that support cache management
@MainActor
public protocol CacheableService {
    func clearCache()
}

/// Protocol for services that support state persistence
@MainActor
public protocol PersistentService {
    func saveState() -> [String: Any]
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

/// Global convenience accessor for business logic services
@MainActor
public enum BusinessLogic {
    public static var services: BusinessLogicServiceRegistry {
        BusinessLogicServiceRegistry.shared
    }
    
    public static var lineNumbers: LineNumberCalculationService {
        services.lineNumberCalculationService
    }
    
    public static var gutterSizing: GutterSizingService {
        services.gutterSizingService
    }
    
    public static var codeFolding: CodeFoldingCoordinatorService {
        services.codeFoldingCoordinatorService
    }
    
    public static var layout: EditorLayoutService {
        services.editorLayoutService
    }
}
