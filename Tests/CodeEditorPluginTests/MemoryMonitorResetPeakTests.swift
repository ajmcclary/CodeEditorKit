import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Testing

@Suite("MemoryMonitor resetPeak")
struct MemoryMonitorResetPeakTests {
    @Test
    @MainActor
    func resetPeakSetsPeakToCurrent() {
        let monitor = MemoryMonitor.mock(
            currentUsageMB: 75,
            peakUsageMB: 250
        )
        monitor.resetPeak()
        #expect(monitor.memoryStats.peakUsageMB == 75)
    }

    @Test
    @MainActor
    func resetPeakClearsUsageHistory() {
        let monitor = MemoryMonitor.mock(
            currentUsageMB: 50,
            peakUsageMB: 50,
            usageHistory: [10, 20, 30, 50]
        )
        monitor.resetPeak()
        #expect(monitor.memoryStats.usageHistory.isEmpty)
    }
}

@Suite("MemoryMonitor.mock factory")
struct MemoryMonitorMockFactoryTests {
    @Test
    @MainActor
    func mockWithFixedValues() {
        let monitor = MemoryMonitor.mock(
            currentUsageMB: 145,
            peakUsageMB: 210,
            averageUsageMB: 132,
            usageHistory: [100, 120, 145],
            isUnderPressure: false
        )
        #expect(monitor.memoryStats.currentUsageMB == 145)
        #expect(monitor.memoryStats.peakUsageMB == 210)
        #expect(monitor.memoryStats.averageUsageMB == 132)
        #expect(monitor.memoryStats.usageHistory == [100, 120, 145])
    }
}
