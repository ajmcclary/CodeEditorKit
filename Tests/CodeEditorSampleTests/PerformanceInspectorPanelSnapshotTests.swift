#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class PerformanceInspectorPanelSnapshotTests: XCTestCase {

    func testStoppedState() {
        let view = panel(
            state: .stopped,
            fps: 0,
            lastHighlightMs: nil,
            highlightP95Ms: nil,
            memorySparkline: []
        )
        assertSnapshot(of: host(view), as: .image, named: "stopped")
    }

    func testLiveHighQualityGreen() {
        assertSnapshot(of: host(panel()), as: .image, named: "live-highquality-green")
    }

    func testLiveBalancedAmberMemory() {
        let stats = MemoryStatistics()
        var mutableStats = stats
        mutableStats.currentUsageMB = 1_200
        mutableStats.peakUsageMB = 1_400
        mutableStats.averageUsageMB = 900
        mutableStats.usageHistory = (0..<80).map { 800 + Double($0 * 5) }
        let view = panel(
            memoryStats: mutableStats,
            pressure: .warning,
            adaptiveMode: .balanced,
            healthScore: 65
        )
        assertSnapshot(of: host(view), as: .image, named: "live-balanced-amber")
    }

    func testLivePerformanceRedHighlight() {
        let view = panel(
            adaptiveMode: .performance,
            lastHighlightMs: 240,
            highlightP95Ms: 450,
            healthScore: 35
        )
        assertSnapshot(of: host(view), as: .image, named: "live-performance-red")
    }

    func testLiveCriticalPressure() {
        let view = panel(
            pressure: .critical,
            healthScore: 25,
            issuesCount: 3,
            recommendationsCount: 1
        )
        assertSnapshot(of: host(view), as: .image, named: "live-critical-pressure")
    }

    // MARK: - Helpers

    private func defaultStats() -> MemoryStatistics {
        var stats = MemoryStatistics()
        stats.currentUsageMB = 145
        stats.peakUsageMB = 210
        stats.averageUsageMB = 132
        stats.usageHistory = [100, 120, 145]
        return stats
    }

    private func panel(
        state: PerformanceSampleCoordinator.State = .live,
        fps: Int = 58,
        memoryStats: MemoryStatistics? = nil,
        pressure: MemoryPressure = .normal,
        adaptiveMode: PerformanceMode = .highQuality,
        lastHighlightMs: Double? = 2.4,
        highlightP95Ms: Double? = 5.8,
        healthScore: Double = 82,
        issuesCount: Int = 0,
        recommendationsCount: Int = 0,
        memorySparkline: [Double] = (0..<60).map { 100 + Double($0) }
    ) -> some View {
        PerformanceInspectorPanel(
            state: state,
            fps: fps,
            memoryStats: memoryStats ?? defaultStats(),
            pressure: pressure,
            adaptiveMode: adaptiveMode,
            lastHighlightMs: lastHighlightMs,
            highlightP95Ms: highlightP95Ms,
            healthScore: healthScore,
            issuesCount: issuesCount,
            recommendationsCount: recommendationsCount,
            memorySparkline: memorySparkline,
            thresholds: .default(fpsTarget: 60),
            onResetPeak: {},
            onShowReport: {},
            onAppear: {},
            onDisappear: {}
        )
        .frame(width: 360)
    }

    private func host<V: View>(_ view: V) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(x: 0, y: 0, width: 360, height: 280)
        return hosting
    }
}
#endif
