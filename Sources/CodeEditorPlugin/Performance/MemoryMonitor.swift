import Foundation
#if canImport(Combine)
import Combine
#endif

/// Monitors memory usage and provides automatic cleanup capabilities
///
/// MemoryMonitor provides sophisticated memory tracking and automatic cleanup for the code editor.
/// It supports dependency injection for better testability and allows sharing monitors across components.
///
/// ## Overview
///
/// Instead of using the deprecated singleton pattern, create MemoryMonitor instances and inject them
/// through `EditorConfiguration` or directly into components that need memory management.
///
/// ## Basic Usage
///
/// ```swift
/// // Create and configure a monitor
/// let monitor = MemoryMonitor()
/// monitor.memoryThresholdMB = 150.0
/// monitor.enableAutomaticCleanup = true
///
/// // Start monitoring explicitly (since v1.1.0)
/// monitor.startMonitoring()
///
/// // Inject via configuration
/// var config = EditorConfiguration()
/// config.performance.memoryMonitor = monitor
/// config.apply(to: editorView)
/// ```
///
/// ## Lifecycle Management
///
/// **Important**: Always stop monitoring when the associated view or component is deallocated:
///
/// ```swift
/// class MyViewController {
///     let monitor = MemoryMonitor()
///     
///     override func viewDidLoad() {
///         super.viewDidLoad()
///         monitor.startMonitoring()
///     }
///     
///     override func viewWillDisappear(_ animated: Bool) {
///         super.viewWillDisappear(animated)
///         monitor.stopMonitoring()
///     }
///     
///     deinit {
///         // Ensure monitoring is stopped if not already done
///         monitor.stopMonitoring()
///     }
/// }
/// ```
///
/// For SwiftUI views:
/// ```swift
/// struct ContentView: View {
///     @StateObject private var monitor = MemoryMonitor()
///     
///     var body: some View {
///         CodeEditor(text: $code)
///             .memoryMonitor(monitor)
///             .onAppear {
///                 monitor.startMonitoring()
///             }
///             .onDisappear {
///                 monitor.stopMonitoring()
///             }
///     }
/// }
/// ```
///
/// ## Integration with CodeEditorView
///
/// When using MemoryMonitor with CodeEditorView, ensure proper cleanup:
///
/// ```swift
/// class CustomEditorView: CodeEditorView {
///     private let memoryMonitor = MemoryMonitor()
///     
///     override func commonInit() {
///         super.commonInit()
///         
///         // Configure memory monitor
///         memoryMonitor.memoryThresholdMB = 200.0
///         memoryMonitor.enableAutomaticCleanup = true
///         
///         // Register cleanup for syntax highlighting cache
///         memoryMonitor.registerCleanupHandler(
///             identifier: "syntax-cache",
///             priority: .medium
///         ) { [weak self] in
///             let freed = self?.syntaxHighlighter?.clearCache() ?? 0
///             return CleanupResult(
///                 success: true,
///                 memoryFreedMB: Double(freed) / 1_048_576,
///                 description: "Cleared syntax highlighting cache"
///             )
///         }
///         
///         memoryMonitor.startMonitoring()
///     }
///     
///     override func removeFromSuperview() {
///         // CRITICAL: Stop monitoring before removal
///         memoryMonitor.stopMonitoring()
///         super.removeFromSuperview()
///     }
/// }
/// ```
///
/// ## Cleanup Handlers
///
/// Register custom cleanup handlers for your resources:
///
/// ```swift
/// monitor.registerCleanupHandler(
///     identifier: "cache-cleanup",
///     priority: .high
/// ) { @MainActor in
///     let freed = MyCache.shared.clear()
///     return CleanupResult(memoryFreedMB: freed)
/// }
/// ```
///
/// ## Multi-Window Applications
///
/// For apps with multiple editor windows, share a single monitor or coordinate multiple monitors:
///
/// ```swift
/// // Shared monitor approach (recommended)
/// @MainActor
/// class EditorWindowManager {
///     static let sharedMemoryMonitor = MemoryMonitor()
///     
///     static func setupSharedMonitor() {
///         sharedMemoryMonitor.memoryThresholdMB = 500.0  // Higher for multi-window
///         sharedMemoryMonitor.enableAutomaticCleanup = true
///         sharedMemoryMonitor.startMonitoring()
///     }
/// }
///
/// // Per-window usage
/// class EditorWindowController {
///     override func windowDidLoad() {
///         super.windowDidLoad()
///         
///         // Register window-specific cleanup
///         EditorWindowManager.sharedMemoryMonitor.registerCleanupHandler(
///             identifier: "window-\(windowID)",
///             priority: .low
///         ) { [weak self] in
///             guard let self else { return CleanupResult(success: false) }
///             let freed = self.editorView.performCleanup()
///             return CleanupResult(
///                 success: true,
///                 memoryFreedMB: freed,
///                 description: "Cleaned window \(self.windowID)"
///             )
///         }
///     }
///     
///     func windowWillClose(_ notification: Notification) {
///         // Unregister this window's cleanup handler
///         EditorWindowManager.sharedMemoryMonitor.unregisterCleanupHandler(
///             identifier: "window-\(windowID)"
///         )
///     }
/// }
/// ```
///
/// For comprehensive examples and patterns, see:
/// - <doc:MemoryMonitor-Injection>
///
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class MemoryMonitor: ObservableObject {
    // MARK: - Dependencies

    /// Memory provider for platform-specific memory information
    private let memoryProvider: PlatformMemoryProvider
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

    /// Memory monitoring task
    private var monitoringTask: Task<Void, Never>?

    /// Periodic cleanup task
    private var cleanupTask: Task<Void, Never>?

    /// Logger
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.memory", category: "MemoryMonitor")

    /// Whether we're under memory pressure
    @Published public private(set) var isUnderPressure: Bool = false

    /// Cleanup operations history
    @Published public private(set) var cleanupHistory: [CleanupOperation] = []

    // MARK: - Initialization

    /// Initialize with optional memory provider
    /// - Parameter memoryProvider: Platform memory provider (defaults to system provider)
    /// 
    /// - Note: As of v1.1.0, monitoring no longer starts automatically. Call `startMonitoring()` explicitly
    ///   to begin memory monitoring. This change provides better control over resource usage.
    public init(memoryProvider: PlatformMemoryProvider? = nil) {
        self.memoryProvider = memoryProvider ?? SystemMemoryProvider()

        // Note: No longer auto-starts monitoring.
        // Call startMonitoring() explicitly when ready.
    }

    deinit {
        // Note: We cannot safely access @MainActor properties from deinit
        // as it may be called from any thread. The tasks will be automatically
        // cancelled when they are deallocated.
        // Users should call stopMonitoring() explicitly before releasing the monitor
        // to ensure proper cleanup.
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

            // Only log in non-test environments
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                logger.debug("Cleanup handler \(handler.identifier) freed \(result.memoryFreedMB)MB")
            }

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

        // Only log in non-test environments to avoid cluttering test output
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            logger.info("Cleanup completed. Memory freed: \(actualFreed)MB in \(duration)s")
        }

        return actualFreed
    }

    /// Get current memory usage in MB
    public func getCurrentMemoryUsage() -> Double {
        memoryProvider.getCurrentMemoryUsage()
    }

    /// Get memory pressure status
    public func getMemoryPressure() -> MemoryPressure {
        memoryProvider.getMemoryPressure()
    }

    /// Start memory monitoring
    /// 
    /// - Note: Since v1.1.0, monitoring must be started explicitly. This provides better control
    ///   over when resource-intensive monitoring begins.
    public func startMonitoring() {
        stopMonitoring()

        // Start monitoring task
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                await self.checkMemoryUsage()

                do {
                    try await Task.sleep(for: .seconds(self.monitoringInterval))
                } catch {
                    // Task was cancelled
                    return
                }
            }
        }

        // Start periodic cleanup task if enabled
        if enablePeriodicCleanup {
            cleanupTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }

                    do {
                        try await Task.sleep(for: .seconds(self.periodicCleanupInterval))
                    } catch {
                        // Task was cancelled
                        return
                    }

                    await self.performPeriodicCleanup()
                }
            }
        }

        logger.info("Memory monitoring started")
    }

    /// Stop memory monitoring
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil

        cleanupTask?.cancel()
        cleanupTask = nil

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

        // Update pressure status
        let wasUnderPressure = isUnderPressure
        isUnderPressure = memoryProvider.isUnderMemoryPressure()

        // Notify if pressure status changed
        if isUnderPressure != wasUnderPressure {
            logger.info("Memory pressure changed: \(wasUnderPressure ? "normal" : "pressure") -> \(isUnderPressure ? "pressure" : "normal")")
        }

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

        // Only log in non-test environments
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            logger.info("Automatic cleanup freed \(freed)MB")
        }
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

        // Only log in non-test environments
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            logger.info("Periodic cleanup freed \(freed)MB")
        }
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
    /// Current memory usage in megabytes.
    public var currentUsageMB: Double = 0
    /// Peak memory usage in megabytes.
    public var peakUsageMB: Double = 0
    /// Average memory usage in megabytes.
    public var averageUsageMB: Double = 0
    /// Total number of cleanup operations performed.
    public var totalCleanupOperations: Int = 0
    /// Total amount of memory freed in megabytes.
    public var totalMemoryFreed: Double = 0
    /// Timestamp of the last statistics update.
    public var lastUpdateTime = Date()

    /// History of memory usage measurements.
    public var usageHistory: [Double] = []

    /// Memory efficiency metric (0-1, higher is better).
    public var memoryEfficiency: Double {
        guard peakUsageMB > 0 else { return 0 }
        return 1.0 - (averageUsageMB / peakUsageMB)
    }

    /// Average memory freed per cleanup operation.
    public var cleanupEffectiveness: Double {
        guard totalCleanupOperations > 0 else { return 0 }
        return totalMemoryFreed / Double(totalCleanupOperations)
    }
}

// MARK: - Extensions

extension MemoryMonitor {
    /// Convenience initializer for testing with mock provider
    public static func mock(
        memoryUsage: Double = 100.0,
        memoryPressure: MemoryPressure = .normal
    ) -> MemoryMonitor {
        let mockProvider = MockMemoryProvider(
            memoryUsage: memoryUsage,
            memoryPressure: memoryPressure
        )
        return MemoryMonitor(memoryProvider: mockProvider)
    }
}
