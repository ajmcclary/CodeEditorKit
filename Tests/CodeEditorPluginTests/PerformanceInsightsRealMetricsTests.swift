import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Foundation
import Testing

private struct TestDocumentMetrics: DocumentMetricsProviding {
    let fileSizeBytes: Int?
}

private struct TestLayoutMetrics: TextLayoutMetricsProviding {
    let averageLayoutTime: TimeInterval?
    let cacheHitRate: Double?
}

@Suite("PerformanceInsights injected metrics")
struct PerformanceInsightsInjectedMetricsTests {
    @MainActor
    @Test("recommendations use injected document size")
    func documentSizeRecommendation() {
        let insights = PerformanceInsights(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            frameRateMonitor: FrameRateMonitor(),
            documentMetrics: TestDocumentMetrics(fileSizeBytes: 200_000_000),
            textLayoutMetrics: TestLayoutMetrics(
                averageLayoutTime: nil,
                cacheHitRate: nil
            )
        )

        insights.refresh()

        #expect(insights.recommendations.contains { recommendation in
            if case .splitLargeFile = recommendation {
                return true
            }
            return false
        })
    }

    @MainActor
    @Test("layout issues require available measurements")
    func unavailableLayoutMetricsProduceNoLayoutIssues() {
        let insights = PerformanceInsights(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            frameRateMonitor: FrameRateMonitor(),
            documentMetrics: TestDocumentMetrics(fileSizeBytes: nil),
            textLayoutMetrics: TestLayoutMetrics(
                averageLayoutTime: nil,
                cacheHitRate: nil
            )
        )

        insights.refresh()

        #expect(insights.issues.contains { issue in
            switch issue {
            case .slowTextLayout, .lowCacheHitRate:
                return true
            default:
                return false
            }
        } == false)
    }

    @MainActor
    @Test("layout issues use injected measurements")
    func availableLayoutMetricsProduceIssues() {
        let insights = PerformanceInsights(
            memoryMonitor: MemoryMonitor.mock(memoryUsage: 100),
            frameRateMonitor: FrameRateMonitor(),
            documentMetrics: TestDocumentMetrics(fileSizeBytes: nil),
            textLayoutMetrics: TestLayoutMetrics(
                averageLayoutTime: 0.2,
                cacheHitRate: 0.1
            )
        )

        insights.refresh()

        #expect(insights.issues.contains { issue in
            if case .slowTextLayout = issue { return true }
            return false
        })
        #expect(insights.issues.contains { issue in
            if case .lowCacheHitRate = issue { return true }
            return false
        })
    }
}

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
