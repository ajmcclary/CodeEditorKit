import Foundation
#if canImport(Combine)
import Combine
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - ViewportManager

/// Manages viewport-based rendering and optimization for large files
@MainActor
public final class ViewportManager: ObservableObject {
    // MARK: - Properties

    private weak var textView: PlatformTextView?
    private let textKitBridge: TextKitBridge
    private var cancellables = Set<AnyCancellable>()

    /// Current viewport information
    @Published public private(set) var viewport: Viewport = .zero

    /// Performance metrics
    @Published public private(set) var metrics = ViewportMetrics()

    /// Update throttle interval (seconds)
    public var updateInterval: TimeInterval = 0.1

    /// Prefetch distance multiplier
    public var prefetchMultiplier: CGFloat = 1.5

    /// Maximum cached ranges
    public var maxCachedRanges: Int = 10

    /// Memory monitor for managing cache memory
    private let memoryMonitor: MemoryMonitor

    /// Cached visible ranges for quick access
    private let rangeCache: LRUCache<ViewportManagerCacheKey, CachedViewportData>

    /// Active rendering tasks
    private var renderingTasks: [UUID: Task<Void, Never>] = [:]

    /// Scroll velocity for predictive prefetching
    private var scrollVelocity: Double = 0.0
    private var lastScrollPosition: CGFloat = 0.0
    private var lastScrollTime: TimeInterval = 0.0

    // MARK: - Initialization

    public init(textView: PlatformTextView, memoryMonitor: MemoryMonitor) {
        self.textView = textView
        self.textKitBridge = textView.createTextKitBridge()
        self.memoryMonitor = memoryMonitor
        self.rangeCache = LRUCache<ViewportManagerCacheKey, CachedViewportData>(capacity: 10, memoryMonitor: memoryMonitor)

        setupObservers()
        updateViewport()
    }

    deinit {
        // Cancel all active tasks
        renderingTasks.values.forEach { $0.cancel() }
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe scroll changes
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.publisher(for: NSView.boundsDidChangeNotification)
            .compactMap { [weak self] _ in self?.textView }
            .throttle(for: .seconds(updateInterval), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.updateViewport()
            }
            .store(in: &cancellables)
        #elseif canImport(UIKit)
        // For iOS, we'll update viewport when text changes since UITextView doesn't have
        // a direct content offset notification
        NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)
            .compactMap { [weak self] _ in self?.textView }
            .throttle(for: .seconds(updateInterval), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.updateViewport()
            }
            .store(in: &cancellables)
        #endif

        // Observe text changes
        NotificationCenter.default.publisher(for: NSTextStorage.didProcessEditingNotification)
            .compactMap { [weak self] _ in self?.textView }
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.invalidateCache()
                self?.updateViewport()
            }
            .store(in: &cancellables)
    }

    // MARK: - Viewport Updates

    /// Update the current viewport
    public func updateViewport() {
        guard let textView else { return }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Get visible bounds
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let visibleBounds = textView.visibleRect
        #elseif canImport(UIKit)
        let visibleBounds = textView.bounds
        #endif

        // Calculate scroll velocity
        let currentTime = ProcessInfo.processInfo.systemUptime
        let currentPosition = visibleBounds.origin.y

        if lastScrollTime > 0 {
            let timeDelta = currentTime - lastScrollTime
            if timeDelta > 0 && timeDelta < 1.0 { // Only update if within 1 second
                scrollVelocity = (currentPosition - lastScrollPosition) / timeDelta
            } else {
                scrollVelocity = 0.0
            }
        }

        lastScrollPosition = currentPosition
        lastScrollTime = currentTime

        // Calculate viewport with prefetch area
        let prefetchBounds = calculatePrefetchBounds(from: visibleBounds)

        // Get visible range from TextKitBridge
        if let visibleRange = textKitBridge.visibleRange {
            // Check cache first
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let textLength = textView.string.count
            #else
            let textLength = textView.text?.count ?? 0
            #endif
            let cacheKey = ViewportManagerCacheKey(bounds: visibleBounds, textLength: textLength)

            if let cachedData = rangeCache.get(cacheKey) {
                // Use cached data
                viewport = Viewport(
                    visibleBounds: visibleBounds,
                    prefetchBounds: prefetchBounds,
                    visibleRange: cachedData.visibleRange,
                    prefetchRange: cachedData.prefetchRange
                )
                metrics.cacheHits += 1
            } else {
                // Calculate new viewport data
                let prefetchRange = calculatePrefetchRange(from: visibleRange)

                viewport = Viewport(
                    visibleBounds: visibleBounds,
                    prefetchBounds: prefetchBounds,
                    visibleRange: visibleRange,
                    prefetchRange: prefetchRange
                )

                // Cache the result
                let cachedData = CachedViewportData(
                    visibleRange: visibleRange,
                    prefetchRange: prefetchRange
                )
                rangeCache.set(cachedData, forKey: cacheKey)
                metrics.cacheMisses += 1
            }

            // Update metrics
            let updateTime = CFAbsoluteTimeGetCurrent() - startTime
            metrics.averageUpdateTime = (metrics.averageUpdateTime * Double(metrics.updateCount) + updateTime) / Double(metrics.updateCount + 1)
            metrics.updateCount += 1

            // Trigger viewport-based rendering
            performViewportRendering()

            // Trigger predictive prefetching if scrolling
            if abs(scrollVelocity) > 50.0 { // Only prefetch if scrolling fast enough
                performPredictivePrefetching()
            }
        }
    }

    // MARK: - Rendering

    /// Perform viewport-based rendering optimizations
    private func performViewportRendering() {
        guard textView != nil else { return }

        // Cancel any existing rendering tasks outside the new viewport
        cancelRenderingOutsideViewport()

        // Create a new rendering task
        let taskId = UUID()
        let renderingTask = Task { [weak self] in
            guard let self else { return }

            // Ensure layout for visible range
            self.textKitBridge.ensureLayout(for: self.viewport.visibleRange)

            // Prefetch layout for prefetch range if not cancelled
            if !Task.isCancelled {
                let prefetchRanges = self.splitRangeForBatchProcessing(self.viewport.prefetchRange)
                for range in prefetchRanges {
                    if Task.isCancelled { break }
                    self.textKitBridge.ensureLayout(for: range)

                    // Small delay between batches
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }

            // Remove task when complete
            _ = await MainActor.run {
                self.renderingTasks.removeValue(forKey: taskId)
            }
        }

        renderingTasks[taskId] = renderingTask
    }

    /// Cancel rendering tasks outside the current viewport
    private func cancelRenderingOutsideViewport() {
        // Cancel all tasks for now (could be optimized to check ranges)
        renderingTasks.values.forEach { $0.cancel() }
        renderingTasks.removeAll()
    }

    /// Perform predictive prefetching based on scroll velocity
    private func performPredictivePrefetching() {
        guard let textView else { return }

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textLength = textView.string.count
        #else
        let textLength = textView.text?.count ?? 0
        #endif

        // Predict where the user will scroll to
        let predictedOffset = Int(scrollVelocity * 0.5) // Predict 0.5 seconds ahead
        let predictedLocation = max(
            0,
            min(textLength - viewport.visibleRange.length, viewport.visibleRange.location + predictedOffset)
        )

        let predictedRange = NSRange(
            location: predictedLocation,
            length: viewport.visibleRange.length
        )

        // Don't prefetch if predicted range overlaps with current prefetch range
        if NSIntersectionRange(predictedRange, viewport.prefetchRange).length >
           predictedRange.length / 2 {
            return
        }

        // Create a prefetch task
        let taskId = UUID()
        let prefetchTask = Task(priority: .background) { [weak self] in
            guard let self else { return }

            // Ensure layout for predicted range
            let prefetchRanges = self.splitRangeForBatchProcessing(predictedRange)
            for range in prefetchRanges {
                if Task.isCancelled { break }
                self.textKitBridge.ensureLayout(for: range)

                // Longer delay for predictive prefetch
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }

            // Remove task when complete
            _ = await MainActor.run {
                self.renderingTasks.removeValue(forKey: taskId)
            }
        }

        renderingTasks[taskId] = prefetchTask
    }

    // MARK: - Range Calculations

    /// Calculate prefetch bounds based on visible bounds
    private func calculatePrefetchBounds(from visibleBounds: CGRect) -> CGRect {
        let prefetchHeight = visibleBounds.height * prefetchMultiplier
        let extraHeight = (prefetchHeight - visibleBounds.height) / 2

        return CGRect(
            x: visibleBounds.origin.x,
            y: max(0, visibleBounds.origin.y - extraHeight),
            width: visibleBounds.width,
            height: prefetchHeight
        )
    }

    /// Calculate prefetch range based on visible range
    private func calculatePrefetchRange(from visibleRange: NSRange) -> NSRange {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textLength = textView?.string.count else { return visibleRange }
        #else
        guard let textLength = textView?.text?.count else { return visibleRange }
        #endif

        let prefetchLength = Int(CGFloat(visibleRange.length) * prefetchMultiplier)
        let extraLength = (prefetchLength - visibleRange.length) / 2

        let location = max(0, visibleRange.location - extraLength)
        let maxLength = textLength - location
        let length = min(prefetchLength, maxLength)

        return NSRange(location: location, length: length)
    }

    /// Split a range into smaller batches for processing
    private func splitRangeForBatchProcessing(_ range: NSRange) -> [NSRange] {
        let batchSize = 1_000 // Default batch size
        var ranges: [NSRange] = []

        var currentLocation = range.location
        let endLocation = NSMaxRange(range)

        while currentLocation < endLocation {
            let remainingLength = endLocation - currentLocation
            let currentLength = min(batchSize, remainingLength)
            ranges.append(NSRange(location: currentLocation, length: currentLength))
            currentLocation += currentLength
        }

        return ranges
    }

    // MARK: - Cache Management

    /// Invalidate the viewport cache
    public func invalidateCache() {
        rangeCache.removeAll()
        metrics.cacheInvalidations += 1
    }

    /// Get cache statistics
    public var cacheStatistics: CacheStatistics {
        rangeCache.statistics
    }

    // MARK: - Optimization Hints

    /// Provide optimization hints based on current usage
    public func getOptimizationHints() -> [OptimizationHint] {
        var hints: [OptimizationHint] = []

        // Check cache performance
        let cacheHitRate = metrics.cacheHits > 0 ? Double(metrics.cacheHits) / Double(metrics.cacheHits + metrics.cacheMisses) : 0
        if cacheHitRate < 0.5 {
            hints.append(.increaseCacheSize)
        }

        // Check update frequency
        if metrics.averageUpdateTime > 0.05 { // 50ms
            hints.append(.reduceUpdateFrequency)
        }

        // Check viewport size
        if viewport.prefetchRange.length > 50_000 {
            hints.append(.reducePrefetchMultiplier)
        }

        return hints
    }

    /// Optimization hints
    public enum OptimizationHint {
        case increaseCacheSize
        case reduceUpdateFrequency
        case reducePrefetchMultiplier
        case enableAsyncRendering

        var description: String {
            switch self {
            case .increaseCacheSize:
                return "Consider increasing cache size for better performance"

            case .reduceUpdateFrequency:
                return "Reduce viewport update frequency to improve performance"

            case .reducePrefetchMultiplier:
                return "Reduce prefetch area for large documents"

            case .enableAsyncRendering:
                return "Enable async rendering for better responsiveness"
            }
        }
    }
}

// MARK: - Supporting Types

/// Viewport information
public struct Viewport: Equatable, Sendable {
    public let visibleBounds: CGRect
    public let prefetchBounds: CGRect
    public let visibleRange: NSRange
    public let prefetchRange: NSRange

    @MainActor
    public static let zero = Self(
        visibleBounds: .zero,
        prefetchBounds: .zero,
        visibleRange: NSRange(location: 0, length: 0),
        prefetchRange: NSRange(location: 0, length: 0)
    )
}

/// Viewport performance metrics
public struct ViewportMetrics {
    /// Total number of viewport updates performed.
    public var updateCount: Int = 0
    /// Average time taken for viewport updates.
    public var averageUpdateTime: TimeInterval = 0
    /// Number of cache hits during viewport operations.
    public var cacheHits: Int = 0
    /// Number of cache misses during viewport operations.
    public var cacheMisses: Int = 0
    /// Number of cache invalidations performed.
    public var cacheInvalidations: Int = 0

    /// Cache hit rate as a percentage (0-1).
    public var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0
    }
}

/// Cache key for viewport data
private struct ViewportManagerCacheKey: Hashable {
    let bounds: CGRect
    let textLength: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(bounds.origin.x)
        hasher.combine(bounds.origin.y)
        hasher.combine(bounds.size.width)
        hasher.combine(bounds.size.height)
        hasher.combine(textLength)
    }
}

/// Cached viewport data
private struct CachedViewportData {
    let visibleRange: NSRange
    let prefetchRange: NSRange
}

// MARK: - ViewportManager Integration

extension CodeEditorView {
    /// Create or get the viewport manager for this text view
    public func getViewportManager() -> ViewportManager {
        // Use the text view's existing memory monitor for proper dependency injection
        ViewportManager(textView: self, memoryMonitor: memoryMonitor)
    }
}
