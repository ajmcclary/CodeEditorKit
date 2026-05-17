import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorSyntaxHighlighting
import Foundation

// `RecoverableAsyncError`, `RecoveryStrategy`, `BackoffStrategy` live in
// `CodeEditorCommon`; `SyntaxHighlightingError` lives in
// `CodeEditorSyntaxHighlighting` — relocated during the §6.2.7 extraction.

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
