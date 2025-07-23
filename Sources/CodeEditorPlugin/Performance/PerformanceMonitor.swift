import Foundation

// MARK: - PerformanceMonitor

/// Monitors and reports performance metrics for the code editor.
///
/// `PerformanceMonitor` provides comprehensive performance tracking for all editor operations,
/// helping identify bottlenecks and optimize performance. It uses actor isolation for thread-safe
/// metric collection with automatic cleanup of old metrics.
///
/// ## Features
///
/// - **Automatic Measurement**: Track operation duration with tokens
/// - **Block Measurement**: Measure synchronous and async code blocks
/// - **Performance Reports**: Generate detailed performance summaries
/// - **Automatic Cleanup**: Old metrics are automatically removed
/// - **Thread Safety**: Actor-based design ensures safe concurrent access
///
/// ## Basic Usage
///
/// ```swift
/// let monitor = PerformanceMonitor.shared
/// 
/// // Manual measurement with tokens
/// let token = await monitor.startMeasuring("syntax-highlighting")
/// // ... perform operation ...
/// await monitor.endMeasuring(token)
/// 
/// // Block measurement
/// let result = await monitor.measure("file-loading") {
///     try await loadFile(at: path)
/// }
/// 
/// // Generate report
/// let report = await monitor.generateReport()
/// logger.debug("Average operation time: \\(report.averageDuration)s")
/// ```
///
/// ## Performance Thresholds
///
/// Operations exceeding 100ms are logged as warnings to help identify
/// performance issues. The monitor automatically maintains the last 1000
/// metrics or 1 hour of data, whichever limit is reached first.
///
/// - SeeAlso: ``MeasurementToken``, ``PerformanceReport``, ``MonitoringPerformanceMetric``
public actor PerformanceMonitor {
    // MARK: - Configuration

    /// Maximum number of metrics to retain before automatic cleanup
    private static let maxMetricsCount = 1_000

    /// Maximum age of metrics before automatic cleanup (in seconds)
    private static let maxMetricAge: TimeInterval = 3_600 // 1 hour

    // MARK: - Singleton (Deprecated)

    /// Shared instance of the performance monitor (deprecated).
    @available(*, deprecated, message: "Use dependency injection instead of the singleton pattern. Create an instance with PerformanceMonitor() and pass it to components that need it.")
    public static let shared = PerformanceMonitor()

    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "Performance")
    private var metrics: [String: MonitoringPerformanceMetric] = [:]
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new performance monitor instance.
    public init() {
        // Start periodic cleanup task
        Task {
            await startPeriodicCleanup()
        }
    }

    // MARK: - Public Methods

    /// Start measuring a performance metric
    @discardableResult
    public func startMeasuring(_ name: String) -> MeasurementToken {
        let token = MeasurementToken(name: name, startTime: CFAbsoluteTimeGetCurrent())

        metrics[name] = MonitoringPerformanceMetric(
            name: name,
            startTime: token.startTime
        )

        // Trigger cleanup if needed
        if metrics.count > Self.maxMetricsCount {
            Task { cleanupOldMetrics() }
        }

        return token
    }

    /// End measuring and record the result
    public func endMeasuring(_ token: MeasurementToken) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - token.startTime

        if var metric = metrics[token.name] {
            metric.endTime = endTime
            metric.duration = duration
            metrics[token.name] = metric

            // Log if duration exceeds threshold
            if duration > 0.1 { // 100ms threshold
                logger.warning("Performance issue: \(token.name) took \(String(format: "%.2f", duration * 1_000))ms")
            } else {
                logger.debug("\(token.name) completed in \(String(format: "%.2f", duration * 1_000))ms")
            }
        }
    }

    /// Measure a block of code
    public func measure<T>(_ name: String, block: () throws -> T) async rethrows -> T {
        let token = startMeasuring(name)
        do {
            let result = try block()
            endMeasuring(token)
            return result
        } catch {
            endMeasuring(token)
            throw error
        }
    }

    /// Measure an async block of code
    public func measure<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let token = startMeasuring(name)
        do {
            let result = try await block()
            endMeasuring(token)
            return result
        } catch {
            endMeasuring(token)
            throw error
        }
    }

    /// Get all recorded metrics
    public func getAllMetrics() -> [MonitoringPerformanceMetric] {
        Array(metrics.values)
    }

    /// Get metrics for a specific operation
    public func getMetrics(for name: String) -> MonitoringPerformanceMetric? {
        metrics[name]
    }

    /// Clear all metrics
    public func clearMetrics() {
        metrics.removeAll()
        logger.info("Cleared all performance metrics")
    }

    /// Clear metrics older than specified age
    public func clearMetrics(olderThan age: TimeInterval) {
        let cutoffTime = CFAbsoluteTimeGetCurrent() - age
        let oldCount = metrics.count

        metrics = metrics.filter { _, metric in
            metric.startTime > cutoffTime
        }

        let removedCount = oldCount - metrics.count
        if removedCount > 0 {
            logger.info("Removed \(removedCount) old metrics")
        }
    }

    /// Generate a performance report
    public func generateReport() -> PerformanceReport {
        let allMetrics = getAllMetrics()

        let completedMetrics = allMetrics.filter { $0.isComplete }
        let totalDuration = completedMetrics.reduce(0.0) { $0 + ($1.duration ?? 0) }
        let averageDuration = completedMetrics.isEmpty ? 0 : totalDuration / Double(completedMetrics.count)

        let slowestOperations = completedMetrics
            .sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
            .prefix(10)

        return PerformanceReport(
            totalOperations: allMetrics.count,
            completedOperations: completedMetrics.count,
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            slowestOperations: Array(slowestOperations),
            oldestMetricAge: oldestMetricAge()
        )
    }

    // MARK: - Private Methods

    private func startPeriodicCleanup() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                // Wait for cleanup interval (every 5 minutes)
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes

                // Check if self still exists before continuing
                guard let self else { break }
                await self.cleanupOldMetrics()
            }
        }
    }

    private func cleanupOldMetrics() {
        clearMetrics(olderThan: Self.maxMetricAge)

        // Also enforce max count limit
        if metrics.count > Self.maxMetricsCount {
            // Keep only the most recent metrics
            let sortedMetrics = metrics.sorted { $0.value.startTime > $1.value.startTime }
            let metricsToKeep = sortedMetrics.prefix(Self.maxMetricsCount)

            metrics = Dictionary(uniqueKeysWithValues: metricsToKeep.map { ($0.key, $0.value) })
            logger.info("Enforced metric count limit, kept \(self.metrics.count) most recent metrics")
        }
    }

    private func oldestMetricAge() -> TimeInterval? {
        guard let oldestMetric = metrics.values.min(by: { $0.startTime < $1.startTime }) else {
            return nil
        }
        return CFAbsoluteTimeGetCurrent() - oldestMetric.startTime
    }

    deinit {
        cleanupTask?.cancel()
    }
}

// MARK: - MeasurementToken

/// Token returned when starting a measurement.
///
/// `MeasurementToken` is used to track the duration of an operation.
/// Keep the token and pass it to `endMeasuring(_:)` when the operation completes.
///
/// ## Example
///
/// ```swift
/// let token = await monitor.startMeasuring("database-query")
/// defer { await monitor.endMeasuring(token) }
/// 
/// // Perform operation...
/// ```
///
/// - SeeAlso: ``PerformanceMonitor``
public struct MeasurementToken: Sendable {
    /// The name of the operation being measured.
    let name: String

    /// The start time of the measurement.
    let startTime: CFAbsoluteTime
}

// MARK: - MonitoringPerformanceMetric

/// A single performance metric for monitoring.
///
/// Represents a measured operation with timing information.
/// Metrics are automatically managed by the `PerformanceMonitor`.
///
/// ## Properties
///
/// - `name`: The operation identifier
/// - `startTime`: When the operation began
/// - `endTime`: When the operation completed (nil if still running)
/// - `duration`: Total duration in seconds (nil if still running)
/// - `isComplete`: Whether the measurement has finished
///
/// - SeeAlso: ``PerformanceMonitor``, ``PerformanceReport``
public struct MonitoringPerformanceMetric: Sendable {
    /// The name/identifier of the measured operation.
    public let name: String

    /// The absolute time when measurement started.
    public let startTime: CFAbsoluteTime

    /// The absolute time when measurement ended (nil if ongoing).
    public var endTime: CFAbsoluteTime?

    /// The duration of the operation in seconds (nil if ongoing).
    public var duration: TimeInterval?

    /// Whether the measurement has completed.
    public var isComplete: Bool {
        endTime != nil
    }

    public init(name: String, startTime: CFAbsoluteTime, endTime: CFAbsoluteTime? = nil, metadata _: [String: Any] = [:]) {
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.map { $0 - startTime }
        // Note: metadata is not stored as [String: Any] is not Sendable
        // Consider using a Sendable alternative if metadata is needed
    }
}

// MARK: - PerformanceReport

/// Performance report with aggregated metrics.
///
/// Provides a comprehensive summary of performance metrics collected by the monitor.
/// Use this to identify performance bottlenecks and optimize critical paths.
///
/// ## Example
///
/// ```swift
/// let report = await monitor.generateReport()
/// logger.debug(report.summary)
/// 
/// // Check slowest operations
/// for operation in report.slowestOperations {
///     logger.debug("\(operation.name): \(operation.duration ?? 0)s")
/// }
/// ```
///
/// - SeeAlso: ``PerformanceMonitor``, ``MonitoringPerformanceMetric``
public struct PerformanceReport: Sendable {
    /// Total number of operations tracked.
    public let totalOperations: Int

    /// Number of operations that have completed.
    public let completedOperations: Int

    /// Combined duration of all completed operations in seconds.
    public let totalDuration: TimeInterval

    /// Average duration of completed operations in seconds.
    public let averageDuration: TimeInterval

    /// The 10 slowest operations, sorted by duration.
    public let slowestOperations: [MonitoringPerformanceMetric]

    /// Age of the oldest metric in seconds (nil if no metrics).
    public let oldestMetricAge: TimeInterval?

    public var summary: String {
        let ageString = oldestMetricAge.map {
            String(format: "%.1f minutes", $0 / 60)
        } ?? "N/A"

        return """
        Performance Report
        ==================
        Total Operations: \(totalOperations)
        Completed Operations: \(completedOperations)
        Total Duration: \(String(format: "%.2f", totalDuration * 1_000))ms
        Average Duration: \(String(format: "%.2f", averageDuration * 1_000))ms
        Oldest Metric Age: \(ageString)

        Slowest Operations:
        \(slowestOperations
            .enumerated()
            .map { index, metric in
                "\(index + 1). \(metric.name): \(String(format: "%.2f", (metric.duration ?? 0) * 1_000))ms"
            }
            .joined(separator: "\n")
        )
        """
    }
}
