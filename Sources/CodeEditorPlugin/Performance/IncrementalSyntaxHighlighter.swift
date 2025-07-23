import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Incremental syntax highlighter that only re-highlights changed regions
/// This is a critical performance optimization for large files
@MainActor
public final class IncrementalSyntaxHighlighter {
    // MARK: - Types

    /// Represents a cached highlighting region
    private struct CachedRegion {
        let range: NSRange
        let tokens: [Token]
        let contentHash: Int
        let timestamp: Date
    }

    /// Tracks text changes for incremental updates
    private struct TextChange {
        let range: NSRange
        let replacementLength: Int
        var affectedRange: NSRange {
            NSRange(location: range.location, length: replacementLength)
        }
    }

    // MARK: - Properties

    private let baseHighlighter: AsyncSyntaxHighlighter
    private let memoryMonitor: MemoryMonitor
    private let regionSize: Int = 1_000 // Characters per region

    /// Line-level token cache for efficient partial updates
    private var lineTokenCache: [Int: [Token]] = [:]

    /// Region-based cache for larger sections
    private var regionCache: [Int: CachedRegion] = [:]

    /// Tracks the last processed text for change detection
    private var lastProcessedText: String = ""
    private var lastProcessedHash: Int = 0

    /// Performance metrics
    private var incrementalHighlights = 0
    private var fullHighlights = 0

    // MARK: - Initialization

    /// Creates a new incremental syntax highlighter.
    /// - Parameter memoryMonitor: The memory monitor for tracking usage
    public init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
        self.baseHighlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor)
    }

    // MARK: - Public Methods

    /// Highlights text incrementally, only processing changed regions
    public func highlightIncrementally(
        text: String,
        language: Language,
        textChange: NSRange? = nil,
        visibleRange: NSRange? = nil
    ) async -> [Token] {
        // Check if we can do incremental update
        if let change = textChange, canUseIncrementalUpdate(text: text, change: change) {
            return await performIncrementalHighlight(
                text: text,
                language: language,
                change: change,
                visibleRange: visibleRange
            )
        } else {
            // Fall back to full highlight
            return await performFullHighlight(
                text: text,
                language: language,
                visibleRange: visibleRange
            )
        }
    }

    /// Clears all cached data
    public func clearCache() {
        lineTokenCache.removeAll()
        regionCache.removeAll()
        lastProcessedText = ""
        lastProcessedHash = 0
    }

    /// Returns cache statistics for monitoring
    public func getCacheStatistics() -> (lines: Int, regions: Int, hitRate: Double) {
        let hitRate = incrementalHighlights + fullHighlights > 0
            ? Double(incrementalHighlights) / Double(incrementalHighlights + fullHighlights)
            : 0.0

        return (
            lines: lineTokenCache.count,
            regions: regionCache.count,
            hitRate: hitRate
        )
    }

    // MARK: - Private Methods

    private func canUseIncrementalUpdate(text: String, change: NSRange) -> Bool {
        // Check if we have cached data
        guard !lastProcessedText.isEmpty else { return false }

        // Check if the change is small enough for incremental update
        let changeRatio = Double(change.length) / Double(text.count)
        guard changeRatio < 0.1 else { return false } // More than 10% changed

        // Verify text consistency (rough check)
        let textHash = text.hashValue
        let expectedHash = combineHashes(lastProcessedHash, change: change)

        return abs(textHash - expectedHash) < Int.max / 4 // Allow some variance
    }

    private func performIncrementalHighlight(
        text: String,
        language: Language,
        change: NSRange,
        visibleRange _: NSRange?
    ) async -> [Token] {
        incrementalHighlights += 1

        // Calculate affected regions
        let affectedRegions = calculateAffectedRegions(change: change, in: text)

        // Invalidate affected cache entries
        invalidateCache(for: affectedRegions)

        // Re-highlight only affected regions
        var updatedTokens: [Token] = []

        for region in affectedRegions {
            let regionTokens = await highlightRegion(
                text: text,
                range: region,
                language: language
            )
            updatedTokens.append(contentsOf: regionTokens)

            // Cache the updated region
            cacheRegion(range: region, tokens: regionTokens, text: text)
        }

        // Merge with cached tokens
        let allTokens = mergeTokens(updated: updatedTokens, text: text)

        // Update tracking
        lastProcessedText = text
        lastProcessedHash = text.hashValue

        return allTokens
    }

    private func performFullHighlight(
        text: String,
        language: Language,
        visibleRange _: NSRange?
    ) async -> [Token] {
        fullHighlights += 1

        // Clear existing cache as it's invalid
        clearCache()

        // Get tokens through the coordinator
        let coordinator = SyntaxHighlightingCoordinator()
        let tokens = coordinator.highlight(source: text, language: language)

        // Convert to our Token type
        let convertedTokens = tokens.map { highlightedToken in
            Token(
                name: highlightedToken.type.rawValue,
                range: highlightedToken.range
            )
        }

        // Cache the results
        cacheTokens(convertedTokens, for: text)

        // Update tracking
        lastProcessedText = text
        lastProcessedHash = text.hashValue

        return convertedTokens
    }

    private func calculateAffectedRegions(change: NSRange, in text: String) -> [NSRange] {
        var regions: [NSRange] = []

        // Expand change to include surrounding context
        let expandedRange = expandRangeToLineBreaks(change, in: text)

        // Calculate region boundaries
        let startRegion = expandedRange.location / regionSize
        let endRegion = (expandedRange.location + expandedRange.length) / regionSize

        for regionIndex in startRegion...endRegion {
            let regionStart = regionIndex * regionSize
            let regionEnd = min((regionIndex + 1) * regionSize, text.count)
            let regionRange = NSRange(location: regionStart, length: regionEnd - regionStart)

            if regionRange.length > 0 {
                regions.append(regionRange)
            }
        }

        return regions
    }

    private func expandRangeToLineBreaks(_ range: NSRange, in text: String) -> NSRange {
        guard let stringRange = Range(range, in: text) else { return range }

        // Find line start
        var lineStart = stringRange.lowerBound
        while lineStart > text.startIndex {
            let prevIndex = text.index(before: lineStart)
            if text[prevIndex].isNewline {
                break
            }
            lineStart = prevIndex
        }

        // Find line end
        var lineEnd = stringRange.upperBound
        while lineEnd < text.endIndex {
            if text[lineEnd].isNewline {
                lineEnd = text.index(after: lineEnd)
                break
            }
            lineEnd = text.index(after: lineEnd)
        }

        let expandedRange = lineStart..<lineEnd
        return NSRange(expandedRange, in: text)
    }

    private func highlightRegion(
        text: String,
        range: NSRange,
        language: Language
    ) async -> [Token] {
        guard let substring = substringForRange(text, range: range) else { return [] }

        // Get tokens through the coordinator
        let coordinator = SyntaxHighlightingCoordinator()
        let tokens = coordinator.highlight(source: substring, language: language)

        // Adjust token ranges to match the original text and convert types
        return tokens.map { highlightedToken in
            Token(
                name: highlightedToken.type.rawValue,
                range: NSRange(
                    location: highlightedToken.range.location + range.location,
                    length: highlightedToken.range.length
                )
            )
        }
    }

    private func invalidateCache(for regions: [NSRange]) {
        // Invalidate line cache
        let affectedLines = regions.flatMap { range in
            lineIndicesForRange(range)
        }

        for line in affectedLines {
            lineTokenCache.removeValue(forKey: line)
        }

        // Invalidate region cache
        let affectedRegionIndices = regions.map { $0.location / regionSize }
        for index in affectedRegionIndices {
            regionCache.removeValue(forKey: index)
        }
    }

    private func cacheRegion(range: NSRange, tokens: [Token], text: String) {
        let regionIndex = range.location / regionSize

        // Check memory before caching
        let estimatedSize = tokens.count * 32 // Rough estimate: 32 bytes per token
        guard memoryMonitor.shouldCache(size: estimatedSize) else { return }

        let contentHash = substringForRange(text, range: range)?.hashValue ?? 0
        regionCache[regionIndex] = CachedRegion(
            range: range,
            tokens: tokens,
            contentHash: contentHash,
            timestamp: Date()
        )
    }

    private func cacheTokens(_ tokens: [Token], for _: String) {
        // Group tokens by line
        var tokensByLine: [Int: [Token]] = [:]

        for token in tokens {
            let lines = lineIndicesForRange(token.range)
            for line in lines {
                tokensByLine[line, default: []].append(token)
            }
        }

        // Cache with memory check
        for (line, lineTokens) in tokensByLine {
            let estimatedSize = lineTokens.count * 32
            if memoryMonitor.shouldCache(size: estimatedSize) {
                lineTokenCache[line] = lineTokens
            }
        }
    }

    private func mergeTokens(updated: [Token], text _: String) -> [Token] {
        var allTokens: [Token] = updated

        // Add cached tokens that don't overlap with updated ones
        for (_, cachedRegion) in regionCache {
            let overlapsUpdate = updated.contains { token in
                NSIntersectionRange(token.range, cachedRegion.range).length > 0
            }

            if !overlapsUpdate {
                allTokens.append(contentsOf: cachedRegion.tokens)
            }
        }

        // Sort by location
        allTokens.sort { $0.range.location < $1.range.location }

        return allTokens
    }

    private func lineIndicesForRange(_ range: NSRange) -> [Int] {
        // Simplified line calculation - in production, use line index cache
        let startLine = range.location / 80 // Assume average 80 chars per line
        let endLine = (range.location + range.length) / 80
        return Array(startLine...endLine)
    }

    private func createMockTextView(with text: String) -> CodeEditorView {
        let view = CodeEditorView()
        view.text = text
        return view
    }

    private func combineHashes(_ base: Int, change: NSRange) -> Int {
        // Simple hash combination for change detection
        var hasher = Hasher()
        hasher.combine(base)
        hasher.combine(change.location)
        hasher.combine(change.length)
        return hasher.finalize()
    }

    private func substringForRange(_ text: String, range: NSRange) -> String? {
        guard let stringRange = Range(range, in: text) else { return nil }
        return String(text[stringRange])
    }
}

// MARK: - Memory Monitor Extension

extension MemoryMonitor {
    func shouldCache(size: Int) -> Bool {
        let availableMemory = getCurrentMemoryUsage()
        let threshold = 100.0 // MB
        return availableMemory < threshold && size < 1_000_000 // Don't cache if over 1MB
    }
}
