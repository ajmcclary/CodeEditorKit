import CodeEditorCommon
import CodeEditorLanguages
import Foundation

/// Enhanced performance tracking for syntax highlighting with detailed breakdowns
@MainActor
public final class SyntaxHighlightingPerformanceTracker {
    // MARK: - Types

    public struct PerformanceMetrics: Sendable {
        public let tokenizationTime: TimeInterval
        public let cacheCheckTime: TimeInterval
        public let highlightingTime: TimeInterval
        public let applyAttributesTime: TimeInterval
        public let totalTime: TimeInterval
        public let tokenCount: Int
        public let cacheHit: Bool
        public let language: String
        public let textLength: Int

        public var tokensPerSecond: Double {
            guard highlightingTime > 0 else { return 0 }
            return Double(tokenCount) / highlightingTime
        }

        public var performanceLevel: PerformanceLevel {
            switch totalTime {
            case ..<0.05: return .excellent
            case ..<0.1: return .good
            case ..<0.5: return .acceptable
            case ..<1.0: return .warning
            default: return .critical
            }
        }
    }

    public enum PerformanceLevel: String {
        case excellent = "✅"
        case good = "🟢"
        case acceptable = "🟡"
        case warning = "🟠"
        case critical = "🔴"
    }

    /// Aggregated performance metrics across multiple operations
    public struct AggregatedMetrics {
        /// Average total time across all operations
        public let averageTotalTime: TimeInterval
        /// 50th percentile (median) total time
        public let p50TotalTime: TimeInterval
        /// 95th percentile total time
        public let p95TotalTime: TimeInterval
        /// 99th percentile total time
        public let p99TotalTime: TimeInterval
        /// Cache hit rate as a fraction (0.0 to 1.0)
        public let cacheHitRate: Double
        /// Total number of operations tracked
        public let totalOperations: Int
        /// Number of operations that exceeded critical threshold
        public let criticalOperations: Int
        /// Average tokens processed per second
        public let averageTokensPerSecond: Double

        /// Overall performance score from 0-100 based on time, cache, and critical operations
        public var performanceScore: Double {
            let timeScore = max(0, 1 - (averageTotalTime / 0.1)) * 0.4
            let cacheScore = cacheHitRate * 0.3
            let criticalScore = max(0, 1 - (Double(criticalOperations) / Double(max(1, totalOperations)))) * 0.3
            return (timeScore + cacheScore + criticalScore) * 100
        }
    }

    // MARK: - Properties

    private var recentMetrics: [PerformanceMetrics] = []
    private let maxMetricsCount = 1_000
    private let logger = CodeEditorLog.logger(category: "SyntaxHighlightingPerformance")

    // Real-time monitoring
    private var warningThreshold: TimeInterval = 0.1
    private var criticalThreshold: TimeInterval = 0.5

    // MARK: - Public Methods

    /// Track a complete highlighting operation with detailed timing
    public func trackOperation(metrics: PerformanceMetrics) {
        addMetrics(metrics)
        logPerformance(metrics)
    }

    /// Track highlighting operation - convenience struct for timing data
    public struct OperationTiming {
        /// Time spent tokenizing the source text
        public let tokenizationTime: TimeInterval
        /// Time spent checking the cache for existing results
        public let cacheCheckTime: TimeInterval
        /// Time spent performing syntax highlighting
        public let highlightingTime: TimeInterval
        /// Time spent applying attributes to the text storage
        public let applyAttributesTime: TimeInterval

        /// Creates a new operation timing record
        ///
        /// - Parameters:
        ///   - tokenizationTime: Time spent tokenizing
        ///   - cacheCheckTime: Time spent checking cache
        ///   - highlightingTime: Time spent highlighting
        ///   - applyAttributesTime: Time spent applying attributes
        public init(
            tokenizationTime: TimeInterval,
            cacheCheckTime: TimeInterval,
            highlightingTime: TimeInterval,
            applyAttributesTime: TimeInterval
        ) {
            self.tokenizationTime = tokenizationTime
            self.cacheCheckTime = cacheCheckTime
            self.highlightingTime = highlightingTime
            self.applyAttributesTime = applyAttributesTime
        }
    }

    /// Track a complete highlighting operation with detailed timing
    public func trackOperation(
        timing: OperationTiming,
        tokenCount: Int,
        cacheHit: Bool,
        language: Language,
        textLength: Int
    ) {
        let totalTime = timing.tokenizationTime + timing.cacheCheckTime +
                       timing.highlightingTime + timing.applyAttributesTime

        let metrics = PerformanceMetrics(
            tokenizationTime: timing.tokenizationTime,
            cacheCheckTime: timing.cacheCheckTime,
            highlightingTime: timing.highlightingTime,
            applyAttributesTime: timing.applyAttributesTime,
            totalTime: totalTime,
            tokenCount: tokenCount,
            cacheHit: cacheHit,
            language: language.name,
            textLength: textLength
        )

        trackOperation(metrics: metrics)
    }

    /// Get aggregated performance metrics
    public func getAggregatedMetrics() -> AggregatedMetrics? {
        guard !recentMetrics.isEmpty else { return nil }

        let totalTimes = recentMetrics.map { $0.totalTime }.sorted()
        let cacheHits = recentMetrics.filter { $0.cacheHit }.count
        let criticalOps = recentMetrics.filter { $0.performanceLevel == .critical }.count
        let avgTokensPerSec = recentMetrics.compactMap { $0.tokensPerSecond }.reduce(0, +) / Double(recentMetrics.count)

        return AggregatedMetrics(
            averageTotalTime: totalTimes.reduce(0, +) / Double(totalTimes.count),
            p50TotalTime: percentile(totalTimes, 0.5),
            p95TotalTime: percentile(totalTimes, 0.95),
            p99TotalTime: percentile(totalTimes, 0.99),
            cacheHitRate: Double(cacheHits) / Double(recentMetrics.count),
            totalOperations: recentMetrics.count,
            criticalOperations: criticalOps,
            averageTokensPerSecond: avgTokensPerSec
        )
    }

    /// Get performance breakdown by language
    public func getPerformanceByLanguage() -> [String: AggregatedMetrics] {
        var languageMetrics: [String: [PerformanceMetrics]] = [:]

        for metric in recentMetrics {
            languageMetrics[metric.language, default: []].append(metric)
        }

        var results: [String: AggregatedMetrics] = [:]

        for (language, metrics) in languageMetrics {
            let totalTimes = metrics.map { $0.totalTime }.sorted()
            let cacheHits = metrics.filter { $0.cacheHit }.count
            let criticalOps = metrics.filter { $0.performanceLevel == .critical }.count
            let avgTokensPerSec = metrics.compactMap { $0.tokensPerSecond }.reduce(0, +) / Double(metrics.count)

            results[language] = AggregatedMetrics(
                averageTotalTime: totalTimes.reduce(0, +) / Double(totalTimes.count),
                p50TotalTime: percentile(totalTimes, 0.5),
                p95TotalTime: percentile(totalTimes, 0.95),
                p99TotalTime: percentile(totalTimes, 0.99),
                cacheHitRate: Double(cacheHits) / Double(metrics.count),
                totalOperations: metrics.count,
                criticalOperations: criticalOps,
                averageTokensPerSecond: avgTokensPerSec
            )
        }

        return results
    }

    /// Generate performance report
    public func generateReport() -> String {
        guard let aggregated = getAggregatedMetrics() else {
            return "No performance data available"
        }

        var report = """
        === Syntax Highlighting Performance Report ===

        Overall Performance Score: \(String(format: "%.1f", aggregated.performanceScore))/100

        Timing Statistics:
        - Average: \(formatTime(aggregated.averageTotalTime))
        - P50: \(formatTime(aggregated.p50TotalTime))
        - P95: \(formatTime(aggregated.p95TotalTime))
        - P99: \(formatTime(aggregated.p99TotalTime))

        Cache Performance:
        - Hit Rate: \(String(format: "%.1f%%", aggregated.cacheHitRate * 100))

        Operation Statistics:
        - Total Operations: \(aggregated.totalOperations)
        - Critical Operations: \(aggregated.criticalOperations) (\(String(format: "%.1f%%", Double(aggregated.criticalOperations) / Double(aggregated.totalOperations) * 100)))
        - Avg Tokens/Second: \(String(format: "%.0f", aggregated.averageTokensPerSecond))

        """

        // Add language breakdown
        let languagePerf = getPerformanceByLanguage()
        if !languagePerf.isEmpty {
            report += "\nPerformance by Language:\n"
            for (language, metrics) in languagePerf.sorted(by: { $0.value.averageTotalTime > $1.value.averageTotalTime }) {
                report += "- \(language): avg \(formatTime(metrics.averageTotalTime)), cache hit \(String(format: "%.0f%%", metrics.cacheHitRate * 100))\n"
            }
        }

        return report
    }

    /// Reset all metrics
    public func reset() {
        recentMetrics.removeAll()
    }

    // MARK: - Private Methods

    private func addMetrics(_ metrics: PerformanceMetrics) {
        recentMetrics.append(metrics)

        // Keep only recent metrics
        if recentMetrics.count > maxMetricsCount {
            recentMetrics.removeFirst(recentMetrics.count - maxMetricsCount)
        }
    }

    private func logPerformance(_ metrics: PerformanceMetrics) {
        let level = metrics.performanceLevel
        let message = """
        \(level.rawValue) Syntax Highlighting: \(formatTime(metrics.totalTime)) \
        (\(metrics.language), \(metrics.textLength) chars, \(metrics.tokenCount) tokens, \
        cache: \(metrics.cacheHit ? "HIT" : "MISS"))
        """

        switch level {
        case .excellent, .good:
            logger.debug("\(message)")

        case .acceptable:
            logger.info("\(message)")

        case .warning:
            logger.warning("\(message)")

        case .critical:
            logger.error("""
            \(message)
            Breakdown: tokenization=\(formatTime(metrics.tokenizationTime)), \
            cache=\(formatTime(metrics.cacheCheckTime)), \
            highlighting=\(formatTime(metrics.highlightingTime)), \
            attributes=\(formatTime(metrics.applyAttributesTime))
            """)
        }
    }

    private func percentile(_ values: [TimeInterval], _ percentile: Double) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        let index = Int(Double(values.count - 1) * percentile)
        return values[index]
    }

    private func formatTime(_ time: TimeInterval) -> String {
        if time < 0.001 {
            return String(format: "%.0fµs", time * 1_000_000)
        } else if time < 1.0 {
            return String(format: "%.0fms", time * 1_000)
        } else {
            return String(format: "%.2fs", time)
        }
    }
}
