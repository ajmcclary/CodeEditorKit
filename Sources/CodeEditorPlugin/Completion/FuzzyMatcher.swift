import Foundation

/// Advanced fuzzy matching engine for code completion
public struct FuzzyMatcher {
    // MARK: - Configuration

    /// Configuration settings for fuzzy matching behavior
    public struct Configuration {
        /// Weight for consecutive character matches
        public var consecutiveBonus: Double = 15.0

        /// Weight for matching the first character
        public var firstCharBonus: Double = 10.0

        /// Weight for matching immediately after a separator
        public var separatorBonus: Double = 20.0

        /// Weight for camelCase/snake_case boundaries
        public var camelCaseBonus: Double = 25.0

        /// Penalty for each unmatched character
        public var unmatchedPenalty: Double = -1.0

        /// Penalty for gaps in matching
        public var gapPenalty: Double = -3.0

        /// Minimum score threshold
        public var minimumScore: Double = 0.0

        /// Maximum results to return
        public var maxResults: Int = 100

        /// Creates a new configuration with default values
        public init() {}
    }

    // MARK: - Types

    /// Result of fuzzy matching
    public struct MatchResult {
        /// The matched string item
        public let item: String

        /// Match quality score (higher is better)
        public let score: Double

        /// Character ranges that matched the pattern
        public let matchedRanges: [NSRange]

        /// Creates a new match result
        /// - Parameters:
        ///   - item: The matched string
        ///   - score: Quality score of the match
        ///   - matchedRanges: Character ranges that matched
        public init(item: String, score: Double, matchedRanges: [NSRange]) {
            self.item = item
            self.score = score
            self.matchedRanges = matchedRanges
        }
    }

    /// Match position information
    private struct MatchPosition {
        let patternIndex: Int
        let targetIndex: Int
        let score: Double
        let consecutive: Int
    }

    // MARK: - Properties

    private let configuration: Configuration

    // MARK: - Initialization

    /// Creates a new fuzzy matcher with the specified configuration
    /// - Parameter configuration: Matching behavior configuration (uses defaults if not provided)
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Match pattern against multiple candidates
    public func match(pattern: String, candidates: [String]) -> [MatchResult] {
        guard !pattern.isEmpty else {
            return candidates.map { MatchResult(item: $0, score: 0, matchedRanges: []) }
        }

        var results: [MatchResult] = []

        for candidate in candidates {
            if let result = matchSingle(pattern: pattern, candidate: candidate),
               result.score >= configuration.minimumScore {
                results.append(result)
            }
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }

        // Limit results
        if results.count > configuration.maxResults {
            results = Array(results.prefix(configuration.maxResults))
        }

        return results
    }

    /// Match pattern against a single candidate
    public func matchSingle(pattern: String, candidate: String) -> MatchResult? {
        let patternLower = pattern.lowercased()
        let candidateLower = candidate.lowercased()

        guard let match = performMatch(
            pattern: Array(patternLower),
            candidate: Array(candidateLower),
            originalCandidate: Array(candidate)
        ) else { return nil }

        return MatchResult(
            item: candidate,
            score: match.score,
            matchedRanges: match.ranges
        )
    }

    /// Score a pre-matched result (for re-ranking)
    public func score(pattern: String, candidate: String, matchedRanges: [NSRange]) -> Double {
        calculateScore(
            pattern: Array(pattern.lowercased()),
            candidate: Array(candidate),
            matchedPositions: matchedRanges.flatMap { range in
                Array(range.location..<NSMaxRange(range))
            }
        )
    }

    // MARK: - Private Methods

    private func performMatch(
        pattern: [Character],
        candidate: [Character],
        originalCandidate: [Character]
    ) -> (score: Double, ranges: [NSRange])? {
        guard pattern.count <= candidate.count else { return nil }

        // Dynamic programming approach
        // var bestMatch: (score: Double, positions: [Int])?

        // Try to find the best matching sequence
        let positions = findBestMatchingPositions(
            pattern: pattern,
            candidate: candidate
        )

        guard positions.count == pattern.count else { return nil }

        // Calculate score
        let score = calculateScore(
            pattern: pattern,
            candidate: originalCandidate,
            matchedPositions: positions
        )

        // Convert positions to ranges
        let ranges = positionsToRanges(positions)

        return (score, ranges)
    }

    private func findBestMatchingPositions(
        pattern: [Character],
        candidate: [Character]
    ) -> [Int] {
        var positions: [Int] = []
        var candidateIndex = 0

        for patternChar in pattern {
            // Find next occurrence of pattern character
            var found = false

            while candidateIndex < candidate.count {
                if candidate[candidateIndex] == patternChar {
                    positions.append(candidateIndex)
                    candidateIndex += 1
                    found = true
                    break
                }
                candidateIndex += 1
            }

            if !found {
                return [] // Pattern cannot be matched
            }
        }

        // Try to optimize positions for better scoring
        return optimizeMatchPositions(
            pattern: pattern,
            candidate: candidate,
            initialPositions: positions
        )
    }

    private func optimizeMatchPositions(
        pattern _: [Character],
        candidate _: [Character],
        initialPositions: [Int]
    ) -> [Int] {
        // This is a simplified optimization
        // In a full implementation, you'd use dynamic programming
        initialPositions
    }

    private func calculateScore(
        pattern: [Character],
        candidate: [Character],
        matchedPositions: [Int]
    ) -> Double {
        guard !matchedPositions.isEmpty else { return 0 }

        var score = 0.0
        var previousPosition = -1

        for position in matchedPositions {
            // Base score for match
            score += 10.0

            // First character bonus
            if position == 0 {
                score += configuration.firstCharBonus
            }

            // Consecutive bonus
            if previousPosition >= 0 && position == previousPosition + 1 {
                score += configuration.consecutiveBonus
            } else if previousPosition >= 0 {
                // Gap penalty
                let gapSize = position - previousPosition - 1
                score += configuration.gapPenalty * Double(gapSize)
            }

            // Separator bonus (after underscore, dash, dot, space)
            if position > 0 {
                let prevChar = candidate[position - 1]
                if isSeparator(prevChar) {
                    score += configuration.separatorBonus
                }
            }

            // CamelCase bonus
            if position > 0 && isWordBoundary(
                prev: candidate[position - 1],
                current: candidate[position]
            ) {
                score += configuration.camelCaseBonus
            }

            previousPosition = position
        }

        // Length penalty - prefer shorter candidates with same matches
        let unmatchedCount = candidate.count - matchedPositions.count
        score += configuration.unmatchedPenalty * Double(unmatchedCount)

        // Normalize by pattern length
        score /= Double(pattern.count)

        return max(0, score)
    }

    private func isSeparator(_ char: Character) -> Bool {
        char == "_" || char == "-" || char == "." || char == " " || char == "/" || char == "\\"
    }

    private func isWordBoundary(prev: Character, current: Character) -> Bool {
        // Check for camelCase boundary (lowercase to uppercase)
        if prev.isLowercase && current.isUppercase {
            return true
        }

        // Check for snake_case or kebab-case boundary
        if isSeparator(prev) && current.isLetter {
            return true
        }

        // Check for number to letter boundary
        if prev.isNumber && current.isLetter {
            return true
        }

        return false
    }

    private func positionsToRanges(_ positions: [Int]) -> [NSRange] {
        guard !positions.isEmpty else { return [] }

        var ranges: [NSRange] = []
        var currentStart = positions[0]
        var currentEnd = positions[0]

        for index in 1..<positions.count {
            if positions[index] == currentEnd + 1 {
                // Consecutive position, extend current range
                currentEnd = positions[index]
            } else {
                // Gap found, close current range and start new one
                ranges.append(NSRange(location: currentStart, length: currentEnd - currentStart + 1))
                currentStart = positions[index]
                currentEnd = positions[index]
            }
        }

        // Add final range
        ranges.append(NSRange(location: currentStart, length: currentEnd - currentStart + 1))

        return ranges
    }
}

// MARK: - Acronym Support

extension FuzzyMatcher {
    /// Check if pattern could be an acronym of candidate
    public func matchAcronym(pattern: String, candidate: String) -> MatchResult? {
        let words = extractWords(from: candidate)
        let patternArray = Array(pattern.lowercased())

        guard patternArray.count <= words.count else { return nil }

        var matchedRanges: [NSRange] = []
        var wordIndex = 0

        for patternChar in patternArray {
            // Find next word starting with this character
            while wordIndex < words.count {
                let word = words[wordIndex]
                if word.lowercased().first == patternChar {
                    // Add first character of word to matched ranges
                    let wordStart = candidate.lowercased().range(of: word.lowercased())?.lowerBound
                    if let startIndex = wordStart {
                        let location = candidate.distance(from: candidate.startIndex, to: startIndex)
                        matchedRanges.append(NSRange(location: location, length: 1))
                    }
                    wordIndex += 1
                    break
                }
                wordIndex += 1
            }
        }

        guard matchedRanges.count == patternArray.count else { return nil }

        // High score for acronym matches
        let score = 100.0 * Double(pattern.count) / Double(words.count)

        return MatchResult(
            item: candidate,
            score: score,
            matchedRanges: matchedRanges
        )
    }

    private func extractWords(from text: String) -> [String] {
        var words: [String] = []
        var currentWord = ""
        var previousChar: Character?

        for char in text {
            if char.isLetter {
                if let prev = previousChar {
                    // Check for word boundary
                    if !prev.isLetter || (prev.isLowercase && char.isUppercase) {
                        if !currentWord.isEmpty {
                            words.append(currentWord)
                        }
                        currentWord = String(char)
                    } else {
                        currentWord.append(char)
                    }
                } else {
                    currentWord = String(char)
                }
            } else {
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
            }
            previousChar = char
        }

        if !currentWord.isEmpty {
            words.append(currentWord)
        }

        return words
    }
}

// MARK: - Highlighted String Generation

extension FuzzyMatcher.MatchResult {
    /// Generate an attributed string with matched ranges highlighted
    public func highlightedString(
        highlightAttributes: [NSAttributedString.Key: Any],
        baseAttributes: [NSAttributedString.Key: Any] = [:]
    ) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(
            string: item,
            attributes: baseAttributes
        )

        // Apply highlight attributes to matched ranges
        for range in matchedRanges {
            attributedString.addAttributes(highlightAttributes, range: range)
        }

        return attributedString
    }
}
