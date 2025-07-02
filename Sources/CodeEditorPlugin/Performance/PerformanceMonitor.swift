import Foundation
import os.log

// MARK: - PerformanceMonitor

/// Monitors and reports performance metrics for the code editor
/// Uses actor isolation for thread-safe metric collection with automatic cleanup
public actor PerformanceMonitor {
    // MARK: - Configuration
    
    /// Maximum number of metrics to retain before automatic cleanup
    private static let maxMetricsCount = 1_000
    
    /// Maximum age of metrics before automatic cleanup (in seconds)
    private static let maxMetricAge: TimeInterval = 3_600 // 1 hour
    
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitor()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "Performance")
    private var metrics: [String: MonitoringPerformanceMetric] = [:]
    private var cleanupTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init() {
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

/// Token returned when starting a measurement
public struct MeasurementToken: Sendable {
    let name: String
    let startTime: CFAbsoluteTime
}

// MARK: - MonitoringPerformanceMetric

/// A single performance metric for monitoring
public struct MonitoringPerformanceMetric: Sendable {
    public let name: String
    public let startTime: CFAbsoluteTime
    public var endTime: CFAbsoluteTime?
    public var duration: TimeInterval?
    
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

/// Performance report with aggregated metrics
public struct PerformanceReport: Sendable {
    public let totalOperations: Int
    public let completedOperations: Int
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let slowestOperations: [MonitoringPerformanceMetric]
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
