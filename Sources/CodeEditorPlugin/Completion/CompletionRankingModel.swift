import Foundation

// MARK: - Completion Ranking Model

/// Ranking model for sorting completion suggestions based on relevance and user behavior
/// This is a placeholder for future ML integration
@MainActor
public final class CompletionRankingModel {
    // MARK: - Properties
    
    /// Weights for different ranking factors
    private enum RankingWeights {
        static let exactPrefixMatch = 1.0
        static let containsMatch = 0.5
        static let contextRelevance = 0.3
        static let frequencyBoost = 0.7
        static let recentSelectionBoost = 0.8
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Rank completion items based on context and usage patterns
    /// - Parameters:
    ///   - items: The completion items to rank
    ///   - context: The current completion context
    ///   - frequencyData: Historical frequency data for items
    /// - Returns: Sorted array of completion items
    public func rank(
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
    
    // MARK: - Private Methods
    
    /// Calculate relevance score for a completion item
    /// - Parameters:
    ///   - item: The completion item
    ///   - context: The current completion context
    /// - Returns: Relevance score
    private func calculateRelevance(item: CompletionItemModel, context: CompletionContextModel) -> Double {
        var relevance = 0.0
        
        // Exact prefix match
        if item.label.lowercased().hasPrefix(context.currentWord.lowercased()) {
            relevance += RankingWeights.exactPrefixMatch
        }
        
        // Contains match
        if item.label.lowercased().contains(context.currentWord.lowercased()) {
            relevance += RankingWeights.containsMatch
        }
        
        // Kind relevance based on context
        relevance += calculateKindRelevance(item: item, context: context)
        
        return relevance
    }
    
    /// Calculate relevance based on completion kind and context
    /// - Parameters:
    ///   - item: The completion item
    ///   - context: The current completion context
    /// - Returns: Kind-based relevance score
    private func calculateKindRelevance(item: CompletionItemModel, context: CompletionContextModel) -> Double {
        var relevance = 0.0
        
        switch item.kind {
        case .method, .function:
            if context.lineText.contains("(") {
                relevance += RankingWeights.contextRelevance
            }
            
        case .property, .variable:
            if context.lineText.contains(".") {
                relevance += RankingWeights.contextRelevance
            }
            
        case .keyword:
            // Keywords are generally relevant at the start of lines or after whitespace
            let linePrefix = String(context.lineText.prefix(context.cursorPosition))
            if linePrefix.trimmingCharacters(in: .whitespaces).isEmpty {
                relevance += RankingWeights.contextRelevance
            }
            
        case .class, .struct, .enum:
            // Types are relevant after colons or in generic contexts
            if context.lineText.contains(":") || context.lineText.contains("<") {
                relevance += RankingWeights.contextRelevance
            }
            
        default:
            break
        }
        
        return relevance
    }
    
    /// Calculate score with frequency and recency boosts
    /// - Parameters:
    ///   - baseScore: The base relevance score
    ///   - frequency: How often this item has been selected
    ///   - recencyScore: How recently this item was selected (0-1)
    /// - Returns: Final score with boosts applied
    public func applyUsageBoosts(baseScore: Double, frequency: Int, recencyScore: Double) -> Double {
        var score = baseScore
        
        // Apply frequency boost (logarithmic to prevent domination)
        if frequency > 0 {
            score += RankingWeights.frequencyBoost * log(Double(frequency + 1))
        }
        
        // Apply recency boost
        score += RankingWeights.recentSelectionBoost * recencyScore
        
        return score
    }
}

// MARK: - Machine Learning Integration

/// Protocol for future ML model integration
public protocol CompletionMLModel {
    /// Predict relevance scores for completion items
    /// - Parameters:
    ///   - items: The completion items
    ///   - context: The current context
    /// - Returns: Dictionary mapping item labels to predicted scores
    func predictScores(for items: [CompletionItemModel], context: CompletionContextModel) async -> [String: Double]
}

/// Placeholder for neural network-based ranking
public struct NeuralCompletionRanker: CompletionMLModel {
    public init() {}
    
    public func predictScores(for _: [CompletionItemModel], context _: CompletionContextModel) async -> [String: Double] {
        // TODO: Integrate with CoreML or CreateML model
        // For now, return empty scores
        [:]
    }
}
