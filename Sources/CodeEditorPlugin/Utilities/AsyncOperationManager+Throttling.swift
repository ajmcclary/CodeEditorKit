import Foundation

// MARK: - Throttling

extension AsyncOperationManager {
    /// Throttles execution of an operation to limit frequency.
    ///
    /// Throttling ensures that an operation is not executed more frequently than
    /// the specified interval. If called multiple times within the interval,
    /// only the first call executes, and subsequent calls receive the cached result.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Throttle API calls to once per second
    /// let data = try await manager.throttle(
    ///     key: "user-data",
    ///     interval: 1.0
    /// ) {
    ///     try await api.fetchUserData()
    /// }
    ///
    /// // Immediate subsequent calls return cached result
    /// let cachedData = try await manager.throttle(
    ///     key: "user-data",
    ///     interval: 1.0
    /// ) {
    ///     try await api.fetchUserData() // Not executed
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the throttled operation.
    ///   - interval: Minimum time between executions, in seconds.
    ///   - operation: The async operation to throttle.
    ///
    /// - Returns: The result of the operation, either fresh or cached.
    ///
    /// - Throws: Any error thrown by the operation.
    ///
    /// - Note: Results are cached for the duration of the interval.
    public func throttle<T>(
        key: String,
        interval: TimeInterval,
        operation: () async throws -> T
    ) async throws -> T {
        let now = Date()
        
        if let lastRun = throttleInfo[key],
           now.timeIntervalSince(lastRun) < interval {
            // Return cached result if available
            if let cached = debounceResults[key] as? T {
                return cached
            }
        }
        
        throttleInfo[key] = now
        
        do {
            let result = try await operation()
            debounceResults[key] = result
            return result
        } catch {
            debounceErrors[key] = error
            throw error
        }
    }
    
    /// Creates a throttled version of an async function.
    ///
    /// This method returns a new function that automatically throttles calls
    /// to the original function. Useful for creating reusable throttled operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let throttledSearch = await manager.makeThrottled(
    ///     key: "search",
    ///     interval: 0.5
    /// ) { query in
    ///     try await searchAPI.search(query: query)
    /// }
    ///
    /// // Use the throttled function
    /// let results = try await throttledSearch("swift")
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the throttled operation.
    ///   - interval: Minimum time between executions, in seconds.
    ///   - operation: The async operation to throttle.
    ///
    /// - Returns: A throttled version of the operation.
    ///
    /// - Note: The returned function maintains its own timing state.
    public func makeThrottled<T: Sendable>(
        key: String,
        interval: TimeInterval,
        operation: @escaping () async throws -> T
    ) -> () async throws -> T {
        {
            try await self.throttle(
                key: key,
                interval: interval,
                operation: operation
            )
        }
    }
}
