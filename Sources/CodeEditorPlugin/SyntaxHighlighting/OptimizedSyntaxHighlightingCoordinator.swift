import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Optimized syntax highlighting coordinator with performance improvements
@MainActor
public final class OptimizedSyntaxHighlightingCoordinator {
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
    private var lastHighlightedText: String?
    private var lastHighlightedTokens: [HighlightedToken] = []
    
    // MARK: - Initialization
    
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
            Task {
                await warmCache()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Highlight text with optimizations
    public func highlight(
        text: String,
        language: Language,
        visibleRange: NSRange? = nil
    ) async -> [HighlightedToken] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
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
                textLength: text.count,
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
                textLength: text.count,
                totalStartTime: startTime
            ))
            
            return cachedTokens
        }
        
        let cacheCheckTime = CFAbsoluteTimeGetCurrent() - cacheCheckStart
        
        // Determine highlighting strategy
        let tokens: [HighlightedToken]
        
        if configuration.enableViewportOptimization && visibleRange != nil && text.count > 10_000 {
            tokens = await highlightViewport(
                text: text,
                language: language,
                visibleRange: visibleRange!,
                cacheCheckTime: cacheCheckTime,
                totalStartTime: startTime
            )
        } else if configuration.enableIncrementalHighlighting && canUseIncrementalHighlighting(text: text) {
            tokens = await highlightIncrementally(
                text: text,
                language: language,
                cacheCheckTime: cacheCheckTime,
                totalStartTime: startTime
            )
        } else {
            tokens = await highlightFull(
                text: text,
                language: language,
                cacheCheckTime: cacheCheckTime,
                totalStartTime: startTime
            )
        }
        
        // Cache the result
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        await tokenCache.setCachedTokens(
            tokens,
            for: cacheKey,
            computationTime: Duration.seconds(totalTime),
            viewportRange: visibleRange
        )
        
        // Update incremental state
        lastHighlightedText = text
        lastHighlightedTokens = tokens
        
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
    ) async -> [HighlightedToken] {
        // Expand visible range with padding
        let expandedRange = NSRange(
            location: max(0, visibleRange.location - configuration.viewportPadding),
            length: min(text.count - visibleRange.location, visibleRange.length + 2 * configuration.viewportPadding)
        )
        
        // Extract viewport text
        let start = text.index(text.startIndex, offsetBy: expandedRange.location)
        let end = text.index(start, offsetBy: expandedRange.length)
        let viewportText = String(text[start..<end])
        guard !viewportText.isEmpty else {
            return []
        }
        
        let highlightStart = CFAbsoluteTimeGetCurrent()
        var tokens = await coordinator.highlightAsync(source: viewportText, language: language)
        let highlightTime = CFAbsoluteTimeGetCurrent() - highlightStart
        
        // Adjust token ranges to match original text
        tokens = tokens.map { token in
            HighlightedToken(
                range: NSRange(
                    location: token.range.location + expandedRange.location,
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
            textLength: viewportText.count,
            totalStartTime: totalStartTime
        ))
        
        return tokens
    }
    
    private func highlightIncrementally(
        text: String,
        language: Language,
        cacheCheckTime: TimeInterval,
        totalStartTime: TimeInterval
    ) async -> [HighlightedToken] {
        // TODO: Implement incremental highlighting
        // For now, fall back to full highlighting
        await highlightFull(
            text: text,
            language: language,
            cacheCheckTime: cacheCheckTime,
            totalStartTime: totalStartTime
        )
    }
    
    private func highlightFull(
        text: String,
        language: Language,
        cacheCheckTime: TimeInterval,
        totalStartTime: TimeInterval
    ) async -> [HighlightedToken] {
        let highlightStart = CFAbsoluteTimeGetCurrent()
        
        // Use chunking for large texts
        if text.count > configuration.maxChunkSize {
            var allTokens: [HighlightedToken] = []
            var offset = 0
            
            while offset < text.count {
                let chunkLength = min(configuration.maxChunkSize, text.count - offset)
                _ = NSRange(location: offset, length: chunkLength)
                
                let chunkStart = text.index(text.startIndex, offsetBy: offset)
                let chunkEnd = text.index(chunkStart, offsetBy: chunkLength)
                let chunk = String(text[chunkStart..<chunkEnd])
                guard !chunk.isEmpty else {
                    break
                }
                
                let chunkTokens = await coordinator.highlightAsync(source: chunk, language: language)
                
                // Adjust token ranges
                let adjustedTokens = chunkTokens.map { token in
                    HighlightedToken(
                        range: NSRange(
                            location: token.range.location + offset,
                            length: token.range.length
                        ),
                        type: token.type,
                        text: token.text
                    )
                }
                
                allTokens.append(contentsOf: adjustedTokens)
                offset += chunkLength
                
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
                textLength: text.count,
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
                textLength: text.count,
                totalStartTime: totalStartTime
            ))
            
            return tokens
        }
    }
    
    private func canUseIncrementalHighlighting(text: String) -> Bool {
        guard let lastText = lastHighlightedText else { return false }
        
        // Simple heuristic: use incremental if texts are similar in length
        let lengthDiff = abs(text.count - lastText.count)
        return lengthDiff < 1_000 && lengthDiff < lastText.count / 10
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
        CrossPlatformLogger.logger().warning("Syntax highlighting circuit breaker tripped (\(circuitBreakerTrips) trips)")
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
            CrossPlatformLogger.logger().warning(
                "⚠️ Slow SyntaxHighlighting: \(String(format: "%.3f", totalTime))s (\(data.language.name))"
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
            _ = await highlight(text: snippet, language: language)
        }
    }
}
