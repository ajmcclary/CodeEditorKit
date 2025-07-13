import Foundation

// MARK: - Retry Operations

extension AsyncOperationManager {
    /// Executes an operation with automatic retry on failure.
    ///
    /// Implements exponential backoff retry logic for operations that may fail
    /// transiently. Each retry attempt waits longer than the previous one based
    /// on the backoff multiplier.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Retry network request up to 3 times
    /// let data = try await manager.retry(
    ///     operation: { try await networkClient.fetchData() },
    ///     maxAttempts: 3,
    ///     delay: 1.0,
    ///     backoffMultiplier: 2.0
    /// )
    ///
    /// // Retry with custom error handling
    /// let result = try await manager.retry(
    ///     operation: { try await unstableOperation() },
    ///     maxAttempts: 5,
    ///     delay: 0.5,
    ///     shouldRetry: { error in
    ///         // Only retry on specific errors
    ///         error is NetworkError
    ///     }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - operation: The operation to execute with retry.
    ///   - maxAttempts: Maximum number of attempts. Must be at least 1.
    ///   - delay: Initial delay between attempts, in seconds.
    ///   - backoffMultiplier: Multiplier for exponential backoff. Defaults to 2.0.
    ///   - shouldRetry: Optional predicate to determine if retry should occur.
    ///
    /// - Returns: The result of the successful operation.
    ///
    /// - Throws: The last error if all attempts fail.
    ///
    /// - Note: Delay increases exponentially: delay, delay × multiplier, delay × multiplier², etc.
    public func retry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int,
        delay: TimeInterval,
        backoffMultiplier: Double = 2.0,
        shouldRetry: ((Error) -> Bool)? = nil
    ) async throws -> T {
        precondition(maxAttempts >= 1, "maxAttempts must be at least 1")
        
        var currentDelay = delay
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                if let shouldRetry, !shouldRetry(error) {
                    throw error
                }
                
                // Don't delay after the last attempt
                if attempt < maxAttempts {
                    logger.info("Retry attempt \(attempt) failed, waiting \(currentDelay)s before retry")
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= backoffMultiplier
                }
            }
        }
        
        throw lastError ?? AsyncOperationError.noResult
    }
}
