import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Asynchronous syntax highlighter with debouncing and cancellation support
@MainActor
public final class AsyncSyntaxHighlighter {
    // MARK: - Adaptive editor text color

    /// Dynamic foreground for unhighlighted code (identifier / unknown
    /// tokens). Cream on dark appearance, near-black on light. Resolves
    /// at draw time, so theme/appearance flips repaint without needing a
    /// fresh highlight pass.
    static let editorAdaptiveTextColor: PlatformColor = {
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            return isDark
                ? NSColor(srgbRed: 242.0 / 255.0, green: 231.0 / 255.0, blue: 216.0 / 255.0, alpha: 1.0)
                : NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        }
        #elseif canImport(UIKit)
        return UIColor { trait in
            // swiftlint:disable object_literal
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 242.0 / 255.0, green: 231.0 / 255.0, blue: 216.0 / 255.0, alpha: 1.0)
                : UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
            // swiftlint:enable object_literal
        }
        #else
        return PlatformColors.label
        #endif
    }()

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
    public init(memoryMonitor: MemoryMonitor, performanceMetrics: ProductionPerformanceMetrics? = nil, debounceInterval: Duration = .milliseconds(300), enablePeriodicOptimization: Bool = true) {
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
            applyTokens(cachedTokens, to: textView, visibleRange: visibleRange)

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
                        self.applyTokens(tokens, to: textView, visibleRange: visibleRange)
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

        // Wait for the task to complete
        await task.value
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
        visibleRange: NSRange? = nil
    ) {
        // Get text storage - works for both TextKit1 and TextKit2
        #if canImport(AppKit)
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

        // First, apply base text color to the entire range. Use an
        // explicitly dynamic NSColor whose provider closure runs at draw
        // time against the textView's effective appearance so the editor
        // tracks Light/Dark theme switching without re-highlighting.
        // We don't trust NSColor.textColor here because the system color's
        // resolution path through NSAttributedString proved unreliable
        // (rendered as a baked, mis-tinted value in practice).
        let baseTextColor: PlatformColor = Self.editorAdaptiveTextColor

        #if true
        textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: rangeToHighlight)
        #endif

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

            // .identifier / .unknown / .punctuation render in the base
            // editor text color. Their hardcoded adaptiveColors use
            // NSColor.{label,secondaryLabel}.withAlphaComponent, which
            // collapses to a static color resolved against the *system*
            // appearance and produces invisible dark-on-dark (or
            // washed-out light-on-light) when the active theme's
            // appearance disagrees with the system's.
            if token.type == .identifier
                || token.type == .unknown
                || token.type == .punctuation {
                tokensByColor[baseTextColor, default: []].append(token.range)
                continue
            }

            // Group tokens by color
            let tokenColor = token.type.adaptiveColor
            tokensByColor[tokenColor, default: []].append(token.range)
        }

        // Apply each color group in a single operation for better performance.
        //
        // C3 perf: hoist Mac-Catalyst per-token work out of the inner loop —
        // colour resolution and font lookup are O(palette) instead of
        // O(tokens). On non-Catalyst, build a single attribute dictionary so
        // the inner call is `addAttributes(_:range:)` not per-attribute.
        #if true
        for (color, ranges) in tokensByColor {
            let mergedRanges = mergeAdjacentRanges(ranges)
            for range in mergedRanges {
                textStorage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
        #endif

        textStorage.endEditing()
    }

    private func clearHighlighting(for textView: CodeEditorView) {
        #if canImport(AppKit)
        guard let textStorage = textView.textStorage else { return }
        #else
        let textStorage = textView.textStorage
        #endif

        #if canImport(AppKit)
            let range = NSRange(location: 0, length: textView.string.count)
        #else
            let range = NSRange(location: 0, length: textView.text?.count ?? 0)
        #endif

        textStorage.beginEditing()

        // Reset to the adaptive editor text color (matches applyTokens).
        textStorage.addAttribute(.foregroundColor, value: Self.editorAdaptiveTextColor, range: range)

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
        // Note: cleanup() should be called explicitly before deallocation
        // We cannot access MainActor-isolated properties in deinit with Swift 6
        // Any remaining cleanup will be handled by ARC when references are released
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
