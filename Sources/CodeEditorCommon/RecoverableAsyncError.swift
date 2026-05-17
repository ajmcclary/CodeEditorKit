import Foundation

// MARK: - Enhanced Error Types with Recovery Strategies

/// Protocol for errors that can provide recovery suggestions
public protocol RecoverableAsyncError: Error, Sendable {
    /// Suggested recovery strategies for this error
    var recoveryStrategies: [RecoveryStrategy] { get }

    /// Whether this error should trigger an automatic retry
    var isRetryable: Bool { get }

    /// Suggested delay before retry (if retryable)
    var retryDelay: Duration? { get }

    /// User-friendly error description
    var userDescription: String { get }
}

/// A recovery strategy for handling errors
public struct RecoveryStrategy: Sendable {
    public enum Action: Sendable {
        case retry(maxAttempts: Int, backoffStrategy: BackoffStrategy)
        case fallback(description: String)
        case ignore
        case reportToUser(message: String)
        case clearCacheAndRetry
        case useAlternativeImplementation(name: String)
        case reduceResourceUsage(suggestion: String)
    }

    public let action: Action
    public let priority: Int // Higher number = higher priority
    public let description: String

    public init(action: Action, priority: Int, description: String) {
        self.action = action
        self.priority = priority
        self.description = description
    }
}

/// Backoff strategies for retries
public enum BackoffStrategy: Sendable {
    case constant(Duration)
    case linear(initial: Duration, increment: Duration)
    case exponential(initial: Duration, multiplier: Double, maxDelay: Duration)
    case jitter(base: Duration, maxJitter: Duration)

    public func delay(for attempt: Int) -> Duration {
        switch self {
        case .constant(let duration):
            return duration

        case let .linear(initial, increment):
            let milliseconds = Double(initial.components.seconds) * 1_000 + Double(initial.components.attoseconds) / 1_000_000_000_000_000
            let incrementMs = Double(increment.components.seconds) * 1_000 + Double(increment.components.attoseconds) / 1_000_000_000_000_000
            return .milliseconds(Int(milliseconds + incrementMs * Double(attempt - 1)))

        case let .exponential(initial, multiplier, maxDelay):
            let initialMs = Double(initial.components.seconds) * 1_000 + Double(initial.components.attoseconds) / 1_000_000_000_000_000
            let delayMs = initialMs * pow(multiplier, Double(attempt - 1))
            let maxMs = Double(maxDelay.components.seconds) * 1_000 + Double(maxDelay.components.attoseconds) / 1_000_000_000_000_000
            return .milliseconds(Int(min(delayMs, maxMs)))

        case let .jitter(base, maxJitter):
            let baseMs = Double(base.components.seconds) * 1_000 + Double(base.components.attoseconds) / 1_000_000_000_000_000
            let jitterMs = Double(maxJitter.components.seconds) * 1_000 + Double(maxJitter.components.attoseconds) / 1_000_000_000_000_000
            let jitter = Double.random(in: 0...jitterMs)
            return .milliseconds(Int(baseMs + jitter))
        }
    }
}
