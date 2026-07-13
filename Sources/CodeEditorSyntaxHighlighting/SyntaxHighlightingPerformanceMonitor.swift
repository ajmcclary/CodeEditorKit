import CodeEditorCommon
import CodeEditorInstrumentation
import Foundation

/// Simple performance monitoring for syntax highlighting
@MainActor
package final class SyntaxHighlightingPerformanceMonitor {
    private static let logger = CodeEditorLog.logger(category: "SyntaxHighlightingPerformance")

    package enum Category: String {
        case syntaxHighlighting = "SyntaxHighlighting"
        case tokenApplication = "TokenApplication"
        case cacheOperation = "CacheOperation"
    }

    private var metrics: [Category: [Duration]] = [:]
    private let metricsLimit = 100

    package init() {}

    package func measure<T>(
        category: Category,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = Duration.seconds(CFAbsoluteTimeGetCurrent() - startTime)
            recordMetric(category: category, duration: duration)
        }
        return try await operation()
    }

    private func recordMetric(category: Category, duration: Duration) {
        var categoryMetrics = metrics[category] ?? []
        categoryMetrics.append(duration)

        // Keep only recent metrics
        if categoryMetrics.count > metricsLimit {
            categoryMetrics.removeFirst()
        }

        metrics[category] = categoryMetrics

        // Log slow operations
        if duration > .milliseconds(100) {
            Self.logger.debug(
                "Slow \(category.rawValue): \(String(format: "%.3f", duration.timeInterval))s"
            )
        }
    }

    package func getAverageTime(for category: Category) -> Duration? {
        guard let categoryMetrics = metrics[category], !categoryMetrics.isEmpty else {
            return nil
        }
        // Sum all durations and divide by count
        let totalSeconds = categoryMetrics.reduce(0.0) { sum, duration in
            sum + duration.timeInterval
        }
        return Duration.seconds(totalSeconds / Double(categoryMetrics.count))
    }

    package func reset() {
        metrics.removeAll()
    }
}
