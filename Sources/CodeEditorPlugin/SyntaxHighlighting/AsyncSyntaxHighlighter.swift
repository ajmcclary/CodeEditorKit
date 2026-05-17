import CodeEditorCommon
import Foundation
#if canImport(AppKit)
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
    internal let performanceMonitor = SyntaxHighlightingPerformanceMonitor()

    // Smart cache for highlight results
    internal var tokenCache = SmartTokenCache()

    /// Enable background highlighting for large files
    public var enableBackgroundHighlighting: Bool = true

    /// File size threshold for background highlighting
    public var backgroundHighlightingThreshold: Int = 10_000

    // Memory monitor for managing cache memory
    private let memoryMonitor: MemoryMonitor

    // Performance metrics for production monitoring
    private let performanceMetrics: ProductionPerformanceMetrics

    // Error recovery coordinator
    private let errorRecovery = ErrorRecoveryCoordinator()

    // MARK: - Initialization

    /// Creates a new asynchronous syntax highlighter.
    ///
    /// - Parameters:
    ///   - memoryMonitor: Memory monitor for tracking resource usage
    ///   - performanceMetrics: Performance metrics instance (defaults to shared)
    ///   - debounceInterval: Time to wait before processing highlighting requests
    ///   - enablePeriodicOptimization: Whether to enable periodic cache optimization
    public init(memoryMonitor: MemoryMonitor, performanceMetrics: ProductionPerformanceMetrics? = nil, debounceInterval: Duration = .seconds(PlatformConstants.defaultAsyncHighlightingDebounceInterval), enablePeriodicOptimization: Bool = true) {
        self.coordinator = SyntaxHighlightingCoordinator()
        self.backgroundHighlighter = BackgroundSyntaxHighlighter(memoryMonitor: memoryMonitor)
        self.debounceInterval = debounceInterval
        self.memoryMonitor = memoryMonitor
        self.performanceMetrics = performanceMetrics ?? CodeEditorDependencies.makeProductionPerformanceMetrics()

        // Set up periodic cache optimization (can be disabled for tests)
        if enablePeriodicOptimization {
            setupPeriodicCacheOptimization()
        }

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

        // Check if streaming should be used
        #if canImport(AppKit)
        let text = textView.string
        #else
        let text = textView.text ?? ""
        #endif

        if shouldUseStreaming(for: text) {
            await highlightStreamingly(
                for: textView,
                language: language,
                visibleRange: visibleRange,
                configuration: .largeFile
            )
        } else {
            await performHighlighting(for: textView, language: language, visibleRange: visibleRange)
        }
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
        #if canImport(AppKit)
            let text = textView.string
        #else
            let text = textView.text ?? ""
        #endif
        let textLength = text.count

        // Check performance limits
        guard textLength <= textView.configuration.performance.maxSyntaxHighlightingLength else {
            // File too large for syntax highlighting - try streaming instead
            let error = SyntaxHighlightingError.textTooLarge(
                size: textLength,
                limit: textView.configuration.performance.maxSyntaxHighlightingLength
            )

            // Attempt recovery with streaming
            do {
                try await errorRecovery.recover(from: error) {
                    // Use streaming highlighter as recovery strategy
                    await self.highlightStreamingly(
                        for: textView,
                        language: language,
                        visibleRange: visibleRange,
                        configuration: .largeFile
                    )
                }
                return
            } catch is CancellationError {
                clearHighlighting(for: textView)
                return
            } catch {
                CrossPlatformLogger.logger().error(
                    "AsyncSyntaxHighlighter recovery path failed: \(error.localizedDescription); clearing highlighting"
                )
                clearHighlighting(for: textView)
                return
            }
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
            applyTokens(cachedTokens, to: textView, language: language, visibleRange: visibleRange)

            // Track cache hit
            await performanceMetrics.trackHighlighting(
                duration: 0.001, // Near-instant for cache hits
                fileSize: textLength,
                language: language,
                cacheHit: true
            )
            return
        }

        // Start new highlighting task
        let task = Task { [weak self] in
            guard let self else { return }

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                try await performanceMonitor.measure(category: .syntaxHighlighting) {
                    // Choose highlighting strategy based on text size and settings
                    var tokens: [HighlightedToken]

                    do {
                        if self.enableBackgroundHighlighting && textLength > self.backgroundHighlightingThreshold {
                            // Use background highlighter for large files
                            tokens = try await self.highlightWithBackgroundHighlighterSafe(
                                text: text,
                                language: language,
                                visibleRange: visibleRange
                            )
                        } else {
                            // Use synchronous highlighting for small files
                            tokens = try await self.highlightInBackgroundSafe(text: text, language: language)
                        }
                    } catch let error as SyntaxHighlightingError {
                        // Attempt error recovery
                        tokens = try await self.errorRecovery.recover(from: error) {
                            // Retry with fallback strategy
                            try await self.highlightInBackgroundSafe(text: text, language: language)
                        }
                    }

                    // Check if task was cancelled
                    guard !Task.isCancelled else {
                        throw SyntaxHighlightingError.cancelled
                    }

                    // Cache all results with performance metrics (including empty for consistency)
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let computationTime = Duration.seconds(endTime - startTime)
                    await self.tokenCache.setCachedTokens(tokens, for: cacheKey, computationTime: computationTime)

                    // Track performance metrics for production monitoring
                    await performanceMetrics.trackHighlighting(
                        duration: endTime - startTime,
                        fileSize: textLength,
                        language: language,
                        cacheHit: false
                    )

                    // Apply tokens on main thread
                    await MainActor.run {
                        self.applyTokens(tokens, to: textView, language: language, visibleRange: visibleRange)
                    }
                }
            } catch {
                // Log error and clear highlighting on failure
                CrossPlatformLogger.logger().error("Highlighting failed: \(error)")
                await MainActor.run {
                    self.clearHighlighting(for: textView)
                }
            }
        }

        // Store the task
        highlightingTask = task

        // Wait for the task to complete, optionally feeding UnifiedPerformanceSystem.
        if let ups = textView.configuration.performance.unifiedPerformanceSystem {
            await ups.track(.syntaxHighlighting) {
                await task.value
            }
        } else {
            await task.value
        }
    }

    nonisolated private func highlightInBackground(text: String, language: Language) async -> [HighlightedToken] {
        // Run the highlighting computation off the main thread for better performance
        await coordinator.highlightAsync(source: text, language: language)
    }

    nonisolated private func highlightInBackgroundSafe(text: String, language: Language) async throws -> [HighlightedToken] {
        // Check for cancellation
        try Task.checkCancellation()

        // Validate language support
        guard coordinator.supportsLanguage(language) else {
            throw SyntaxHighlightingError.languageNotSupported(language)
        }

        // Run the highlighting computation off the main thread for better performance
        let tokens = await coordinator.highlightAsync(source: text, language: language)

        // Check for cancellation again
        try Task.checkCancellation()

        return tokens
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

    private func highlightWithBackgroundHighlighterSafe(
        text: String,
        language: Language,
        visibleRange _: NSRange?
    ) async throws -> [HighlightedToken] {
        // Check memory pressure before processing large file
        let requiredMemoryMB = Double(text.count) / (1_024 * 1_024) * 2 // Rough estimate: 2x text size
        let availableMemoryMB = memoryMonitor.availableMemoryMB

        if availableMemoryMB < requiredMemoryMB {
            throw SyntaxHighlightingError.memoryPressure(
                availableMB: availableMemoryMB,
                requiredMB: requiredMemoryMB
            )
        }

        // For large texts, try streaming first
        if text.count > 500_000 {
            // Delegate to streaming highlighter
            throw SyntaxHighlightingError.textTooLarge(
                size: text.count,
                limit: 500_000
            )
        }

        return try await highlightInBackgroundSafe(text: text, language: language)
    }

    internal func applyTokens(
        _ tokens: [HighlightedToken],
        to textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil
    ) {
        let bridge = textView.textKitBridge
        let documentLength = bridge.documentLength
        guard documentLength > 0 else { return }

        // Determine range to apply
        let rangeToHighlight = visibleRange ?? NSRange(location: 0, length: documentLength)

        // Validate range
        guard rangeToHighlight.location >= 0,
              rangeToHighlight.location + rangeToHighlight.length <= documentLength else {
            CrossPlatformLogger.logger().warning("Invalid range for highlighting: \(rangeToHighlight) with text length: \(documentLength)")
            return
        }

        let appliedTheme = textView.appliedTheme
        let baseTextColor = Self.color(for: .identifier, theme: appliedTheme)
        CodeEditorRenderingDiagnostics.logHighlighting(
            "syntax.applyTokens.begin",
            textView: textView,
            language: language,
            tokenCount: tokens.count,
            range: rangeToHighlight,
            baseColor: baseTextColor
        )

        // Establish the base color across the entire range as rendering
        // attributes. Subsequent token color writes overwrite this for
        // matched ranges.
        bridge.addAttributes([.foregroundColor: baseTextColor], range: rangeToHighlight)

        // Apply new highlighting - batch tokens by color for performance
        var tokensByColor: [PlatformColor: [NSRange]] = [:]

        for token in tokens {
            // Validate that token.range is within bounds.
            guard
                token.range.location >= 0,
                token.range.length > 0,
                token.range.location < documentLength,
                token.range.location + token.range.length <= documentLength
            else {
                continue
            }

            // Neutral tokens render in the base editor foreground so theme
            // contrast is controlled by the theme's editor/token palette.
            if token.type == .identifier
                || token.type == .unknown
                || token.type == .punctuation {
                tokensByColor[baseTextColor, default: []].append(token.range)
                continue
            }

            // Group tokens by resolved theme/scheme color.
            let tokenColor = Self.color(for: token.type, theme: appliedTheme)
            tokensByColor[tokenColor, default: []].append(token.range)
        }

        // Apply each color group via rendering attributes.
        for (color, ranges) in tokensByColor {
            let mergedRanges = mergeAdjacentRanges(ranges)
            for range in mergedRanges {
                bridge.addAttributes([.foregroundColor: color], range: range)
            }
        }
        CodeEditorRenderingDiagnostics.logHighlighting(
            "syntax.applyTokens.end",
            textView: textView,
            language: language,
            tokenCount: tokens.count,
            range: rangeToHighlight,
            baseColor: baseTextColor
        )
    }

    private func clearHighlighting(for textView: CodeEditorView) {
        let bridge = textView.textKitBridge
        let range = NSRange(location: 0, length: bridge.documentLength)
        guard range.length > 0 else { return }

        CodeEditorRenderingDiagnostics.log(
            "syntax.clearHighlighting",
            textView: textView,
            theme: textView.appliedTheme,
            note: "range={\(range.location),\(range.length)}"
        )
        bridge.addAttributes(
            [.foregroundColor: Self.color(for: .identifier, theme: textView.appliedTheme)],
            range: range
        )
    }

    private static func color(for tokenType: TokenType, theme: Theme?) -> PlatformColor {
        guard let theme else {
            return SyntaxColorScheme.default.color(for: tokenType)
        }
        return SyntaxColorScheme.color(for: tokenType, in: theme)
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
        debounceTask?.cancel()
        periodicOptimizationTask?.cancel()
        highlightingTask?.cancel()
    }

    // MARK: - Cache Management

    private func setupPeriodicCacheOptimization() {
        // Set up task to periodically optimize cache (every 5 minutes).
        // Cancellation breaks the loop; transient errors are logged so a single
        // failure doesn't kill the periodic optimisation forever.
        periodicOptimizationTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(300))
                    await self?.optimizeCache()
                } catch is CancellationError {
                    break
                } catch {
                    CrossPlatformLogger.logger().error(
                        "AsyncSyntaxHighlighter periodic cache optimisation: \(error.localizedDescription); continuing"
                    )
                    continue
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
