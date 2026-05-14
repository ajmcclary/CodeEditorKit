import Foundation

/// Optimized fuzzy matching engine with improved performance characteristics
public struct OptimizedFuzzyMatcher: Sendable {
    // MARK: - Configuration

    public struct Configuration: Sendable {
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

        /// Enable parallel processing for large candidate sets
        public var enableParallelProcessing: Bool = true

        /// Minimum candidates for parallel processing
        public var parallelThreshold: Int = 50

        public init() {}
    }

    // MARK: - Types

    /// Result of fuzzy matching
    public struct MatchResult: Sendable {
        public let item: String
        public let score: Double
        public let matchedRanges: [NSRange]

        public init(item: String, score: Double, matchedRanges: [NSRange]) {
            self.item = item
            self.score = score
            self.matchedRanges = matchedRanges
        }
    }

    /// Pre-computed candidate data for faster matching
    private struct CandidateData: Sendable {
        let original: String
        let lowercase: [Character]
        let wordBoundaries: [Int]
        let separatorPositions: [Int]
    }

    // MARK: - Properties

    private let configuration: Configuration

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Match pattern against multiple candidates with optimizations
    public func match(pattern: String, candidates: [String]) async -> [MatchResult] {
        guard !pattern.isEmpty else {
            return candidates.prefix(configuration.maxResults).map { MatchResult(item: $0, score: 0, matchedRanges: []) }
        }

        let patternLower = Array(pattern.lowercased())
        let patternLength = patternLower.count

        // Early filtering: Remove candidates shorter than pattern
        let viableCandidates = candidates.filter { $0.count >= patternLength }

        // Use parallel processing for large candidate sets
        if configuration.enableParallelProcessing && viableCandidates.count >= configuration.parallelThreshold {
            return await matchParallel(pattern: patternLower, candidates: viableCandidates)
        } else {
            return matchSequential(pattern: patternLower, candidates: viableCandidates)
        }
    }

    /// Synchronous sequential match for callers that can't await (e.g. MainActor query handlers).
    public func matchSequential(pattern: String, candidates: [String]) -> [MatchResult] {
        guard !pattern.isEmpty else {
            return candidates.prefix(configuration.maxResults).map { MatchResult(item: $0, score: 0, matchedRanges: []) }
        }
        let patternLower = Array(pattern.lowercased())
        let viableCandidates = candidates.filter { $0.count >= patternLower.count }
        return matchSequential(pattern: patternLower, candidates: viableCandidates)
    }

    // MARK: - Private Methods

    private func matchSequential(pattern: [Character], candidates: [String]) -> [MatchResult] {
        var results: [(result: MatchResult, quickScore: Double)] = []
        results.reserveCapacity(candidates.count)

        for candidate in candidates {
            let candidateData = preprocessCandidate(candidate)
            // Quick rejection based on character frequency
            if !quickReject(pattern: pattern, candidateData: candidateData) {
                if let result = matchSingleOptimized(pattern: pattern, candidateData: candidateData) {
                    let quickScore = calculateQuickScore(result: result)
                    results.append((result, quickScore))
                }
            }
        }

        // If no results found, return empty array
        if results.isEmpty {
            return []
        }

        // Sort by quick score first, then refine top results
        results.sort { $0.quickScore > $1.quickScore }

        // Take top results and calculate detailed scores
        let topCount = min(configuration.maxResults * 2, results.count)
        let topResults = results.prefix(topCount).map { $0.result }

        // Sort final results by detailed score
        return Array(topResults
            .sorted { $0.score > $1.score }
            .prefix(configuration.maxResults)
            .filter { $0.score >= configuration.minimumScore })
    }

    private func matchParallel(pattern: [Character], candidates: [String]) async -> [MatchResult] {
        // Process candidates in chunks using TaskGroup
        let chunkSize = max(1, candidates.count / ProcessInfo.processInfo.activeProcessorCount)
        let chunks = candidates.chunked(into: chunkSize)

        // Use TaskGroup for concurrent processing
        let allResults = await withTaskGroup(of: [(result: MatchResult, quickScore: Double)].self) { group in
            // Create tasks for each chunk
            for chunk in chunks {
                group.addTask { [self] in
                    var localResults: [(result: MatchResult, quickScore: Double)] = []

                    for candidate in chunk {
                        let candidateData = self.preprocessCandidate(candidate)
                        if !self.quickReject(pattern: pattern, candidateData: candidateData) {
                            if let result = self.matchSingleOptimized(pattern: pattern, candidateData: candidateData) {
                                let quickScore = self.calculateQuickScore(result: result)
                                localResults.append((result, quickScore))
                            }
                        }
                    }

                    return localResults
                }
            }

            // Collect all results
            var allResults: [(result: MatchResult, quickScore: Double)] = []
            for await chunkResults in group {
                allResults.append(contentsOf: chunkResults)
            }
            return allResults
        }

        // If no results found, return empty array
        if allResults.isEmpty {
            return []
        }

        // Sort and filter as in sequential version
        var finalResults = allResults
        finalResults.sort { $0.quickScore > $1.quickScore }

        let topCount = min(configuration.maxResults * 2, finalResults.count)
        let topResults = finalResults.prefix(topCount).map { $0.result }

        return Array(topResults
            .sorted { $0.score > $1.score }
            .prefix(configuration.maxResults)
            .filter { $0.score >= configuration.minimumScore })
    }

    private func preprocessCandidate(_ candidate: String) -> CandidateData {
        let lowercaseArray = Array(candidate.lowercased())
        var wordBoundaries: [Int] = []
        var separatorPositions: [Int] = []

        // Pre-compute word boundaries and separator positions
        for (index, char) in candidate.enumerated() where index > 0 {
            let prevChar = candidate[candidate.index(candidate.startIndex, offsetBy: index - 1)]

            if isSeparator(prevChar) {
                separatorPositions.append(index)
            }

            if isWordBoundary(prev: prevChar, current: char) {
                wordBoundaries.append(index)
            }
        }

        return CandidateData(
            original: candidate,
            lowercase: lowercaseArray,
            wordBoundaries: wordBoundaries,
            separatorPositions: separatorPositions
        )
    }

    private func quickReject(pattern _: [Character], candidateData _: CandidateData) -> Bool {
        // For now, disable quick reject to debug the issue
        false
    }

    private func matchSingleOptimized(pattern: [Character], candidateData: CandidateData) -> MatchResult? {
        let positions = findBestMatchingPositionsOptimized(
            pattern: pattern,
            candidateData: candidateData
        )

        guard positions.count == pattern.count else { return nil }

        let score = calculateScoreOptimized(
            candidateData: candidateData,
            matchedPositions: positions
        )

        let ranges = positionsToRanges(positions)

        return MatchResult(
            item: candidateData.original,
            score: score,
            matchedRanges: ranges
        )
    }

    private func findBestMatchingPositionsOptimized(
        pattern: [Character],
        candidateData: CandidateData
    ) -> [Int] {
        var positions: [Int] = []
        var candidateIndex = 0

        // Simple sequential matching for now
        for patternChar in pattern {
            var found = false

            while candidateIndex < candidateData.lowercase.count {
                if candidateData.lowercase[candidateIndex] == patternChar {
                    positions.append(candidateIndex)
                    candidateIndex += 1
                    found = true
                    break
                }
                candidateIndex += 1
            }

            if !found {
                return []
            }
        }

        return positions
    }

    private func calculateScoreOptimized(
        candidateData: CandidateData,
        matchedPositions: [Int]
    ) -> Double {
        guard !matchedPositions.isEmpty else { return 0 }

        var score = 0.0
        var previousPosition = -1

        for position in matchedPositions {
            // Base score
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

            // Separator bonus (pre-computed)
            if candidateData.separatorPositions.contains(position) {
                score += configuration.separatorBonus
            }

            // Word boundary bonus (pre-computed)
            if candidateData.wordBoundaries.contains(position) {
                score += configuration.camelCaseBonus
            }

            previousPosition = position
        }

        // Length penalty
        let unmatchedCount = candidateData.lowercase.count - matchedPositions.count
        score += configuration.unmatchedPenalty * Double(unmatchedCount)

        return score
    }

    private func calculateQuickScore(result: MatchResult) -> Double {
        // Quick score based on match density and position
        guard !result.matchedRanges.isEmpty else { return 0 }

        let firstMatchPosition = result.matchedRanges[0].location
        let matchDensity = Double(result.matchedRanges.count) / Double(result.item.count)

        return result.score + (100.0 * matchDensity) - Double(firstMatchPosition)
    }

    private func positionsToRanges(_ positions: [Int]) -> [NSRange] {
        guard !positions.isEmpty else { return [] }

        var ranges: [NSRange] = []
        var start = positions[0]
        var length = 1

        for index in 1..<positions.count {
            if positions[index] == positions[index - 1] + 1 {
                length += 1
            } else {
                ranges.append(NSRange(location: start, length: length))
                start = positions[index]
                length = 1
            }
        }

        ranges.append(NSRange(location: start, length: length))
        return ranges
    }

    private func isSeparator(_ char: Character) -> Bool {
        char == "_" || char == "-" || char == "." || char == " " || char == "/" || char == "\\"
    }

    private func isWordBoundary(prev: Character, current: Character) -> Bool {
        // camelCase boundary
        if prev.isLowercase && current.isUppercase {
            return true
        }

        // number to letter boundary
        if prev.isNumber && current.isLetter {
            return true
        }

        return false
    }
}

// MARK: - Array Extension

extension Array {
    internal func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
