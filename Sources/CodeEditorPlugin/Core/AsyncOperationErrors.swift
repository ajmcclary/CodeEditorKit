import CodeEditorCommon
import CodeEditorLanguages
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

// MARK: - Syntax Highlighting Errors

/// Errors that can occur during syntax highlighting operations
public enum SyntaxHighlightingError: RecoverableAsyncError {
    case textTooLarge(size: Int, limit: Int)
    case languageNotSupported(Language)
    case parsingFailed(underlying: Error)
    case cacheCorrupted
    case memoryPressure(availableMB: Double, requiredMB: Double)
    case timeout(duration: Duration)
    case cancelled

    public var recoveryStrategies: [RecoveryStrategy] {
        switch self {
        case .textTooLarge:
            return [
                RecoveryStrategy(
                    action: .useAlternativeImplementation(name: "StreamingHighlighter"),
                    priority: 100,
                    description: "Use streaming highlighter for large files"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Disable syntax highlighting"),
                    priority: 50,
                    description: "Continue without syntax highlighting"
                ),
                RecoveryStrategy(
                    action: .reduceResourceUsage(suggestion: "Increase performance limits in configuration"),
                    priority: 25,
                    description: "Adjust performance settings"
                )
            ]

        case .languageNotSupported:
            return [
                RecoveryStrategy(
                    action: .fallback(description: "Use plain text highlighting"),
                    priority: 100,
                    description: "Fall back to basic text display"
                ),
                RecoveryStrategy(
                    action: .reportToUser(message: "Language not supported for syntax highlighting"),
                    priority: 50,
                    description: "Inform user about limitation"
                )
            ]

        case .parsingFailed:
            return [
                RecoveryStrategy(
                    action: .retry(maxAttempts: 2, backoffStrategy: .constant(.milliseconds(100))),
                    priority: 75,
                    description: "Retry parsing with fresh state"
                ),
                RecoveryStrategy(
                    action: .clearCacheAndRetry,
                    priority: 50,
                    description: "Clear cache and retry"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Use regex-based highlighting"),
                    priority: 25,
                    description: "Fall back to simpler highlighting"
                )
            ]

        case .cacheCorrupted:
            return [
                RecoveryStrategy(
                    action: .clearCacheAndRetry,
                    priority: 100,
                    description: "Clear corrupted cache and rebuild"
                )
            ]

        case .memoryPressure:
            return [
                RecoveryStrategy(
                    action: .reduceResourceUsage(suggestion: "Reduce cache size and retry"),
                    priority: 100,
                    description: "Free memory and retry"
                ),
                RecoveryStrategy(
                    action: .useAlternativeImplementation(name: "LowMemoryHighlighter"),
                    priority: 75,
                    description: "Use memory-efficient implementation"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Postpone highlighting until memory available"),
                    priority: 50,
                    description: "Defer operation"
                )
            ]

        case .timeout:
            return [
                RecoveryStrategy(
                    action: .retry(maxAttempts: 1, backoffStrategy: .constant(.seconds(1))),
                    priority: 75,
                    description: "Retry with increased timeout"
                ),
                RecoveryStrategy(
                    action: .useAlternativeImplementation(name: "StreamingHighlighter"),
                    priority: 50,
                    description: "Use incremental processing"
                )
            ]

        case .cancelled:
            return [
                RecoveryStrategy(
                    action: .ignore,
                    priority: 100,
                    description: "Operation was intentionally cancelled"
                )
            ]
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .parsingFailed, .timeout, .memoryPressure:
            return true

        case .textTooLarge, .languageNotSupported, .cacheCorrupted, .cancelled:
            return false
        }
    }

    public var retryDelay: Duration? {
        switch self {
        case .parsingFailed:
            return .milliseconds(100)

        case .timeout:
            return .seconds(1)

        case .memoryPressure:
            return .seconds(2)

        default:
            return nil
        }
    }

    public var userDescription: String {
        switch self {
        case let .textTooLarge(size, limit):
            return "File too large for syntax highlighting (\(size) > \(limit) characters)"

        case .languageNotSupported(let language):
            return "\(language.rawValue) is not supported for syntax highlighting"

        case .parsingFailed:
            return "Failed to parse file for syntax highlighting"

        case .cacheCorrupted:
            return "Syntax highlighting cache is corrupted"

        case let .memoryPressure(available, required):
            return "Insufficient memory (available: \(Int(available))MB, required: \(Int(required))MB)"

        case .timeout:
            return "Syntax highlighting took too long"

        case .cancelled:
            return "Syntax highlighting was cancelled"
        }
    }
}

// MARK: - Completion Errors

/// Errors that can occur during code completion operations
public enum CompletionAsyncError: RecoverableAsyncError {
    case providerNotAvailable(Language)
    case contextExtractionFailed
    case timeout(duration: Duration)
    case tooManyResults(count: Int, limit: Int)
    case lspConnectionFailed(Error)
    case cancelled

    public var recoveryStrategies: [RecoveryStrategy] {
        switch self {
        case .providerNotAvailable:
            return [
                RecoveryStrategy(
                    action: .fallback(description: "Use basic keyword completion"),
                    priority: 100,
                    description: "Fall back to simple completion"
                )
            ]

        case .contextExtractionFailed:
            return [
                RecoveryStrategy(
                    action: .retry(maxAttempts: 2, backoffStrategy: .constant(.milliseconds(50))),
                    priority: 75,
                    description: "Retry context extraction"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Use partial context"),
                    priority: 50,
                    description: "Continue with limited context"
                )
            ]

        case .timeout:
            return [
                RecoveryStrategy(
                    action: .retry(maxAttempts: 1, backoffStrategy: .constant(.milliseconds(200))),
                    priority: 75,
                    description: "Retry with extended timeout"
                ),
                RecoveryStrategy(
                    action: .reduceResourceUsage(suggestion: "Request fewer completions"),
                    priority: 50,
                    description: "Limit completion results"
                )
            ]

        case let .tooManyResults(count, limit):
            return [
                RecoveryStrategy(
                    action: .reduceResourceUsage(suggestion: "Filter to top \(limit) results"),
                    priority: 100,
                    description: "Limit results to \(limit)"
                ),
                RecoveryStrategy(
                    action: .reportToUser(message: "Showing \(limit) of \(count) completions"),
                    priority: 50,
                    description: "Inform user about truncation"
                )
            ]

        case .lspConnectionFailed:
            return [
                RecoveryStrategy(
                    action: .retry(maxAttempts: 3, backoffStrategy: .exponential(initial: .seconds(1), multiplier: 2, maxDelay: .seconds(10))),
                    priority: 100,
                    description: "Retry LSP connection"
                ),
                RecoveryStrategy(
                    action: .fallback(description: "Use built-in completion provider"),
                    priority: 75,
                    description: "Fall back to local completion"
                ),
                RecoveryStrategy(
                    action: .reportToUser(message: "Language server unavailable"),
                    priority: 50,
                    description: "Notify user about LSP issue"
                )
            ]

        case .cancelled:
            return [
                RecoveryStrategy(
                    action: .ignore,
                    priority: 100,
                    description: "Completion was cancelled by user"
                )
            ]
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .contextExtractionFailed, .timeout, .lspConnectionFailed:
            return true

        default:
            return false
        }
    }

    public var retryDelay: Duration? {
        switch self {
        case .contextExtractionFailed:
            return .milliseconds(50)

        case .timeout:
            return .milliseconds(200)

        case .lspConnectionFailed:
            return .seconds(1)

        default:
            return nil
        }
    }

    public var userDescription: String {
        switch self {
        case .providerNotAvailable(let language):
            return "Code completion not available for \(language.rawValue)"

        case .contextExtractionFailed:
            return "Failed to analyze code context"

        case .timeout:
            return "Code completion timed out"

        case let .tooManyResults(count, limit):
            return "Too many completions found (\(count)), showing first \(limit)"

        case .lspConnectionFailed:
            return "Language server connection failed"

        case .cancelled:
            return "Code completion cancelled"
        }
    }
}

// MARK: - Error Recovery Coordinator

/// Coordinates error recovery strategies across the application
@available(macOS 13.0, iOS 16.0, *)
public actor ErrorRecoveryCoordinator {
    private var activeRecoveries: [UUID: RecoveryTask] = [:]

    private struct RecoveryTask {
        let error: any RecoverableAsyncError
        let strategy: RecoveryStrategy
        let startTime: Date
        var attempts: Int = 0
    }

    /// Attempt to recover from an error using its suggested strategies
    public func recover<T>(
        from error: any RecoverableAsyncError,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let strategies = error.recoveryStrategies.sorted { $0.priority > $1.priority }

        for strategy in strategies {
            let recoveryId = UUID()
            activeRecoveries[recoveryId] = RecoveryTask(
                error: error,
                strategy: strategy,
                startTime: Date()
            )

            do {
                let result = try await attemptRecovery(
                    strategy: strategy,
                    error: error,
                    operation: operation,
                    recoveryId: recoveryId
                )
                activeRecoveries.removeValue(forKey: recoveryId)
                return result
            } catch {
                activeRecoveries.removeValue(forKey: recoveryId)
                // Try next strategy
                continue
            }
        }

        // All strategies failed, throw original error
        throw error
    }

    private func attemptRecovery<T>(
        strategy: RecoveryStrategy,
        error: any RecoverableAsyncError,
        operation: @Sendable () async throws -> T,
        recoveryId _: UUID
    ) async throws -> T {
        switch strategy.action {
        case let .retry(maxAttempts, backoffStrategy):
            return try await retryWithBackoff(
                maxAttempts: maxAttempts,
                backoffStrategy: backoffStrategy,
                operation: operation
            )

        case .fallback, .useAlternativeImplementation:
            // These require context-specific handling
            throw error

        case .ignore:
            throw CancellationError()

        case .reportToUser:
            // Log and continue
            CrossPlatformLogger.logger().error("Error reported to user: \(error.userDescription)")
            throw error

        case .clearCacheAndRetry:
            // This would need to be handled by specific subsystems
            throw error

        case .reduceResourceUsage:
            // This would need to be handled by specific subsystems
            throw error
        }
    }

    private func retryWithBackoff<T>(
        maxAttempts: Int,
        backoffStrategy: BackoffStrategy,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                if attempt < maxAttempts {
                    let delay = backoffStrategy.delay(for: attempt)
                    try await Task.sleep(for: delay)
                }
            }
        }

        throw lastError ?? SyntaxHighlightingError.cancelled
    }
}
