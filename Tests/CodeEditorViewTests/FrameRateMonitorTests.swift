import CodeEditorDiagnostics
@testable import CodeEditorView
import Testing

@Suite("FrameRateMonitor")
struct FrameRateMonitorTests {
    @Test
    @MainActor
    func startsAtZero() {
        let monitor = FrameRateMonitor()
        #expect(monitor.currentFPS == 0)
        #expect(monitor.averageFPS == 0)
    }

    @Test
    @MainActor
    func computeFPSEmptyWindow() {
        let result = FrameRateMonitor.computeFPS(timestamps: [], window: 1.0, now: 100)
        #expect(result.current == 0)
        #expect(result.average == 0)
    }

    @Test
    @MainActor
    func computeFPSSingleSampleInWindow() {
        let result = FrameRateMonitor.computeFPS(timestamps: [99.9], window: 1.0, now: 100)
        #expect(result.current == 1)
        #expect(result.average == 1.0)
    }

    @Test
    @MainActor
    func computeFPSSixtyFramesIn1s() {
        let stamps = (0..<60).map { 99.0 + Double($0) / 60.0 }
        let result = FrameRateMonitor.computeFPS(timestamps: stamps, window: 1.0, now: 100)
        #expect(result.current == 60)
        #expect(abs(result.average - 60.0) < 0.5)
    }

    @Test
    @MainActor
    func computeFPSDropsSamplesOlderThanWindow() {
        let stamps = [50.0, 90.0, 99.5]
        let result = FrameRateMonitor.computeFPS(timestamps: stamps, window: 1.0, now: 100)
        #expect(result.current == 1)
    }

    @Test
    @MainActor
    func stopMonitoringResetsFPS() {
        let monitor = FrameRateMonitor()
        monitor.startMonitoring()
        monitor.stopMonitoring()
        #expect(monitor.currentFPS == 0)
        #expect(monitor.averageFPS == 0)
    }
}
