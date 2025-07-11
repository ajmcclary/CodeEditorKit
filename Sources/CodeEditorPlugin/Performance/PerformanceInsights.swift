import Combine
import Foundation
import SwiftUI

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
    private let performanceMonitor = PerformanceMonitor.shared
    private let textKit2Monitor = TextKit2PerformanceMonitor()
    private let memoryMonitor: MemoryMonitor
    
    /// Update timer
    private var updateTimer: Timer?
    
    /// Thresholds for performance detection
    private let thresholds = PerformanceThresholds()
    
    /// Alert manager for user notifications
    private let alertManager = PerformanceAlertManager()
    
    // MARK: - Initialization
    
    public init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
        startMonitoring()
    }
    
    deinit {
        // Timer cleanup is handled by the system when deallocated
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
        if let cpuTrend = history.getTrend(for: .cpu), cpuTrend.isIncreasing {
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

/// Performance status levels for insights
public enum InsightsPerformanceStatus {
    case optimal
    case suboptimal
    case degraded
    case critical
    
    public var color: Color {
        switch self {
        case .optimal: return .green
        case .suboptimal: return .yellow
        case .degraded: return .orange
        case .critical: return .red
        }
    }
    
    public var description: String {
        switch self {
        case .optimal: return "Performance is optimal"
        case .suboptimal: return "Minor performance issues detected"
        case .degraded: return "Performance is degraded"
        case .critical: return "Critical performance issues"
        }
    }
}

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

/// Real-time performance metrics
public struct RealTimeMetrics {
    public var cpuUsage: Double = 0
    public var memoryUsage: Double = 0
    public var currentFPS: Int = 60
    public var activeOperations: Int = 0
    public var averageResponseTime: Double = 0
}

/// Performance thresholds
struct PerformanceThresholds {
    let maxLayoutTime: TimeInterval = 0.05 // 50ms
    let maxMemoryUsageGB: Double = 2.0
    let minCacheHitRate: Double = 0.7
    let minFPS: Int = 30
    let maxResponseTime: TimeInterval = 0.1 // 100ms
}

/// Monitoring configuration
public struct MonitoringConfiguration {
    public var enableRealTimeMetrics: Bool = true
    public var enableAlerts: Bool = true
    public var alertThreshold: IssueSeverity = .warning
    public var updateInterval: TimeInterval = 1.0
}

/// Performance history tracking
public final class PerformanceHistory {
    private var dataPoints: [PerformanceDataPoint] = []
    private let maxDataPoints = 300 // 5 minutes at 1 second intervals
    
    func record(_ metrics: RealTimeMetrics) {
        let dataPoint = PerformanceDataPoint(
            timestamp: Date(),
            cpuUsage: metrics.cpuUsage,
            memoryUsage: metrics.memoryUsage,
            fps: metrics.currentFPS,
            responseTime: metrics.averageResponseTime
        )
        
        dataPoints.append(dataPoint)
        
        // Trim old data
        if dataPoints.count > maxDataPoints {
            dataPoints.removeFirst()
        }
    }
    
    func getTrends() -> [MetricType: PerformanceTrend] {
        var trends: [MetricType: PerformanceTrend] = [:]
        
        for metricType in MetricType.allCases {
            if let trend = getTrend(for: metricType) {
                trends[metricType] = trend
            }
        }
        
        return trends
    }
    
    func getTrend(for metric: MetricType) -> PerformanceTrend? {
        guard dataPoints.count >= 10 else { return nil }
        
        let values = dataPoints.suffix(60).map { dataPoint -> Double in
            switch metric {
            case .cpu: return dataPoint.cpuUsage
            case .memory: return dataPoint.memoryUsage
            case .fps: return Double(dataPoint.fps)
            case .responseTime: return dataPoint.responseTime
            }
        }
        
        // Simple linear regression
        let count = Double(values.count)
        let sumX = (0..<values.count).reduce(0.0) { $0 + Double($1) }
        let sumY = values.reduce(0.0, +)
        let sumXY = values.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let sumX2 = (0..<values.count).reduce(0.0) { $0 + Double($1) * Double($1) }
        
        let slope = (count * sumXY - sumX * sumY) / (count * sumX2 - sumX * sumX)
        let average = sumY / count
        
        return PerformanceTrend(
            metric: metric,
            isIncreasing: slope > 0.1,
            isDecreasing: slope < -0.1,
            changeRate: slope,
            averageValue: average
        )
    }
    
    func clear() {
        dataPoints.removeAll()
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
    
    public enum MetricType: CaseIterable {
        case cpu
        case memory
        case fps
        case responseTime
    }
}

/// Performance data point
private struct PerformanceDataPoint {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let fps: Int
    let responseTime: Double
}

/// Performance trend analysis
public struct PerformanceTrend {
    let metric: PerformanceHistory.MetricType
    let isIncreasing: Bool
    let isDecreasing: Bool
    let changeRate: Double
    let averageValue: Double
}

/// Detailed performance report
public struct DetailedPerformanceReport {
    public let timestamp: Date
    public let overallStatus: InsightsPerformanceStatus
    public let performanceMetrics: PerformanceReport
    public let textKitMetrics: String
    public let memoryStatus: MemoryStatistics
    public let activeIssues: [InsightsPerformanceIssue]
    public let recommendations: [InsightsPerformanceRecommendation]
    public let historicalTrends: [PerformanceHistory.MetricType: PerformanceTrend]
}

/// Performance alert manager
@MainActor
private class PerformanceAlertManager {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "PerformanceAlertManager")
    var isEnabled = true
    var alertThreshold: IssueSeverity = .warning
    private var sentAlerts: Set<String> = []
    
    func sendAlert(for issue: InsightsPerformanceIssue) {
        guard !sentAlerts.contains(issue.id) else { return }
        
        // Mark as sent
        sentAlerts.insert(issue.id)
        
        // In a real implementation, this would show a user notification
        // For now, just log it
        logger.warning("Performance Alert: \(issue.description)")
        
        // Remove from sent alerts after 5 minutes
        let issueId = issue.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
            self?.sentAlerts.remove(issueId)
        }
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - SwiftUI Views

#if canImport(SwiftUI)
/// Performance status indicator view
public struct PerformanceStatusView: View {
    @ObservedObject var insights: PerformanceInsights
    
    public init(insights: PerformanceInsights) {
        self.insights = insights
    }
    
    public var body: some View {
        HStack {
            Circle()
                .fill(insights.status.color)
                .frame(width: 8, height: 8)
            
            Text(insights.status.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !insights.issues.isEmpty {
                Text("(\(insights.issues.count) issues)")
                    .font(.caption)
                    .foregroundColor(insights.status.color)
            }
        }
    }
}

/// Performance insights panel
public struct PerformanceInsightsPanel: View {
    @ObservedObject var insights: PerformanceInsights
    @State private var showingDetailedReport = false
    
    public init(insights: PerformanceInsights) {
        self.insights = insights
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Performance Insights")
                    .font(.headline)
                
                Spacer()
                
                PerformanceStatusView(insights: insights)
            }
            
            // Real-time metrics
            VStack(alignment: .leading, spacing: 8) {
                MetricRow(label: "CPU", value: "\(Int(insights.metrics.cpuUsage))%")
                MetricRow(label: "Memory", value: String(format: "%.1f GB", insights.metrics.memoryUsage))
                MetricRow(label: "FPS", value: "\(insights.metrics.currentFPS)")
                MetricRow(label: "Response", value: String(format: "%.0f ms", insights.metrics.averageResponseTime))
            }
            .padding(.vertical, 4)
            
            // Issues
            if !insights.issues.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Issues")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(insights.issues) { issue in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(issue.severity == .critical ? .red : .orange)
                                .font(.caption)
                            
                            Text(issue.description)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }
            
            // Recommendations
            if !insights.recommendations.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(insights.recommendations.prefix(3)) { recommendation in
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text(recommendation.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // Actions
            Divider()
            
            HStack {
                Button("Detailed Report") {
                    showingDetailedReport = true
                }
                .font(.caption)
                
                Spacer()
                
                Button("Reset") {
                    insights.reset()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(PlatformColors.controlBackground))
        .cornerRadius(8)
        .sheet(isPresented: $showingDetailedReport) {
            // Detailed report view would go here
            Text("Detailed Performance Report")
                .padding()
        }
    }
    
    struct MetricRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                Text(value)
                    .font(.caption.monospacedDigit())
            }
        }
    }
}
#endif
