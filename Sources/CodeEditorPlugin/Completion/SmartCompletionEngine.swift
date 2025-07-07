import Combine
import Foundation
import os.log

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

    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "SmartCompletion")
    
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
        // Register built-in providers
        let swiftProvider = SwiftCompletionProvider()
        registerProvider(swiftProvider, for: Language.swift.identifier)

        let pythonProvider = PythonCompletionProvider()
        registerProvider(pythonProvider, for: Language.python.identifier)

        let javascriptProvider = JavaScriptCompletionProvider()
        registerProvider(javascriptProvider, for: Language.javascript.identifier)

        let typescriptProvider = TypeScriptCompletionProvider()
        registerProvider(typescriptProvider, for: Language.typescript.identifier)

        let goProvider = GoCompletionProvider()
        registerProvider(goProvider, for: Language.go.identifier)

        let rustProvider = RustCompletionProvider()
        registerProvider(rustProvider, for: Language.rust.identifier)

        let cProvider = CCompletionProvider()
        registerProvider(cProvider, for: Language.c.identifier)
        registerProvider(cProvider, for: Language.cpp.identifier)

        let javaProvider = JavaCompletionProvider()
        registerProvider(javaProvider, for: Language.java.identifier)

        let htmlProvider = HTMLCompletionProvider()
        registerProvider(htmlProvider, for: Language.html.identifier)

        let cssProvider = CSSCompletionProvider()
        registerProvider(cssProvider, for: Language.css.identifier)

        let jsonProvider = JSONCompletionProvider()
        registerProvider(jsonProvider, for: Language.json.identifier)

        let yamlProvider = YAMLCompletionProvider()
        registerProvider(yamlProvider, for: Language.yaml.identifier)

        let xmlProvider = XMLCompletionProvider()
        registerProvider(xmlProvider, for: Language.xml.identifier)

        let sqlProvider = SQLCompletionProvider()
        registerProvider(sqlProvider, for: Language.sql.identifier)

        let rubyProvider = RubyCompletionProvider()
        registerProvider(rubyProvider, for: Language.ruby.identifier)

        let phpProvider = PHPCompletionProvider()
        registerProvider(phpProvider, for: Language.php.identifier)

        let shellProvider = ShellCompletionProvider()
        registerProvider(shellProvider, for: Language.shell.identifier)

        let markdownProvider = MarkdownCompletionProvider()
        registerProvider(markdownProvider, for: Language.markdown.identifier)

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
        // Analyze patterns in recent code
        let patterns = analyzeCodePatterns(context: context)

        // Generate suggestions based on patterns
        var suggestions: [CompletionItemModel] = []

        for pattern in patterns {
            if let suggestion = pattern.generateSuggestion(for: context) {
                suggestions.append(suggestion)
            }
        }

        return suggestions
    }

    private func analyzeCodePatterns(context: CompletionContextModel) -> [CodePattern] {
        // Simple pattern analysis - could be enhanced with ML
        var patterns: [CodePattern] = []

        // Method chaining pattern
        if context.lineText.contains(".") {
            patterns.append(MethodChainingPattern())
        }

        // Property access pattern
        if context.currentWord.hasPrefix(".") {
            patterns.append(PropertyAccessPattern())
        }

        // Function call pattern
        if context.lineText.contains("(") {
            patterns.append(FunctionCallPattern())
        }

        return patterns
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
    public var maxCompletions: Int = 50
    public var maxSmartSuggestions: Int = 10
    public var cacheExpirationTime: TimeInterval = 300 // 5 minutes
    public var frequencyThreshold: Int = 3
    public var enableMachineLearning: Bool = true
    public var enablePatternAnalysis: Bool = true
}

/// Completion metrics
public struct CompletionMetrics {
    public var totalRequests: Int = 0
    public var totalSelections: Int = 0
    public var cacheHits: Int = 0
    public var cacheMisses: Int = 0
    public var averageCompletionTime: TimeInterval = 0

    public var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0
    }

    public var selectionRate: Double {
        totalRequests > 0 ? Double(totalSelections) / Double(totalRequests) : 0
    }
}

// MARK: - Code Pattern Analysis

/// Protocol for code patterns
protocol CodePattern {
    func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel?
}

/// Method chaining pattern
struct MethodChainingPattern: CodePattern {
    func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel? {
        // Suggest common chaining methods
        if context.currentWord.isEmpty && context.lineText.hasSuffix(".") {
            return CompletionItemModel(
                label: "map",
                insertText: "map { <#code#> }",
                kind: .method,
                detail: "Transform elements"
            )
        }
        return nil
    }
}

/// Property access pattern
struct PropertyAccessPattern: CodePattern {
    func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel? {
        // Suggest common properties
        if context.currentWord.hasPrefix(".") {
            let propertyName = String(context.currentWord.dropFirst())
            if propertyName.isEmpty || "count".hasPrefix(propertyName) {
                return CompletionItemModel(
                    label: "count",
                    insertText: "count",
                    kind: .property,
                    detail: "Number of elements"
                )
            }
        }
        return nil
    }
}

/// Function call pattern
struct FunctionCallPattern: CodePattern {
    func generateSuggestion(for context: CompletionContextModel) -> CompletionItemModel? {
        // Suggest function parameter completion
        if context.lineText.contains("(") && !context.lineText.contains(")") {
            return CompletionItemModel(
                label: "completion",
                insertText: "<#parameter#>)",
                kind: .keyword,
                detail: "Parameter placeholder"
            )
        }
        return nil
    }
}

// MARK: - Completion Ranking Model

/// Simple ranking model (placeholder for ML integration)
private class CompletionRankingModel {
    func rank(
        items: [CompletionItemModel],
        context: CompletionContextModel,
        frequencyData: [String: Int]
    ) -> [CompletionItemModel] {
        // Sort by multiple factors
        items.sorted { item1, item2 in
            // Priority 1: Sort text (if provided)
            if let sort1 = item1.sortText, let sort2 = item2.sortText {
                if sort1 != sort2 {
                    return sort1 < sort2
                }
            }

            // Priority 2: Frequency
            let freq1 = frequencyData[item1.label] ?? 0
            let freq2 = frequencyData[item2.label] ?? 0
            if freq1 != freq2 {
                return freq1 > freq2
            }

            // Priority 3: Relevance to context
            let relevance1 = calculateRelevance(item: item1, context: context)
            let relevance2 = calculateRelevance(item: item2, context: context)
            if relevance1 != relevance2 {
                return relevance1 > relevance2
            }

            // Priority 4: Alphabetical
            return item1.label < item2.label
        }
    }

    private func calculateRelevance(item: CompletionItemModel, context: CompletionContextModel) -> Double {
        var relevance = 0.0

        // Exact prefix match
        if item.label.lowercased().hasPrefix(context.currentWord.lowercased()) {
            relevance += 1.0
        }

        // Contains match
        if item.label.lowercased().contains(context.currentWord.lowercased()) {
            relevance += 0.5
        }

        // Kind relevance
        switch item.kind {
        case .method, .function:
            if context.lineText.contains("(") {
                relevance += 0.3
            }

        case .property, .variable:
            if context.lineText.contains(".") {
                relevance += 0.3
            }

        default:
            break
        }

        return relevance
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}
