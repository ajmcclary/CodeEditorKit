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
    private var currentTask: Task<Void, Never>?

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

        // Store the current task so it can be cancelled
        let task = Task<T, Error> {
            try await operation(value)
        }

        // Track the task for potential cancellation
        currentTask = Task {
            _ = await task.result
        }

        do {
            let result = try await task.value
            endBackgroundWork()
            currentTask = nil
            return result
        } catch {
            endBackgroundWork()
            currentTask = nil
            throw error
        }
    }

    /// Cancel any pending operations
    package func cancelPendingOperations() {
        // Cancel the current task if any
        currentTask?.cancel()
        currentTask = nil

        // Reset pending count since we're cancelling all operations
        pendingCount = 0
    }
}
