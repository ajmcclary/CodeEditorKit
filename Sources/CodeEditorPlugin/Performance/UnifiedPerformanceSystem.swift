import Foundation

/// Unified performance monitoring and insights system
@MainActor
public final class UnifiedPerformanceSystem {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "UnifiedPerformanceSystem")

    /// Public initializer for dependency injection
    public init() {}

    deinit {
        // Cleanup is handled automatically by ARC
    }

    // MARK: - Performance Metrics Storage

    private var metrics: [PerformanceMetricType: [PerformanceMetric]] = [:]
    private var activeOperations: [UUID: OperationInfo] = [:]
    private var performanceProfiles: [String: PerformanceProfile] = [:]

    // MARK: - Configuration

    private var retentionPeriod: TimeInterval = 3_600 // 1 hour
    private var maxMetricsPerType = 1_000
    private var enableAutoOptimization = true

    // MARK: - Public API

    /// Track a performance metric
    public func track<T>(
        _ metricType: PerformanceMetricType,
        operation: () async throws -> T
    ) async throws -> T {
        let operationId = UUID()
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()

        // Record operation start
        activeOperations[operationId] = OperationInfo(
            id: operationId,
            type: metricType,
            startTime: startTime,
            startMemory: startMemory
        )

        do {
            let result = try await operation()

            // Record success
            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getMemoryUsage()

            await recordMetric(
                type: metricType,
                duration: endTime - startTime,
                memoryDelta: Int64(endMemory) - Int64(startMemory),
                success: true
            )

            activeOperations.removeValue(forKey: operationId)
            return result
        } catch {
            // Record failure
            let endTime = CFAbsoluteTimeGetCurrent()

            await recordMetric(
                type: metricType,
                duration: endTime - startTime,
                memoryDelta: 0,
                success: false,
                error: error
            )

            activeOperations.removeValue(forKey: operationId)
            throw error
        }
    }

    /// Track a performance metric for a non-throwing async operation.
    /// Records duration on success identically to the throwing variant.
    public func track<T>(
        _ metricType: PerformanceMetricType,
        operation: () async -> T
    ) async -> T {
        let operationId = UUID()
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()

        activeOperations[operationId] = OperationInfo(
            id: operationId,
            type: metricType,
            startTime: startTime,
            startMemory: startMemory
        )

        let result = await operation()

        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getMemoryUsage()

        await recordMetric(
            type: metricType,
            duration: endTime - startTime,
            memoryDelta: Int64(endMemory) - Int64(startMemory),
            success: true
        )

        activeOperations.removeValue(forKey: operationId)
        return result
    }

    /// Generate performance insights
    public func generateInsights() -> UnifiedPerformanceInsights {
        cleanupOldMetrics()

        var insights = UnifiedPerformanceInsights()

        // Analyze each metric type
        for (metricType, metricList) in metrics {
            guard !metricList.isEmpty else { continue }

            let analysis = analyzeMetrics(metricList, type: metricType)
            insights.metricAnalyses[metricType] = analysis

            // Check for issues
            let issues = detectIssues(analysis, type: metricType)
            if !issues.isEmpty {
                insights.issues.append(contentsOf: issues)
            }
        }

        // Generate recommendations
        insights.recommendations = generateRecommendations(from: insights.issues)

        // Calculate overall health
        insights.overallHealth = calculateHealthScore(from: insights)

        return insights
    }

    /// Apply performance optimizations based on current profile
    public func applyOptimizations(basedOn profile: PerformanceProfile) {
        guard enableAutoOptimization else { return }

        logger.info("Applying performance optimizations for profile: \(profile.name)")

        // Apply configuration changes based on profile
        switch profile.type {
        case .lowMemory:
            applyLowMemoryOptimizations()

        case .highLatency:
            applyHighLatencyOptimizations()

        case .cpuIntensive:
            applyCPUOptimizations()

        case .balanced:
            applyBalancedOptimizations()
        }

        // Store the active profile
        performanceProfiles[profile.name] = profile
    }

    /// Get current performance status
    public func getCurrentStatus() -> PerformanceStatus {
        let insights = generateInsights()

        return PerformanceStatus(
            activeOperations: activeOperations.count,
            healthScore: insights.overallHealth,
            criticalIssues: insights.issues.filter { $0.severity == .critical }.count,
            currentProfile: getCurrentProfile()
        )
    }

    // MARK: - Private Methods

    private func recordMetric(
        type: PerformanceMetricType,
        duration: TimeInterval,
        memoryDelta: Int64,
        success: Bool,
        error: Error? = nil
    ) async {
        let metric = PerformanceMetric(
            id: UUID(),
            type: type,
            timestamp: Date(),
            duration: duration,
            memoryDelta: memoryDelta,
            success: success,
            errorDescription: error?.localizedDescription
        )

        if metrics[type] == nil {
            metrics[type] = []
        }

        metrics[type]?.append(metric)

        // Limit stored metrics
        if let count = metrics[type]?.count, count > maxMetricsPerType {
            let removeCount = count - maxMetricsPerType
            metrics[type]?.removeFirst(removeCount)
        }

        // Log significant issues
        if !success || duration > type.warningThreshold {
            logger.warning("Performance issue detected: \(type.rawValue) took \(duration)s")
        }
    }

    private func cleanupOldMetrics() {
        let cutoffDate = Date().addingTimeInterval(-retentionPeriod)

        for (type, metricList) in metrics {
            metrics[type] = metricList.filter { $0.timestamp > cutoffDate }
        }
    }

    private func analyzeMetrics(_ metricList: [PerformanceMetric], type _: PerformanceMetricType) -> MetricAnalysis {
        let successfulMetrics = metricList.filter { $0.success }
        let durations = successfulMetrics.map { $0.duration }

        return MetricAnalysis(
            count: metricList.count,
            averageDuration: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
            maxDuration: durations.max() ?? 0,
            minDuration: durations.min() ?? 0,
            successRate: Double(successfulMetrics.count) / Double(max(metricList.count, 1)),
            p95Duration: calculatePercentile(durations, percentile: 0.95),
            memoryImpact: calculateAverageMemoryImpact(metricList)
        )
    }

    private func detectIssues(_ analysis: MetricAnalysis, type: PerformanceMetricType) -> [PerformanceIssue] {
        var issues: [PerformanceIssue] = []

        // Check for slow operations
        if analysis.averageDuration > type.warningThreshold {
            issues.append(PerformanceIssue(
                type: type,
                severity: analysis.averageDuration > type.criticalThreshold ? .critical : .warning,
                description: "\(type) operations are running slowly",
                metric: "Average duration: \(String(format: "%.2f", analysis.averageDuration))s"
            ))
        }

        // Check for low success rate
        if analysis.successRate < 0.95 {
            issues.append(PerformanceIssue(
                type: type,
                severity: analysis.successRate < 0.8 ? .critical : .warning,
                description: "\(type) operations have high failure rate",
                metric: "Success rate: \(String(format: "%.0f", analysis.successRate * 100))%"
            ))
        }

        // Check for memory issues
        if analysis.memoryImpact > 10 * 1_024 * 1_024 { // 10MB
            issues.append(PerformanceIssue(
                type: type,
                severity: .warning,
                description: "\(type) operations are using significant memory",
                metric: "Average memory impact: \(ByteCountFormatter.string(fromByteCount: analysis.memoryImpact, countStyle: .binary))"
            ))
        }

        return issues
    }

    private func generateRecommendations(from issues: [PerformanceIssue]) -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []

        // Group issues by type
        let issuesByType = Dictionary(grouping: issues) { $0.type }

        for (type, typeIssues) in issuesByType {
            let criticalCount = typeIssues.filter { $0.severity == .critical }.count

            if criticalCount > 0 {
                recommendations.append(contentsOf: type.criticalRecommendations)
            } else {
                recommendations.append(contentsOf: type.warningRecommendations)
            }
        }

        // Add general recommendations based on overall issues
        if issues.count > 5 {
            recommendations.append(PerformanceRecommendation(
                title: "Enable Performance Mode",
                description: "Multiple performance issues detected. Consider enabling performance mode.",
                action: .enableFeature("performance.mode"),
                priority: .high
            ))
        }

        return recommendations
    }

    private func calculateHealthScore(from insights: UnifiedPerformanceInsights) -> Double {
        var score = 100.0

        // Deduct for issues
        for issue in insights.issues {
            switch issue.severity {
            case .critical:
                score -= 20

            case .warning:
                score -= 10

            case .info:
                score -= 5
            }
        }

        // Ensure score stays in bounds
        return max(0, min(100, score))
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func calculatePercentile(_ values: [Double], percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }

        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * percentile)
        return sorted[index]
    }

    private func calculateAverageMemoryImpact(_ metrics: [PerformanceMetric]) -> Int64 {
        guard !metrics.isEmpty else { return 0 }

        let totalImpact = metrics.reduce(0) { $0 + abs($1.memoryDelta) }
        return totalImpact / Int64(metrics.count)
    }

    private func getCurrentProfile() -> PerformanceProfile {
        // Return the most recently applied profile or default
        performanceProfiles.values.max { $0.appliedAt < $1.appliedAt } ?? .balanced
    }

    // MARK: - Optimization Methods

    private func applyLowMemoryOptimizations() {
        // Reduce cache sizes
        NotificationCenter.default.post(
            name: .performanceOptimizationApplied,
            object: nil,
            userInfo: ["optimization": "lowMemory"]
        )
    }

    private func applyHighLatencyOptimizations() {
        // Increase timeouts and batch sizes
        NotificationCenter.default.post(
            name: .performanceOptimizationApplied,
            object: nil,
            userInfo: ["optimization": "highLatency"]
        )
    }

    private func applyCPUOptimizations() {
        // Reduce concurrent operations
        NotificationCenter.default.post(
            name: .performanceOptimizationApplied,
            object: nil,
            userInfo: ["optimization": "cpuIntensive"]
        )
    }

    private func applyBalancedOptimizations() {
        // Reset to default settings
        NotificationCenter.default.post(
            name: .performanceOptimizationApplied,
            object: nil,
            userInfo: ["optimization": "balanced"]
        )
    }
}

// MARK: - Supporting Types

public enum PerformanceMetricType: String, CaseIterable {
    case syntaxHighlighting
    case textEditing
    case scrolling
    case fileLoading
    case completion
    case search
    case rangeProcessing
    case viewportUpdate

    var warningThreshold: TimeInterval {
        switch self {
        case .syntaxHighlighting: return 0.5
        case .textEditing: return 0.1
        case .scrolling: return 0.016 // 60 FPS
        case .fileLoading: return 2.0
        case .completion: return 0.3
        case .search: return 1.0
        case .rangeProcessing: return 0.2
        case .viewportUpdate: return 0.05
        }
    }

    var criticalThreshold: TimeInterval {
        warningThreshold * 2
    }

    var warningRecommendations: [PerformanceRecommendation] {
        switch self {
        case .syntaxHighlighting:
            return [
                PerformanceRecommendation(
                    title: "Optimize Syntax Highlighting",
                    description: "Consider enabling viewport-based highlighting",
                    action: .configureFeature("syntaxHighlighting.viewportOnly", true),
                    priority: .medium
                )
            ]

        case .scrolling:
            return [
                PerformanceRecommendation(
                    title: "Enable Hardware Acceleration",
                    description: "Hardware acceleration can improve scrolling performance",
                    action: .enableFeature("performance.hardwareAcceleration"),
                    priority: .high
                )
            ]

        default:
            return []
        }
    }

    var criticalRecommendations: [PerformanceRecommendation] {
        warningRecommendations + [
            PerformanceRecommendation(
                title: "Reduce Feature Complexity",
                description: "Disable non-essential features to improve performance",
                action: .applyProfile(.performance),
                priority: .critical
            )
        ]
    }
}

/// Represents a single performance metric measurement.
public struct PerformanceMetric {
    let id: UUID
    let type: PerformanceMetricType
    let timestamp: Date
    let duration: TimeInterval
    let memoryDelta: Int64
    let success: Bool
    let errorDescription: String?
}

/// Information about an active performance operation.
public struct OperationInfo {
    let id: UUID
    let type: PerformanceMetricType
    let startTime: CFAbsoluteTime
    let startMemory: UInt64
}

/// Analysis of collected metrics for a specific metric type.
public struct MetricAnalysis {
    /// Number of metric samples included in the analysis.
    public let count: Int
    /// Mean duration of the sampled operations in seconds.
    public let averageDuration: TimeInterval
    /// Longest recorded duration in seconds.
    public let maxDuration: TimeInterval
    /// Shortest recorded duration in seconds.
    public let minDuration: TimeInterval
    /// Proportion of successful operations (`0...1`).
    public let successRate: Double
    /// 95th percentile duration in seconds.
    public let p95Duration: TimeInterval
    /// Sum of memory deltas across samples in bytes.
    public let memoryImpact: Int64
}

/// Comprehensive performance insights and analysis.
public struct UnifiedPerformanceInsights {
    /// Per-metric-type analysis derived from recent samples.
    public var metricAnalyses: [PerformanceMetricType: MetricAnalysis] = [:]
    /// Detected performance issues, ordered by severity.
    public var issues: [PerformanceIssue] = []
    /// Suggested mitigations for the detected issues.
    public var recommendations: [PerformanceRecommendation] = []
    /// Composite health score (`0...100`, higher is better).
    public var overallHealth: Double = 100.0
}

/// Represents a performance issue that needs attention.
public struct PerformanceIssue {
    /// Metric type the issue applies to.
    public let type: PerformanceMetricType
    /// Severity of the issue.
    public let severity: PerformanceIssueSeverity
    /// Human-readable description of the issue.
    public let description: String
    /// Identifier of the metric that triggered the issue.
    public let metric: String
}

/// Severity levels for performance issues.
public enum PerformanceIssueSeverity {
    /// Informational issue that doesn't require immediate action.
    case info
    /// Warning issue that should be addressed.
    case warning
    /// Critical issue that requires immediate attention.
    case critical
}

/// A recommendation for improving performance.
public struct PerformanceRecommendation {
    /// Short title of the recommendation.
    public let title: String
    /// Detailed explanation of the recommendation.
    public let description: String
    /// Suggested concrete action.
    public let action: RecommendationAction
    /// Priority of the recommendation.
    public let priority: RecommendationPriority
}

/// Actions that can be taken to address performance recommendations.
public enum RecommendationAction {
    /// Configure a specific feature with the given parameters.
    case configureFeature(String, Any)
    /// Enable a specific feature.
    case enableFeature(String)
    /// Disable a specific feature.
    case disableFeature(String)
    /// Apply a performance profile.
    case applyProfile(PerformanceProfile)
}

/// Priority levels for performance recommendations.
public enum RecommendationPriority {
    /// Low priority recommendation.
    case low
    /// Medium priority recommendation.
    case medium
    /// High priority recommendation.
    case high
    /// Critical priority recommendation.
    case critical
}

public struct PerformanceProfile: Sendable {
    let name: String
    let type: ProfileType
    let appliedAt: Date

    static let balanced = Self(
        name: "Balanced",
        type: .balanced,
        appliedAt: Date()
    )

    static let performance = Self(
        name: "Performance",
        type: .cpuIntensive,
        appliedAt: Date()
    )

    enum ProfileType {
        case lowMemory
        case highLatency
        case cpuIntensive
        case balanced
    }
}

/// Current status of the performance system.
public struct PerformanceStatus {
    let activeOperations: Int
    let healthScore: Double
    let criticalIssues: Int
    let currentProfile: PerformanceProfile
}

// MARK: - Notifications

extension Notification.Name {
    static let performanceOptimizationApplied = Notification.Name("performanceOptimizationApplied")
}

// MARK: - Integration Extensions

extension CodeEditorView {
    /// Track performance of an operation
    public func trackPerformance<T>(
        _ metric: PerformanceMetricType,
        operation: () async throws -> T
    ) async throws -> T {
        try await CodeEditorDependencies.makeUnifiedPerformanceSystem().track(metric, operation: operation)
    }
}
