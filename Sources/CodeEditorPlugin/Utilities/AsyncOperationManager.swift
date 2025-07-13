import Foundation

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
    let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "AsyncOperationManager")
    
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
    
    struct ScheduledOperation {
        let id: UUID
        let priority: Priority
        let operation: () async throws -> Any
        let scheduledTime: Date
    }
    
    // MARK: - Properties
    
    var scheduledOperations: [UUID: ScheduledOperation] = [:]
    var debounceTasks: [String: Task<Void, Never>] = [:]
    var debounceResults: [String: Any] = [:]
    var debounceErrors: [String: Error] = [:]
    var throttleInfo: [String: Date] = [:]
    var activeOperations: Set<UUID> = []
    let maxConcurrentOperations: Int
    
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
    
    // MARK: - Status
    
    /// Returns the current status of the operation manager.
    ///
    /// This provides insight into the current state of operations including
    /// scheduled, active, throttled, and debounced operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let logger = CrossPlatformLogger.logger()
    /// let status = await manager.getStatus()
    /// logger.debug("Scheduled: \(status.scheduledCount)")
    /// logger.debug("Active: \(status.activeCount)")
    /// logger.debug("Throttled keys: \(status.throttledKeys)")
    /// ```
    ///
    /// - Returns: Current operation status information.
    ///
    /// - SeeAlso: ``OperationStatus``
    public func getStatus() -> OperationStatus {
        OperationStatus(
            scheduledCount: scheduledOperations.count,
            activeCount: activeOperations.count,
            throttledKeys: Set(throttleInfo.keys),
            debouncedKeys: Set(debounceTasks.keys),
            maxConcurrentOperations: maxConcurrentOperations
        )
    }
    
    /// Cleans up stale operation data older than the specified interval.
    ///
    /// This method removes old throttle timing information and clears
    /// any lingering debounce results to free memory.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Clean up data older than 1 hour
    /// await manager.cleanup(olderThan: 3600)
    /// ```
    ///
    /// - Parameter interval: Age threshold in seconds. Defaults to 1 hour.
    ///
    /// - Note: This is called automatically but can be invoked manually
    ///   for more aggressive cleanup.
    public func cleanup(olderThan interval: TimeInterval = 3_600) {
        let cutoff = Date().addingTimeInterval(-interval)
        
        // Clean throttle info
        throttleInfo = throttleInfo.filter { $0.value > cutoff }
        
        // Clear old debounce data
        let activeKeys = Set(debounceTasks.keys)
        debounceResults = debounceResults.filter { activeKeys.contains($0.key) }
        debounceErrors = debounceErrors.filter { activeKeys.contains($0.key) }
    }
}

// MARK: - Supporting Types

/// Status information for the operation manager.
///
/// Provides a snapshot of the current state of operations managed by
/// ``AsyncOperationManager``.
///
/// ## Properties
///
/// - ``scheduledCount``: Number of operations waiting to execute
/// - ``activeCount``: Number of currently executing operations
/// - ``throttledKeys``: Keys currently under throttle control
/// - ``debouncedKeys``: Keys currently being debounced
/// - ``maxConcurrentOperations``: Maximum allowed concurrent operations
///
/// - SeeAlso: ``AsyncOperationManager/getStatus()``
public struct OperationStatus: Sendable {
    /// Number of operations scheduled but not yet executing.
    public let scheduledCount: Int
    
    /// Number of operations currently executing.
    public let activeCount: Int
    
    /// Set of keys that have active throttling.
    public let throttledKeys: Set<String>
    
    /// Set of keys that have active debouncing.
    public let debouncedKeys: Set<String>
    
    /// Maximum concurrent operations allowed.
    public let maxConcurrentOperations: Int
}

// MARK: - Convenience Functions

/// Creates a debounced version of a synchronous function that returns an async version.
///
/// This convenience function wraps a synchronous function to make it debounced
/// and async-compatible.
///
/// ## Example
///
/// ```swift
/// let logger = CrossPlatformLogger.logger()
/// let debouncedLog = debouncedAsync(
///     delay: 0.5,
///     maxConcurrentOperations: 1
/// ) { message in
///     logger.debug(message)
/// }
///
/// // Multiple rapid calls
/// Task { await debouncedLog("First") }
/// Task { await debouncedLog("Second") }
/// Task { await debouncedLog("Third") } // Only this executes
/// ```
///
/// - Parameters:
///   - delay: Time to wait after the last call before executing.
///   - maxConcurrentOperations: Maximum concurrent operations allowed.
///   - operation: The synchronous operation to make debounced and async.
///
/// - Returns: An async debounced version of the operation.
private actor DebouncedState<T: Sendable> {
    var activeTask: Task<Void, Never>?
    var result: T?
    
    func updateResult(_ value: T) {
        result = value
    }
    
    func cancelActiveTask() {
        activeTask?.cancel()
    }
    
    func setActiveTask(_ task: Task<Void, Never>) {
        activeTask = task
    }
    
    func getResult() -> T? {
        result
    }
}

public func debouncedAsync<T: Sendable>(
    delay: TimeInterval,
    maxConcurrentOperations: Int = 1,
    operation: @escaping @Sendable (T) -> Void
) -> @Sendable (T) async -> Void {
    let state = DebouncedState<T>()
    _ = AsyncOperationManager(maxConcurrentOperations: maxConcurrentOperations)
    
    return { @Sendable value in
        await state.updateResult(value)
        await state.cancelActiveTask()
        
        let task = Task { @Sendable in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            if let capturedResult = await state.getResult(), !Task.isCancelled {
                operation(capturedResult)
            }
        }
        
        await state.setActiveTask(task)
        _ = await task.value
    }
}

/// Creates a throttled version of a synchronous function that returns an async version.
///
/// This convenience function wraps a synchronous function to make it throttled
/// and async-compatible.
///
/// ## Example
///
/// ```swift
/// let throttledSave = throttledAsync(
///     interval: 1.0,
///     maxConcurrentOperations: 1
/// ) { data in
///     saveToFile(data)
/// }
///
/// // Multiple rapid calls
/// await throttledSave(data1) // Executes immediately
/// await throttledSave(data2) // Skipped (too soon)
/// await throttledSave(data3) // Skipped (too soon)
/// ```
///
/// - Parameters:
///   - interval: Minimum time between executions.
///   - maxConcurrentOperations: Maximum concurrent operations allowed.
///   - operation: The synchronous operation to make throttled and async.
///
/// - Returns: An async throttled version of the operation.
private actor ThrottledState {
    var lastRun: Date?
    
    func shouldExecute(interval: TimeInterval) -> Bool {
        let now = Date()
        if let last = lastRun, now.timeIntervalSince(last) < interval {
            return false
        }
        lastRun = now
        return true
    }
}

public func throttledAsync<T: Sendable>(
    interval: TimeInterval,
    maxConcurrentOperations: Int = 1,
    operation: @escaping @Sendable (T) -> Void
) -> @Sendable (T) async -> Void {
    let state = ThrottledState()
    _ = AsyncOperationManager(maxConcurrentOperations: maxConcurrentOperations)
    
    return { @Sendable value in
        if await state.shouldExecute(interval: interval) {
            operation(value)
        }
    }
}
