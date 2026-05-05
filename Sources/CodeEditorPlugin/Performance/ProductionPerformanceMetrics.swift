import Foundation
import os.log

// MARK: - Production Performance Metrics

/// Central system for tracking performance metrics in production
public actor ProductionPerformanceMetrics {
    /// Public initializer for dependency injection
    public init() {}

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "Performance")

    /// Current performance thresholds
    private var thresholds = ProductionThresholds()

    /// Aggregated metrics
    private var metrics = AggregatedMetrics()

    /// Performance event handlers
    private var eventHandlers: [PerformanceEventHandler] = []

    // MARK: - Public API

    /// Track syntax highlighting performance
    public func trackHighlighting(
        duration: TimeInterval,
        fileSize: Int,
        language: Language,
        cacheHit: Bool = false
    ) {
        let metric = HighlightingMetric(
            duration: duration,
            fileSize: fileSize,
            language: language,
            cacheHit: cacheHit,
            timestamp: Date()
        )

        processMetric(metric)

        // Alert if performance degrades
        if duration > thresholds.highlightingThreshold(for: fileSize) {
            notifyPerformanceDegradation(.highlighting, metric: metric)
        }
    }

    /// Track scrolling performance
    public func trackScrolling(
        frameRate: Double,
        viewportSize: Int,
        fileSize: Int
    ) {
        let metric = ScrollingMetric(
            frameRate: frameRate,
            viewportSize: viewportSize,
            fileSize: fileSize,
            timestamp: Date()
        )

        processMetric(metric)

        // Alert if frame rate drops
        if frameRate < thresholds.minimumFrameRate {
            notifyPerformanceDegradation(.scrolling, metric: metric)
        }
    }

    /// Track memory usage
    public func trackMemoryUsage(
        currentUsage: Double,
        peakUsage: Double,
        fileSize: Int
    ) {
        let metric = MemoryMetric(
            currentUsage: currentUsage,
            peakUsage: peakUsage,
            fileSize: fileSize,
            timestamp: Date()
        )

        processMetric(metric)

        // Alert if memory usage is high
        if peakUsage > thresholds.memoryThreshold(for: fileSize) {
            notifyPerformanceDegradation(.memory, metric: metric)
        }
    }

    /// Track code folding performance
    public func trackCodeFolding(
        duration: TimeInterval,
        regionCount: Int,
        fileSize: Int
    ) {
        let metric = CodeFoldingMetric(
            duration: duration,
            regionCount: regionCount,
            fileSize: fileSize,
            timestamp: Date()
        )

        processMetric(metric)
    }

    /// Get current performance report
    public func generateReport() -> ProductionPerformanceReport {
        ProductionPerformanceReport(
            metrics: metrics,
            thresholds: thresholds,
            timestamp: Date()
        )
    }

    /// Register performance event handler
    public func registerEventHandler(_ handler: PerformanceEventHandler) {
        eventHandlers.append(handler)
    }

    /// Configure performance thresholds
    public func configureThresholds(_ thresholds: ProductionThresholds) {
        self.thresholds = thresholds
    }

    // MARK: - Private Methods

    private func processMetric(_ metric: any ProductionMetric) {
        updateAggregatedMetrics(with: metric)

        // Log in debug builds
        #if DEBUG
        logger.debug("Performance metric: \(String(describing: metric))")
        #endif
    }

    private func updateAggregatedMetrics(with metric: any ProductionMetric) {
        switch metric {
        case let highlighting as HighlightingMetric:
            metrics.highlighting.append(highlighting)
            // Keep only last 1000 entries
            if metrics.highlighting.count > 1_000 {
                metrics.highlighting = Array(metrics.highlighting.suffix(1_000))
            }

        case let scrolling as ScrollingMetric:
            metrics.scrolling.append(scrolling)
            if metrics.scrolling.count > 1_000 {
                metrics.scrolling = Array(metrics.scrolling.suffix(1_000))
            }

        case let memory as MemoryMetric:
            metrics.memory.append(memory)
            if metrics.memory.count > 1_000 {
                metrics.memory = Array(metrics.memory.suffix(1_000))
            }

        case let folding as CodeFoldingMetric:
            metrics.codeFolding.append(folding)
            if metrics.codeFolding.count > 1_000 {
                metrics.codeFolding = Array(metrics.codeFolding.suffix(1_000))
            }

        default:
            break
        }
    }

    private func notifyPerformanceDegradation(
        _ type: PerformanceDegradationType,
        metric: any ProductionMetric
    ) {
        logger.warning("Performance degradation detected: \(type.rawValue)")

        let event = PerformanceEvent(
            type: type,
            metric: metric,
            timestamp: Date()
        )

        // Notify all handlers
        eventHandlers.forEach { handler in
            handler.handlePerformanceEvent(event)
        }
    }
}

// MARK: - Supporting Types

/// Protocol for performance metrics
public protocol ProductionMetric: Sendable {
    var timestamp: Date { get }
}

/// Highlighting performance metric
public struct HighlightingMetric: ProductionMetric {
    public let duration: TimeInterval
    public let fileSize: Int
    public let language: Language
    public let cacheHit: Bool
    public let timestamp: Date
}

/// Scrolling performance metric
public struct ScrollingMetric: ProductionMetric {
    public let frameRate: Double
    public let viewportSize: Int
    public let fileSize: Int
    public let timestamp: Date
}

/// Memory usage metric
public struct MemoryMetric: ProductionMetric {
    public let currentUsage: Double
    public let peakUsage: Double
    public let fileSize: Int
    public let timestamp: Date
}

/// Code folding performance metric
public struct CodeFoldingMetric: ProductionMetric {
    public let duration: TimeInterval
    public let regionCount: Int
    public let fileSize: Int
    public let timestamp: Date
}

/// Performance thresholds configuration
public struct ProductionThresholds: Sendable {
    public var minimumFrameRate: Double = 50.0

    public func highlightingThreshold(for fileSize: Int) -> TimeInterval {
        switch fileSize {
        case 0..<10_000:
            return 0.1  // 100ms for small files

        case 10_000..<100_000:
            return 0.5  // 500ms for medium files

        default:
            return 1.0  // 1s for large files
        }
    }

    public func memoryThreshold(for fileSize: Int) -> Double {
        // Allow ~50MB per MB of file
        Double(fileSize) / 1_000_000 * 50.0
    }
}

/// Aggregated performance metrics
public struct AggregatedMetrics: Sendable {
    public var highlighting: [HighlightingMetric] = []
    public var scrolling: [ScrollingMetric] = []
    public var memory: [MemoryMetric] = []
    public var codeFolding: [CodeFoldingMetric] = []
}

/// Performance degradation types
public enum PerformanceDegradationType: String, Sendable {
    case highlighting = "Syntax Highlighting"
    case scrolling = "Scrolling"
    case memory = "Memory Usage"
    case codeFolding = "Code Folding"
}

/// Performance event
public struct PerformanceEvent: Sendable {
    public let type: PerformanceDegradationType
    public let metric: any ProductionMetric
    public let timestamp: Date
}

/// Protocol for handling performance events
public protocol PerformanceEventHandler: AnyObject {
    func handlePerformanceEvent(_ event: PerformanceEvent)
}

/// Performance report
public struct ProductionPerformanceReport: Sendable {
    public let metrics: AggregatedMetrics
    public let thresholds: ProductionThresholds
    public let timestamp: Date

    public var summary: String {
        let highlightingP95 = calculateP95(
            metrics.highlighting.map { $0.duration }
        )
        let averageFrameRate = calculateAverage(
            metrics.scrolling.map { $0.frameRate }
        )
        let peakMemory = metrics.memory.map { $0.peakUsage }.max() ?? 0

        return """
        Performance Report (\(timestamp))
        ================================
        Highlighting P95: \(String(format: "%.3f", highlightingP95))s
        Average Frame Rate: \(String(format: "%.1f", averageFrameRate)) fps
        Peak Memory: \(String(format: "%.1f", peakMemory)) MB
        Total Samples: \(metrics.highlighting.count + metrics.scrolling.count)
        """
    }

    private func calculateP95(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int(Double(sorted.count) * 0.95)
        return sorted[min(index, sorted.count - 1)]
    }

    private func calculateAverage(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
