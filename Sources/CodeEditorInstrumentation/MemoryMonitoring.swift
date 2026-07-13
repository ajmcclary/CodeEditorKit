import CodeEditorCommon
import CodeEditorPlatform
import Foundation

/// Lightweight instrumentation contract for memory monitoring.
///
/// This is the seam lean targets (`CodeEditorView`, `CodeEditorCompletion`,
/// `CodeEditorSyntaxHighlighting`, `CodeEditorLSP`) program against instead of
/// naming the concrete ``MemoryMonitor`` class, so hosts can substitute their
/// own monitor (or ``NoOpMemoryMonitor``) without carrying the full
/// diagnostics system.
@MainActor
public protocol MemoryMonitoring: AnyObject {
    /// Memory threshold for triggering cleanup (in MB).
    var memoryThresholdMB: Double { get set }

    /// Current memory usage statistics.
    var memoryStats: MemoryStatistics { get }

    /// Available system memory in megabytes.
    var availableMemoryMB: Double { get }

    /// Current system memory pressure.
    func getMemoryPressure() -> MemoryPressure

    /// Registers a cleanup handler invoked when the monitor decides memory
    /// should be reclaimed.
    func registerCleanupHandler(
        identifier: String,
        priority: CleanupPriority,
        handler: @escaping @MainActor @Sendable () async -> CleanupResult
    )

    /// Removes a previously registered cleanup handler.
    func unregisterCleanupHandler(identifier: String)
}

extension MemoryMonitoring {
    /// Registers a cleanup handler with `.normal` priority.
    public func registerCleanupHandler(
        identifier: String,
        handler: @escaping @MainActor @Sendable () async -> CleanupResult
    ) {
        registerCleanupHandler(identifier: identifier, priority: .normal, handler: handler)
    }
}

/// A `MemoryMonitoring` implementation that never reports pressure and never
/// invokes cleanup handlers. Useful for hosts that opt out of memory
/// instrumentation entirely.
@MainActor
public final class NoOpMemoryMonitor: MemoryMonitoring {
    /// Threshold is stored but never acted upon.
    public var memoryThresholdMB: Double = .greatestFiniteMagnitude

    /// Always zero-valued statistics.
    public private(set) var memoryStats = MemoryStatistics()

    /// Reports effectively unlimited available memory.
    public var availableMemoryMB: Double { .greatestFiniteMagnitude }

    /// Creates a no-op monitor.
    public init() {}

    /// Always `.normal`.
    public func getMemoryPressure() -> MemoryPressure { .normal }

    /// Discards the handler — it will never be invoked.
    public func registerCleanupHandler(
        identifier _: String,
        priority _: CleanupPriority,
        handler _: @escaping @MainActor @Sendable () async -> CleanupResult
    ) {}

    /// No-op.
    public func unregisterCleanupHandler(identifier _: String) {}
}

/// A `UnifiedPerformanceTracking` conformer that records nothing. Useful for
/// hosts that opt out of performance telemetry.
public final class NoOpPerformanceTracker: UnifiedPerformanceTracking {
    /// Creates a no-op tracker.
    public init() {}
}
