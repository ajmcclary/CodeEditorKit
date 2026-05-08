import Foundation

/// Central coordinator for managing specialized actors across the editor
///
/// This coordinator provides a unified interface for accessing specialized actors
/// and ensures proper lifecycle management and dependency injection.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public final class ActorCoordinator {
    // MARK: - Actors

    /// Text processing actor for text manipulation operations.
    ///
    /// Handles background text processing tasks like formatting, validation,
    /// and other computationally intensive text operations.
    public let textProcessor: TextProcessingActor

    /// Cache coordinator for managing all caches
    public let cacheCoordinator: CacheCoordinatorActor

    /// File system actor for file operations
    public let fileSystem: FileSystemActor

    /// Performance metrics actor for tracking performance
    public let performanceMetrics: PerformanceMetricsActor

    /// Document state actor for managing document lifecycle
    public let documentState: DocumentStateActor

    /// Error recovery coordinator for handling errors
    public let errorRecovery: ErrorRecoveryCoordinator

    // MARK: - Initialization

    /// Creates a new actor coordinator with all specialized actors.
    ///
    /// This initializer creates instances of all specialized actors needed
    /// for editor operations. Each actor is isolated and thread-safe.
    ///
    /// ## Actors Created
    ///
    /// - ``TextProcessingActor``: For text manipulation operations
    /// - ``CacheCoordinatorActor``: For managing all caches
    /// - ``FileSystemActor``: For file operations
    /// - ``PerformanceMetricsActor``: For tracking performance
    /// - ``DocumentStateActor``: For document lifecycle management
    /// - ``ErrorRecoveryCoordinator``: For error handling
    public init() {
        self.textProcessor = TextProcessingActor()
        self.cacheCoordinator = CacheCoordinatorActor()
        self.fileSystem = FileSystemActor()
        self.performanceMetrics = PerformanceMetricsActor()
        self.documentState = DocumentStateActor()
        self.errorRecovery = ErrorRecoveryCoordinator()
    }

    // MARK: - Convenience Methods

    /// Process text with automatic error recovery
    public func processText(
        _ text: String,
        processorType: TextProcessingActor.TextProcessor.ProcessorType,
        priority: TaskPriority = .high
    ) async throws -> String {
        do {
            return try await textProcessor.process(
                text: text,
                with: processorType,
                priority: priority
            )
        } catch {
            // Convert to recoverable error if needed
            if let recoverableError = error as? any RecoverableAsyncError {
                return try await errorRecovery.recover(from: recoverableError) {
                    try await self.textProcessor.process(
                        text: text,
                        with: processorType,
                        priority: priority
                    )
                }
            }
            throw error
        }
    }

    /// Track performance metric with automatic aggregation
    public func trackPerformance(
        name: String,
        duration: Duration,
        metadata: [String: String] = [:]
    ) async {
        let metric = SendablePerformanceMetric(
            name: name,
            duration: duration,
            metadata: metadata
        )
        await performanceMetrics.record(metric)
    }

    /// Create or update a document with state tracking
    @discardableResult
    public func createOrUpdateDocument(
        content: String,
        url: URL? = nil,
        language: Language = .plainText
    ) async -> UUID {
        if let url, let existingDoc = await documentState.getDocument(at: url) {
            // Update existing document
            await documentState.updateContent(for: existingDoc.id, content: content)
            return existingDoc.id
        } else {
            // Create new document
            return await documentState.createDocument(
                content: content,
                url: url,
                language: language
            )
        }
    }
}

// MARK: - Factory for creating ActorCoordinator instances

extension ActorCoordinator {
    /// Creates a new ActorCoordinator instance
    /// Use this instead of the deprecated singleton
    public static func create() -> ActorCoordinator {
        ActorCoordinator()
    }
}

// MARK: - Integration with CodeEditorView

extension CodeEditorView {
    /// Access the actor coordinator for this editor instance
    /// Creates a new instance if not provided in configuration
    @available(macOS 13.0, iOS 16.0, *)
    public var actorCoordinator: ActorCoordinator {
        if let coordinator = configuration.actorCoordinator {
            return coordinator
        }
        // Create and store a new coordinator
        let newCoordinator = ActorCoordinator.create()
        configuration.actorCoordinator = newCoordinator
        return newCoordinator
    }

    /// Process text using the integrated actor system
    public func processText(
        with processorType: TextProcessingActor.TextProcessor.ProcessorType,
        priority: TaskPriority = .high
    ) async throws {
        #if canImport(AppKit)
        let currentText = string
        #else
        let currentText = text ?? ""
        #endif

        let processedText = try await actorCoordinator.processText(
            currentText,
            processorType: processorType,
            priority: priority
        )

        // Update text on main actor
        #if canImport(AppKit)
        string = processedText
        #else
        text = processedText
        #endif
    }
}

// MARK: - Cache Integration

/// Extension to make SmartTokenCache work with CacheCoordinatorActor
extension SmartTokenCache: CacheProtocol {
    public typealias Value = [HighlightedToken]

    // swiftlint:disable:next discouraged_optional_collection
    public func getValue(for key: String) async -> [HighlightedToken]? {
        // Convert string key to CacheKey
        guard let cacheKey = CacheKey(fromString: key) else { return nil }
        let tokens = getCachedTokens(for: cacheKey)
        return tokens.isEmpty ? nil : tokens
    }

    public func setValue(_ value: [HighlightedToken], for key: String, cost _: Int) async {
        guard let cacheKey = CacheKey(fromString: key) else { return }
        setCachedTokens(value, for: cacheKey, computationTime: .zero)
    }

    public func contains(key: String) async -> Bool {
        guard let cacheKey = CacheKey(fromString: key) else { return false }
        let tokens = getCachedTokens(for: cacheKey)
        return !tokens.isEmpty
    }

    public func clear() async {
        clearCache()
    }
}

extension SmartTokenCache.CacheKey {
    /// Create cache key from string representation
    init?(fromString string: String) {
        // Simple parsing - in production would be more robust
        let components = string.split(separator: "|")
        guard components.count >= 2 else { return nil }

        // Create a dummy text to generate the cache key
        let dummyText = String(components[0])
        self.init(
            text: dummyText,
            language: Language(rawValue: String(components[1])) ?? .plainText,
            version: components.count > 2 ? Int(components[2]) ?? 0 : 0
        )
    }

    /// Convert cache key to string representation
    var stringRepresentation: String {
        "\(textHash)|\(language.rawValue)|\(version)"
    }
}
