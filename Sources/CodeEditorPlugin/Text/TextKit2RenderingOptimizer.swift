import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Optimizes TextKit2 rendering performance for large files
@MainActor
public final class TextKit2RenderingOptimizer: ObservableObject {
    // MARK: - Configuration

    /// Maximum number of text layout fragments to keep in memory
    public var maxCachedFragments: Int = 500

    /// Size threshold for considering a file "large" (in characters)
    public var largeFileThreshold: Int = 50_000

    /// Enable viewport-based fragment management
    public var enableViewportOptimization: Bool = true

    /// Prefetch distance around visible area (as multiplier of visible area)
    public var prefetchMultiplier: Double = 1.5

    /// Enable text layout fragment recycling
    public var enableFragmentRecycling: Bool = true

    // MARK: - State

    /// Current rendering statistics
    @Published public private(set) var renderingStats = RenderingStatistics()

    /// Fragment cache for viewport optimization
    private var fragmentCache: [NSRange: CachedFragment] = [:]

    /// Recycled fragments pool
    private var recycledFragments: [NSTextLayoutFragment] = []

    /// Currently visible range
    private var visibleRange = NSRange(location: 0, length: 0)

    /// Text layout manager being optimized
    private weak var textLayoutManager: NSTextLayoutManager?

    /// Text content storage
    private weak var textContentStorage: NSTextContentStorage?

    /// Performance monitoring
    private var layoutTimes: [TimeInterval] = []
    private let maxLayoutTimeSamples = 50

    /// Memory monitor for managing cache memory
    private let memoryMonitor: MemoryMonitor

    // MARK: - Initialization

    public init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
        // Register with memory monitor
        registerWithMemoryMonitor()
    }

    // MARK: - Public Methods

    /// Configure the optimizer for a specific text view
    /// - Parameters:
    ///   - textLayoutManager: The TextKit2 layout manager to optimize
    ///   - textContentStorage: The text content storage
    public func configure(
        textLayoutManager: NSTextLayoutManager,
        textContentStorage: NSTextContentStorage
    ) {
        self.textLayoutManager = textLayoutManager
        self.textContentStorage = textContentStorage

        // Set up layout optimization if file is large
        if let documentLength = textContentStorage.textStorage?.length, documentLength > largeFileThreshold {
            enableLargeFileOptimizations()
        }
    }

    /// Update the visible range for viewport optimization
    /// - Parameter range: The currently visible text range
    public func updateVisibleRange(_ range: NSRange) {
        guard enableViewportOptimization else { return }

        renderingStats.recordVisibleRangeCalculation()

        let oldVisibleRange = visibleRange
        visibleRange = range

        // Only process if visible range changed significantly
        let changeThreshold = max(100, range.length / 10)
        if abs(range.location - oldVisibleRange.location) > changeThreshold ||
           abs(range.length - oldVisibleRange.length) > changeThreshold {
            optimizeForVisibleRange(range)
        }
    }

    /// Optimize layout for large files
    public func optimizeLargeFileLayout() {
        guard let textLayoutManager,
              textContentStorage != nil else { return }

        let startTime = Date()

        // Enable viewport-based layout if not already enabled
        if enableViewportOptimization {
            configureViewportOptimization(textLayoutManager)
        }

        // Configure fragment recycling
        if enableFragmentRecycling {
            configureFragmentRecycling(textLayoutManager)
        }

        // Optimize text container settings
        optimizeTextContainerSettings(textLayoutManager)

        let processingTime = Date().timeIntervalSince(startTime)
        recordLayoutOptimization(processingTime: processingTime)
    }

    /// Prefetch layout for upcoming content
    /// - Parameters:
    ///   - direction: Direction of scrolling/navigation
    ///   - distance: Distance to prefetch (in characters)
    public func prefetchLayout(direction: ScrollDirection, distance: Int = 5_000) {
        guard textLayoutManager != nil,
              enableViewportOptimization else { return }

        let prefetchRange: NSRange

        switch direction {
        case .up:
            let location = max(0, visibleRange.location - distance)
            let length = min(distance, visibleRange.location - location)
            prefetchRange = NSRange(location: location, length: length)

        case .down:
            let maxLength = textContentStorage?.textStorage?.length ?? 0
            let location = visibleRange.upperBound
            let length = min(distance, maxLength - location)
            prefetchRange = NSRange(location: location, length: length)
        }

        // Prefetch layout asynchronously
        Task {
            await prefetchLayoutAsync(for: prefetchRange)
        }
    }

    /// Force cleanup of cached fragments outside visible area
    public func cleanupNonVisibleFragments() {
        guard enableViewportOptimization else { return }

        let expandedRange = calculateExpandedRange(visibleRange)
        var removedCount = 0

        for (range, _) in fragmentCache where NSIntersectionRange(expandedRange, range).length == 0 {
            fragmentCache.removeValue(forKey: range)
            removedCount += 1
        }

        renderingStats.recordFragmentCleanup(removedCount: removedCount)
    }

    /// Reset optimizer state
    public func reset() {
        fragmentCache.removeAll()
        recycledFragments.removeAll()
        visibleRange = NSRange(location: 0, length: 0)
        renderingStats.reset()
        layoutTimes.removeAll()
    }

    // MARK: - Private Methods

    private func enableLargeFileOptimizations() {
        // Enable all optimizations for large files
        enableViewportOptimization = true
        enableFragmentRecycling = true
        maxCachedFragments = 1_000 // Increase cache for large files
        prefetchMultiplier = 2.0 // Larger prefetch area

        renderingStats.recordLargeFileOptimization()
    }

    private func optimizeForVisibleRange(_ range: NSRange) {
        let startTime = Date()

        // Calculate expanded range for prefetching
        let expandedRange = calculateExpandedRange(range)

        // Cleanup fragments outside the expanded range
        cleanupFragmentsOutside(expandedRange)

        // Ensure fragments are cached for the expanded range
        cacheFragmentsForRange(expandedRange)

        let processingTime = Date().timeIntervalSince(startTime)
        recordLayoutOptimization(processingTime: processingTime)
    }

    private func calculateExpandedRange(_ range: NSRange) -> NSRange {
        let expansion = Int(Double(range.length) * (prefetchMultiplier - 1.0) / 2.0)
        let expandedLocation = max(0, range.location - expansion)
        let maxLength = textContentStorage?.textStorage?.length ?? range.upperBound
        let expandedUpperBound = min(maxLength, range.upperBound + expansion)

        return NSRange(
            location: expandedLocation,
            length: expandedUpperBound - expandedLocation
        )
    }

    private func cleanupFragmentsOutside(_ keepRange: NSRange) {
        var toRemove: [NSRange] = []

        for (range, _) in fragmentCache where NSIntersectionRange(keepRange, range).length == 0 {
            toRemove.append(range)
        }

        for range in toRemove {
            if let fragment = fragmentCache.removeValue(forKey: range) {
                // Add to recycling pool if enabled
                if enableFragmentRecycling && recycledFragments.count < 50 {
                    recycledFragments.append(fragment.layoutFragment)
                }
            }
        }

        if !toRemove.isEmpty {
            renderingStats.recordFragmentCleanup(removedCount: toRemove.count)
        }
    }

    private func cacheFragmentsForRange(_ range: NSRange) {
        guard let textLayoutManager else { return }

        // Break range into chunks for efficient processing
        let chunkSize = 1_000
        var currentLocation = range.location

        while currentLocation < range.upperBound {
            let chunkLength = min(chunkSize, range.upperBound - currentLocation)
            let chunkRange = NSRange(location: currentLocation, length: chunkLength)

            // Check if we already have this chunk cached
            if !isRangeCached(chunkRange) {
                cacheFragmentForChunk(chunkRange, layoutManager: textLayoutManager)
            }

            currentLocation += chunkLength
        }
    }

    private func isRangeCached(_ range: NSRange) -> Bool {
        fragmentCache.contains { cachedRange, _ in
            NSLocationInRange(range.location, cachedRange) && NSLocationInRange(NSMaxRange(range) - 1, cachedRange)
        }
    }

    private func cacheFragmentForChunk(_ range: NSRange, layoutManager _: NSTextLayoutManager) {
        // For now, we'll create a simple cache entry
        // In a full implementation, this would create or retrieve actual layout fragments
        let cachedFragment = CachedFragment(
            range: range,
            layoutFragment: createOrRecycleFragment(),
            timestamp: Date()
        )

        fragmentCache[range] = cachedFragment
        renderingStats.recordFragmentCached()
    }

    private func createOrRecycleFragment() -> NSTextLayoutFragment {
        // Try to recycle an existing fragment
        if enableFragmentRecycling && !recycledFragments.isEmpty {
            return recycledFragments.removeFirst()
        }

        // Create new fragment (simplified - real implementation would be more complex)
        let textElement = NSTextParagraph(attributedString: NSAttributedString())
        return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
    }

    private func configureViewportOptimization(_: NSTextLayoutManager) {
        // Configure layout manager for viewport optimization
        // This would involve setting up proper text layout fragment generation

        renderingStats.recordViewportOptimizationEnabled()
    }

    private func configureFragmentRecycling(_: NSTextLayoutManager) {
        // Configure fragment recycling
        // This would involve setting up fragment reuse patterns

        renderingStats.recordFragmentRecyclingEnabled()
    }

    private func optimizeTextContainerSettings(_ layoutManager: NSTextLayoutManager) {
        // Optimize text container settings for large files
        guard let textContainer = layoutManager.textContainer else { return }

        #if canImport(AppKit)
        // Optimize for macOS
        textContainer.heightTracksTextView = false
        textContainer.widthTracksTextView = true

        // Set reasonable line fragment padding for performance
        textContainer.lineFragmentPadding = 5.0
        #endif

        renderingStats.recordContainerOptimization()
    }

    private func prefetchLayoutAsync(for _: NSRange) async {
        // Perform prefetch layout in background
        let startTime = Date()

        // Simulate prefetch work (real implementation would do actual layout)
        await Task.yield()

        let processingTime = Date().timeIntervalSince(startTime)
        await MainActor.run {
            renderingStats.recordPrefetchOperation(processingTime: processingTime)
        }
    }

    private func recordLayoutOptimization(processingTime: TimeInterval) {
        layoutTimes.append(processingTime)
        if layoutTimes.count > maxLayoutTimeSamples {
            layoutTimes.removeFirst()
        }

        let averageTime = layoutTimes.reduce(0, +) / Double(layoutTimes.count)
        renderingStats.recordLayoutOptimization(
            processingTime: processingTime,
            averageTime: averageTime
        )
    }

    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            self.memoryMonitor.registerCleanupHandler(
                identifier: "textkit2-rendering-optimizer",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "TextKit2RenderingOptimizer deallocated")
                }

                // Clear fragment cache
                let beforeCacheSize = self.fragmentCache.count
                self.fragmentCache.removeAll()

                // Clear recycled fragments
                let beforeRecycledCount = self.recycledFragments.count
                self.recycledFragments.removeAll()

                // Reset statistics
                self.renderingStats.reset()
                self.layoutTimes.removeAll()

                // Estimate memory freed
                let estimatedMemoryMB = Double(beforeCacheSize + beforeRecycledCount) * 0.02 // 20KB per fragment estimate

                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Cleared \(beforeCacheSize) cached fragments and \(beforeRecycledCount) recycled fragments"
                )
            }
        }
    }

    /// Get a performance report with detailed metrics
    /// - Returns: A formatted performance report
    public func performanceReport() -> String {
        let stats = renderingStats

        return """
        TextKit2 Rendering Performance Report
        ====================================

        Basic Metrics:
        - Total Optimizations: \(stats.totalOptimizations)
        - Average Optimization Time: \(String(format: "%.2f", stats.averageOptimizationTime * 1_000))ms
        - Fragments Cached: \(stats.fragmentsCached)
        - Cache Hit Rate: \(String(format: "%.1f", stats.cacheHitRate * 100))%

        Performance Timing:
        - Fragment Creation: \(String(format: "%.2f", stats.fragmentCreationTime))ms avg
        - Layout Calculation: \(String(format: "%.2f", stats.layoutCalculationTime))ms avg
        - Drawing Time: \(String(format: "%.2f", stats.drawingTime))ms avg

        Memory Usage:
        - Current: \(String(format: "%.1f", stats.currentMemoryUsageMB))MB
        - Peak: \(String(format: "%.1f", stats.peakMemoryUsageMB))MB
        - Memory Pressure Events: \(stats.memoryPressureEvents)

        Performance Budgets:
        - Layout Budget Exceeded: \(stats.layoutBudgetExceeded) times
        - Rendering Budget Exceeded: \(stats.renderingBudgetExceeded) times
        - Memory Budget Exceeded: \(stats.memoryBudgetExceeded) times

        Optimization Features:
        - Viewport Optimizations: \(stats.viewportOptimizationsEnabled)
        - Large File Optimizations: \(stats.largeFileOptimizationsEnabled)
        - Fragment Recycling: \(stats.fragmentRecyclingEnabled)
        """
    }
}

/// Cached text layout fragment
private struct CachedFragment {
    let range: NSRange
    let layoutFragment: NSTextLayoutFragment
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}

/// Rendering performance statistics with detailed metrics
@MainActor
public final class RenderingStatistics: ObservableObject {
    // MARK: - Basic Statistics
    @Published public private(set) var totalOptimizations: Int = 0
    @Published public private(set) var averageOptimizationTime: TimeInterval = 0
    @Published public private(set) var fragmentsCached: Int = 0
    @Published public private(set) var fragmentsCleaned: Int = 0
    @Published public private(set) var prefetchOperations: Int = 0
    @Published public private(set) var averagePrefetchTime: TimeInterval = 0
    @Published public private(set) var largeFileOptimizationsEnabled: Int = 0
    @Published public private(set) var viewportOptimizationsEnabled: Int = 0
    @Published public private(set) var fragmentRecyclingEnabled: Int = 0
    @Published public private(set) var containerOptimizations: Int = 0
    @Published public private(set) var lastOptimizationTime: Date?

    // MARK: - Detailed Performance Metrics
    @Published public private(set) var fragmentCreationTime: TimeInterval = 0
    @Published public private(set) var layoutCalculationTime: TimeInterval = 0
    @Published public private(set) var drawingTime: TimeInterval = 0
    @Published public private(set) var cacheHitRate: Double = 0
    @Published public private(set) var memoryPressureEvents: Int = 0
    @Published public private(set) var layoutInvalidations: Int = 0
    @Published public private(set) var visibleRangeCalculations: Int = 0
    @Published public private(set) var peakMemoryUsageMB: Double = 0
    @Published public private(set) var currentMemoryUsageMB: Double = 0

    // MARK: - Performance Budgets
    @Published public private(set) var layoutBudgetExceeded: Int = 0
    @Published public private(set) var renderingBudgetExceeded: Int = 0
    @Published public private(set) var memoryBudgetExceeded: Int = 0

    // Performance thresholds
    private let layoutBudgetMs: TimeInterval = 16.67 // 60fps target
    private let renderingBudgetMs: TimeInterval = 16.67 // 60fps target
    private let memoryBudgetMB: Double = 100.0 // 100MB budget

    private var optimizationTimes: [TimeInterval] = []
    private var prefetchTimes: [TimeInterval] = []
    private let maxSamples = 100

    internal func recordLayoutOptimization(processingTime: TimeInterval, averageTime _: TimeInterval) {
        totalOptimizations += 1
        lastOptimizationTime = Date()

        optimizationTimes.append(processingTime)
        if optimizationTimes.count > maxSamples {
            optimizationTimes.removeFirst()
        }

        averageOptimizationTime = optimizationTimes.reduce(0, +) / Double(optimizationTimes.count)
    }

    internal func recordFragmentCached() {
        fragmentsCached += 1
    }

    internal func recordFragmentCleanup(removedCount: Int) {
        fragmentsCleaned += removedCount
    }

    internal func recordPrefetchOperation(processingTime: TimeInterval) {
        prefetchOperations += 1

        prefetchTimes.append(processingTime)
        if prefetchTimes.count > maxSamples {
            prefetchTimes.removeFirst()
        }

        averagePrefetchTime = prefetchTimes.reduce(0, +) / Double(prefetchTimes.count)
    }

    internal func recordLargeFileOptimization() {
        largeFileOptimizationsEnabled += 1
    }

    internal func recordViewportOptimizationEnabled() {
        viewportOptimizationsEnabled += 1
    }

    internal func recordFragmentRecyclingEnabled() {
        fragmentRecyclingEnabled += 1
    }

    internal func recordContainerOptimization() {
        containerOptimizations += 1
    }

    // MARK: - Detailed Metric Recording

    internal func recordFragmentCreation(duration: TimeInterval) {
        fragmentCreationTime = (fragmentCreationTime * Double(fragmentsCached) + duration) / Double(fragmentsCached + 1)
    }

    internal func recordLayoutCalculation(duration: TimeInterval) {
        layoutCalculationTime = (layoutCalculationTime * Double(totalOptimizations) + duration) / Double(totalOptimizations + 1)

        if duration > layoutBudgetMs {
            layoutBudgetExceeded += 1
        }
    }

    internal func recordDrawing(duration: TimeInterval) {
        drawingTime = (drawingTime * Double(totalOptimizations) + duration) / Double(totalOptimizations + 1)

        if duration > renderingBudgetMs {
            renderingBudgetExceeded += 1
        }
    }

    internal func recordCacheHit(hit: Bool) {
        let totalRequests = Double(fragmentsCached + 1)
        let hits = cacheHitRate * Double(fragmentsCached) + (hit ? 1.0 : 0.0)
        cacheHitRate = hits / totalRequests
    }

    internal func recordMemoryPressure() {
        memoryPressureEvents += 1
    }

    internal func recordLayoutInvalidation() {
        layoutInvalidations += 1
    }

    internal func recordVisibleRangeCalculation() {
        visibleRangeCalculations += 1
    }

    internal func updateMemoryUsage(currentMB: Double) {
        currentMemoryUsageMB = currentMB
        if currentMB > peakMemoryUsageMB {
            peakMemoryUsageMB = currentMB
        }

        if currentMB > memoryBudgetMB {
            memoryBudgetExceeded += 1
        }
    }

    public func reset() {
        // Basic statistics
        totalOptimizations = 0
        averageOptimizationTime = 0
        fragmentsCached = 0
        fragmentsCleaned = 0
        prefetchOperations = 0
        averagePrefetchTime = 0
        largeFileOptimizationsEnabled = 0
        viewportOptimizationsEnabled = 0
        fragmentRecyclingEnabled = 0
        containerOptimizations = 0
        lastOptimizationTime = nil
        optimizationTimes.removeAll()
        prefetchTimes.removeAll()

        // Detailed metrics
        fragmentCreationTime = 0
        layoutCalculationTime = 0
        drawingTime = 0
        cacheHitRate = 0
        memoryPressureEvents = 0
        layoutInvalidations = 0
        visibleRangeCalculations = 0
        peakMemoryUsageMB = 0
        currentMemoryUsageMB = 0

        // Budget tracking
        layoutBudgetExceeded = 0
        renderingBudgetExceeded = 0
        memoryBudgetExceeded = 0
    }
}

// NSRange extensions moved to NSRange+Extensions.swift
