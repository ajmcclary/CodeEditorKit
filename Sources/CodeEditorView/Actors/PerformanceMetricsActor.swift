import CodeEditorCommon
import Foundation

// MARK: - Performance Metrics Actor

/// Actor responsible for managing performance metrics
@available(macOS 13.0, iOS 16.0, *)
public actor PerformanceMetricsActor {
    private var metrics: [String: [SendablePerformanceMetric]] = [:]
    private let maxMetricsPerCategory = 1_000
    private var aggregatedStats: [String: AggregatedStats] = [:]

    public struct AggregatedStats: Sendable {
        public let category: String
        public let count: Int
        public let averageDuration: Duration
        public let minDuration: Duration
        public let maxDuration: Duration
        public let percentile95: Duration
        public let lastUpdated: Date
    }

    /// Record a performance metric
    public func record(_ metric: SendablePerformanceMetric) {
        let category = metric.name

        // Add to metrics array
        var categoryMetrics = metrics[category] ?? []
        categoryMetrics.append(metric)

        // Limit array size
        if categoryMetrics.count > maxMetricsPerCategory {
            categoryMetrics.removeFirst(categoryMetrics.count - maxMetricsPerCategory)
        }

        metrics[category] = categoryMetrics

        // Update aggregated stats
        updateAggregatedStats(for: category)
    }

    /// Get aggregated statistics for a category
    public func getStats(for category: String) -> AggregatedStats? {
        aggregatedStats[category]
    }

    /// Get all aggregated statistics
    public func getAllStats() -> [String: AggregatedStats] {
        aggregatedStats
    }

    /// Clear metrics for a specific category
    public func clearMetrics(for category: String) {
        metrics.removeValue(forKey: category)
        aggregatedStats.removeValue(forKey: category)
    }

    /// Clear all metrics
    public func clearAllMetrics() {
        metrics.removeAll()
        aggregatedStats.removeAll()
    }

    private func updateAggregatedStats(for category: String) {
        guard let categoryMetrics = metrics[category], !categoryMetrics.isEmpty else { return }

        let durations = categoryMetrics.map { $0.duration }

        // Convert durations to milliseconds for sorting
        let durationMs = durations.map { duration in
            Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        }

        let sortedIndices = Array(0..<durations.count).sorted { firstIndex, secondIndex in
            durationMs[firstIndex] < durationMs[secondIndex]
        }

        let sortedDurations = sortedIndices.map { durations[$0] }

        let totalMs = durationMs.reduce(0.0, +)

        let averageMs = totalMs / Double(durations.count)
        let percentile95Index = Int(Double(sortedDurations.count) * 0.95)

        aggregatedStats[category] = AggregatedStats(
            category: category,
            count: categoryMetrics.count,
            averageDuration: .milliseconds(Int(averageMs)),
            minDuration: sortedDurations.first ?? .zero,
            maxDuration: sortedDurations.last ?? .zero,
            percentile95: sortedDurations[min(percentile95Index, sortedDurations.count - 1)],
            lastUpdated: Date()
        )
    }
}
