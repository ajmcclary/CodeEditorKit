import CodeEditorCommon
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorTextModel
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Optimized syntax highlighting coordinator with performance improvements
@MainActor
public final class OptimizedSyntaxHighlightingCoordinator {
    private static let logger = CodeEditorLog.logger(category: "OptimizedSyntaxHighlighting")
    // MARK: - Types

    private struct PerformanceData {
        let tokenizationTime: TimeInterval
        let cacheCheckTime: TimeInterval
        let highlightingTime: TimeInterval
        let applyAttributesTime: TimeInterval
        let tokenCount: Int
        let cacheHit: Bool
        let language: Language
        let textLength: Int
        let totalStartTime: TimeInterval
    }

    public struct HighlightingConfiguration: Sendable {
        public var enableViewportOptimization: Bool = true
        public var viewportPadding: Int = 500 // Characters before/after visible range
        public var maxChunkSize: Int = 5_000 // Max characters per chunk
        public var enableIncrementalHighlighting: Bool = true
        public var cacheWarmingEnabled: Bool = true
        public var circuitBreakerThreshold: TimeInterval = 0.1 // 100ms

        public static let `default` = Self()

        public static let performance = Self(
            enableViewportOptimization: true,
            viewportPadding: 200,
            maxChunkSize: 2_000,
            enableIncrementalHighlighting: true,
            cacheWarmingEnabled: true,
            circuitBreakerThreshold: 0.05
        )
    }

    // MARK: - Properties

    private let coordinator: SyntaxHighlightingCoordinator
    private let tokenCache: SmartTokenCache
    private let performanceTracker: SyntaxHighlightingPerformanceTracker
    private let memoryMonitor: MemoryMonitor
    private var configuration: HighlightingConfiguration

    // Circuit breaker state
    private var circuitBreakerTrips = 0
    private var lastCircuitBreakerReset = Date()

    // Incremental state
    private var cacheWarmingTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new optimized syntax highlighting coordinator.
    ///
    /// - Parameters:
    ///   - memoryMonitor: Memory monitor for tracking resource usage
    ///   - configuration: Highlighting configuration with optimization settings
    public init(
        memoryMonitor: MemoryMonitor,
        configuration: HighlightingConfiguration = .default
    ) {
        self.coordinator = SyntaxHighlightingCoordinator()
        self.tokenCache = SmartTokenCache()
        self.performanceTracker = SyntaxHighlightingPerformanceTracker()
        self.memoryMonitor = memoryMonitor
        self.configuration = configuration

        // Warm cache for common languages if enabled
        if configuration.cacheWarmingEnabled {
            cacheWarmingTask = Task { [weak self] in
                await self?.warmCache()
            }
        }
    }

    deinit {
        cacheWarmingTask?.cancel()
    }

    // MARK: - Public Methods

    /// Highlight text with optimizations
    public func highlight(
        text: String,
        language: Language,
        visibleRange: NSRange? = nil
    ) async -> [HighlightedToken] {
        let startTime = CFAbsoluteTimeGetCurrent()
        let textLength = TextRangeUtilities.utf16Length(of: text)

        // Check circuit breaker
        if shouldTripCircuitBreaker() {
            return [] // Return empty tokens to prevent further delays
        }

        // For plain text, return immediately
        if language == .plainText {
            trackPerformance(PerformanceData(
                tokenizationTime: 0,
                cacheCheckTime: 0,
                highlightingTime: 0,
                applyAttributesTime: 0,
                tokenCount: 0,
                cacheHit: false,
                language: language,
                textLength: textLength,
                totalStartTime: startTime
            ))
            return []
        }

        // Check cache
        let cacheCheckStart = CFAbsoluteTimeGetCurrent()
        let cacheKey = SmartTokenCache.CacheKey(text: text, language: language, version: 0)

        let cachedTokens = await tokenCache.getCachedTokens(for: cacheKey, viewportRange: visibleRange)
        if !cachedTokens.isEmpty {
            let cacheCheckTime = CFAbsoluteTimeGetCurrent() - cacheCheckStart

            trackPerformance(PerformanceData(
                tokenizationTime: 0,
                cacheCheckTime: cacheCheckTime,
                highlightingTime: 0,
                applyAttributesTime: 0,
                tokenCount: cachedTokens.count,
                cacheHit: true,
                language: language,
                textLength: textLength,
                totalStartTime: startTime
            ))

            return cachedTokens
        }

        let cacheCheckTime = CFAbsoluteTimeGetCurrent() - cacheCheckStart

        // Determine highlighting strategy
        let tokens: [HighlightedToken]
        let coverage: SmartTokenCache.CacheEntry.Coverage

        if configuration.enableViewportOptimization,
           let visibleRange,
           textLength > 10_000 {
            let result = await highlightViewport(
                text: text,
                language: language,
                visibleRange: visibleRange,
                cacheCheckTime: cacheCheckTime,
                totalStartTime: startTime
            )
            tokens = result.tokens
            coverage = .viewport(result.coveredRange)
        } else {
            tokens = await highlightFull(
                text: text,
                language: language,
                cacheCheckTime: cacheCheckTime,
                totalStartTime: startTime
            )
            coverage = .fullDocument
        }

        // Cache the result with explicit coverage so a later
        // full-document or non-overlapping viewport read doesn't get a
        // false hit against this partial result.
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        await tokenCache.setCachedTokens(
            tokens,
            for: cacheKey,
            computationTime: Duration.seconds(totalTime),
            coverage: coverage
        )

        return tokens
    }

    /// Apply highlighting to attributed string with performance tracking
    public func applyHighlighting(
        to attributedString: NSMutableAttributedString,
        tokens: [HighlightedToken],
        progressHandler: ((Double) -> Void)? = nil
    ) async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Remove existing highlighting
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.removeAttribute(.foregroundColor, range: range)

        // Apply in chunks for better responsiveness
        let chunkSize = 500
        for (index, token) in tokens.enumerated() {
            if index.isMultiple(of: chunkSize) {
                await Task.yield()
                progressHandler?(Double(index) / Double(tokens.count))

                // Check circuit breaker
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                if elapsed > configuration.circuitBreakerThreshold {
                    tripCircuitBreaker()
                    break
                }
            }

            guard token.range.location + token.range.length <= attributedString.length else {
                continue
            }

            attributedString.addAttribute(.foregroundColor, value: token.type.color, range: token.range)
        }

        progressHandler?(1.0)
    }

    /// Get performance report
    public func getPerformanceReport() -> String {
        performanceTracker.generateReport()
    }

    /// Update configuration
    public func updateConfiguration(_ configuration: HighlightingConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Private Methods

    private func highlightViewport(
        text: String,
        language: Language,
        visibleRange: NSRange,
        cacheCheckTime: TimeInterval,
        totalStartTime: TimeInterval
    ) async -> (tokens: [HighlightedToken], coveredRange: NSRange) {
        // Expand visible range with padding
        let textLength = TextRangeUtilities.utf16Length(of: text)
        let visibleRange = TextRangeUtilities.clampRange(visibleRange, toTextLength: textLength)
        let expandedStart = max(0, visibleRange.location - configuration.viewportPadding)
        let expandedEnd = min(
            textLength,
            NSMaxRange(visibleRange) + configuration.viewportPadding
        )
        let expandedRange = NSRange(location: expandedStart, length: expandedEnd - expandedStart)

        // Extract viewport text
        guard let viewportSlice = textSlice(from: text, range: expandedRange) else {
            return ([], visibleRange)
        }

        let viewportText = viewportSlice.text
        guard !viewportText.isEmpty else {
            return ([], viewportSlice.range)
        }

        let highlightStart = CFAbsoluteTimeGetCurrent()
        var tokens = await coordinator.highlightAsync(source: viewportText, language: language)
        let highlightTime = CFAbsoluteTimeGetCurrent() - highlightStart

        // Adjust token ranges to match original text
        tokens = tokens.map { token in
            HighlightedToken(
                range: NSRange(
                    location: token.range.location + viewportSlice.range.location,
                    length: token.range.length
                ),
                type: token.type,
                text: token.text
            )
        }

        trackPerformance(PerformanceData(
            tokenizationTime: 0,
            cacheCheckTime: cacheCheckTime,
            highlightingTime: highlightTime,
            applyAttributesTime: 0,
            tokenCount: tokens.count,
            cacheHit: false,
            language: language,
            textLength: TextRangeUtilities.utf16Length(of: viewportText),
            totalStartTime: totalStartTime
        ))

        // Coverage reflects the slice we actually tokenized, including
        // the padding expansion — that's what the caller stores in the
        // cache entry so future overlapping requests can hit safely.
        return (tokens, viewportSlice.range)
    }

    private func highlightFull(
        text: String,
        language: Language,
        cacheCheckTime: TimeInterval,
        totalStartTime: TimeInterval
    ) async -> [HighlightedToken] {
        let highlightStart = CFAbsoluteTimeGetCurrent()
        let textLength = TextRangeUtilities.utf16Length(of: text)

        // Use chunking for large texts
        if textLength > configuration.maxChunkSize {
            var allTokens: [HighlightedToken] = []
            var offset = 0

            while offset < textLength {
                let chunkLength = min(max(configuration.maxChunkSize, 1), textLength - offset)
                guard let chunkSlice = chunkSlice(from: text, startingAt: offset, preferredLength: chunkLength) else {
                    break
                }

                let chunk = chunkSlice.text
                guard !chunk.isEmpty else {
                    break
                }

                let chunkTokens = await coordinator.highlightAsync(source: chunk, language: language)

                // Adjust token ranges
                let adjustedTokens = chunkTokens.map { token in
                    HighlightedToken(
                        range: NSRange(
                            location: token.range.location + chunkSlice.range.location,
                            length: token.range.length
                        ),
                        type: token.type,
                        text: token.text
                    )
                }

                allTokens.append(contentsOf: adjustedTokens)
                offset = NSMaxRange(chunkSlice.range)

                // Yield to prevent blocking
                await Task.yield()
            }

            let highlightTime = CFAbsoluteTimeGetCurrent() - highlightStart

            trackPerformance(PerformanceData(
                tokenizationTime: 0,
                cacheCheckTime: cacheCheckTime,
                highlightingTime: highlightTime,
                applyAttributesTime: 0,
                tokenCount: allTokens.count,
                cacheHit: false,
                language: language,
                textLength: textLength,
                totalStartTime: totalStartTime
            ))

            return allTokens
        } else {
            let tokens = await coordinator.highlightAsync(source: text, language: language)
            let highlightTime = CFAbsoluteTimeGetCurrent() - highlightStart

            trackPerformance(PerformanceData(
                tokenizationTime: 0,
                cacheCheckTime: cacheCheckTime,
                highlightingTime: highlightTime,
                applyAttributesTime: 0,
                tokenCount: tokens.count,
                cacheHit: false,
                language: language,
                textLength: textLength,
                totalStartTime: totalStartTime
            ))

            return tokens
        }
    }

    private func shouldTripCircuitBreaker() -> Bool {
        // Reset circuit breaker after 1 minute
        if Date().timeIntervalSince(lastCircuitBreakerReset) > 60 {
            circuitBreakerTrips = 0
            lastCircuitBreakerReset = Date()
        }

        return circuitBreakerTrips > 5
    }

    private func tripCircuitBreaker() {
        circuitBreakerTrips += 1
        Self.logger.warning("Syntax highlighting circuit breaker tripped (\(circuitBreakerTrips) trips)")
    }

    private func textSlice(from text: String, range: NSRange) -> (text: String, range: NSRange)? {
        let textLength = TextRangeUtilities.utf16Length(of: text)
        let clampedRange = TextRangeUtilities.clampRange(range, toTextLength: textLength)

        if let substring = TextRangeUtilities.substring(inUTF16Range: clampedRange, from: text) {
            return (substring, clampedRange)
        }

        guard let alignedRange = TextRangeUtilities.characterAlignedRange(clampedRange, in: text),
              let substring = TextRangeUtilities.substring(inUTF16Range: alignedRange, from: text)
        else {
            return nil
        }

        return (substring, alignedRange)
    }

    private func chunkSlice(from text: String, startingAt offset: Int, preferredLength: Int) -> (text: String, range: NSRange)? {
        let textLength = TextRangeUtilities.utf16Length(of: text)
        guard offset < textLength else { return nil }

        var length = min(preferredLength, textLength - offset)
        while offset + length <= textLength {
            let range = NSRange(location: offset, length: length)
            if let substring = TextRangeUtilities.substring(inUTF16Range: range, from: text) {
                return (substring, range)
            }
            length += 1
        }

        return nil
    }

    private func trackPerformance(_ data: PerformanceData) {
        let totalTime = CFAbsoluteTimeGetCurrent() - data.totalStartTime

        let metrics = SyntaxHighlightingPerformanceTracker.PerformanceMetrics(
            tokenizationTime: data.tokenizationTime,
            cacheCheckTime: data.cacheCheckTime,
            highlightingTime: data.highlightingTime,
            applyAttributesTime: data.applyAttributesTime,
            totalTime: totalTime,
            tokenCount: data.tokenCount,
            cacheHit: data.cacheHit,
            language: data.language.name,
            textLength: data.textLength
        )

        performanceTracker.trackOperation(metrics: metrics)

        // Log slow operations
        if totalTime > 0.1 {
            Self.logger.warning(
                "Slow syntax highlighting: \(String(format: "%.3f", totalTime))s (\(data.language.name))"
            )
        }
    }

    private func warmCache() async {
        // Warm cache with common code snippets
        let commonSnippets = [
            ("func example() { }", Language.swift),
            ("class Example { }", Language.swift),
            ("{\"key\": \"value\"}", Language.json),
            ("def example():", Language.python),
            ("function example() { }", Language.javascript)
        ]

        for (snippet, language) in commonSnippets {
            guard !Task.isCancelled else { return }
            _ = await highlight(text: snippet, language: language)
        }
    }
}
