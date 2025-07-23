import Foundation

/// Performance budget configuration for monitoring and enforcing performance targets
public struct PerformanceBudget: Sendable {
    /// Budget for a specific operation
    public struct Budget: Sendable {
        public let operation: String
        public let targetTime: TimeInterval
        public let warningTime: TimeInterval
        public let criticalTime: TimeInterval
        
        public init(
            operation: String,
            targetTime: TimeInterval,
            warningTime: TimeInterval? = nil,
            criticalTime: TimeInterval? = nil
        ) {
            self.operation = operation
            self.targetTime = targetTime
            self.warningTime = warningTime ?? targetTime * 1.5
            self.criticalTime = criticalTime ?? targetTime * 2.0
        }
        
        /// Check if a duration meets the budget
        public func check(_ duration: TimeInterval) -> BudgetStatus {
            if duration <= targetTime {
                return .withinBudget
            } else if duration <= warningTime {
                return .warning
            } else if duration <= criticalTime {
                return .critical
            } else {
                return .exceeded
            }
        }
    }
    
    /// Budget check status
    public enum BudgetStatus: String, Sendable {
        case withinBudget = "✅ Within Budget"
        case warning = "⚠️ Warning"
        case critical = "❌ Critical"
        case exceeded = "🚨 Exceeded"
        
        public var isAcceptable: Bool {
            self == .withinBudget || self == .warning
        }
    }
    
    /// Pre-defined performance budgets
    public static let budgets: [String: Budget] = [
        // Core operations
        "syntax_highlighting": Budget(
            operation: "Syntax Highlighting",
            targetTime: 0.016, // 60fps
            warningTime: 0.033, // 30fps
            criticalTime: 0.1
        ),
        "text_layout": Budget(
            operation: "Text Layout",
            targetTime: 0.016,
            warningTime: 0.05,
            criticalTime: 0.1
        ),
        "scrolling": Budget(
            operation: "Scrolling",
            targetTime: 0.008, // 120fps
            warningTime: 0.016, // 60fps
            criticalTime: 0.033
        ),
        
        // Completion operations
        "completion_request": Budget(
            operation: "Completion Request",
            targetTime: 0.05,
            warningTime: 0.1,
            criticalTime: 0.2
        ),
        "completion_cancellation": Budget(
            operation: "Completion Cancellation",
            targetTime: 0.01,
            warningTime: 0.05,
            criticalTime: 0.1
        ),
        
        // File operations
        "file_open_small": Budget(
            operation: "Open Small File (<10KB)",
            targetTime: 0.1,
            warningTime: 0.2,
            criticalTime: 0.5
        ),
        "file_open_medium": Budget(
            operation: "Open Medium File (10KB-1MB)",
            targetTime: 0.5,
            warningTime: 1.0,
            criticalTime: 2.0
        ),
        "file_open_large": Budget(
            operation: "Open Large File (>1MB)",
            targetTime: 2.0,
            warningTime: 5.0,
            criticalTime: 10.0
        ),
        
        // Search operations
        "find_in_file": Budget(
            operation: "Find in File",
            targetTime: 0.05,
            warningTime: 0.1,
            criticalTime: 0.2
        ),
        "fuzzy_search": Budget(
            operation: "Fuzzy Search (10k items)",
            targetTime: 0.1,
            warningTime: 0.2,
            criticalTime: 0.5
        ),
        
        // Memory operations
        "memory_pressure_recovery": Budget(
            operation: "Memory Pressure Recovery",
            targetTime: 0.5,
            warningTime: 1.0,
            criticalTime: 2.0
        ),
        
        // UI operations
        "context_menu_creation": Budget(
            operation: "Context Menu Creation",
            targetTime: 0.05,
            warningTime: 0.1,
            criticalTime: 0.5
        ),
        "line_number_update": Budget(
            operation: "Line Number Update",
            targetTime: 0.016,
            warningTime: 0.033,
            criticalTime: 0.1
        ),
        
        // Test operations
        "test_setup": Budget(
            operation: "Test Setup",
            targetTime: 0.1,
            warningTime: 0.5,
            criticalTime: 1.0
        ),
        "test_teardown": Budget(
            operation: "Test Teardown",
            targetTime: 0.1,
            warningTime: 0.5,
            criticalTime: 1.0
        )
    ]
    
    /// Get budget for an operation
    public static func budget(for operation: String) -> Budget? {
        budgets[operation]
    }
    
    /// Check all budgets and return violations
    public static func checkBudgets(_ measurements: [String: TimeInterval]) -> [BudgetViolation] {
        var violations: [BudgetViolation] = []
        
        for (operation, duration) in measurements {
            if let budget = budgets[operation] {
                let status = budget.check(duration)
                if !status.isAcceptable {
                    violations.append(BudgetViolation(
                        operation: operation,
                        budget: budget,
                        actualTime: duration,
                        status: status
                    ))
                }
            }
        }
        
        return violations
    }
}

/// Represents a budget violation
public struct BudgetViolation: Sendable {
    public let operation: String
    public let budget: PerformanceBudget.Budget
    public let actualTime: TimeInterval
    public let status: PerformanceBudget.BudgetStatus
    
    public var percentageOverBudget: Double {
        ((actualTime - budget.targetTime) / budget.targetTime) * 100.0
    }
    
    public var description: String {
        String(
            format: "%@ %@: %.3fs (%.1f%% over budget of %.3fs)",
            status.rawValue,
            operation,
            actualTime,
            percentageOverBudget,
            budget.targetTime
        )
    }
}

/// Performance budget reporter
public actor PerformanceBudgetReporter {
    private var measurements: [String: [TimeInterval]] = [:]
    private let logger = CrossPlatformLogger.logger(
        subsystem: "com.codeeditor.performance",
        category: "Budget"
    )
    
    public init() {}
    
    /// Record a measurement
    public func record(operation: String, duration: TimeInterval) {
        if measurements[operation] == nil {
            measurements[operation] = []
        }
        measurements[operation]?.append(duration)
        
        // Check budget immediately
        if let budget = PerformanceBudget.budget(for: operation) {
            let status = budget.check(duration)
            
            switch status {
            case .withinBudget:
                logger.debug("\(operation): \(String(format: "%.3f", duration))s ✅")

            case .warning:
                logger.warning("\(operation): \(String(format: "%.3f", duration))s ⚠️ (budget: \(String(format: "%.3f", budget.targetTime))s)")

            case .critical:
                logger.error("\(operation): \(String(format: "%.3f", duration))s ❌ (budget: \(String(format: "%.3f", budget.targetTime))s)")

            case .exceeded:
                logger.error("\(operation): \(String(format: "%.3f", duration))s 🚨 (budget: \(String(format: "%.3f", budget.targetTime))s)")
            }
        }
    }
    
    /// Get average measurements
    public func averageMeasurements() -> [String: TimeInterval] {
        var averages: [String: TimeInterval] = [:]
        
        for (operation, times) in measurements where !times.isEmpty {
            let average = times.reduce(0, +) / Double(times.count)
            averages[operation] = average
        }
        
        return averages
    }
    
    /// Generate performance report
    public func generateReport() -> PerformanceBudgetReport {
        let averages = averageMeasurements()
        let violations = PerformanceBudget.checkBudgets(averages)
        
        return PerformanceBudgetReport(
            measurements: measurements,
            averages: averages,
            violations: violations
        )
    }
    
    /// Clear all measurements
    public func reset() {
        measurements.removeAll()
    }
}

/// Performance budget report
public struct PerformanceBudgetReport: Sendable {
    public let measurements: [String: [TimeInterval]]
    public let averages: [String: TimeInterval]
    public let violations: [BudgetViolation]
    
    public var summary: String {
        var lines: [String] = ["Performance Budget Report"]
        lines.append("=" * 50)
        
        // Summary stats
        lines.append("Total Operations: \(measurements.count)")
        lines.append("Total Violations: \(violations.count)")
        lines.append("")
        
        // Violations
        if !violations.isEmpty {
            lines.append("Violations:")
            for violation in violations.sorted(by: { $0.percentageOverBudget > $1.percentageOverBudget }) {
                lines.append("  \(violation.description)")
            }
            lines.append("")
        }
        
        // All measurements
        lines.append("All Measurements (Average):")
        for (operation, average) in averages.sorted(by: { $0.key < $1.key }) {
            if let budget = PerformanceBudget.budget(for: operation) {
                let status = budget.check(average)
                lines.append("  \(operation): \(String(format: "%.3f", average))s \(status.rawValue)")
            } else {
                lines.append("  \(operation): \(String(format: "%.3f", average))s")
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

// Helper for string repetition
extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
