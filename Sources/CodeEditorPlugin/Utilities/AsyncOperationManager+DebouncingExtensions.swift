import Foundation

// MARK: - Debouncing

extension AsyncOperationManager {
    /// Debounces execution of an operation by delaying until a quiet period.
    ///
    /// Debouncing delays operation execution until after a period of inactivity.
    /// If called multiple times rapidly, only the last call executes after the delay.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Debounce search to wait 0.3 seconds after typing stops
    /// try await manager.debounce(
    ///     key: "search",
    ///     delay: 0.3
    /// ) {
    ///     try await performSearch(query: searchText)
    /// }
    ///
    /// // Debounce file saves
    /// try await manager.debounce(
    ///     key: "save-\(fileId)",
    ///     delay: 1.0
    /// ) {
    ///     try await saveFile(content: updatedContent)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the debounced operation.
    ///   - delay: Time to wait after the last call before executing, in seconds.
    ///   - operation: The async operation to debounce.
    ///
    /// - Returns: The result of the operation when it eventually executes.
    ///
    /// - Throws: Any error thrown by the operation or stored from previous execution.
    ///
    /// - Note: Only the last operation in a debounce sequence is executed.
    public func debounce<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Cancel existing task
        debounceTasks[key]?.cancel()
        
        // Clear previous results/errors
        debounceResults.removeValue(forKey: key)
        debounceErrors.removeValue(forKey: key)
        
        // Create new debounce task
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                guard !Task.isCancelled else { return }
                
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
    
    /// Creates a debounced version of an async function.
    ///
    /// Returns a function that automatically debounces calls to the original function.
    /// Ideal for creating reusable debounced operations that can be called multiple times.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let debouncedSave = await manager.makeDebounced(
    ///     key: "auto-save",
    ///     delay: 2.0
    /// ) {
    ///     try await document.save()
    /// }
    ///
    /// // Call multiple times - only last execution runs
    /// Task { try await debouncedSave() }
    /// Task { try await debouncedSave() }
    /// Task { try await debouncedSave() } // Only this executes
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the debounced operation.
    ///   - delay: Time to wait after the last call before executing, in seconds.
    ///   - operation: The async operation to debounce.
    ///
    /// - Returns: A debounced version of the operation.
    public func makeDebounced<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) -> @Sendable () async throws -> T {
        {
            try await self.debounce(key: key, delay: delay, operation: operation)
        }
    }
    
    // MARK: - Private Helpers
    
    func cleanupDebounceTask(key: String) {
        debounceTasks.removeValue(forKey: key)
    }
    
    func storeDebounceResult(key: String, result: Any) {
        debounceResults[key] = result
    }
    
    func storeDebounceError(key: String, error: Error) {
        debounceErrors[key] = error
    }
}
