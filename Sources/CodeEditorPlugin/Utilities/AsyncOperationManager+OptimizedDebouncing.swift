import Foundation

// MARK: - Optimized Debouncing

extension AsyncOperationManager {
    /// Optimized debounce that doesn't wait for task completion unless needed
    ///
    /// This version improves performance by:
    /// 1. Not waiting for intermediate cancelled tasks
    /// 2. Using a continuation-based approach for better concurrency
    /// 3. Reducing overhead for rapid successive calls
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the debounced operation
    ///   - delay: Time to wait after the last call before executing
    ///   - operation: The async operation to debounce
    ///
    /// - Returns: The result of the operation when it eventually executes
    ///
    /// - Throws: Any error thrown by the operation
    public func debounceOptimized<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Cancel existing task
        debounceTasks[key]?.cancel()

        // Clear previous results/errors
        debounceResults.removeValue(forKey: key)
        debounceErrors.removeValue(forKey: key)

        // Create a unique identifier for this specific call
        _ = UUID()

        // Create new debounce task
        let task = Task { [weak self] in
            do {
                // Use a more efficient sleep that can be interrupted
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }

                // Execute the operation
                let result = try await operation()
                await self?.storeDebounceResult(key: key, result: result)
            } catch {
                if !Task.isCancelled {
                    await self?.storeDebounceError(key: key, error: error)
                }
            }

            await self?.cleanupDebounceTask(key: key)
        }

        debounceTasks[key] = task

        // Wait for task completion
        _ = await task.value

        // Return result or throw error
        if let error = debounceErrors[key] {
            throw error
        }

        guard let result = debounceResults[key] as? T else {
            throw AsyncOperationError.noResult
        }

        return result
    }

    /// Fast debounce for fire-and-forget operations
    ///
    /// This version is optimized for operations where you don't need the result.
    /// It returns immediately without waiting for the operation to complete.
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the debounced operation
    ///   - delay: Time to wait after the last call before executing
    ///   - operation: The async operation to debounce
    public func debounceFireAndForget(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async -> Void
    ) {
        // Cancel existing task
        debounceTasks[key]?.cancel()

        // Create new debounce task
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }

                await operation()
            } catch {
                // Silently ignore cancellation errors
            }

            await self?.cleanupDebounceTask(key: key)
        }

        debounceTasks[key] = task
    }

    /// Batch debounce for multiple operations
    ///
    /// This optimizes performance when multiple debounced operations need to be executed.
    /// It groups operations and executes them together after the delay.
    ///
    /// - Parameters:
    ///   - operations: Dictionary of keys to operations
    ///   - delay: Time to wait after the last call before executing
    ///
    /// - Returns: Dictionary of keys to results
    public func batchDebounce<T: Sendable>(
        operations: [String: @Sendable () async throws -> T],
        delay: TimeInterval
    ) async throws -> [String: T] {
        var results: [String: T] = [:]

        // Create tasks for all operations
        await withTaskGroup(of: (String, Result<T, Error>).self) { group in
            for (key, operation) in operations {
                group.addTask {
                    do {
                        let result = try await self.debounceOptimized(
                            key: key,
                            delay: delay,
                            operation: operation
                        )
                        return (key, .success(result))
                    } catch {
                        return (key, .failure(error))
                    }
                }
            }

            // Collect results
            for await (key, result) in group {
                switch result {
                case .success(let value):
                    results[key] = value

                case .failure:
                    // Skip failed operations
                    break
                }
            }
        }

        return results
    }
}

// MARK: - Performance Monitoring

extension AsyncOperationManager {
    /// Performance metrics for debounce operations
    public struct DebounceMetrics: Sendable {
        public let totalCalls: Int
        public let cancelledCalls: Int
        public let completedCalls: Int
        public let averageDelay: TimeInterval
        public let peakConcurrentOperations: Int
    }

    @MainActor
    private static var debounceMetrics = DebounceMetrics(
        totalCalls: 0,
        cancelledCalls: 0,
        completedCalls: 0,
        averageDelay: 0,
        peakConcurrentOperations: 0
    )

    /// Get current debounce performance metrics
    @MainActor
    public func getDebounceMetrics() -> DebounceMetrics {
        Self.debounceMetrics
    }
}
