import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Completion Errors

public enum CompletionError: Error {
    case engineUnavailable
    case contextInvalid
    case providerFailed(Error)
}

// MARK: - SmartCompletionEngine

/// Intelligent completion engine with caching, learning, and adaptive suggestions
@MainActor
public final class SmartCompletionEngine: ObservableObject {
    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "SmartCompletion")

    /// Memory monitor for managing cache memory
    private let memoryMonitor: MemoryMonitor

    /// Result cache for fast repeated completions
    private let resultCache: LRUCache<CompletionCacheKey, CachedCompletionResult>

    /// Frequency cache for learning user patterns
    private let frequencyCache: LRUCache<String, CompletionFrequency>

    /// Recent selections for context-aware suggestions
    private let recentSelections: LRUCache<String, CompletionSelection>

    /// Active completion providers
    private var providers: [String: any CompletionProvider] = [:]

    /// Machine learning model for ranking (placeholder for future ML integration)
    private let rankingModel = CompletionRankingModel()

    /// Performance metrics
    @Published public private(set) var metrics = CompletionMetrics()

    /// Current completion session
    private var currentSession: CompletionSession?

    /// Debouncer for completion requests
    private let completionDebouncer = CompletionDebouncer()

    /// Settings
    public var settings = SmartCompletionSettings()

    /// Fuzzy matcher for intelligent completion matching
    private let fuzzyMatcher = FuzzyMatcher()

    // MARK: - Initialization

    public init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
        self.resultCache = LRUCache<CompletionCacheKey, CachedCompletionResult>(capacity: 100, memoryMonitor: memoryMonitor)
        self.frequencyCache = LRUCache<String, CompletionFrequency>(capacity: 500, memoryMonitor: memoryMonitor)
        self.recentSelections = LRUCache<String, CompletionSelection>(capacity: 50, memoryMonitor: memoryMonitor)
        setupDefaultProviders()
        loadUserPatterns()
        setupCompletionDebouncer()
    }

    // MARK: - Public Methods

    /// Request completions for the given context
    public func requestCompletions(
        for context: CompletionContextModel,
        completion: @escaping @Sendable (CompletionResult) -> Void
    ) {
        // Start a new session
        let session = CompletionSession(id: UUID(), context: context)
        currentSession = session

        // Check cache first
        let cacheKey = CompletionCacheKey(context: context)
        if let cached = resultCache.get(cacheKey), !cached.isExpired {
            logger.debug("Cache hit for completion request")
            metrics.cacheHits += 1

            // Re-rank based on recent usage
            let rerankedResult = rerank(cached.result, for: context)
            completion(rerankedResult)
            return
        }

        metrics.cacheMisses += 1

        // Debounce the request
        completionDebouncer.requestCompletions(for: context) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let completionResult):
                    completion(completionResult)

                case .failure:
                    // If debouncer fails, perform completion directly
                    if let self {
                        await self.performCompletion(session: session, context: context, completion: completion)
                    } else {
                        // Engine was deallocated, return empty result
                        completion(CompletionResult(
                            items: [],
                            context: context,
                            isIncomplete: false,
                            processingTime: 0
                        ))
                    }
                }
            }
        }
    }

    /// Register a completion provider
    public func registerProvider(_ provider: any CompletionProvider, for language: String) {
        providers[language] = provider
        logger.info("Registered completion provider for \(language)")
    }

    /// Record a completion selection for learning
    public func recordSelection(_ item: CompletionItemModel, context: CompletionContextModel) {
        // Update frequency data
        let key = "\(context.language.identifier):\(item.label)"
        var frequency = frequencyCache.get(key) ?? CompletionFrequency(identifier: key)
        frequency.incrementUsage()
        frequencyCache.set(frequency, forKey: key)

        // Record recent selection
        let selection = CompletionSelection(
            item: item,
            context: context,
            timestamp: Date()
        )
        recentSelections.set(selection, forKey: item.insertText)

        // Update metrics
        metrics.totalSelections += 1

        // Save patterns periodically
        if metrics.totalSelections.isMultiple(of: 10) {
            saveUserPatterns()
        }
    }

    /// Get smart suggestions based on context and history
    public func getSmartSuggestions(for context: CompletionContextModel) async -> [CompletionItemModel] {
        var suggestions: [CompletionItemModel] = []

        // Get recent selections that match the context
        let recentItems = getRecentlyUsedCompletions(for: context)
        suggestions.append(contentsOf: recentItems)

        // Get frequently used items
        let frequentItems = getFrequentlyUsedCompletions(for: context)
        suggestions.append(contentsOf: frequentItems)

        // Get pattern-based suggestions
        let patternItems = await getPatternBasedSuggestions(for: context)
        suggestions.append(contentsOf: patternItems)

        // Remove duplicates and limit (can't use Set with CompletionItemModel)
        let uniqueSuggestions = removeDuplicates(from: suggestions).prefix(settings.maxSmartSuggestions)

        return Array(uniqueSuggestions)
    }

    /// Clear all caches and learned data
    public func clearAllData() {
        resultCache.removeAll()
        frequencyCache.removeAll()
        recentSelections.removeAll()
        metrics = CompletionMetrics()
        logger.info("Cleared all completion data")
    }

    // MARK: - Private Methods

    private func setupCompletionDebouncer() {
        completionDebouncer.setCompletionHandler { [weak self] context in
            guard let self else {
                throw CompletionError.engineUnavailable
            }

            // Create a session for this debounced request
            let session = CompletionSession(id: UUID(), context: context)

            return try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    await self.performCompletion(session: session, context: context) { result in
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }

    private func setupDefaultProviders() {
        for language in LanguageProviderFactory.supportedLanguages.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let provider = LanguageProviderFactory.createProvider(for: language) else {
                continue
            }
            registerProvider(provider, for: language.identifier)
        }

        // Register LSP provider as fallback
        // Note: LSPCompletionProvider requires an LSPManager instance
        // This will need to be injected or created elsewhere
        // For now, commenting out to fix compilation
        // let lspProvider = LSPCompletionProvider(lspManager: lspManager)
        // registerProvider(lspProvider, for: "default")
    }

    private func performCompletion(
        session: CompletionSession,
        context: CompletionContextModel,
        completion: @escaping (CompletionResult) -> Void
    ) async {
        // Check if session is still current
        guard currentSession?.id == session.id else {
            logger.debug("Completion session cancelled")
            // Always call completion to avoid hanging
            completion(CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            ))
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Get provider for language
        let provider = providers[context.language.identifier] ?? providers["default"]

        guard let provider else {
            completion(CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            ))
            return
        }

        do {
            // Get completions from provider
            let providerResult = try await provider.completions(for: context)
            let items = providerResult.items

            // Get smart suggestions
            let smartSuggestions = await getSmartSuggestions(for: context)

            // Combine and rank all items
            let allItems = combineAndRank(
                providerItems: items,
                smartSuggestions: smartSuggestions,
                context: context
            )

            // Create result
            let result = CompletionResult(
                items: allItems,
                context: context,
                isIncomplete: items.count >= settings.maxCompletions,
                processingTime: Date().timeIntervalSince(context.timestamp)
            )

            // Cache the result
            let cacheKey = CompletionCacheKey(context: context)
            let cachedResult = CachedCompletionResult(
                result: result,
                expirationTime: settings.cacheExpirationTime
            )
            resultCache.set(cachedResult, forKey: cacheKey)

            // Update metrics
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            metrics.averageCompletionTime = (metrics.averageCompletionTime * Double(metrics.totalRequests) + duration) / Double(metrics.totalRequests + 1)
            metrics.totalRequests += 1

            // Return result
            completion(result)
        } catch {
            logger.error("Completion failed: \(error)")
            completion(CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            ))
        }
    }

    private func combineAndRank(
        providerItems: [CompletionItemModel],
        smartSuggestions: [CompletionItemModel],
        context: CompletionContextModel
    ) -> [CompletionItemModel] {
        var allItems = providerItems

        // Add smart suggestions with boost
        for suggestion in smartSuggestions {
            allItems.append(suggestion)
        }

        // Apply fuzzy matching if there's a current word to match
        let filteredItems: [CompletionItemModel]
        if !context.currentWord.isEmpty {
            filteredItems = applyFuzzyMatching(to: allItems, pattern: context.currentWord)
        } else {
            filteredItems = allItems
        }

        // Remove duplicates
        let uniqueItems = removeDuplicates(from: filteredItems)

        // Rank using the model
        let rankedItems = rankingModel.rank(
            items: uniqueItems,
            context: context,
            frequencyData: getFrequencyData(for: context)
        )

        // Limit results
        return Array(rankedItems.prefix(settings.maxCompletions))
    }

    private func applyFuzzyMatching(to items: [CompletionItemModel], pattern: String) -> [CompletionItemModel] {
        // Extract labels for fuzzy matching
        let labels = items.map { $0.label }

        // Perform fuzzy matching
        let fuzzyResults = fuzzyMatcher.match(pattern: pattern, candidates: labels)

        // Create a mapping of labels to fuzzy scores
        var scoreMap: [String: Double] = [:]
        for result in fuzzyResults {
            scoreMap[result.item] = result.score
        }

        // Filter and sort items based on fuzzy scores
        let scoredItems = items.compactMap { item -> (item: CompletionItemModel, score: Double)? in
            guard let score = scoreMap[item.label] else { return nil }
            return (item, score)
        }

        // Sort by score descending

        return scoredItems
            .sorted { $0.score > $1.score }
            .map { $0.item }
    }

    private func removeDuplicates(from items: [CompletionItemModel]) -> [CompletionItemModel] {
        var seen = Set<String>()
        var unique: [CompletionItemModel] = []

        for item in items where !seen.contains(item.label) {
            seen.insert(item.label)
            unique.append(item)
        }

        return unique
    }

    private func rerank(_ result: CompletionResult, for context: CompletionContextModel) -> CompletionResult {
        let rerankedItems = rankingModel.rank(
            items: result.items,
            context: context,
            frequencyData: getFrequencyData(for: context)
        )

        return CompletionResult(
            items: rerankedItems,
            context: context,
            isIncomplete: result.isIncomplete
        )
    }

    private func getRecentlyUsedCompletions(for context: CompletionContextModel) -> [CompletionItemModel] {
        let prefix = context.currentWord.lowercased()
        var recentItems: [CompletionItemModel] = []

        for key in recentSelections.allKeys {
            if let selection = recentSelections.get(key),
               selection.item.label.lowercased().hasPrefix(prefix),
               selection.context.language == context.language {
                recentItems.append(selection.item)
            }
        }

        return Array(recentItems.prefix(5))
    }

    private func getFrequentlyUsedCompletions(for context: CompletionContextModel) -> [CompletionItemModel] {
        let prefix = context.currentWord.lowercased()
        var frequentItems: [(item: CompletionItemModel, frequency: Int)] = []

        for key in frequencyCache.allKeys {
            if let frequency = frequencyCache.get(key),
               key.hasPrefix("\(context.language.identifier):"),
               frequency.usageCount > settings.frequencyThreshold {
                let label = String(key.dropFirst(context.language.identifier.count + 1))
                if label.lowercased().hasPrefix(prefix) {
                    let item = CompletionItemModel(
                        label: label,
                        insertText: label,
                        kind: .variable,
                        detail: "Frequently used"
                    )
                    frequentItems.append((item, frequency.usageCount))
                }
            }
        }

        // Sort by frequency
        frequentItems.sort { $0.frequency > $1.frequency }

        return frequentItems.prefix(5).map { $0.item }
    }

    private func getPatternBasedSuggestions(for context: CompletionContextModel) async -> [CompletionItemModel] {
        // Use the pattern registry to generate suggestions
        kCodePatternRegistry.generateSuggestions(for: context)
    }

    private func getFrequencyData(for context: CompletionContextModel) -> [String: Int] {
        var frequencyData: [String: Int] = [:]

        for key in frequencyCache.allKeys {
            if let frequency = frequencyCache.get(key),
               key.hasPrefix("\(context.language.identifier):") {
                let label = String(key.dropFirst(context.language.identifier.count + 1))
                frequencyData[label] = frequency.usageCount
            }
        }

        return frequencyData
    }

    // MARK: - Persistence

    private func loadUserPatterns() {
        // Load saved frequency data and patterns
        // This would load from UserDefaults or a file
    }

    private func saveUserPatterns() {
        // Save frequency data and patterns
        // This would save to UserDefaults or a file
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Supporting Types

/// Completion session tracking
private struct CompletionSession {
    let id: UUID
    let context: CompletionContextModel
    let startTime = Date()
}

/// Frequency tracking for completions
public struct CompletionFrequency: Codable, Sendable {
    let identifier: String
    var usageCount: Int = 0
    var lastUsed = Date()

    mutating func incrementUsage() {
        usageCount += 1
        lastUsed = Date()
    }
}

/// Recent completion selection
public struct CompletionSelection: Sendable {
    let item: CompletionItemModel
    let context: CompletionContextModel
    let timestamp: Date
}

/// Smart completion settings
public struct SmartCompletionSettings {
    /// Maximum number of completions to show
    public var maxCompletions: Int = 50

    /// Maximum number of smart suggestions to provide
    public var maxSmartSuggestions: Int = 10

    /// Time before cached completions expire (in seconds)
    public var cacheExpirationTime: TimeInterval = 300 // 5 minutes

    /// Minimum frequency threshold for promoting suggestions
    public var frequencyThreshold: Int = 3

    /// Whether to enable machine learning features
    public var enableMachineLearning: Bool = true

    /// Whether to enable pattern analysis
    public var enablePatternAnalysis: Bool = true
}

/// Completion metrics
public struct CompletionMetrics {
    /// Total number of completion requests made
    public var totalRequests: Int = 0

    /// Total number of completions selected by user
    public var totalSelections: Int = 0

    /// Number of times cache provided results
    public var cacheHits: Int = 0

    /// Number of times cache was empty
    public var cacheMisses: Int = 0

    /// Average time to generate completions
    public var averageCompletionTime: TimeInterval = 0

    /// Percentage of requests served from cache
    public var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0
    }

    /// Percentage of completions that were selected
    public var selectionRate: Double {
        totalRequests > 0 ? Double(totalSelections) / Double(totalRequests) : 0
    }
}

// MARK: - Pattern Analysis

/// Shared pattern registry for code completion patterns
@MainActor
private let kCodePatternRegistry = CodePatternRegistry()
