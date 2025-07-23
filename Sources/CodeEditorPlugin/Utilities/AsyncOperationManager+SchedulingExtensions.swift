import Foundation

// MARK: - Scheduling

extension AsyncOperationManager {
    /// Schedules an async operation with priority and optional delay.
    ///
    /// Operations are queued and executed based on their priority and available
    /// concurrency slots. Higher priority operations are executed first when
    /// multiple operations are waiting.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await manager.schedule(
    ///     { try await fetchUserData(userId: 123) },
    ///     priority: .high,
    ///     delay: 0.5
    /// )
    ///
    /// // Schedule low-priority background task
    /// Task {
    ///     try await manager.schedule(
    ///         { await cleanupTemporaryFiles() },
    ///         priority: .low
    ///     )
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - operation: The async operation to execute.
    ///   - priority: The execution priority. Defaults to `.medium`.
    ///   - delay: Time to wait before execution, in seconds. Defaults to 0.
    ///
    /// - Returns: The result of the operation.
    ///
    /// - Throws: Any error thrown by the operation or `CancellationError` if cancelled.
    ///
    /// - Note: Operations may be delayed if the concurrent operation limit is reached.
    ///
    /// - SeeAlso: ``Priority``
    @discardableResult
    public func schedule<T>(
        _ operation: @escaping () async throws -> T,
        priority: Priority = .medium,
        delay: TimeInterval = 0
    ) async throws -> T {
        let operationId = UUID()
        let scheduledTime = Date().addingTimeInterval(delay)

        // Create scheduled operation
        let scheduled = ScheduledOperation(
            id: operationId,
            priority: priority,
            operation: { try await operation() },
            scheduledTime: scheduledTime
        )

        scheduledOperations[operationId] = scheduled

        // Wait for execution slot
        while activeOperations.count >= maxConcurrentOperations {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        // Execute when ready
        activeOperations.insert(operationId)
        defer {
            activeOperations.remove(operationId)
            scheduledOperations.removeValue(forKey: operationId)
        }

        // Apply delay if needed
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Execute operation
        return try await operation()
    }

    /// Cancels scheduled operations that match the given predicate.
    ///
    /// This method allows selective cancellation of operations based on their
    /// ID and priority. Only operations that haven't started executing will be cancelled.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Cancel all low-priority operations
    /// await manager.cancelOperations { _, priority in
    ///     priority == .low
    /// }
    ///
    /// // Cancel specific operation by ID
    /// let targetId = operationId
    /// await manager.cancelOperations { id, _ in
    ///     id == targetId
    /// }
    /// ```
    ///
    /// - Parameter predicate: A closure that returns `true` for operations to cancel.
    ///   Receives the operation ID and priority as parameters.
    ///
    /// - Note: Operations that have already started executing cannot be cancelled
    ///   through this method.
    public func cancelOperations(matching predicate: (UUID, Priority) -> Bool) {
        let toCancel = scheduledOperations.filter { predicate($0.key, $0.value.priority) }

        for (id, _) in toCancel {
            scheduledOperations.removeValue(forKey: id)
            activeOperations.remove(id)
        }

        logger.info("Cancelled \(toCancel.count) operations")
    }

    /// Cancels all scheduled operations.
    ///
    /// This method immediately cancels all operations that haven't started executing.
    /// Operations that are currently running will continue to completion.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Cancel all pending operations
    /// await manager.cancelAllOperations()
    /// ```
    ///
    /// - Note: This only affects scheduled operations, not debounced or throttled operations.
    public func cancelAllOperations() {
        let count = scheduledOperations.count
        scheduledOperations.removeAll()
        logger.info("Cancelled all \(count) scheduled operations")
    }
}
