@testable import CodeEditorPlugin
import Testing

@Suite("PerformanceInsights real FPS")
struct PerformanceInsightsRealFPSTests {
    @Test
    @MainActor
    func currentFPSReflectsInjectedMonitor() async {
        let memory = MemoryMonitor.mock(memoryUsage: 100)
        let frames = FrameRateMonitor()
        let insights = PerformanceInsights(
            memoryMonitor: memory,
            frameRateMonitor: frames
        )
        try? await Task.sleep(for: .milliseconds(1_100))
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
        try? await Task.sleep(for: .milliseconds(1_100))
        let cpu = insights.metrics.cpuUsage
        #expect(cpu >= 0)
        #expect(cpu <= 100)
    }
}
