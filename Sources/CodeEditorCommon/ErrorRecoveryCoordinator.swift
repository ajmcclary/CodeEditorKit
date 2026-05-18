import Foundation

/// Coordinates error recovery strategies across the application
@available(macOS 13.0, iOS 16.0, *)
public actor ErrorRecoveryCoordinator {
    private var activeRecoveries: [UUID: RecoveryTask] = [:]

    /// Creates a new error-recovery coordinator with an empty in-flight queue.
    public init() {}

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

        throw lastError ?? CancellationError()
    }
}
