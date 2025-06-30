import Foundation
import os.log

/// Monitors memory usage and provides automatic cleanup capabilities
@MainActor
public final class MemoryMonitor: ObservableObject {
    // MARK: - Configuration
    
    /// Memory threshold for triggering cleanup (in MB)
    public var memoryThresholdMB: Double = 100.0
    
    /// Monitoring interval in seconds
    public var monitoringInterval: TimeInterval = 10.0
    
    /// Enable automatic cleanup when threshold is exceeded
    public var enableAutomaticCleanup: Bool = true
    
    /// Enable periodic cleanup regardless of memory usage
    public var enablePeriodicCleanup: Bool = true
    
    /// Periodic cleanup interval in seconds
    public var periodicCleanupInterval: TimeInterval = 300.0 // 5 minutes
    
    // MARK: - State
    
    /// Current memory usage statistics
    @Published public private(set) var memoryStats = MemoryStatistics()
    
    /// Registered cleanup handlers
    private var cleanupHandlers: [String: CleanupHandler] = [:]
    
    /// Memory monitoring timer
    private var monitoringTimer: Timer?
    
    /// Periodic cleanup timer
    private var cleanupTimer: Timer?
    
    /// Logger
    private let logger = Logger(subsystem: "com.codeeditor.memory", category: "MemoryMonitor")
    
    /// Cleanup operations history
    @Published public private(set) var cleanupHistory: [CleanupOperation] = []
    
    // MARK: - Singleton
    
    public static let shared = MemoryMonitor()
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        // Note: Cannot call stopMonitoring() in deinit as it's @MainActor isolated
        // Timer invalidation will happen automatically when the monitor is deallocated
    }
    
    // MARK: - Public Methods
    
    /// Register a cleanup handler
    /// - Parameters:
    ///   - identifier: Unique identifier for the handler
    ///   - priority: Cleanup priority (higher values are cleaned first)
    ///   - handler: The cleanup handler
    public func registerCleanupHandler(
        identifier: String,
        priority: CleanupPriority = .normal,
        handler: @escaping @MainActor @Sendable () async -> CleanupResult
    ) {
        cleanupHandlers[identifier] = CleanupHandler(
            identifier: identifier,
            priority: priority,
            handler: handler
        )
        
        logger.info("Registered cleanup handler: \(identifier) with priority: \(priority.rawValue)")
    }
    
    /// Unregister a cleanup handler
    /// - Parameter identifier: The identifier of the handler to remove
    public func unregisterCleanupHandler(identifier: String) {
        cleanupHandlers.removeValue(forKey: identifier)
        logger.info("Unregistered cleanup handler: \(identifier)")
    }
    
    /// Force immediate cleanup
    /// - Parameter targetReduction: Target memory reduction in MB (nil for all available)
    /// - Returns: Total amount of memory freed
    @discardableResult
    public func performCleanup(targetReduction: Double? = nil) async -> Double {
        let startTime = Date()
        let initialMemory = getCurrentMemoryUsage()
        
        logger.info("Starting forced cleanup. Initial memory: \(initialMemory)MB")
        
        var totalFreed: Double = 0
        let sortedHandlers = cleanupHandlers.values.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        for handler in sortedHandlers {
            let result = await handler.handler()
            totalFreed += result.memoryFreedMB
            
            logger.debug("Cleanup handler \(handler.identifier) freed \(result.memoryFreedMB)MB")
            
            // Check if we've reached the target
            if let target = targetReduction, totalFreed >= target {
                break
            }
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let actualFreed = max(0, initialMemory - finalMemory)
        let duration = Date().timeIntervalSince(startTime)
        
        let operation = CleanupOperation(
            timestamp: startTime,
            duration: duration,
            memoryBefore: initialMemory,
            memoryAfter: finalMemory,
            memoryFreed: actualFreed,
            trigger: .manual
        )
        
        recordCleanupOperation(operation)
        updateMemoryStats()
        
        logger.info("Cleanup completed. Memory freed: \(actualFreed)MB in \(duration)s")
        
        return actualFreed
    }
    
    /// Get current memory usage in MB
    public func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1_024 * 1_024) // Convert to MB
        } else {
            logger.warning("Failed to get memory usage: \(kerr)")
            return 0
        }
    }
    
    /// Start memory monitoring
    public func startMonitoring() {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkMemoryUsage()
            }
        }
        
        if enablePeriodicCleanup {
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: periodicCleanupInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    await self?.performPeriodicCleanup()
                }
            }
        }
        
        logger.info("Memory monitoring started")
    }
    
    /// Stop memory monitoring
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        logger.info("Memory monitoring stopped")
    }
    
    /// Get memory statistics
    public func getMemoryStatistics() -> MemoryStatistics {
        var stats = memoryStats
        stats.currentUsageMB = getCurrentMemoryUsage()
        return stats
    }
    
    /// Reset statistics
    public func resetStatistics() {
        memoryStats = MemoryStatistics()
        cleanupHistory.removeAll()
        logger.info("Memory statistics reset")
    }
    
    // MARK: - Private Methods
    
    private func checkMemoryUsage() async {
        let currentUsage = getCurrentMemoryUsage()
        updateMemoryStats(currentUsage: currentUsage)
        
        if enableAutomaticCleanup && currentUsage > memoryThresholdMB {
            logger.warning("Memory usage (\(currentUsage)MB) exceeded threshold (\(self.memoryThresholdMB)MB)")
            
            let targetReduction = currentUsage - (self.memoryThresholdMB * 0.8) // Target 80% of threshold
            await performAutomaticCleanup(targetReduction: targetReduction)
        }
    }
    
    private func performAutomaticCleanup(targetReduction: Double) async {
        let freed = await performCleanup(targetReduction: targetReduction)
        
        _ = CleanupOperation(
            timestamp: Date(),
            duration: 0, // Will be updated by performCleanup
            memoryBefore: 0, // Will be updated by performCleanup
            memoryAfter: 0, // Will be updated by performCleanup
            memoryFreed: freed,
            trigger: .automatic
        )
        
        logger.info("Automatic cleanup freed \(freed)MB")
    }
    
    private func performPeriodicCleanup() async {
        let freed = await performCleanup()
        
        _ = CleanupOperation(
            timestamp: Date(),
            duration: 0,
            memoryBefore: 0,
            memoryAfter: 0,
            memoryFreed: freed,
            trigger: .periodic
        )
        
        logger.info("Periodic cleanup freed \(freed)MB")
    }
    
    private func updateMemoryStats(currentUsage: Double? = nil) {
        let usage = currentUsage ?? getCurrentMemoryUsage()
        
        memoryStats.currentUsageMB = usage
        memoryStats.peakUsageMB = max(memoryStats.peakUsageMB, usage)
        memoryStats.lastUpdateTime = Date()
        
        // Update rolling average
        memoryStats.usageHistory.append(usage)
        if memoryStats.usageHistory.count > 100 { // Keep last 100 readings
            memoryStats.usageHistory.removeFirst()
        }
        
        memoryStats.averageUsageMB = memoryStats.usageHistory.reduce(0, +) / Double(memoryStats.usageHistory.count)
    }
    
    private func recordCleanupOperation(_ operation: CleanupOperation) {
        cleanupHistory.append(operation)
        
        // Keep only last 50 cleanup operations
        if cleanupHistory.count > 50 {
            cleanupHistory.removeFirst()
        }
        
        // Update statistics
        memoryStats.totalCleanupOperations += 1
        memoryStats.totalMemoryFreed += operation.memoryFreed
    }
}

/// Represents a cleanup handler
private struct CleanupHandler {
    let identifier: String
    let priority: CleanupPriority
    let handler: @MainActor @Sendable () async -> CleanupResult
}

/// Priority levels for cleanup operations
public enum CleanupPriority: Int, CaseIterable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

/// Result of a cleanup operation
public struct CleanupResult: Sendable {
    public let memoryFreedMB: Double
    public let description: String?
    
    public init(memoryFreedMB: Double, description: String? = nil) {
        self.memoryFreedMB = memoryFreedMB
        self.description = description
    }
}

/// Cleanup operation trigger
public enum CleanupTrigger: String, Sendable {
    case manual
    case automatic
    case periodic
}

/// Record of a cleanup operation
public struct CleanupOperation: Sendable, Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let duration: TimeInterval
    public let memoryBefore: Double
    public let memoryAfter: Double
    public let memoryFreed: Double
    public let trigger: CleanupTrigger
}

/// Memory usage statistics
@MainActor
public struct MemoryStatistics {
    public var currentUsageMB: Double = 0
    public var peakUsageMB: Double = 0
    public var averageUsageMB: Double = 0
    public var totalCleanupOperations: Int = 0
    public var totalMemoryFreed: Double = 0
    public var lastUpdateTime = Date()
    
    public var usageHistory: [Double] = []
    
    public var memoryEfficiency: Double {
        guard peakUsageMB > 0 else { return 0 }
        return 1.0 - (averageUsageMB / peakUsageMB)
    }
    
    public var cleanupEffectiveness: Double {
        guard totalCleanupOperations > 0 else { return 0 }
        return totalMemoryFreed / Double(totalCleanupOperations)
    }
}

private func mach_task_basic_info() -> mach_task_basic_info_data_t {
    mach_task_basic_info_data_t(
        virtual_size: 0,
        resident_size: 0,
        resident_size_max: 0,
        user_time: time_value_t(),
        system_time: time_value_t(),
        policy: 0,
        suspend_count: 0
    )
}
