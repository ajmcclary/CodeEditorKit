import CodeEditorDiagnostics
@testable import CodeEditorPlugin
import Testing

@Suite("PerformanceInsights real FPS")
struct PerformanceInsightsRealFPSTests {
    @Test
    @MainActor
    func currentFPSReflectsInjectedMonitor() async {
        // Headless test runs don't pump a run loop in a way that triggers
        // `Timer.scheduledTimer` reliably, so we drive the metric refresh
        // explicitly via the public `refresh()` hook instead of sleeping
        // for a timer tick that may never fire.
        let memory = MemoryMonitor.mock(memoryUsage: 100)
        let frames = FrameRateMonitor()
        let insights = PerformanceInsights(
            memoryMonitor: memory,
            frameRateMonitor: frames
        )
        insights.refresh()
        #expect(insights.metrics.currentFPS == frames.currentFPS)
    }
}

@Suite("PerformanceInsights real CPU")
struct PerformanceInsightsRealCPUTests {
    @Test
    @MainActor
    func cpuUsageIsInRange() async {
        let memory = MemoryMonitor.mock(memoryUsage: 100)
        let frames = FrameRateMonitor()
        let insights = PerformanceInsights(memoryMonitor: memory, frameRateMonitor: frames)
        insights.refresh()
        let cpu = insights.metrics.cpuUsage
        #expect(cpu >= 0)
        #expect(cpu <= 100)
    }
}
