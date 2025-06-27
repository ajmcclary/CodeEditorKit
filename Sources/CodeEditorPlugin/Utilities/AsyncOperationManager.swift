import Foundation
import os.log

/// Errors for async operation manager
public enum AsyncOperationError: LocalizedError {
    case noResult
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

/// Manager for async operations with debouncing, throttling, and scheduling capabilities
public actor AsyncOperationManager {
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "AsyncOperationManager")
    
    // MARK: - Types
    
    public enum Priority: Int, Comparable, Sendable {
        case low = 0
        case medium = 1
        case high = 2
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
    
    public init(maxConcurrentOperations: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.maxConcurrentOperations = max(1, maxConcurrentOperations)
    }
    
    // MARK: - Scheduling
    
    /// Schedule an operation with priority
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
    
    /// Cancel operations matching predicate
    public func cancelOperations(matching predicate: (UUID, Priority) -> Bool) {
        let toCancel = scheduledOperations.filter { predicate($0.key, $0.value.priority) }
        
        for (id, _) in toCancel {
            scheduledOperations.removeValue(forKey: id)
            activeOperations.remove(id)
        }
        
        logger.info("Cancelled \(toCancel.count) operations")
    }
    
    /// Cancel all operations
    public func cancelAllOperations() {
        let count = scheduledOperations.count
        scheduledOperations.removeAll()
        activeOperations.removeAll()
        
        logger.info("Cancelled all \(count) operations")
    }
    
    // MARK: - Throttling
    
    /// Execute operation with throttling - ensures minimum interval between executions
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
    
    /// Create a throttled function
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
    
    /// Execute operation with debouncing - delays execution until no new calls for specified duration
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
    
    /// Create a debounced function
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
    
    /// Batch multiple operations together
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
    
    /// Execute operation with retry logic
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
    
    /// Get current operation status
    public func getStatus() -> OperationStatus {
        OperationStatus(
            scheduledCount: scheduledOperations.count,
            activeCount: activeOperations.count,
            throttledKeys: Set(throttleInfo.keys),
            debouncedKeys: Set(debounceTasks.keys)
        )
    }
    
    /// Clean up expired throttle info
    public func cleanup(olderThan interval: TimeInterval = 3_600) {
        let cutoffDate = Date().addingTimeInterval(-interval)
        
        throttleInfo = throttleInfo.filter { $0.value > cutoffDate }
    }
}

// MARK: - Supporting Types

public struct OperationStatus {
    public let scheduledCount: Int
    public let activeCount: Int
    public let throttledKeys: Set<String>
    public let debouncedKeys: Set<String>
}

public enum OperationError: Error {
    case retriesExhausted
    case operationCancelled
}

// MARK: - Convenience Functions

/// Global debounce function
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

/// Global throttle function
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
