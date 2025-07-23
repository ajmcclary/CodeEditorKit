import Foundation

// MARK: - Supporting Types

/// Validation issue found in configuration
public struct ValidationIssue: Sendable {
    public let severity: Severity
    public let path: String
    public let message: String
    public let suggestedValue: (any Sendable)?

    public var isAutoFixable: Bool {
        suggestedValue != nil
    }

    public enum Severity: Comparable, Sendable {
        case info
        case warning
        case error

        public static func < (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.info, .warning), (.info, .error), (.warning, .error):
                return true

            default:
                return false
            }
        }
    }
}

/// Wrapper for values in validation fixes
public enum ValidationValue: Sendable {
    case int(Int)
    case double(Double)
    case float(CGFloat)
    case bool(Bool)
    case string(String)
    case null

    init(from value: Any?) {
        guard let value else {
            self = .null
            return
        }

        switch value {
        case let intValue as Int:
            self = .int(intValue)

        case let doubleValue as Double:
            self = .double(doubleValue)

        case let floatValue as CGFloat:
            self = .float(floatValue)

        case let boolValue as Bool:
            self = .bool(boolValue)

        case let stringValue as String:
            self = .string(stringValue)

        default:
            self = .string("\(value)")
        }
    }

    public var description: String {
        switch self {
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .float(let value): return "\(value)"
        case .bool(let value): return "\(value)"
        case .string(let value): return value
        case .null: return "nil"
        }
    }
}

/// Fix applied to resolve a validation issue
public struct ValidationFix: Sendable {
    public let issue: ValidationIssue
    public let oldValue: ValidationValue
    public let newValue: ValidationValue
    public let applied: Date
}

/// Validation report containing issues and fixes
public struct ValidationReport: Sendable {
    public let originalIssues: [ValidationIssue]
    public let appliedFixes: [ValidationFix]
    public let finalConfiguration: EditorConfiguration

    public var hasIssues: Bool {
        !originalIssues.isEmpty
    }

    public var hasCriticalIssues: Bool {
        originalIssues.contains { $0.severity == .error }
    }

    public var summary: String {
        var parts: [String] = []

        if originalIssues.isEmpty {
            parts.append("✅ Configuration is valid")
        } else {
            let errors = originalIssues.filter { $0.severity == .error }.count
            let warnings = originalIssues.filter { $0.severity == .warning }.count
            let infos = originalIssues.filter { $0.severity == .info }.count

            if errors > 0 {
                parts.append("❌ \(errors) error\(errors == 1 ? "" : "s")")
            }
            if warnings > 0 {
                parts.append("⚠️ \(warnings) warning\(warnings == 1 ? "" : "s")")
            }
            if infos > 0 {
                parts.append("ℹ️ \(infos) info\(infos == 1 ? "" : "s")")
            }
        }

        if !appliedFixes.isEmpty {
            parts.append("🔧 \(appliedFixes.count) fix\(appliedFixes.count == 1 ? "" : "es") applied")
        }

        return parts.joined(separator: ", ")
    }
}

/// Configuration validation error containing issues found during validation
public struct ConfigurationValidationError: Error, Sendable {
    public let issues: [ValidationIssue]

    public init(issues: [ValidationIssue]) {
        self.issues = issues
    }

    public var localizedDescription: String {
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count

        var parts: [String] = []
        if errorCount > 0 {
            parts.append("\(errorCount) error\(errorCount == 1 ? "" : "s")")
        }
        if warningCount > 0 {
            parts.append("\(warningCount) warning\(warningCount == 1 ? "" : "s")")
        }

        return "Configuration validation failed with \(parts.joined(separator: " and "))"
    }
}
