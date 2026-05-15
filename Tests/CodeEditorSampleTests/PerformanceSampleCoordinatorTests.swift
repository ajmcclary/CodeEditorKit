import CodeEditorPlugin
@testable import CodeEditorSample
import Testing

@MainActor
@Suite("PerformanceSampleCoordinator")
struct PerformanceSampleCoordinatorTests {
    @Test func initialStateIsStopped() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            performanceObservation: PerformanceObservation()
        )
        #expect(coordinator.state == .stopped)
        #expect(coordinator.fps == 0)
        #expect(coordinator.adaptiveMode == .balanced)
    }

    @Test func startTransitionsToLive() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            performanceObservation: PerformanceObservation()
        )
        coordinator.start()
        #expect(coordinator.state == .live)
        coordinator.stop()
    }

    @Test func startIsIdempotent() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            performanceObservation: PerformanceObservation()
        )
        coordinator.start()
        coordinator.start()
        #expect(coordinator.state == .live)
        coordinator.stop()
    }

    @Test func stopTransitionsToStopped() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            performanceObservation: PerformanceObservation()
        )
        coordinator.start()
        coordinator.stop()
        #expect(coordinator.state == .stopped)
    }

    @Test func resetPeakClearsPeakAndUsageHistory() {
        let memory = MemoryMonitor.mock(
            currentUsageMB: 145,
            peakUsageMB: 210,
            usageHistory: [100, 145, 210]
        )
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: memory,
            performanceObservation: PerformanceObservation()
        )
        coordinator.resetPeak()
        #expect(memory.memoryStats.peakUsageMB == 145)
        #expect(memory.memoryStats.usageHistory.isEmpty)
    }

    @Test func refreshPopulatesFromInjectedMonitors() {
        let memory = MemoryMonitor.mock(
            currentUsageMB: 145,
            peakUsageMB: 210,
            averageUsageMB: 132,
            usageHistory: [100, 120, 145]
        )
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: memory,
            performanceObservation: PerformanceObservation()
        )
        coordinator.refresh()
        #expect(coordinator.memoryStats.currentUsageMB == 145)
        #expect(coordinator.memoryStats.peakUsageMB == 210)
        #expect(coordinator.memorySparkline == [100, 120, 145])
    }

    @Test func targetFPSReadsFromMainScreen() {
        let coordinator = PerformanceSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            performanceObservation: PerformanceObservation()
        )
        #expect(coordinator.targetFPS >= 60)
    }
}
