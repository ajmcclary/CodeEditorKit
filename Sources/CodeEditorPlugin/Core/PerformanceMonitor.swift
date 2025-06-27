import Foundation
import os.log

// MARK: - PerformanceMonitor

/// Monitors and reports performance metrics for the code editor
@MainActor
public final class PerformanceMonitor {
    deinit {}
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitor()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "Performance")
    private var metrics: [String: MonitoringPerformanceMetric] = [:]
    private let metricsQueue = DispatchQueue(label: "com.codeeditor.performance", attributes: .concurrent)
    
    // MARK: - Public Methods
    
    /// Start measuring a performance metric
    @discardableResult
    public func startMeasuring(_ name: String, metadata: [String: Any] = [:]) -> MeasurementToken {
        let token = MeasurementToken(name: name, startTime: CFAbsoluteTimeGetCurrent())
        
        Task { @MainActor in
            self.metrics[name] = MonitoringPerformanceMetric(
                name: name,
                startTime: token.startTime,
                metadata: metadata
            )
        }
        
        return token
    }
    
    /// End measuring and record the result
    public func endMeasuring(_ token: MeasurementToken) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - token.startTime
        
        Task { @MainActor in
            if var metric = self.metrics[token.name] {
                metric.endTime = endTime
                metric.duration = duration
                self.metrics[token.name] = metric
                
                // Log if duration exceeds threshold
                if duration > 0.1 { // 100ms threshold
                    self.logger.warning("Performance issue: \(token.name) took \(String(format: "%.2f", duration * 1_000))ms")
                } else {
                    self.logger.debug("\(token.name) completed in \(String(format: "%.2f", duration * 1_000))ms")
                }
            }
        }
    }
    
    /// Measure a block of code
    public func measure<T>(_ name: String, metadata: [String: Any] = [:], block: () throws -> T) rethrows -> T {
        let token = startMeasuring(name, metadata: metadata)
        defer { endMeasuring(token) }
        return try block()
    }
    
    /// Measure an async block of code
    public func measure<T>(_ name: String, metadata: [String: Any] = [:], block: () async throws -> T) async rethrows -> T {
        let token = startMeasuring(name, metadata: metadata)
        defer { endMeasuring(token) }
        return try await block()
    }
    
    /// Get all recorded metrics
    @MainActor
    public func getAllMetrics() -> [MonitoringPerformanceMetric] {
        Array(metrics.values)
    }
    
    /// Clear all metrics
    public func clearMetrics() {
        Task { @MainActor in
            self.metrics.removeAll()
        }
    }
    
    /// Generate a performance report
    public func generateReport() async -> PerformanceReport {
        let allMetrics = await getAllMetrics()
        
        let totalDuration = allMetrics.reduce(0.0) { $0 + ($1.duration ?? 0) }
        let averageDuration = allMetrics.isEmpty ? 0 : totalDuration / Double(allMetrics.count)
        
        let slowestOperations = allMetrics
            .filter { $0.duration != nil }
            .sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
            .prefix(10)
        
        return PerformanceReport(
            totalOperations: allMetrics.count,
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            slowestOperations: Array(slowestOperations)
        )
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
public struct MonitoringPerformanceMetric {
    public let name: String
    public let startTime: CFAbsoluteTime
    public var endTime: CFAbsoluteTime?
    public var duration: TimeInterval?
    public let metadata: [String: Any]
    
    public var isComplete: Bool {
        endTime != nil
    }
}

// MARK: - PerformanceReport

/// Performance report with aggregated metrics
public struct PerformanceReport {
    public let totalOperations: Int
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let slowestOperations: [MonitoringPerformanceMetric]
    
    public var summary: String {
        """
        Performance Report
        ==================
        Total Operations: \(totalOperations)
        Total Duration: \(String(format: "%.2f", totalDuration * 1_000))ms
        Average Duration: \(String(format: "%.2f", averageDuration * 1_000))ms
        
        Slowest Operations:
        \(slowestOperations
            .enumerated()
            .map { index, metric in
                "\(index + 1). \(metric.name): \(String(format: "%.2f", (metric.duration ?? 0) * 1_000))ms"
            }
            .joined(separator: "\n"))
        """
    }
}

// MARK: - Performance Categories

enum PerformanceCategory {
    static let syntaxHighlighting = "SyntaxHighlighting"
    static let textLayout = "TextLayout"
    static let annotationUpdate = "AnnotationUpdate"
    static let viewportRendering = "ViewportRendering"
    static let textInsertion = "TextInsertion"
    static let configurationUpdate = "ConfigurationUpdate"
}
