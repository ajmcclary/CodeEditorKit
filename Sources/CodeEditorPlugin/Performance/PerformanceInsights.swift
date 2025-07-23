import Foundation
import SwiftUI
#if canImport(Combine)
import Combine
#endif

// MARK: - PerformanceInsights

/// Provides real-time performance insights and recommendations
@MainActor
public final class PerformanceInsights: ObservableObject {
    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "PerformanceInsights")

    /// Current performance status
    @Published public private(set) var status: InsightsPerformanceStatus = .optimal

    /// Performance issues detected
    @Published public private(set) var issues: [InsightsPerformanceIssue] = []

    /// Performance recommendations
    @Published public private(set) var recommendations: [InsightsPerformanceRecommendation] = []

    /// Real-time metrics
    @Published public private(set) var metrics = RealTimeMetrics()

    /// Historical data
    private var history = PerformanceHistory()

    /// Monitoring components
    private let performanceMonitor: PerformanceMonitor
    private let textKit2Monitor = InsightsTextKit2Monitor()
    private let memoryMonitor: MemoryMonitor

    /// Update timer
    private var updateTimer: Timer?

    /// Thresholds for performance detection
    private let thresholds = PerformanceThresholds()

    /// Alert manager for user notifications
    private let alertManager = PerformanceAlertManager()

    // MARK: - Initialization

    public init(memoryMonitor: MemoryMonitor, performanceMonitor: PerformanceMonitor? = nil) {
        self.memoryMonitor = memoryMonitor
        self.performanceMonitor = performanceMonitor ?? PerformanceMonitor()
        startMonitoring()
    }

    deinit {
        // Use MainActor.assumeIsolated to safely clean up @MainActor resources
        // This is safe because PerformanceInsights instances are created and destroyed on the main actor
        MainActor.assumeIsolated {
            // Properly invalidate timer to prevent memory leaks
            updateTimer?.invalidate()
            updateTimer = nil

            logger.debug("PerformanceInsights deallocated and cleaned up")
        }
    }

    // MARK: - Public Methods

    /// Start performance monitoring
    public func startMonitoring() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }

    /// Stop performance monitoring
    public func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Get detailed performance report
    public func generateDetailedReport() async -> DetailedPerformanceReport {
        let performanceReport = await performanceMonitor.generateReport()
        let textKitSummary = textKit2Monitor.performanceSummary
        let memoryStatus = memoryMonitor.getMemoryStatistics()

        return DetailedPerformanceReport(
            timestamp: Date(),
            overallStatus: status,
            performanceMetrics: performanceReport,
            textKitMetrics: textKitSummary,
            memoryStatus: memoryStatus,
            activeIssues: issues,
            recommendations: recommendations,
            historicalTrends: history.getTrends()
        )
    }

    /// Reset all performance data
    public func reset() {
        Task {
            await performanceMonitor.clearMetrics()
        }
        textKit2Monitor.reset()
        issues.removeAll()
        recommendations.removeAll()
        metrics = RealTimeMetrics()
        history.clear()
        status = .optimal
    }

    /// Enable/disable specific monitoring features
    public func configureMonitoring(_ config: MonitoringConfiguration) {
        // Apply configuration
        if config.enableRealTimeMetrics {
            startMonitoring()
        } else {
            stopMonitoring()
        }

        alertManager.isEnabled = config.enableAlerts
        alertManager.alertThreshold = config.alertThreshold
    }

    // MARK: - Private Methods

    private func updateMetrics() {
        // Collect metrics from various sources
        collectRealTimeMetrics()

        // Analyze performance
        analyzePerformance()

        // Update history
        history.record(metrics)

        // Check for issues
        detectIssues()

        // Generate recommendations
        generateRecommendations()

        // Update overall status
        updateStatus()

        // Send alerts if needed
        checkAlerts()
    }

    private func collectRealTimeMetrics() {
        // CPU usage (simplified - would use proper system APIs)
        metrics.cpuUsage = Double.random(in: 10...90) // Placeholder

        // Memory usage
        let memoryInfo = ProcessInfo.processInfo
        metrics.memoryUsage = Double(memoryInfo.physicalMemory) / 1_073_741_824 // GB

        // FPS (for UI responsiveness)
        metrics.currentFPS = 60 // Placeholder - would measure actual frame rate

        // Active operations and response time will be updated asynchronously
        Task {
            let allMetrics = await performanceMonitor.getAllMetrics()
            metrics.activeOperations = allMetrics.count

            // Response time (from recent operations)
            if let lastMetric = allMetrics.last,
               let duration = lastMetric.duration {
                metrics.averageResponseTime = duration * 1_000 // Convert to ms
            }
        }
    }

    private func analyzePerformance() {
        // Analyze TextKit2 performance
        _ = textKit2Monitor.performanceSummary

        // Check layout performance
        if textKit2Monitor.averageLayoutTime > thresholds.maxLayoutTime {
            addIssue(.slowTextLayout(averageTime: textKit2Monitor.averageLayoutTime))
        }

        // Check memory usage
        if metrics.memoryUsage > thresholds.maxMemoryUsageGB {
            addIssue(.highMemoryUsage(current: metrics.memoryUsage, threshold: thresholds.maxMemoryUsageGB))
        }

        // Check cache performance
        if textKit2Monitor.cacheHitRate < thresholds.minCacheHitRate {
            addIssue(.lowCacheHitRate(current: textKit2Monitor.cacheHitRate, threshold: thresholds.minCacheHitRate))
        }
    }

    private func detectIssues() {
        // Remove resolved issues
        issues.removeAll { issue in
            switch issue {
            case .slowTextLayout:
                return textKit2Monitor.averageLayoutTime <= thresholds.maxLayoutTime

            case .highMemoryUsage:
                return metrics.memoryUsage <= thresholds.maxMemoryUsageGB

            case .lowCacheHitRate:
                return textKit2Monitor.cacheHitRate >= thresholds.minCacheHitRate

            default:
                return false
            }
        }

        // Detect new issues based on trends
        if let cpuTrend = history.analyzeTrend(for: "cpu"), cpuTrend.isIncreasing {
            addIssue(.increasingCPUUsage(trend: cpuTrend))
        }
    }

    private func generateRecommendations() {
        recommendations.removeAll()

        // Based on current issues
        for issue in issues {
            switch issue {
            case .slowTextLayout:
                recommendations.append(.enableViewportOptimization)
                recommendations.append(.reduceFileSize)

            case .highMemoryUsage:
                recommendations.append(.clearCaches)
                recommendations.append(.closeUnusedFiles)

            case .lowCacheHitRate:
                recommendations.append(.increaseCacheSize)

            case .increasingCPUUsage:
                recommendations.append(.disableUnusedFeatures)
                recommendations.append(.reduceUpdateFrequency)

            default:
                break
            }
        }

        // Platform-specific recommendations
        addPlatformSpecificRecommendations()
    }

    private func addPlatformSpecificRecommendations() {
        _ = PlatformCapabilities.shared

        // Check if file size exceeds platform recommendations
        let recommendedMaxFileSize = 500_000  // 500K characters as default
        if let currentFileSize = getCurrentFileSize(),
           currentFileSize > recommendedMaxFileSize {
            recommendations.append(.splitLargeFile(currentSize: currentFileSize, recommendedSize: recommendedMaxFileSize))
        }

        // Check concurrent operations
        let maxConcurrentOperations = 10  // Default value
        if metrics.activeOperations > maxConcurrentOperations {
            recommendations.append(.reduceConcurrentOperations(current: metrics.activeOperations, max: maxConcurrentOperations))
        }
    }

    private func updateStatus() {
        if issues.isEmpty {
            status = .optimal
        } else if issues.contains(where: { $0.severity == .critical }) {
            status = .critical
        } else if issues.contains(where: { $0.severity == .warning }) {
            status = .degraded
        } else {
            status = .suboptimal
        }
    }

    private func checkAlerts() {
        guard alertManager.isEnabled else { return }

        for issue in issues where issue.severity.rawValue >= alertManager.alertThreshold.rawValue {
            alertManager.sendAlert(for: issue)
        }
    }

    private func addIssue(_ issue: InsightsPerformanceIssue) {
        if !issues.contains(where: { $0.id == issue.id }) {
            issues.append(issue)
        }
    }

    private func getCurrentFileSize() -> Int? {
        // This would get the actual file size from the editor
        // For now, return a placeholder
        nil
    }
}

// MARK: - Supporting Types

/// Performance alert manager
private final class PerformanceAlertManager {
    var isEnabled = true
    var alertThreshold: IssueSeverity = .warning
    private var sentAlerts = Set<String>()

    func sendAlert(for issue: InsightsPerformanceIssue) {
        guard !sentAlerts.contains(issue.id) else { return }

        // In a real implementation, this would show a notification
        sentAlerts.insert(issue.id)
    }

    func reset() {
        sentAlerts.removeAll()
    }
}

/// Performance summary data
public struct PerformanceSummary {
    public let averageProcessingTime: TimeInterval
    public let peakProcessingTime: TimeInterval
    public let totalOperations: Int
    public let cacheHitRate: Double
    public let errorCount: Int
}

/// Detailed performance report
public struct DetailedPerformanceReport {
    public let timestamp: Date
    public let overallStatus: InsightsPerformanceStatus
    public let performanceMetrics: PerformanceReport
    public let textKitMetrics: PerformanceSummary
    public let memoryStatus: MemoryStatistics
    public let activeIssues: [InsightsPerformanceIssue]
    public let recommendations: [InsightsPerformanceRecommendation]
    public let historicalTrends: [PerformanceTrend]
}

// Extension for PerformanceHistory
extension PerformanceHistory {
    func getTrends() -> [PerformanceTrend] {
        let metrics = ["cpu", "memory", "fps", "response"]
        return metrics.compactMap { analyzeTrend(for: $0) }
    }
}

/// TextKit2 performance monitor placeholder
private class InsightsTextKit2Monitor {
    var averageLayoutTime: TimeInterval = 0.01
    var cacheHitRate: Double = 0.85
    var performanceSummary: PerformanceSummary {
        PerformanceSummary(
            averageProcessingTime: averageLayoutTime,
            peakProcessingTime: averageLayoutTime * 2,
            totalOperations: 100,
            cacheHitRate: cacheHitRate,
            errorCount: 0
        )
    }

    func reset() {
        averageLayoutTime = 0.01
        cacheHitRate = 0.85
    }
}
