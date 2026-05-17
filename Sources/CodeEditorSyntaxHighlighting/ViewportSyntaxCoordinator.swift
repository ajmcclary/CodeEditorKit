import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorTextModel
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
#if canImport(Combine)
import Combine
#endif

/// Coordinates syntax highlighting with viewport-based optimization for better performance with large files
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class ViewportSyntaxCoordinator: ObservableObject {
    private let baseCoordinator: SyntaxHighlightingCoordinator
    private let cache: LRUCache<ViewportCacheKey, ViewportHighlightResult>
    private let maxCacheSize: Int
    private let viewportExpansionRatio: Double

    /// Current visible range in the text
    @Published public private(set) var visibleRange = NSRange(location: 0, length: 0)

    /// Statistics for viewport highlighting
    @Published public private(set) var statistics = ViewportStatistics()

    private let memoryMonitor: MemoryMonitor

    private struct ViewportExtraction {
        let text: String
        let range: NSRange
    }

    public init(
        memoryMonitor: MemoryMonitor,
        baseCoordinator: SyntaxHighlightingCoordinator = SyntaxHighlightingCoordinator(),
        maxCacheSize: Int = 50,
        viewportExpansionRatio: Double = 1.5 // Highlight 50% more content around visible area
    ) {
        self.baseCoordinator = baseCoordinator
        self.memoryMonitor = memoryMonitor
        self.cache = LRUCache(capacity: maxCacheSize, memoryMonitor: memoryMonitor)
        self.maxCacheSize = maxCacheSize
        self.viewportExpansionRatio = viewportExpansionRatio

        // Register with memory monitor
        registerWithMemoryMonitor()
    }

    deinit {
        // Note: Cannot access @MainActor isolated properties in deinit
        // Cache will be cleaned up automatically by ARC
    }

    /// Update the visible range and trigger highlighting if needed
    /// - Parameters:
    ///   - range: The currently visible text range
    ///   - source: The complete source text
    ///   - language: The programming language
    /// - Returns: Highlighting results for the expanded viewport
    public func updateVisibleRange(
        _ range: NSRange,
        source: String,
        language: Language
    ) -> [HighlightedToken] {
        let startTime = Date()
        visibleRange = range

        // Calculate expanded range for better user experience
        let expandedRange = calculateExpandedRange(
            visibleRange: range,
            sourceLength: TextRangeUtilities.utf16Length(of: source)
        )

        // Check cache first
        var hasher = Hasher()
        hasher.combine(source)
        let cacheKey = ViewportCacheKey(
            range: expandedRange,
            sourceHash: hasher.finalize(),
            language: language.identifier
        )

        if let cachedResult = cache.get(cacheKey) {
            statistics.recordCacheHit(processingTime: Date().timeIntervalSince(startTime))
            return cachedResult.tokens
        }

        // Extract substring for the expanded range
        let extraction = extractSubstring(from: source, range: expandedRange)

        // Highlight the substring
        let tokens = baseCoordinator.highlight(source: extraction.text, language: language)

        // Adjust token ranges to match original text positions
        let adjustedTokens = adjustTokenRanges(tokens, offset: extraction.range.location)

        // Cache the result
        let result = ViewportHighlightResult(
            tokens: adjustedTokens,
            range: extraction.range,
            timestamp: Date()
        )
        cache.set(result, forKey: cacheKey)

        let processingTime = Date().timeIntervalSince(startTime)
        statistics.recordHighlighting(
            range: extraction.range,
            tokenCount: adjustedTokens.count,
            processingTime: processingTime
        )

        return adjustedTokens
    }

    /// Highlight only the visible portion of text for optimal performance
    /// - Parameters:
    ///   - source: Complete source text
    ///   - visibleRange: Currently visible text range
    ///   - language: Programming language for highlighting
    /// - Returns: Highlighted tokens for the visible area
    public func highlightViewport(
        source: String,
        visibleRange: NSRange,
        language: Language
    ) -> [HighlightedToken] {
        updateVisibleRange(visibleRange, source: source, language: language)
    }

    /// Preload highlighting for ranges likely to be viewed soon
    /// - Parameters:
    ///   - source: Complete source text
    ///   - currentRange: Current visible range
    ///   - language: Programming language
    ///   - direction: Direction of likely scrolling
    public func preloadHighlighting(
        source: String,
        currentRange: NSRange,
        language: Language,
        direction: ScrollDirection = .down
    ) {
        let preloadSize = max(currentRange.length, 1_000) // At least 1000 characters
        let preloadRange: NSRange

        switch direction {
        case .up:
            let location = max(0, currentRange.location - preloadSize)
            let length = min(preloadSize, currentRange.location - location)
            preloadRange = NSRange(location: location, length: length)

        case .down:
            let maxLocation = TextRangeUtilities.utf16Length(of: source)
            let location = min(maxLocation, NSMaxRange(currentRange))
            let length = min(preloadSize, maxLocation - location)
            preloadRange = NSRange(location: location, length: length)
        }

        // Preload in background
        Task {
            _ = await highlightRangeAsync(
                source: source,
                range: preloadRange,
                language: language
            )
        }
    }

    /// Clear the highlight cache
    public func clearCache() {
        cache.removeAll()
        statistics.reset()
    }

    /// Get cache statistics
    public var cacheStatistics: CacheStatistics {
        cache.statistics
    }

    // MARK: - Private Methods

    private func calculateExpandedRange(visibleRange: NSRange, sourceLength: Int) -> NSRange {
        let expansionSize = Int(Double(visibleRange.length) * (viewportExpansionRatio - 1.0) / 2.0)

        let startLocation = max(0, visibleRange.location - expansionSize)
        let endLocation = min(sourceLength, NSMaxRange(visibleRange) + expansionSize)

        return NSRange(location: startLocation, length: endLocation - startLocation)
    }

    nonisolated private func extractSubstring(from source: String, range: NSRange) -> ViewportExtraction {
        let sourceLength = TextRangeUtilities.utf16Length(of: source)
        let clampedRange = TextRangeUtilities.clampRange(range, toTextLength: sourceLength)

        if let substring = TextRangeUtilities.substring(inUTF16Range: clampedRange, from: source) {
            return ViewportExtraction(text: substring, range: clampedRange)
        }

        if let alignedRange = TextRangeUtilities.characterAlignedRange(clampedRange, in: source),
           let substring = TextRangeUtilities.substring(inUTF16Range: alignedRange, from: source) {
            return ViewportExtraction(text: substring, range: alignedRange)
        }

        return ViewportExtraction(text: source, range: TextRangeUtilities.fullRange(in: source))
    }

    nonisolated private func adjustTokenRanges(_ tokens: [HighlightedToken], offset: Int) -> [HighlightedToken] {
        tokens.map { token in
            HighlightedToken(
                range: NSRange(
                    location: token.range.location + offset,
                    length: token.range.length
                ),
                type: token.type,
                text: token.text
            )
        }
    }

    private func highlightRangeAsync(
        source: String,
        range: NSRange,
        language: Language
    ) async -> [HighlightedToken] {
        let extraction = extractSubstring(from: source, range: range)

        // Perform highlighting on main actor since baseCoordinator requires it
        let tokens = baseCoordinator.highlight(source: extraction.text, language: language)

        return adjustTokenRanges(tokens, offset: extraction.range.location)
    }

    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            self.memoryMonitor.registerCleanupHandler(
                identifier: "viewport-syntax-coordinator",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "ViewportSyntaxCoordinator deallocated")
                }

                // Clear highlighting cache
                let beforeCacheSize = self.cache.count
                self.cache.removeAll()

                // Reset statistics
                self.statistics.reset()

                // Estimate memory freed
                let estimatedMemoryMB = Double(beforeCacheSize) * 0.010 // 10KB per cached highlight result estimate

                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Cleared \\(beforeCacheSize) viewport highlighting cache items"
                )
            }
        }
    }
}

// MARK: - Supporting Types

/// Direction for preloading highlighting
public enum ScrollDirection {
    /// Scrolling upward (toward beginning of document)
    case up
    /// Scrolling downward (toward end of document)
    case down
}

/// Cache key for viewport highlighting results
public struct ViewportCacheKey: Hashable, Sendable {
    public let range: NSRange
    public let sourceHash: Int
    public let language: String

    public func hash(into hasher: inout Hasher) {
        hasher.combine(range.location)
        hasher.combine(range.length)
        hasher.combine(sourceHash)
        hasher.combine(language)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.range == rhs.range &&
               lhs.sourceHash == rhs.sourceHash &&
               lhs.language == rhs.language
    }
}

/// Cached viewport highlighting result
public struct ViewportHighlightResult: Sendable {
    public let tokens: [HighlightedToken]
    public let range: NSRange
    public let timestamp: Date

    public var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 600 // 10 minutes
    }
}

/// Statistics for viewport-based highlighting
@MainActor
@available(macOS 10.15, iOS 13.0, *)
public final class ViewportStatistics: ObservableObject {
    @Published public private(set) var totalHighlights: Int = 0
    @Published public private(set) var cacheHits: Int = 0
    @Published public private(set) var averageTokensHighlighted: Double = 0
    @Published public private(set) var averageProcessingTime: TimeInterval = 0
    @Published public private(set) var lastHighlightTime: Date?

    private var tokenCounts: [Int] = []
    private var processingTimes: [TimeInterval] = []
    private let maxSamples = 100

    public var cacheHitRate: Double {
        totalHighlights > 0 ? Double(cacheHits) / Double(totalHighlights) : 0
    }

    package func recordHighlighting(range _: NSRange, tokenCount: Int, processingTime: TimeInterval) {
        totalHighlights += 1
        lastHighlightTime = Date()

        // Update token count statistics
        tokenCounts.append(tokenCount)
        if tokenCounts.count > maxSamples {
            tokenCounts.removeFirst()
        }
        averageTokensHighlighted = Double(tokenCounts.reduce(0, +)) / Double(tokenCounts.count)

        // Update processing time statistics
        processingTimes.append(processingTime)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }

    package func recordCacheHit(processingTime: TimeInterval) {
        totalHighlights += 1
        cacheHits += 1
        lastHighlightTime = Date()

        // Still record processing time for cache hits (should be very fast)
        processingTimes.append(processingTime)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }

    public func reset() {
        totalHighlights = 0
        cacheHits = 0
        averageTokensHighlighted = 0
        averageProcessingTime = 0
        lastHighlightTime = nil
        tokenCounts.removeAll()
        processingTimes.removeAll()
    }
}
