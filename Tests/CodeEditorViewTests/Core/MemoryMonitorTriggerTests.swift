import CodeEditorDiagnostics
import CodeEditorPlatform
import XCTest

/// The monitor compares the whole process's footprint with its threshold,
/// so an app that embeds the editor is above it all the time. Automatic
/// passes must be proportionate to that, not one per check.
@MainActor
final class MemoryMonitorTriggerTests: XCTestCase {
    /// A memory provider whose footprint and pressure the test sets.
    private final class AdjustableMemoryProvider: PlatformMemoryProvider, @unchecked Sendable {
        var usageMB: Double
        var pressure: MemoryPressure = .normal

        init(usageMB: Double) {
            self.usageMB = usageMB
        }

        func getCurrentMemoryUsage() -> Double { usageMB }
        func getPhysicalMemory() -> UInt64 { 16 << 30 }
        func getMemoryPressure() -> MemoryPressure { pressure }
        func isUnderMemoryPressure() -> Bool { pressure != .normal }
    }

    /// A host that legitimately sits above the threshold gets one pass, not
    /// one per check (every 10 s by default).
    func testAFootprintThatStaysAboveTheThresholdRunsOnePass() async {
        let provider = AdjustableMemoryProvider(usageMB: 400)
        let monitor = MemoryMonitor(memoryProvider: provider)
        monitor.minimumAutomaticCleanupInterval = 0

        for _ in 0..<5 {
            await monitor.checkMemoryUsageNow()
        }

        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 1)
    }

    /// Another pass runs once the footprint has grown by half the threshold
    /// since the last one, or after it fell below the threshold and rose
    /// again; never twice within `minimumAutomaticCleanupInterval`.
    func testFurtherPassesNeedGrowthAndAreRateLimited() async {
        let provider = AdjustableMemoryProvider(usageMB: 400)
        let monitor = MemoryMonitor(memoryProvider: provider)
        monitor.minimumAutomaticCleanupInterval = 0

        await monitor.checkMemoryUsageNow() // first pass above the threshold
        provider.usageMB = 440
        await monitor.checkMemoryUsageNow() // +40 MB: less than half of 100
        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 1)
        provider.usageMB = 450
        await monitor.checkMemoryUsageNow() // +50 MB
        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 2)

        provider.usageMB = 80
        await monitor.checkMemoryUsageNow() // below: no pass, re-armed
        provider.usageMB = 120
        await monitor.checkMemoryUsageNow()
        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 3)

        monitor.minimumAutomaticCleanupInterval = 3_600
        provider.usageMB = 1_000
        await monitor.checkMemoryUsageNow() // grown, but within the interval
        provider.pressure = .critical
        await monitor.checkMemoryUsageNow() // critical, still within the interval
        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 3)
    }

    /// Critical pressure (as the monitor reads it) does not wait for growth.
    func testCriticalPressureRunsAPassWithoutGrowth() async {
        let provider = AdjustableMemoryProvider(usageMB: 400)
        let monitor = MemoryMonitor(memoryProvider: provider)
        monitor.minimumAutomaticCleanupInterval = 0

        await monitor.checkMemoryUsageNow()
        provider.pressure = .critical
        await monitor.checkMemoryUsageNow()

        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 2)
    }
}
