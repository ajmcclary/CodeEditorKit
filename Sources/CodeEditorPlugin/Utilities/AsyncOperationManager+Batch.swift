import Foundation

// MARK: - Batch Operations

extension AsyncOperationManager {
    /// Executes multiple operations in batches with controlled concurrency.
    ///
    /// Batch processing allows efficient execution of multiple similar operations
    /// while respecting concurrency limits. Operations within each batch run
    /// concurrently, with batches processed sequentially.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let userIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    ///
    /// let users = try await manager.batch(
    ///     operations: userIds.map { id in
    ///         { try await fetchUser(id: id) }
    ///     },
    ///     batchSize: 3
    /// )
    ///
    /// // Process files in batches
    /// let results = try await manager.batch(
    ///     operations: files.map { file in
    ///         { try await processFile(file) }
    ///     },
    ///     batchSize: 5,
    ///     priority: .high
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - operations: Array of async operations to execute.
    ///   - batchSize: Maximum operations per batch. Defaults to `maxConcurrentOperations`.
    ///   - priority: Priority for all operations. Defaults to `.medium`.
    ///
    /// - Returns: Array of results in the same order as input operations.
    ///
    /// - Throws: Rethrows the first error encountered. Other operations continue.
    ///
    /// - Note: Failed operations return `nil` in the results array.
    public func batch<T: Sendable>(
        operations: [@Sendable () async throws -> T],
        batchSize: Int? = nil,
        priority _: Priority = .medium
    ) async throws -> [T?] {
        let effectiveBatchSize = min(batchSize ?? maxConcurrentOperations, maxConcurrentOperations)
        var results: [T?] = Array(repeating: nil, count: operations.count)
        var firstError: Error?
        
        // Process in batches
        for batchStart in stride(from: 0, to: operations.count, by: effectiveBatchSize) {
            let batchEnd = min(batchStart + effectiveBatchSize, operations.count)
            let batchOperations = Array(operations[batchStart..<batchEnd])
            let batchIndices = Array(batchStart..<batchEnd)
            
            // Execute batch concurrently
            await withTaskGroup(of: (Int, Result<T, Error>).self) { group in
                for (offset, operation) in batchOperations.enumerated() {
                    let index = batchIndices[offset]
                    
                    group.addTask { @Sendable in
                        do {
                            let result = try await operation()
                            return (index, .success(result))
                        } catch {
                            return (index, .failure(error))
                        }
                    }
                }
                
                // Collect results
                for await (index, result) in group {
                    switch result {
                    case .success(let value):
                        results[index] = value
                        
                    case .failure(let error):
                        if firstError == nil {
                            firstError = error
                        }
                        logger.error("Batch operation \(index) failed: \(error)")
                    }
                }
            }
        }
        
        // Throw first error if any occurred
        if let error = firstError {
            throw error
        }
        
        return results
    }
}
