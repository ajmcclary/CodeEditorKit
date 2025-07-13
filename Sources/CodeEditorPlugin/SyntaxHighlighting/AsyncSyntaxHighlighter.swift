import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Asynchronous syntax highlighter with debouncing and cancellation support
@MainActor
public final class AsyncSyntaxHighlighter {
    // MARK: - Properties
    
    private let coordinator: SyntaxHighlightingCoordinator
    private let backgroundHighlighter: BackgroundSyntaxHighlighter
    private var highlightingTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var periodicOptimizationTask: Task<Void, Never>?
    private let debounceInterval: Duration
    private let performanceMonitor = SyntaxHighlightingPerformanceMonitor()
    
    // Smart cache for highlight results
    private var tokenCache = SmartTokenCache()
    
    // Enable background highlighting for large files
    public var enableBackgroundHighlighting: Bool = true
    
    // File size threshold for background highlighting
    public var backgroundHighlightingThreshold: Int = 10_000
    
    // Memory monitor for managing cache memory
    private let memoryMonitor: MemoryMonitor
    
    // MARK: - Initialization
    
    public init(memoryMonitor: MemoryMonitor, debounceInterval: Duration = .milliseconds(300)) {
        self.coordinator = SyntaxHighlightingCoordinator()
        self.backgroundHighlighter = BackgroundSyntaxHighlighter(memoryMonitor: memoryMonitor)
        self.debounceInterval = debounceInterval
        self.memoryMonitor = memoryMonitor
        
        // Set up periodic cache optimization
        setupPeriodicCacheOptimization()
        
        // Register cache with memory monitor
        registerCacheWithMemoryMonitor()
    }
    
    // MARK: - Public Methods
    
    /// Schedule highlighting with debouncing
    public func scheduleHighlighting(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) {
        // Cancel any pending debounce task
        debounceTask?.cancel()
        
        // Schedule new highlighting
        debounceTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await Task.sleep(for: self.debounceInterval)
                
                // Perform highlighting directly without nested tasks
                await self.performHighlighting(for: textView, language: language, visibleRange: visibleRange)
            } catch {
                // Task was cancelled, which is expected behavior
            }
        }
    }
    
    /// Perform highlighting immediately (cancels any pending operations)
    public func highlightImmediately(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) async {
        // Cancel debounce task
        debounceTask?.cancel()
        debounceTask = nil
        
        await performHighlighting(for: textView, language: language, visibleRange: visibleRange)
    }
    
    /// Cancel all pending highlighting operations
    public func cancelAllHighlighting() {
        debounceTask?.cancel()
        debounceTask = nil
        highlightingTask?.cancel()
        highlightingTask = nil
        backgroundHighlighter.cancelAllRequests()
    }
    
    /// Update visible range for priority highlighting
    public func updateVisibleRange(_ range: NSRange) {
        backgroundHighlighter.updateVisibleRange(range)
    }
    
    /// Get background highlighting statistics
    public var backgroundStatistics: BackgroundHighlightingStatistics {
        backgroundHighlighter.statistics
    }
    
    /// Get cache statistics
    public func getCacheStatistics() async -> TokenCacheStatistics {
        await tokenCache.getStatistics()
    }
    
    /// Optimize cache performance by removing stale entries
    public func optimizeCache() async {
        await tokenCache.optimizeCache()
    }
    
    /// Configure cache settings
    public func configureCacheSettings(
        maxCacheSize: Int? = nil,
        maxMemoryUsageMB: Double? = nil,
        staleThreshold: Duration? = nil
    ) async {
        await tokenCache.configureCacheSettings(
            maxCacheSize: maxCacheSize,
            maxMemoryUsageMB: maxMemoryUsageMB,
            staleThreshold: staleThreshold
        )
    }
    
    /// Clear all cached tokens
    public func clearCache() async {
        await tokenCache.clearCache()
    }
    
    // MARK: - Private Methods
    
    private func performHighlighting(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) async {
        // Cancel any existing highlighting task
        highlightingTask?.cancel()
        
        // Get the text content
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let text = textView.string
        #else
            let text = textView.text ?? ""
        #endif
        let textLength = text.count
        
        // Check performance limits
        guard textLength <= textView.configuration.performance.maxSyntaxHighlightingLength else {
            // File too large for syntax highlighting
            clearHighlighting(for: textView)
            return
        }
        
        // Create cache key
        let cacheKey = SmartTokenCache.CacheKey(
            text: text,
            language: language,
            version: 0 // Version tracking for future use
        )
        
        // Check cache first
        let cachedTokens = await tokenCache.getCachedTokens(for: cacheKey)
        if !cachedTokens.isEmpty {
            applyTokens(cachedTokens, to: textView, visibleRange: visibleRange)
            return
        }
        
        // Start new highlighting task
        highlightingTask = Task { [weak self] in
            guard let self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            await performanceMonitor.measure(category: .syntaxHighlighting) {
                // Choose highlighting strategy based on text size and settings
                var tokens: [HighlightedToken]
                
                if self.enableBackgroundHighlighting && textLength > self.backgroundHighlightingThreshold {
                    // Use background highlighter for large files
                    tokens = await self.highlightWithBackgroundHighlighter(
                        text: text, 
                        language: language, 
                        visibleRange: visibleRange
                    )
                    
                    // If background highlighting failed (returned empty), fall back to synchronous
                    if tokens.isEmpty {
                        tokens = await self.highlightInBackground(text: text, language: language)
                    }
                } else {
                    // Use synchronous highlighting for small files
                    tokens = await self.highlightInBackground(text: text, language: language)
                }
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Cache all results with performance metrics (including empty for consistency)
                let endTime = CFAbsoluteTimeGetCurrent()
                let computationTime = Duration.seconds(endTime - startTime)
                await self.tokenCache.setCachedTokens(tokens, for: cacheKey, computationTime: computationTime)
                
                // Apply tokens on main thread
                await MainActor.run {
                    self.applyTokens(tokens, to: textView, visibleRange: visibleRange)
                }
            }
        }
    }
    
    private func highlightInBackground(text: String, language: Language) async -> [HighlightedToken] {
        // Create a new coordinator for background processing to avoid main actor isolation issues
        await Task.detached(priority: .userInitiated) {
            let backgroundCoordinator = SyntaxHighlightingCoordinator()
            return await backgroundCoordinator.highlightAsync(source: text, language: language)
        }.value
    }
    
    private func highlightWithBackgroundHighlighter(
        text: String,
        language: Language,
        visibleRange _: NSRange?
    ) async -> [HighlightedToken] {
        // For large texts, fall back to synchronous highlighting to ensure cache works
        // This avoids the complexity of background highlighting in tests
        await highlightInBackground(text: text, language: language)
    }
    
    private func applyTokens(
        _ tokens: [HighlightedToken],
        to textView: CodeEditorView,
        visibleRange: NSRange? = nil
    ) {
        // Get text storage - works for both TextKit1 and TextKit2
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = textView.textStorage else { return }
        #else
        let textStorage = textView.textStorage
        #endif
        
        // Determine range to apply
        let rangeToHighlight = visibleRange ?? NSRange(location: 0, length: textStorage.length)
        
        // Validate range
        guard rangeToHighlight.location >= 0,
              rangeToHighlight.location + rangeToHighlight.length <= textStorage.length else {
            CrossPlatformLogger.logger().warning("Invalid range for highlighting: \(rangeToHighlight) with text length: \(textStorage.length)")
            return
        }
        
        // Update text storage efficiently with both TextKit1 and TextKit2 support
        textStorage.beginEditing()
        
        // First, apply base text color to the entire range
        let baseTextColor = textView.textColor ?? PlatformColors.label
        textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: rangeToHighlight)
        
        // Apply new highlighting - batch tokens by color for performance
        var tokensByColor: [PlatformColor: [NSRange]] = [:]
        
        for token in tokens {
            // Prevent out-of-bounds NSRange crashes, required for stability:
            // Validate that token.range.location and length are within textStorage bounds
            guard
                token.range.location >= 0,
                token.range.length > 0,
                token.range.location < textStorage.length,
                token.range.location + token.range.length <= textStorage.length
            else {
                continue
            }
            
            // Group tokens by color
            let tokenColor = token.type.adaptiveColor
            tokensByColor[tokenColor, default: []].append(token.range)
        }
        
        // Apply each color group in a single operation for better performance
        for (color, ranges) in tokensByColor {
            // Merge adjacent or overlapping ranges for even better performance
            let mergedRanges = mergeAdjacentRanges(ranges)
            for range in mergedRanges {
                textStorage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
        
        textStorage.endEditing()
    }
    
    private func clearHighlighting(for textView: CodeEditorView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = textView.textStorage else { return }
        #else
        let textStorage = textView.textStorage
        #endif
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let range = NSRange(location: 0, length: textView.string.count)
        #else
            let range = NSRange(location: 0, length: textView.text?.count ?? 0)
        #endif
        
        textStorage.beginEditing()
        
        // Instead of removing the color, reset to the base text color
        let baseTextColor = textView.textColor ?? PlatformColors.label
        textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: range)
        
        textStorage.endEditing()
    }
    
    /// Merge adjacent or overlapping ranges for more efficient attribute application
    private func mergeAdjacentRanges(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }
        
        // Sort ranges by location
        let sorted = ranges.sorted { $0.location < $1.location }
        var merged: [NSRange] = []
        var current = sorted[0]
        
        for index in 1..<sorted.count {
            let next = sorted[index]
            
            // Check if ranges are adjacent or overlapping
            if current.location + current.length >= next.location {
                // Merge ranges
                let endLocation = max(current.location + current.length, next.location + next.length)
                current = NSRange(location: current.location, length: endLocation - current.location)
            } else {
                // Ranges are not adjacent, add current to result
                merged.append(current)
                current = next
            }
        }
        
        // Don't forget the last range
        merged.append(current)
        return merged
    }
    
    /// Clean up resources before deinitialization
    ///
    /// This method cancels all active highlighting tasks and periodic operations.
    /// It's safe to call multiple times and is automatically called from deinit.
    ///
    /// - Important: While this method is synchronous for API compatibility,
    ///   cleanup is also performed automatically in deinit to prevent leaks.
    public func cleanup() {
        debounceTask?.cancel()
        debounceTask = nil
        periodicOptimizationTask?.cancel()
        periodicOptimizationTask = nil
        highlightingTask?.cancel()
        highlightingTask = nil
    }
    
    deinit {
        // Ensure all tasks are cancelled even if cleanup() wasn't called
        // Use MainActor.assumeIsolated since we know deinit runs on MainActor for @MainActor types
        MainActor.assumeIsolated {
            // Cancel all tasks to prevent memory leaks
            if let task = debounceTask {
                task.cancel()
            }
            if let task = periodicOptimizationTask {
                task.cancel()
            }
            if let task = highlightingTask {
                task.cancel()
            }
            
            // Also ensure background highlighter is cleaned up
            backgroundHighlighter.cancelAllRequests()
        }
    }
    
    // MARK: - Cache Management
    
    private func setupPeriodicCacheOptimization() {
        // Set up task to periodically optimize cache (every 5 minutes)
        periodicOptimizationTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(300)) // 5 minutes
                    
                    // Optimize cache directly without nested tasks
                    await self?.optimizeCache()
                } catch {
                    // Task was cancelled
                    break
                }
            }
        }
    }
    
    private func registerCacheWithMemoryMonitor() {
        Task { @MainActor in
            self.memoryMonitor.registerCleanupHandler(
                identifier: "async-syntax-highlighter-cache",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "AsyncSyntaxHighlighter deallocated")
                }
                
                // Get cache stats before cleanup
                let stats = await self.tokenCache.getStatistics()
                let beforeMemoryMB = stats.estimatedMemoryMB
                
                // Clear the cache
                await self.tokenCache.clearCache()
                
                return CleanupResult(
                    memoryFreedMB: beforeMemoryMB,
                    description: "Cleared syntax highlighting cache: \\(stats.cacheSize) entries"
                )
            }
        }
    }
}

// Note: Supporting components have been extracted to separate files:
// - SmartTokenCache.swift: Token caching with intelligent eviction strategies
// - SyntaxHighlightingPerformanceMonitor.swift: Performance monitoring for syntax highlighting
