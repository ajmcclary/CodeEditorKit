import Foundation

/// A thread-safe processor for background operations with proper actor isolation
/// Uses Swift 6 concurrency patterns for safe access to values
package actor BackgroundProcessor<Value: Sendable> {
    package enum AccessMode {
        case synchronous
        case synchronousPreferred
        case asynchronous
    }

    private let value: Value
    private var pendingCount = 0
    /// Cancels the operation started by `processValue` that is in flight.
    private var cancelCurrentOperation: (@Sendable () -> Void)?

    package init(value: Value) {
        self.value = value
    }

    package var hasPendingWork: Bool {
        pendingCount > 0
    }

    private func beginBackgroundWork() {
        precondition(pendingCount >= 0)
        pendingCount += 1
    }

    private func endBackgroundWork() {
        pendingCount -= 1
        precondition(pendingCount >= 0)
    }

    /// Access value if no pending work exists
    /// Returns nil if work is pending to avoid blocking
    package func accessValueIfAvailable<T>(
        operation: (Value) throws -> T
    ) async throws -> T? {
        guard !hasPendingWork else {
            return nil
        }

        return try operation(value)
    }

    /// Access value with proper async handling
    package func accessValue<T>(
        operation: @escaping @Sendable (Value) async throws -> T
    ) async throws -> T {
        beginBackgroundWork()
        defer { endBackgroundWork() }

        return try await operation(value)
    }

    /// Process value with cancellation support
    package func processValue<T: Sendable>(
        operation: @escaping @Sendable (Value) async throws -> T
    ) async throws -> T {
        beginBackgroundWork()

        // Keep a way to cancel the operation itself (not a wrapper).
        let task = Task<T, Error> {
            try await operation(value)
        }
        cancelCurrentOperation = { task.cancel() }

        do {
            let result = try await task.value
            endBackgroundWork()
            cancelCurrentOperation = nil
            return result
        } catch {
            endBackgroundWork()
            cancelCurrentOperation = nil
            throw error
        }
    }

    /// Cancel any pending operations. The pending count is left to the
    /// operations themselves: each one still ends (with a cancellation
    /// error) and decrements it, so zeroing it here would drive it negative.
    package func cancelPendingOperations() {
        cancelCurrentOperation?()
        cancelCurrentOperation = nil
    }
}
