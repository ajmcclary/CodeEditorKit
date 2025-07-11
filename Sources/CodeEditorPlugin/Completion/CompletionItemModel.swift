import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Errors

/// Errors that can occur during completion request operations
public enum CompletionRequestError: Error {
    case noActiveRequest
}

// MARK: - Completion Item Model

/// Represents a code completion item with comprehensive metadata.
///
/// `CompletionItemModel` encapsulates all information needed to display and insert
/// a code completion suggestion. It supports advanced features like snippets,
/// text edits, and documentation.
///
/// ## Example
///
/// ```swift
/// let completion = CompletionItemModel(
///     label: "forEach",
///     insertText: "forEach { <#element#> in\n    <#code#>\n}",
///     kind: .method,
///     detail: "(body: (Element) -> Void) -> Void",
///     documentation: "Calls the given closure on each element in the sequence.",
///     snippetSupport: true,
///     priority: 100
/// )
/// ```
///
/// - SeeAlso: ``CompletionItemKind``, ``CompletionProvider``, ``CompletionManager``
public struct CompletionItemModel: Identifiable, Sendable {
    public let id: String

    // Core completion data
    public let label: String
    public let insertText: String
    public let kind: CompletionItemKind
    public let detail: String?
    public let documentation: String?

    // Advanced features
    public let sortText: String?
    public let filterText: String?
    public let priority: Int
    public let snippetSupport: Bool

    // Visual presentation
    public let deprecated: Bool
    public let preselect: Bool

    // Text editing
    public let textEdit: CompletionTextEdit?
    public let additionalTextEdits: [CompletionTextEdit]

    public init(
        label: String,
        insertText: String? = nil,
        kind: CompletionItemKind = .text,
        detail: String? = nil,
        documentation: String? = nil,
        sortText: String? = nil,
        filterText: String? = nil,
        priority: Int = 0,
        snippetSupport: Bool = false,
        deprecated: Bool = false,
        preselect: Bool = false,
        textEdit: CompletionTextEdit? = nil,
        additionalTextEdits: [CompletionTextEdit] = [],
        id: String? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.label = label
        self.insertText = insertText ?? label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.sortText = sortText
        self.filterText = filterText
        self.priority = priority
        self.snippetSupport = snippetSupport
        self.deprecated = deprecated
        self.preselect = preselect
        self.textEdit = textEdit
        self.additionalTextEdits = additionalTextEdits
    }
}

// MARK: - Completion Kind

/// Types of completion items, compatible with LSP.
///
/// Each kind represents a different type of code element and affects how the
/// completion is displayed (icon) and sorted (priority).
///
/// ## Icons and Priority
///
/// Each kind has an associated icon for visual representation and a default
/// priority that affects sorting in the completion list.
///
/// - SeeAlso: ``CompletionItemModel``, ``CompletionProvider``
public enum CompletionItemKind: String, CaseIterable, Sendable {
    case text = "Text"
    case method = "Method"
    case function = "Function"
    case constructor = "Constructor"
    case field = "Field"
    case variable = "Variable"
    case `class` = "Class"
    case interface = "Interface"
    case module = "Module"
    case property = "Property"
    case unit = "Unit"
    case value = "Value"
    case `enum` = "Enum"
    case keyword = "Keyword"
    case snippet = "Snippet"
    case color = "Color"
    case file = "File"
    case reference = "Reference"
    case folder = "Folder"
    case enumMember = "EnumMember"
    case constant = "Constant"
    case `struct` = "Struct"
    case event = "Event"
    case `operator` = "Operator"
    case typeParameter = "TypeParameter"

    /// Icon character for visual representation
    public var icon: String {
        switch self {
        case .text: return "𝘛"
        case .method: return "𝘮"
        case .function: return "𝑓"
        case .constructor: return "𝘤"
        case .field: return "𝘍"
        case .variable: return "𝘷"
        case .class: return "𝘊"
        case .interface: return "𝘐"
        case .module: return "𝘔"
        case .property: return "𝘱"
        case .unit: return "𝘜"
        case .value: return "𝘝"
        case .enum: return "𝘌"
        case .keyword: return "𝘬"
        case .snippet: return "𝘚"
        case .color: return "🎨"
        case .file: return "📄"
        case .reference: return "🔗"
        case .folder: return "📁"
        case .enumMember: return "𝘦"
        case .constant: return "𝘊"
        case .struct: return "𝘴"
        case .event: return "⚡"
        case .operator: return "⊕"
        case .typeParameter: return "𝘛"
        }
    }

    /// Priority for sorting (higher is better)
    public var defaultPriority: Int {
        switch self {
        case .keyword: return 100
        case .snippet: return 90
        case .method, .function: return 80
        case .property, .field: return 70
        case .variable: return 60
        case .class, .struct, .enum: return 50
        case .constant: return 40
        case .interface: return 30
        case .module: return 20
        default: return 10
        }
    }
}

// MARK: - Text Edit

/// Represents a text edit for completion insertion.
///
/// Defines how text should be modified when a completion is accepted.
/// Supports replacing existing text ranges, not just insertion at cursor.
///
/// ## Example
///
/// ```swift
/// // Replace "pri" with "private"
/// let edit = CompletionTextEdit(
///     range: NSRange(location: 10, length: 3),
///     newText: "private"
/// )
/// ```
///
/// - SeeAlso: ``CompletionItemModel``
public struct CompletionTextEdit: Sendable {
    public let range: NSRange
    public let newText: String

    public init(range: NSRange, newText: String) {
        self.range = range
        self.newText = newText
    }
}

// MARK: - Completion Context

/// Context information for code completion requests.
///
/// Provides all necessary information about the editor state when completion
/// was triggered, including cursor position, surrounding text, and trigger type.
///
/// ## Example
///
/// ```swift
/// let context = CompletionContextModel(
///     text: "let name = user.",
///     cursorPosition: 16,
///     language: .swift,
///     triggerKind: .character,
///     triggerCharacter: ".",
///     lineText: "let name = user.",
///     wordRange: NSRange(location: 11, length: 4)
/// )
/// ```
///
/// - SeeAlso: ``CompletionTriggerKind``, ``CompletionProvider``
public struct CompletionContextModel: Sendable {
    public let text: String
    public let cursorPosition: Int
    public let language: Language
    public let triggerKind: CompletionTriggerKind
    public let triggerCharacter: String?
    public let lineText: String
    public let wordRange: NSRange?
    public let timestamp: Date

    public init(
        text: String,
        cursorPosition: Int,
        language: Language,
        triggerKind: CompletionTriggerKind = .manual,
        triggerCharacter: String? = nil,
        lineText: String = "",
        wordRange: NSRange? = nil
    ) {
        self.text = text
        self.cursorPosition = cursorPosition
        self.language = language
        self.triggerKind = triggerKind
        self.triggerCharacter = triggerCharacter
        self.lineText = lineText
        self.wordRange = wordRange
        self.timestamp = Date()
    }

    /// Get the current word being typed
    public var currentWord: String {
        guard let wordRange,
              wordRange.location != NSNotFound,
              wordRange.location + wordRange.length <= text.count else {
            return ""
        }

        let startIndex = text.index(text.startIndex, offsetBy: wordRange.location)
        let endIndex = text.index(startIndex, offsetBy: wordRange.length)
        return String(text[startIndex..<endIndex])
    }
}

// MARK: - Completion Trigger Kind

/// How completion was triggered.
///
/// Indicates whether the user explicitly requested completion or it was
/// triggered automatically by typing certain characters.
///
/// - SeeAlso: ``CompletionContextModel``
public enum CompletionTriggerKind: String, Sendable {
    case manual = "Manual"              // User explicitly requested (Ctrl+Space)
    case character = "Character"        // Triggered by typing a character
    case retrigger = "Retrigger"       // Re-triggered for filtered results
}

// MARK: - Completion Result

/// Result of a completion request.
///
/// Contains the completion items along with metadata about the request,
/// including whether more results are available and processing time.
///
/// ## Example
///
/// ```swift
/// let result = CompletionResult(
///     items: completionItems,
///     context: context,
///     isIncomplete: hasMoreResults,
///     processingTime: 0.05
/// )
/// ```
///
/// - SeeAlso: ``CompletionItemModel``, ``CompletionProvider``
public struct CompletionResult: Sendable {
    public let items: [CompletionItemModel]
    public let isIncomplete: Bool
    public let context: CompletionContextModel
    public let processingTime: TimeInterval

    public init(
        items: [CompletionItemModel],
        context: CompletionContextModel,
        isIncomplete: Bool = false,
        processingTime: TimeInterval = 0
    ) {
        self.items = items
        self.isIncomplete = isIncomplete
        self.context = context
        self.processingTime = processingTime
    }
}

// MARK: - Completion Provider Protocol

/// Protocol for providing code completions.
///
/// Implement this protocol to create custom completion providers that can
/// suggest code completions for specific languages or contexts.
///
/// ## Implementing a Provider
///
/// ```swift
/// @MainActor
/// final class SwiftCompletionProvider: CompletionProvider {
///     let id = "swift-provider"
///     let supportedLanguages: [Language] = [.swift]
///     let triggerCharacters = [".", "(", "[", "<"]
///     let supportsSnippets = true
///     
///     func completions(for context: CompletionContextModel) async throws -> CompletionResult {
///         // Analyze context and generate completions
///         let items = generateCompletions(context)
///         return CompletionResult(items: items, context: context)
///     }
/// }
/// ```
///
/// ## Registration
///
/// ```swift
/// let manager = CompletionManager()
/// manager.registerProvider(SwiftCompletionProvider())
/// ```
///
/// - SeeAlso: ``CompletionManager``, ``CompletionContextModel``, ``CompletionResult``
@MainActor
public protocol CompletionProvider: Sendable {
    /// Provider identifier
    var id: String { get }

    /// Supported languages
    var supportedLanguages: [Language] { get }

    /// Characters that trigger completion
    var triggerCharacters: [String] { get }

    /// Whether this provider supports snippets
    var supportsSnippets: Bool { get }

    /// Provide completions for the given context
    func completions(for context: CompletionContextModel) async throws -> CompletionResult

    /// Resolve additional details for a completion item (optional)
    func resolve(item: CompletionItemModel) async throws -> CompletionItemModel
}

extension CompletionProvider {
    public var supportsSnippets: Bool { false }

    public func resolve(item: CompletionItemModel) async throws -> CompletionItemModel {
        item // Default: no additional resolution
    }
}

/// Manages multiple completion providers and coordinates completion requests.
///
/// `CompletionManager` is the central coordinator for code completion in the editor.
/// It manages multiple providers, handles caching, debouncing, and aggregates results
/// from different sources.
///
/// ## Features
///
/// - **Multiple Providers**: Register different providers for different languages
/// - **Caching**: LRU cache for recent completions to improve performance
/// - **Debouncing**: Prevents excessive requests while typing
/// - **Statistics**: Track performance and cache hit rates
/// - **Memory Management**: Automatic cleanup under memory pressure
///
/// ## Basic Usage
///
/// ```swift
/// let manager = CompletionManager()
/// 
/// // Register providers
/// manager.registerProvider(SwiftCompletionProvider())
/// manager.registerProvider(LSPCompletionProvider())
/// 
/// // Request completions
/// let context = CompletionContextModel(...)
/// let result = try await manager.requestCompletions(for: context)
/// 
/// // Or with debouncing
/// manager.requestCompletionsDebounced(for: context) { result in
///     switch result {
///     case .success(let completions):
///         // Show completions
///     case .failure(let error):
///         // Handle error
///     }
/// }
/// ```
///
/// ## Performance
///
/// The manager includes several optimizations:
/// - Concurrent requests to multiple providers
/// - Result deduplication and smart sorting
/// - Configurable caching with expiration
/// - Debouncing to reduce request frequency
///
/// - SeeAlso: ``CompletionProvider``, ``CompletionDebouncer``, ``CompletionStatistics``
@MainActor
public final class CompletionManager {
    private var providers: [String: any CompletionProvider] = [:]
    private var currentRequest: Task<CompletionResult, Error>?
    private let cache: LRUCache<CompletionCacheKey, CachedCompletionResult>
    private let cacheExpirationTime: TimeInterval
    private let enableCaching: Bool
    private let debouncer: CompletionDebouncer
    private let memoryMonitor: MemoryMonitor

    /// Completion request statistics
    public private(set) var statistics = CompletionStatistics()

    public init(
        memoryMonitor: MemoryMonitor,
        cacheSize: Int = 100,
        cacheExpirationTime: TimeInterval = 300, // 5 minutes
        enableCaching: Bool = true,
        debouncer: CompletionDebouncer? = nil
    ) {
        self.memoryMonitor = memoryMonitor
        self.cache = LRUCache(capacity: cacheSize, memoryMonitor: memoryMonitor)
        self.cacheExpirationTime = cacheExpirationTime
        self.enableCaching = enableCaching
        self.debouncer = debouncer ?? CompletionDebouncer()

        // Wire up the debouncer to use this manager's completion logic
        self.debouncer.setCompletionHandler { [weak self] context in
            guard let self else {
                throw CompletionDebouncingError.cancelled
            }
            return try await self.requestCompletions(for: context)
        }

        // Register with memory monitor
        registerWithMemoryMonitor()
    }

    // MARK: - Provider Management

    /// Register a completion provider
    public func registerProvider(_ provider: any CompletionProvider) {
        providers[provider.id] = provider
    }

    /// Unregister a completion provider
    public func unregisterProvider(withId id: String) {
        providers.removeValue(forKey: id)
    }

    /// Get all registered providers
    public var registeredProviders: [any CompletionProvider] {
        Array(providers.values)
    }

    /// Clear the completion cache
    public func clearCache() {
        cache.removeAll()
        statistics.resetCacheStats()
    }

    /// Get cache statistics
    public var cacheStatistics: CacheStatistics {
        cache.statistics
    }

    // MARK: - Completion Requests

    /// Request completions for the given context
    public func requestCompletions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Cancel any existing request
        currentRequest?.cancel()

        // Check cache first if enabled
        if enableCaching {
            let cacheKey = CompletionCacheKey(context: context)
            if let cachedResult = cache.get(cacheKey), !cachedResult.isExpired {
                statistics.recordCacheHit()
                return cachedResult.result
            }
            statistics.recordCacheMiss()
        }

        // Create new request
        currentRequest = Task {
            let startTime = Date()

            // Find applicable providers
            let applicableProviders = providers.values.filter { provider in
                provider.supportedLanguages.contains(context.language) ||
                provider.supportedLanguages.isEmpty
            }

            guard !applicableProviders.isEmpty else {
                let result = CompletionResult(
                    items: [],
                    context: context,
                    isIncomplete: false,
                    processingTime: 0
                )
                statistics.recordRequest(processingTime: 0)
                return result
            }

            // Request from all applicable providers concurrently
            let results = await withTaskGroup(of: CompletionResult?.self) { group in
                for provider in applicableProviders {
                    _ = provider.id // Capture the id on the main actor
                    group.addTask {
                        do {
                            return try await provider.completions(for: context)
                        } catch {
                            // Log error but don't fail the entire request
                            // Log error but don't fail the entire request
                            return nil
                        }
                    }
                }

                var allResults: [CompletionResult] = []
                for await result in group {
                    if let result {
                        allResults.append(result)
                    }
                }
                return allResults
            }

            // Combine results
            let allItems = results.flatMap { $0.items }
            let isIncomplete = results.contains { $0.isIncomplete }
            let processingTime = Date().timeIntervalSince(startTime)

            // Sort and deduplicate items
            let sortedItems = sortAndDeduplicateItems(allItems)

            let result = CompletionResult(
                items: sortedItems,
                context: context,
                isIncomplete: isIncomplete,
                processingTime: processingTime
            )

            // Cache the result if enabled and not incomplete
            if enableCaching && !isIncomplete && !sortedItems.isEmpty {
                let cacheKey = CompletionCacheKey(context: context)
                let cachedResult = CachedCompletionResult(result: result, expirationTime: cacheExpirationTime)
                cache.set(cachedResult, forKey: cacheKey)
            }

            statistics.recordRequest(processingTime: processingTime)
            return result
        }

        guard let request = currentRequest else {
            throw CompletionRequestError.noActiveRequest
        }
        return try await request.value
    }

    /// Request completions with debouncing and throttling
    /// - Parameters:
    ///   - context: The completion context
    ///   - priority: Request priority (default: normal)
    ///   - completion: Completion handler
    public func requestCompletionsDebounced(
        for context: CompletionContextModel,
        priority: CompletionPriority = .normal,
        completion: @escaping @Sendable (Result<CompletionResult, Error>) -> Void
    ) {
        debouncer.requestCompletions(
            for: context,
            priority: priority
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let completionResult):
                    completion(.success(completionResult))

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Cancel any pending completion request
    public func cancelCurrentRequest() {
        currentRequest?.cancel()
        currentRequest = nil
        debouncer.cancelAllRequests()
    }

    /// Access to the debouncer for configuration
    public var debouncingConfiguration: CompletionDebouncer {
        debouncer
    }

    // MARK: - Private Methods

    private func sortAndDeduplicateItems(_ items: [CompletionItemModel]) -> [CompletionItemModel] {
        // Remove duplicates based on label and kind
        var seen = Set<String>()
        let unique = items.filter { item in
            let key = "\(item.label):\(item.kind.rawValue)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        // Sort by priority (desc), then by label (asc)
        return unique.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            if lhs.kind.defaultPriority != rhs.kind.defaultPriority {
                return lhs.kind.defaultPriority > rhs.kind.defaultPriority
            }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            self.memoryMonitor.registerCleanupHandler(
                identifier: "completion-manager",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "CompletionManager deallocated")
                }

                // Clear completion cache
                let beforeCacheSize = self.cache.count
                self.cache.removeAll()

                // Cancel pending requests
                self.cancelCurrentRequest()

                // Reset statistics
                self.statistics.reset()

                // Estimate memory freed
                let estimatedMemoryMB = Double(beforeCacheSize) * 0.005 // 5KB per cached item estimate

                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Cleared \(beforeCacheSize) completion cache items"
                )
            }
        }
    }
}

/// Statistics for completion requests and cache performance.
///
/// Tracks metrics about completion system performance including request counts,
/// cache hit rates, and processing times. Useful for monitoring and optimization.
///
/// ## Example
///
/// ```swift
/// let stats = manager.statistics
/// logger.debug("Total requests: \(stats.totalRequests)")
/// logger.debug("Cache hit rate: \(stats.cacheHitRate * 100)%")
/// logger.debug("Avg processing time: \(stats.averageProcessingTime)s")
/// ```
///
/// - SeeAlso: ``CompletionManager``
@MainActor
public final class CompletionStatistics {
    public private(set) var totalRequests: Int = 0
    public private(set) var totalCacheHits: Int = 0
    public private(set) var totalCacheMisses: Int = 0
    public private(set) var averageProcessingTime: TimeInterval = 0
    public private(set) var lastRequestTime: Date?

    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimeSamples = 100

    public var cacheHitRate: Double {
        let totalCacheRequests = totalCacheHits + totalCacheMisses
        return totalCacheRequests > 0 ? Double(totalCacheHits) / Double(totalCacheRequests) : 0
    }

    internal func recordRequest(processingTime: TimeInterval) {
        totalRequests += 1
        lastRequestTime = Date()

        // Update processing time statistics
        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingTimeSamples {
            processingTimes.removeFirst()
        }

        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }

    internal func recordCacheHit() {
        totalCacheHits += 1
    }

    internal func recordCacheMiss() {
        totalCacheMisses += 1
    }

    internal func resetCacheStats() {
        totalCacheHits = 0
        totalCacheMisses = 0
    }

    public func reset() {
        totalRequests = 0
        totalCacheHits = 0
        totalCacheMisses = 0
        averageProcessingTime = 0
        lastRequestTime = nil
        processingTimes.removeAll()
    }
}

/// Internal adapter for bridging CompletionItemModel to CompletionItem protocol
@MainActor
internal struct CompletionItemAdapter: CompletionItem {
    let id: String
    let model: CompletionItemModel

    init(_ model: CompletionItemModel) {
        self.id = model.id
        self.model = model
    }

    var view: PlatformView {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let view = NSView()
        view.wantsLayer = true
        return view
        #else
        return UIView()
        #endif
    }
}
