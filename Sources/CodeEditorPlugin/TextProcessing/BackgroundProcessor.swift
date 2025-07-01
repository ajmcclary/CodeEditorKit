import Foundation

/// A thread-safe processor for background operations with proper actor isolation
/// Uses Swift 6 concurrency patterns for safe access to values
actor BackgroundProcessor<Value: Sendable> {
    enum AccessMode {
        case synchronous
        case synchronousPreferred
        case asynchronous
    }

    private let value: Value
    private var pendingCount = 0

    init(value: Value) {
        self.value = value
    }

    var hasPendingWork: Bool {
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
    func accessValueIfAvailable<T>(
        operation: (Value) throws -> T
    ) async throws -> T? {
        guard !hasPendingWork else {
            return nil
        }
        
        return try operation(value)
    }

    /// Access value with proper async handling
    func accessValue<T>(
        operation: @escaping @Sendable (Value) async throws -> T
    ) async throws -> T {
        beginBackgroundWork()
        defer { endBackgroundWork() }
        
        return try await operation(value)
    }

    /// Process value with cancellation support
    func processValue<T: Sendable>(
        operation: @escaping @Sendable (Value) async throws -> T
    ) async throws -> T {
        beginBackgroundWork()
        
        do {
            let result = try await withTaskCancellationHandler {
                try await operation(value)
            } onCancel: {
                Task { await self.endBackgroundWork() }
            }
            
            endBackgroundWork()
            return result
        } catch {
            endBackgroundWork()
            throw error
        }
    }
    
    /// Cancel any pending operations
    func cancelPendingOperations() {
        // Reset pending count since we're cancelling all operations
        pendingCount = 0
    }
}
