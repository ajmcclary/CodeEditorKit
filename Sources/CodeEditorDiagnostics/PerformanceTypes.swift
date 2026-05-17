import Foundation
import SwiftUI

// MARK: - Performance Status

/// Performance status levels for insights
public enum InsightsPerformanceStatus {
    /// Performance is operating at optimal levels.
    case optimal
    /// Performance has minor issues but is still acceptable.
    case suboptimal
    /// Performance is noticeably degraded.
    case degraded
    /// Performance has critical issues requiring immediate attention.
    case critical

    /// The color associated with this performance status.
    public var color: Color {
        switch self {
        case .optimal: return .green
        case .suboptimal: return .yellow
        case .degraded: return .orange
        case .critical: return .red
        }
    }

    /// A human-readable description of the performance status.
    public var description: String {
        switch self {
        case .optimal: return "Performance is optimal"
        case .suboptimal: return "Minor performance issues detected"
        case .degraded: return "Performance is degraded"
        case .critical: return "Critical performance issues"
        }
    }
}

// MARK: - Performance Issues

/// Performance issues for insights
public enum InsightsPerformanceIssue: Identifiable {
    case slowTextLayout(averageTime: TimeInterval)
    case highMemoryUsage(current: Double, threshold: Double)
    case lowCacheHitRate(current: Double, threshold: Double)
    case increasingCPUUsage(trend: PerformanceTrend)
    case unresponsiveUI(fps: Int)
    case slowSyntaxHighlighting(time: TimeInterval)

    public var id: String {
        switch self {
        case .slowTextLayout: return "slowTextLayout"
        case .highMemoryUsage: return "highMemoryUsage"
        case .lowCacheHitRate: return "lowCacheHitRate"
        case .increasingCPUUsage: return "increasingCPUUsage"
        case .unresponsiveUI: return "unresponsiveUI"
        case .slowSyntaxHighlighting: return "slowSyntaxHighlighting"
        }
    }

    public var severity: IssueSeverity {
        switch self {
        case .slowTextLayout(let time):
            return time > 0.1 ? .critical : .warning

        case .highMemoryUsage:
            return .warning

        case .lowCacheHitRate:
            return .info

        case .increasingCPUUsage:
            return .warning

        case .unresponsiveUI:
            return .critical

        case .slowSyntaxHighlighting(let time):
            return time > 0.5 ? .warning : .info
        }
    }

    public var description: String {
        switch self {
        case .slowTextLayout(let time):
            return "Text layout is slow (avg: \(String(format: "%.2f", time * 1_000))ms)"

        case let .highMemoryUsage(current, threshold):
            return "High memory usage: \(String(format: "%.1f", current))GB (threshold: \(String(format: "%.1f", threshold))GB)"

        case let .lowCacheHitRate(current, threshold):
            return "Low cache hit rate: \(String(format: "%.1f%%", current * 100)) (threshold: \(String(format: "%.1f%%", threshold * 100)))"

        case .increasingCPUUsage(let trend):
            return "CPU usage increasing: \(String(format: "+%.1f%%", trend.changeRate)) per minute"

        case .unresponsiveUI(let fps):
            return "UI is unresponsive: \(fps) FPS"

        case .slowSyntaxHighlighting(let time):
            return "Syntax highlighting is slow: \(String(format: "%.0f", time * 1_000))ms"
        }
    }
}

/// Issue severity levels
public enum IssueSeverity: Int, Comparable {
    case info = 0
    case warning = 1
    case critical = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Performance Recommendations

/// Performance recommendations for insights
public enum InsightsPerformanceRecommendation: Identifiable {
    case enableViewportOptimization
    case reduceFileSize
    case clearCaches
    case closeUnusedFiles
    case increaseCacheSize
    case disableUnusedFeatures
    case reduceUpdateFrequency
    case splitLargeFile(currentSize: Int, recommendedSize: Int)
    case reduceConcurrentOperations(current: Int, max: Int)
    case enableHardwareAcceleration
    case useReadOnlyMode

    public var id: String {
        switch self {
        case .enableViewportOptimization: return "enableViewportOptimization"
        case .reduceFileSize: return "reduceFileSize"
        case .clearCaches: return "clearCaches"
        case .closeUnusedFiles: return "closeUnusedFiles"
        case .increaseCacheSize: return "increaseCacheSize"
        case .disableUnusedFeatures: return "disableUnusedFeatures"
        case .reduceUpdateFrequency: return "reduceUpdateFrequency"
        case .splitLargeFile: return "splitLargeFile"
        case .reduceConcurrentOperations: return "reduceConcurrentOperations"
        case .enableHardwareAcceleration: return "enableHardwareAcceleration"
        case .useReadOnlyMode: return "useReadOnlyMode"
        }
    }

    public var title: String {
        switch self {
        case .enableViewportOptimization:
            return "Enable Viewport Optimization"

        case .reduceFileSize:
            return "Reduce File Size"

        case .clearCaches:
            return "Clear Caches"

        case .closeUnusedFiles:
            return "Close Unused Files"

        case .increaseCacheSize:
            return "Increase Cache Size"

        case .disableUnusedFeatures:
            return "Disable Unused Features"

        case .reduceUpdateFrequency:
            return "Reduce Update Frequency"

        case .splitLargeFile:
            return "Split Large File"

        case .reduceConcurrentOperations:
            return "Reduce Concurrent Operations"

        case .enableHardwareAcceleration:
            return "Enable Hardware Acceleration"

        case .useReadOnlyMode:
            return "Use Read-Only Mode"
        }
    }

    public var actionDescription: String {
        switch self {
        case .enableViewportOptimization:
            return "Enable viewport-based rendering to improve performance with large files"

        case .reduceFileSize:
            return "Consider splitting this file into smaller modules for better performance"

        case .clearCaches:
            return "Clear editor caches to free up memory"

        case .closeUnusedFiles:
            return "Close files you're not actively editing to reduce memory usage"

        case .increaseCacheSize:
            return "Increase cache size to improve hit rate and reduce redundant processing"

        case .disableUnusedFeatures:
            return "Disable features like minimap or annotations if not needed"

        case .reduceUpdateFrequency:
            return "Reduce real-time update frequency to improve responsiveness"

        case let .splitLargeFile(current, recommended):
            return "File size (\(current / 1_000_000)MB) exceeds recommendation (\(recommended / 1_000_000)MB)"

        case let .reduceConcurrentOperations(current, max):
            return "Reduce concurrent operations from \(current) to \(max) or less"

        case .enableHardwareAcceleration:
            return "Enable hardware acceleration in settings for better rendering performance"

        case .useReadOnlyMode:
            return "Switch to read-only mode if you're just viewing code"
        }
    }
}

// MARK: - Metrics and Configuration

/// Real-time performance metrics
public struct RealTimeMetrics {
    /// Current CPU usage percentage (0-100).
    public var cpuUsage: Double = 0
    /// Current memory usage in MB.
    public var memoryUsage: Double = 0
    /// Current frames per second.
    public var currentFPS: Int = 60
    /// Number of currently active operations.
    public var activeOperations: Int = 0
    /// Average response time in seconds.
    public var averageResponseTime: Double = 0

    /// Creates a new real-time metrics instance with default values.
    public init() {}
}

/// Performance thresholds
public struct PerformanceThresholds {
    /// Maximum acceptable layout time in seconds.
    public let maxLayoutTime: TimeInterval
    /// Maximum acceptable memory usage in GB.
    public let maxMemoryUsageGB: Double
    /// Minimum acceptable cache hit rate (0-1).
    public let minCacheHitRate: Double
    /// Minimum acceptable frames per second.
    public let minFPS: Int
    /// Maximum acceptable response time in seconds.
    public let maxResponseTime: TimeInterval

    /// Creates performance thresholds with specified values.
    /// - Parameters:
    ///   - maxLayoutTime: Maximum layout time (default: 0.05s)
    ///   - maxMemoryUsageGB: Maximum memory usage in GB (default: 2.0)
    ///   - minCacheHitRate: Minimum cache hit rate (default: 0.7)
    ///   - minFPS: Minimum frames per second (default: 30)
    ///   - maxResponseTime: Maximum response time (default: 0.1s)
    public init(
        maxLayoutTime: TimeInterval = 0.05, // 50ms
        maxMemoryUsageGB: Double = 2.0,
        minCacheHitRate: Double = 0.7,
        minFPS: Int = 30,
        maxResponseTime: TimeInterval = 0.1 // 100ms
    ) {
        self.maxLayoutTime = maxLayoutTime
        self.maxMemoryUsageGB = maxMemoryUsageGB
        self.minCacheHitRate = minCacheHitRate
        self.minFPS = minFPS
        self.maxResponseTime = maxResponseTime
    }
}

/// Monitoring configuration
public struct MonitoringConfiguration {
    /// Whether to enable real-time metrics collection.
    public var enableRealTimeMetrics: Bool
    /// Whether to enable performance alerts.
    public var enableAlerts: Bool
    /// Severity threshold for triggering alerts.
    public var alertThreshold: IssueSeverity
    /// Update interval for metrics collection in seconds.
    public var updateInterval: TimeInterval

    /// Creates monitoring configuration with specified settings.
    /// - Parameters:
    ///   - enableRealTimeMetrics: Enable real-time metrics (default: true)
    ///   - enableAlerts: Enable alerts (default: true)
    ///   - alertThreshold: Alert threshold (default: .warning)
    ///   - updateInterval: Update interval (default: 1.0s)
    public init(
        enableRealTimeMetrics: Bool = true,
        enableAlerts: Bool = true,
        alertThreshold: IssueSeverity = .warning,
        updateInterval: TimeInterval = 1.0
    ) {
        self.enableRealTimeMetrics = enableRealTimeMetrics
        self.enableAlerts = enableAlerts
        self.alertThreshold = alertThreshold
        self.updateInterval = updateInterval
    }
}

// MARK: - History Tracking

/// Performance data point for history tracking
public struct PerformanceDataPoint {
    /// Timestamp when this data point was recorded.
    public let timestamp: Date
    /// CPU usage percentage at this point.
    public let cpuUsage: Double
    /// Memory usage in MB at this point.
    public let memoryUsage: Double
    /// Frames per second at this point.
    public let fps: Int
    /// Response time in seconds at this point.
    public let responseTime: Double

    /// Creates a performance data point.
    /// - Parameters:
    ///   - timestamp: When this data point was recorded
    ///   - cpuUsage: CPU usage percentage
    ///   - memoryUsage: Memory usage in MB
    ///   - fps: Frames per second
    ///   - responseTime: Response time in seconds
    public init(
        timestamp: Date,
        cpuUsage: Double,
        memoryUsage: Double,
        fps: Int,
        responseTime: Double
    ) {
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.fps = fps
        self.responseTime = responseTime
    }
}

/// Performance trend analysis
public struct PerformanceTrend {
    /// The metric being analyzed.
    public let metric: String
    /// Percentage change per time unit.
    public let changeRate: Double
    /// Whether the trend is increasing.
    public let isIncreasing: Bool
    /// Confidence in the trend analysis (0-1).
    public let confidence: Double

    /// Creates a performance trend analysis.
    /// - Parameters:
    ///   - metric: The metric being analyzed
    ///   - changeRate: Percentage change per time unit
    ///   - isIncreasing: Whether the trend is increasing
    ///   - confidence: Confidence in the analysis (0-1)
    public init(metric: String, changeRate: Double, isIncreasing: Bool, confidence: Double) {
        self.metric = metric
        self.changeRate = changeRate
        self.isIncreasing = isIncreasing
        self.confidence = confidence
    }
}

/// Performance history tracking
@MainActor
public final class PerformanceHistory {
    private var dataPoints: [PerformanceDataPoint] = []
    private let maxDataPoints = 300 // 5 minutes at 1 second intervals

    /// Creates a new performance history tracker.
    public init() {}

    /// Records a new performance data point.
    /// - Parameter metrics: The real-time metrics to record
    public func record(_ metrics: RealTimeMetrics) {
        let dataPoint = PerformanceDataPoint(
            timestamp: Date(),
            cpuUsage: metrics.cpuUsage,
            memoryUsage: metrics.memoryUsage,
            fps: metrics.currentFPS,
            responseTime: metrics.averageResponseTime
        )

        dataPoints.append(dataPoint)

        // Trim old data points
        if dataPoints.count > maxDataPoints {
            dataPoints.removeFirst(dataPoints.count - maxDataPoints)
        }
    }

    /// Gets performance history for a specified duration.
    /// - Parameters:
    ///   - metric: The metric name (unused in current implementation)
    ///   - duration: Duration in seconds to look back
    /// - Returns: Array of performance data points within the duration
    public func getHistory(for _: String, duration: TimeInterval) -> [PerformanceDataPoint] {
        let cutoff = Date().addingTimeInterval(-duration)
        return dataPoints.filter { $0.timestamp >= cutoff }
    }

    /// Analyzes the trend for a specific metric.
    /// - Parameter metric: The metric to analyze ("cpu", "memory", "fps", "response")
    /// - Returns: Performance trend analysis or nil if insufficient data
    public func analyzeTrend(for metric: String) -> PerformanceTrend? {
        guard dataPoints.count >= 10 else { return nil }

        // Simple linear regression for trend analysis
        let recentPoints = Array(dataPoints.suffix(60)) // Last minute
        guard recentPoints.count >= 10 else { return nil }

        let values: [Double]
        switch metric {
        case "cpu":
            values = recentPoints.map { $0.cpuUsage }

        case "memory":
            values = recentPoints.map { $0.memoryUsage }

        case "fps":
            values = recentPoints.map { Double($0.fps) }

        case "response":
            values = recentPoints.map { $0.responseTime }

        default:
            return nil
        }

        // Calculate simple trend
        let firstHalf = values.prefix(values.count / 2).reduce(0, +) / Double(values.count / 2)
        let secondHalf = values.suffix(values.count / 2).reduce(0, +) / Double(values.count / 2)

        let changeRate = ((secondHalf - firstHalf) / firstHalf) * 100
        let isIncreasing = secondHalf > firstHalf

        // Simple confidence based on variance
        let variance = values.reduce(0) { sum, value in
            sum + pow(value - firstHalf, 2)
        } / Double(values.count)
        let confidence = max(0, min(1, 1 - (variance / 100)))

        return PerformanceTrend(
            metric: metric,
            changeRate: abs(changeRate),
            isIncreasing: isIncreasing,
            confidence: confidence
        )
    }

    /// Clears all performance history data.
    public func clear() {
        dataPoints.removeAll()
    }
}
