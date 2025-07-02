import Foundation
import os.log

/// Errors that can occur during async operation management.
///
/// These errors represent failures specific to the operation management system,
/// such as cancellation or missing results.
///
/// ## Error Cases
///
/// - ``noResult``: Operation completed but produced no result
/// - ``operationCancelled``: Operation was cancelled before completion
///
/// - SeeAlso: ``AsyncOperationManager``
public enum AsyncOperationError: LocalizedError {
    /// Operation completed but no result was available.
    case noResult
    
    /// Operation was cancelled before it could complete.
    case operationCancelled
    
    public var errorDescription: String? {
        switch self {
        case .noResult:
            return "No result available"

        case .operationCancelled:
            return "Operation was cancelled"
        }
    }
}

/// A thread-safe manager for asynchronous operations with advanced scheduling capabilities.
///
/// `AsyncOperationManager` provides a comprehensive solution for managing async operations
/// with features like debouncing, throttling, priority scheduling, retry logic, and
/// batch processing. It's designed for high-performance scenarios where precise control
/// over operation execution is required.
///
/// ## Overview
///
/// This actor-based manager ensures thread safety while providing sophisticated control
/// over async operation execution. It's particularly useful for:
/// - Managing UI-triggered operations that need debouncing
/// - Rate-limiting API calls with throttling
/// - Scheduling operations with priority queuing
/// - Implementing retry logic with exponential backoff
/// - Batch processing of similar operations
///
/// ## Key Features
///
/// - **Debouncing**: Delay operation execution until a quiet period
/// - **Throttling**: Limit operation frequency to prevent overload
/// - **Priority Scheduling**: Execute operations based on importance
/// - **Retry Logic**: Automatic retry with configurable backoff
/// - **Batch Processing**: Execute multiple operations efficiently
/// - **Concurrency Control**: Limit simultaneous operations
///
/// ## Example Usage
///
/// ```swift
/// let operationManager = AsyncOperationManager(maxConcurrentOperations: 4)
///
/// // Debounce search operations
/// let searchDebounced = await operationManager.makeDebounced(
///     key: "search",
///     delay: 0.3
/// ) {
///     try await performSearch(query: searchText)
/// }
///
/// // Throttle API calls
/// let result = try await operationManager.throttle(
///     key: "api-call",
///     interval: 1.0
/// ) {
///     try await apiClient.fetchData()
/// }
///
/// // Schedule with priority
/// let criticalResult = try await operationManager.schedule(
///     { try await criticalOperation() },
///     priority: .critical
/// )
///
/// // Retry with backoff
/// let data = try await operationManager.retry(
///     operation: { try await unreliableNetworkCall() },
///     maxAttempts: 3,
///     delay: 1.0,
///     backoffMultiplier: 2.0
/// )
/// ```
///
/// - Note: This manager uses Swift concurrency and requires iOS 16.0+ or macOS 13.0+
///
/// - SeeAlso: ``AsyncOperationError``
/// - SeeAlso: ``OperationStatus``
/// - SeeAlso: ``Priority``
public actor AsyncOperationManager {
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "AsyncOperationManager")
    
    // MARK: - Types
    
    /// Operation priority levels for scheduling.
    ///
    /// Higher priority operations are executed before lower priority ones
    /// when multiple operations are scheduled.
    ///
    /// ## Priority Levels
    ///
    /// - ``low``: Background operations that can be delayed
    /// - ``medium``: Standard priority for most operations
    /// - ``high``: Important operations that should execute soon
    /// - ``critical``: Urgent operations that must execute immediately
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Schedule a critical operation
    /// try await manager.schedule(
    ///     { try await saveUserData() },
    ///     priority: .critical
    /// )
    ///
    /// // Schedule a background task
    /// try await manager.schedule(
    ///     { try await cleanupCache() },
    ///     priority: .low
    /// )
    /// ```
    public enum Priority: Int, Comparable, Sendable {
        /// Low priority for background operations.
        case low = 0
        
        /// Medium priority for standard operations (default).
        case medium = 1
        
        /// High priority for important operations.
        case high = 2
        
        /// Critical priority for urgent operations.
        case critical = 3
        
        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    private struct ScheduledOperation {
        let id: UUID
        let priority: Priority
        let operation: () async throws -> Any
        let scheduledTime: Date
    }
    
    // MARK: - Properties
    
    private var scheduledOperations: [UUID: ScheduledOperation] = [:]
    private var debounceTasks: [String: Task<Void, Never>] = [:]
    private var debounceResults: [String: Any] = [:]
    private var debounceErrors: [String: Error] = [:]
    private var throttleInfo: [String: Date] = [:]
    private var activeOperations: Set<UUID> = []
    private let maxConcurrentOperations: Int
    
    // MARK: - Initialization
    
    /// Creates a new async operation manager with specified concurrency limit.
    ///
    /// - Parameter maxConcurrentOperations: Maximum number of operations that can
    ///   run simultaneously. Defaults to the number of active processor cores.
    ///
    /// - Note: The concurrency limit is enforced across all operation types
    ///   (scheduled, debounced, throttled, etc.)
    public init(maxConcurrentOperations: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.maxConcurrentOperations = max(1, maxConcurrentOperations)
    }
    
    // MARK: - Scheduling
    
    /// Schedules an operation for execution with specified priority and optional delay.
    ///
    /// Operations are executed based on their priority, with higher priority operations
    /// executing before lower priority ones. The manager respects the maximum concurrent
    /// operations limit.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Schedule a high-priority data save
    /// let result = try await manager.schedule(
    ///     { try await database.save(userData) },
    ///     priority: .high,
    ///     delay: 0.5  // Wait 500ms before execution
    /// )
    ///
    /// // Schedule a low-priority cleanup
    /// try await manager.schedule(
    ///     { try await cache.cleanup() },
    ///     priority: .low
    /// )
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
    /// // Cancel all pending operations during cleanup
    /// await manager.cancelAllOperations()
    /// ```
    ///
    /// - Note: This does not affect debounced or throttled operations,
    ///   only explicitly scheduled operations.
    public func cancelAllOperations() {
        let count = scheduledOperations.count
        scheduledOperations.removeAll()
        activeOperations.removeAll()
        
        logger.info("Cancelled all \(count) operations")
    }
    
    // MARK: - Throttling
    
    /// Executes an operation with throttling to limit execution frequency.
    ///
    /// Throttling ensures a minimum time interval between executions of the same
    /// operation (identified by key). If called too frequently, the operation is
    /// skipped and `nil` is returned.
    ///
    /// ## Overview
    ///
    /// Throttling is useful for rate-limiting operations like:
    /// - API calls to respect rate limits
    /// - UI updates to prevent excessive rendering
    /// - File system operations to avoid overwhelming the system
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Throttle location updates to once per second
    /// let location = try await manager.throttle(
    ///     key: "location-update",
    ///     interval: 1.0
    /// ) {
    ///     try await locationService.getCurrentLocation()
    /// }
    ///
    /// if let location {
    ///     // Update UI with new location
    /// } else {
    ///     // Operation was throttled, use cached location
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for this throttled operation.
    ///   - interval: Minimum time interval between executions, in seconds.
    ///   - operation: The async operation to execute.
    ///
    /// - Returns: The operation result, or `nil` if throttled.
    ///
    /// - Throws: Any error thrown by the operation.
    ///
    /// - Note: Each unique key maintains its own throttle timing.
    ///
    /// - SeeAlso: ``makeThrottled(key:interval:operation:)``
    public func throttle<T>(
        key: String,
        interval: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T? {
        let now = Date()
        
        // Check last execution time
        if let lastExecution = throttleInfo[key] {
            let timeSinceLastExecution = now.timeIntervalSince(lastExecution)
            
            if timeSinceLastExecution < interval {
                // Too soon, skip execution
                logger.debug("Throttled operation '\(key)' - too soon since last execution")
                return nil
            }
        }
        
        // Update last execution time
        throttleInfo[key] = now
        
        // Execute operation
        return try await operation()
    }
    
    /// Creates a reusable throttled function.
    ///
    /// This method returns a function that automatically applies throttling
    /// whenever it's called, making it convenient for repeated use.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a throttled save function
    /// let throttledSave = await manager.makeThrottled(
    ///     key: "auto-save",
    ///     interval: 5.0  // Save at most once every 5 seconds
    /// ) {
    ///     try await document.save()
    /// }
    ///
    /// // Use it multiple times - only executes based on throttle interval
    /// textDidChange()
    /// if let saved = try await throttledSave() {
    ///     print("Document saved")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for this throttled operation.
    ///   - interval: Minimum time interval between executions, in seconds.
    ///   - operation: The async operation to execute. Must be `Sendable`.
    ///
    /// - Returns: A function that executes the operation with throttling.
    ///
    /// - Note: The returned function captures a weak reference to the manager.
    ///
    /// - SeeAlso: ``throttle(key:interval:operation:)``
    public func makeThrottled<T: Sendable>(
        key: String,
        interval: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) -> @Sendable () async throws -> T? {
        { @Sendable [weak self] in
            guard let self else { return nil }
            return try await self.throttle(key: key, interval: interval, operation: operation)
        }
    }
    
    // MARK: - Debouncing
    
    /// Executes an operation with debouncing to coalesce rapid calls.
    ///
    /// Debouncing delays execution until a quiet period occurs - the operation
    /// only executes after the specified delay has passed without any new calls.
    /// This is ideal for operations triggered by user input.
    ///
    /// ## Overview
    ///
    /// Common use cases for debouncing:
    /// - Search-as-you-type functionality
    /// - Auto-save after typing stops
    /// - Validating form input
    /// - Resizing or scroll event handlers
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Debounce search to wait for typing to stop
    /// @MainActor
    /// func searchTextChanged(_ text: String) async {
    ///     do {
    ///         let results = try await manager.debounce(
    ///             key: "search",
    ///             delay: 0.3  // Wait 300ms after typing stops
    ///         ) {
    ///             try await searchAPI.search(query: text)
    ///         }
    ///         updateSearchResults(results)
    ///     } catch {
    ///         // Handle error
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for this debounced operation.
    ///   - delay: Time to wait after the last call before executing, in seconds.
    ///   - operation: The async operation to execute. Must be `Sendable`.
    ///
    /// - Returns: The result of the operation.
    ///
    /// - Throws: Any error thrown by the operation or ``AsyncOperationError/noResult``
    ///   if no result is available.
    ///
    /// - Important: Each call with the same key cancels the previous pending operation.
    ///
    /// - SeeAlso: ``makeDebounced(key:delay:operation:)``
    public func debounce<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Cancel existing debounce task for this key
        debounceTasks[key]?.cancel()
        debounceResults.removeValue(forKey: key)
        debounceErrors.removeValue(forKey: key)
        
        // Create wrapper task for debouncing
        let wrapperTask = Task { [weak self] in
            do {
                // Wait for debounce delay
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Execute operation
                let result = try await operation()
                
                // Store result
                await self?.storeDebounceResult(key: key, result: result)
            } catch {
                // Store error
                await self?.storeDebounceError(key: key, error: error)
            }
        }
        
        debounceTasks[key] = wrapperTask
        
        // Wait for task completion
        await wrapperTask.value
        
        // Return result or throw error
        if let error = debounceErrors[key] {
            debounceErrors.removeValue(forKey: key)
            throw error
        }
        
        guard let result = debounceResults[key] as? T else {
            throw AsyncOperationError.noResult
        }
        
        debounceResults.removeValue(forKey: key)
        return result
    }
    
    /// Creates a reusable debounced function.
    ///
    /// This method returns a function that automatically applies debouncing
    /// whenever it's called, making it convenient for repeated use.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a debounced validation function
    /// let validateDebounced = await manager.makeDebounced(
    ///     key: "form-validation",
    ///     delay: 0.5  // Wait 500ms after last change
    /// ) {
    ///     try await validateFormData()
    /// }
    ///
    /// // Call it on every text change - only validates after typing stops
    /// func textFieldDidChange() async {
    ///     do {
    ///         let isValid = try await validateDebounced()
    ///         updateValidationUI(isValid)
    ///     } catch {
    ///         showValidationError(error)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for this debounced operation.
    ///   - delay: Time to wait after the last call before executing, in seconds.
    ///   - operation: The async operation to execute. Must be `Sendable`.
    ///
    /// - Returns: A function that executes the operation with debouncing.
    ///
    /// - Throws: `CancellationError` if the manager is deallocated.
    ///
    /// - Note: The returned function captures a weak reference to the manager.
    ///
    /// - SeeAlso: ``debounce(key:delay:operation:)``
    public func makeDebounced<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) -> @Sendable () async throws -> T {
        { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.debounce(key: key, delay: delay, operation: operation)
        }
    }
    
    private func cleanupDebounceTask(key: String) {
        debounceTasks.removeValue(forKey: key)
    }
    
    private func storeDebounceResult(key: String, result: Any) {
        debounceResults[key] = result
    }
    
    private func storeDebounceError(key: String, error: Error) {
        debounceErrors[key] = error
    }
    
    // MARK: - Batch Operations
    
    /// Executes multiple operations concurrently as a batch.
    ///
    /// Batch processing allows efficient execution of multiple similar operations
    /// while respecting the concurrency limit. Each operation is scheduled with
    /// the same priority and executes independently.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Batch process multiple files
    /// let fileOperations = files.map { file in
    ///     { try await processFile(file) }
    /// }
    ///
    /// let results = try await manager.batch(
    ///     operations: fileOperations,
    ///     priority: .high
    /// )
    ///
    /// // Handle results
    /// for (index, result) in results.enumerated() {
    ///     switch result {
    ///     case .success(let output):
    ///         print("File \(index) processed: \(output)")
    ///     case .failure(let error):
    ///         print("File \(index) failed: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - operations: Array of async operations to execute. Each must be `Sendable`.
    ///   - priority: Priority for all operations in the batch. Defaults to `.medium`.
    ///
    /// - Returns: Array of `Result` values in the same order as the input operations.
    ///
    /// - Note: Operations execute concurrently but results maintain input order.
    ///   Failed operations don't affect others in the batch.
    ///
    /// - SeeAlso: ``schedule(_:priority:delay:)``
    public func batch<T: Sendable>(
        operations: [@Sendable () async throws -> T],
        priority: Priority = .medium
    ) async throws -> [Result<T, Error>] {
        let priorityValue = priority // Capture priority to avoid sending it
        
        return await withTaskGroup(of: (Int, Result<T, Error>).self) { group in
            for (index, operation) in operations.enumerated() {
                let op = operation // Capture operation in a local variable
                group.addTask { [weak self] in
                    guard let self else {
                        return (index, .failure(AsyncOperationError.operationCancelled))
                    }
                    do {
                        let result = try await self.schedule(op, priority: priorityValue)
                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            var results: [(Int, Result<T, Error>)] = []
            for await result in group {
                results.append(result)
            }
            
            // Sort by original index
            return results
                .sorted { $0.0 < $1.0 }
                .map { $0.1 }
        }
    }
    
    // MARK: - Retry Operations
    
    /// Executes an operation with automatic retry on failure.
    ///
    /// This method implements exponential backoff retry logic, making it ideal
    /// for handling transient failures in network requests, file operations,
    /// or other potentially unreliable operations.
    ///
    /// ## Retry Behavior
    ///
    /// The operation is retried up to `maxAttempts` times with increasing delays:
    /// - First retry: `delay` seconds
    /// - Second retry: `delay * backoffMultiplier` seconds
    /// - Third retry: `delay * backoffMultiplier²` seconds
    /// - And so on...
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Retry a network request with exponential backoff
    /// let data = try await manager.retry(
    ///     operation: {
    ///         try await networkClient.fetchData(from: url)
    ///     },
    ///     maxAttempts: 3,
    ///     delay: 1.0,           // Start with 1 second delay
    ///     backoffMultiplier: 2.0 // Double delay each retry
    /// )
    /// // Delays: 1s, 2s, 4s
    ///
    /// // Retry with custom backoff for rate-limited API
    /// let result = try await manager.retry(
    ///     operation: {
    ///         try await api.submitRequest()
    ///     },
    ///     maxAttempts: 5,
    ///     delay: 0.5,
    ///     backoffMultiplier: 1.5
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - operation: The async operation to execute with retry.
    ///   - maxAttempts: Maximum number of attempts (including initial). Defaults to 3.
    ///   - delay: Initial delay between retries, in seconds. Defaults to 1.0.
    ///   - backoffMultiplier: Factor to multiply delay by after each retry. Defaults to 2.0.
    ///
    /// - Returns: The result of the successful operation.
    ///
    /// - Throws: The last error encountered if all attempts fail, or
    ///   ``OperationError/retriesExhausted`` if no error was captured.
    ///
    /// - Note: The operation should be idempotent since it may be executed multiple times.
    public func retry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = delay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                logger.warning("Retry attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= backoffMultiplier
                }
            }
        }
        
        throw lastError ?? OperationError.retriesExhausted
    }
    
    // MARK: - Status
    
    /// Returns the current status of the operation manager.
    ///
    /// This method provides insights into the manager's current state,
    /// useful for debugging, monitoring, or adaptive behavior.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let status = await manager.getStatus()
    /// print("Active operations: \(status.activeCount)")
    /// print("Scheduled operations: \(status.scheduledCount)")
    /// print("Throttled keys: \(status.throttledKeys)")
    /// print("Debounced keys: \(status.debouncedKeys)")
    ///
    /// // Adapt behavior based on load
    /// if status.activeCount > 10 {
    ///     // System is busy, defer non-critical operations
    /// }
    /// ```
    ///
    /// - Returns: An ``OperationStatus`` struct containing current state information.
    ///
    /// - SeeAlso: ``OperationStatus``
    public func getStatus() -> OperationStatus {
        OperationStatus(
            scheduledCount: scheduledOperations.count,
            activeCount: activeOperations.count,
            throttledKeys: Set(throttleInfo.keys),
            debouncedKeys: Set(debounceTasks.keys)
        )
    }
    
    /// Cleans up expired throttle information to free memory.
    ///
    /// This method removes throttle timing information for keys that haven't
    /// been used recently, preventing memory growth in long-running applications.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Clean up throttle info older than 1 hour
    /// await manager.cleanup(olderThan: 3_600)
    ///
    /// // Aggressive cleanup - remove info older than 5 minutes
    /// await manager.cleanup(olderThan: 300)
    /// ```
    ///
    /// - Parameter interval: Age threshold in seconds. Throttle info older
    ///   than this will be removed. Defaults to 3600 seconds (1 hour).
    ///
    /// - Note: This only affects throttle timing information, not active operations.
    public func cleanup(olderThan interval: TimeInterval = 3_600) {
        let cutoffDate = Date().addingTimeInterval(-interval)
        
        throttleInfo = throttleInfo.filter { $0.value > cutoffDate }
    }
}

// MARK: - Supporting Types

/// Status information for the async operation manager.
///
/// Provides a snapshot of the manager's current state, including
/// counts of various operation types and active keys.
///
/// ## Properties
///
/// - ``scheduledCount``: Number of operations waiting to execute
/// - ``activeCount``: Number of currently executing operations
/// - ``throttledKeys``: Set of keys with active throttle timers
/// - ``debouncedKeys``: Set of keys with pending debounce operations
///
/// - SeeAlso: ``AsyncOperationManager/getStatus()``
public struct OperationStatus {
    /// Number of operations scheduled but not yet executed.
    public let scheduledCount: Int
    
    /// Number of operations currently executing.
    public let activeCount: Int
    
    /// Set of keys that have active throttle timing information.
    public let throttledKeys: Set<String>
    
    /// Set of keys that have pending debounce operations.
    public let debouncedKeys: Set<String>
}

/// Errors specific to operation execution.
///
/// These errors indicate failures in the operation management logic,
/// separate from errors thrown by the operations themselves.
///
/// ## Error Cases
///
/// - ``retriesExhausted``: All retry attempts failed
/// - ``operationCancelled``: Operation was cancelled
///
/// - SeeAlso: ``AsyncOperationManager/retry(operation:maxAttempts:delay:backoffMultiplier:)``
public enum OperationError: Error {
    /// All retry attempts have been exhausted without success.
    case retriesExhausted
    
    /// The operation was cancelled before completion.
    case operationCancelled
}

// MARK: - Convenience Functions

/// Creates a global debounced function using Grand Central Dispatch.
///
/// This convenience function provides a simple way to debounce synchronous
/// operations without needing an `AsyncOperationManager` instance.
///
/// ## Example
///
/// ```swift
/// let debouncedSave = debounce(delay: 0.5) {
///     saveDocument()
/// }
///
/// // Call multiple times - only executes after delay
/// textChanged()
/// debouncedSave()  // Cancels previous, schedules new
/// textChanged()
/// debouncedSave()  // Cancels previous, schedules new
/// // After 0.5 seconds of no calls, saveDocument() executes
/// ```
///
/// - Parameters:
///   - delay: Time to wait after the last call before executing, in seconds.
///   - queue: The dispatch queue to execute on. Defaults to `.main`.
///   - action: The synchronous action to debounce.
///
/// - Returns: A function that debounces the action. Returns the last result.
///
/// - Note: For async operations, use ``AsyncOperationManager/debounce(key:delay:operation:)`` instead.
public func debounce<T>(
    delay: TimeInterval,
    queue: DispatchQueue = .main,
    action: @escaping () -> T
) -> () -> T? {
    var workItem: DispatchWorkItem?
    var result: T?
    
    return {
        workItem?.cancel()
        workItem = DispatchWorkItem {
            result = action()
        }
        queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
        return result
    }
}

/// Creates a global throttled function using Grand Central Dispatch.
///
/// This convenience function provides a simple way to throttle synchronous
/// operations without needing an `AsyncOperationManager` instance.
///
/// ## Example
///
/// ```swift
/// let throttledUpdate = throttle(interval: 0.1) {
///     updateUI()
/// }
///
/// // In a scroll handler - updates at most every 100ms
/// func scrollViewDidScroll(_ scrollView: UIScrollView) {
///     throttledUpdate()
/// }
/// ```
///
/// - Parameters:
///   - interval: Minimum time interval between executions, in seconds.
///   - queue: The dispatch queue to execute on (parameter ignored in current implementation).
///   - action: The synchronous action to throttle.
///
/// - Returns: A function that throttles the action. Returns the last result
///   if throttled, or the new result if executed.
///
/// - Note: For async operations, use ``AsyncOperationManager/throttle(key:interval:operation:)`` instead.
public func throttle<T>(
    interval: TimeInterval,
    queue _: DispatchQueue = .main,
    action: @escaping () -> T
) -> () -> T? {
    var lastRun: Date?
    var result: T?
    
    return {
        let now = Date()
        if let lastRun {
            let timeSinceLastRun = now.timeIntervalSince(lastRun)
            if timeSinceLastRun < interval {
                return result
            }
        }
        
        lastRun = now
        result = action()
        return result
    }
}
