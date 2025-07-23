import Foundation

// MARK: - Completion Filtering Service

/// Service responsible for filtering and scoring completion items
@MainActor
internal final class CompletionFilteringService {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "CompletionFilteringService")

    // MARK: - Types

    internal struct FilterOptions {
        let caseSensitive: Bool
        let fuzzyMatching: Bool
        let maxResults: Int

        static let `default` = Self(
            caseSensitive: false,
            fuzzyMatching: true,
            maxResults: 100
        )
    }

    // MARK: - Public Methods

    /// Filters completion items based on the given text
    internal func filterItems(
        _ items: [CompletionItemModel],
        filterText: String,
        options: FilterOptions = .default
    ) -> [CompletionItemModel] {
        guard !filterText.isEmpty else {
            // Return all items if no filter
            return Array(items.prefix(options.maxResults))
        }

        let startTime = Date()

        // Filter and score items
        let filtered = items.compactMap { item -> (item: CompletionItemModel, score: Double)? in
            let score = calculateMatchScore(
                item.label,
                prefix: filterText,
                caseSensitive: options.caseSensitive,
                fuzzyMatching: options.fuzzyMatching
            )

            return score > 0 ? (item, score) : nil
        }

        // Sort by score and priority
        let sorted = filtered.sorted { first, second in
            if first.score != second.score {
                return first.score > second.score
            }
            return first.item.priority > second.item.priority
        }

        let result = Array(sorted.map(\.item).prefix(options.maxResults))

        let elapsedTime = Date().timeIntervalSince(startTime)
        logger.debug("Filtered \(items.count) items to \(result.count) in \(String(format: "%.3f", elapsedTime))s")

        return result
    }

    /// Calculates match score for a given text and prefix
    internal func calculateMatchScore(
        _ text: String,
        prefix: String,
        caseSensitive: Bool = false,
        fuzzyMatching: Bool = true
    ) -> Double {
        guard !prefix.isEmpty else { return 1.0 }

        let compareText = caseSensitive ? text : text.lowercased()
        let comparePrefix = caseSensitive ? prefix : prefix.lowercased()

        // Exact prefix match gets highest score
        if compareText.hasPrefix(comparePrefix) {
            let lengthRatio = Double(prefix.count) / Double(text.count)
            return 1.0 - (lengthRatio * 0.1) // Slight penalty for longer texts
        }

        if fuzzyMatching {
            return fuzzyMatchScore(compareText, comparePrefix)
        } else {
            // Simple contains check
            return compareText.contains(comparePrefix) ? 0.5 : 0.0
        }
    }

    /// Updates scores for already filtered items based on new filter text
    internal func updateScores(
        for items: [CompletionItemModel],
        filterText: String,
        caseSensitive: Bool = false
    ) -> [CompletionItemModel] {
        items.map { item in
            _ = calculateMatchScore(
                item.label,
                prefix: filterText,
                caseSensitive: caseSensitive
            )
            // Return the same item since CompletionItemModel is immutable
            // and doesn't have a matchScore property
            return item
        }
    }

    // MARK: - Private Methods

    /// Performs fuzzy matching and returns a score
    private func fuzzyMatchScore(_ text: String, _ pattern: String) -> Double {
        var score = 0.0
        var patternIndex = pattern.startIndex
        var lastMatchIndex: String.Index?
        var consecutiveMatches = 0

        for (offset, textChar) in text.enumerated() {
            guard patternIndex < pattern.endIndex else { break }

            let patternChar = pattern[patternIndex]

            if textChar == patternChar {
                // Character match
                var charScore = 1.0

                // Bonus for consecutive matches
                if let last = lastMatchIndex,
                   text.index(after: last) == text.index(text.startIndex, offsetBy: offset) {
                    consecutiveMatches += 1
                    charScore += Double(consecutiveMatches) * 0.5
                } else {
                    consecutiveMatches = 0
                }

                // Bonus for matching at word boundaries
                if offset == 0 || isWordBoundary(at: offset - 1, in: text) {
                    charScore += 2.0
                }

                // Bonus for matching capital letters
                if textChar.isUppercase {
                    charScore += 1.0
                }

                score += charScore
                lastMatchIndex = text.index(text.startIndex, offsetBy: offset)
                patternIndex = pattern.index(after: patternIndex)
            }
        }

        // Check if all pattern characters were matched
        guard patternIndex == pattern.endIndex else { return 0.0 }

        // Normalize score based on pattern length and text length
        let lengthPenalty = Double(text.count - pattern.count) * 0.01
        let normalizedScore = score / Double(pattern.count) - lengthPenalty

        return max(0.0, min(1.0, normalizedScore / 10.0))
    }

    private func isWordBoundary(at index: Int, in text: String) -> Bool {
        let textIndex = text.index(text.startIndex, offsetBy: index)
        let char = text[textIndex]

        // Check if character is not alphanumeric
        if !char.isLetter && !char.isNumber {
            return true
        }

        // Check if next character exists and is uppercase (camelCase boundary)
        let nextIndex = text.index(after: textIndex)
        if nextIndex < text.endIndex {
            let nextChar = text[nextIndex]
            return char.isLowercase && nextChar.isUppercase
        }

        return false
    }
}
