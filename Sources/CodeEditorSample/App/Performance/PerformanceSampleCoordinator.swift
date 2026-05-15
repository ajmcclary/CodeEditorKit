#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import Foundation
import Observation

/// Owns the sample's Performance Inspector lifecycle. Holds the framework
/// monitors and snapshots them on a 1Hz timer into a single `@Observable`
/// surface for `PerformanceInspectorPanel`.
@MainActor
@Observable
final class PerformanceSampleCoordinator {
    enum State: Sendable {
        case stopped
        case live
    }

    // MARK: - Observable surface

    private(set) var state: State = .stopped
    private(set) var fps: Int = 0
    private(set) var memoryStats: MemoryStatistics
    private(set) var pressure: MemoryPressure = .normal
    private(set) var adaptiveMode: PerformanceMode = .balanced
    private(set) var lastHighlightMs: Double?
    private(set) var highlightP95Ms: Double?
    private(set) var healthScore: Double = 100
    private(set) var issuesCount: Int = 0
    private(set) var recommendationsCount: Int = 0
    private(set) var memorySparkline: [Double] = []
    let targetFPS: Int

    // MARK: - Non-observable internals

    @ObservationIgnored
    private let memoryMonitor: MemoryMonitor

    @ObservationIgnored
    private let frameRateMonitor: FrameRateMonitor

    @ObservationIgnored
    private let performanceObservation: PerformanceObservation

    @ObservationIgnored
    let performanceInsights: PerformanceInsights

    @ObservationIgnored
    private weak var adaptivePerformanceMode: AdaptivePerformanceMode?

    @ObservationIgnored
    private var refreshTimer: Timer?

    /// Platform's max screen refresh rate, with a 60 fallback. Used as
    /// the `targetFPS` baseline for the performance inspector.
    private static func screenMaxFPS() -> Int {
        #if canImport(AppKit)
        return NSScreen.main?.maximumFramesPerSecond ?? 60
        #elseif canImport(UIKit)
        return UIScreen.main.maximumFramesPerSecond
        #else
        return 60
        #endif
    }

    init(
        memoryMonitor: MemoryMonitor,
        performanceObservation: PerformanceObservation
    ) {
        let frames = FrameRateMonitor()
        self.memoryMonitor = memoryMonitor
        self.frameRateMonitor = frames
        self.performanceObservation = performanceObservation
        self.performanceInsights = PerformanceInsights(
            memoryMonitor: memoryMonitor,
            frameRateMonitor: frames
        )
        self.memoryStats = memoryMonitor.memoryStats
        self.targetFPS = Self.screenMaxFPS()
    }

    func attach(controller: EditorController) {
        self.adaptivePerformanceMode = controller.adaptivePerformanceMode
    }

    func start() {
        guard state == .stopped else { return }
        memoryMonitor.startMonitoring()
        frameRateMonitor.startMonitoring()
        performanceInsights.startMonitoring()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        self.refreshTimer = timer
        state = .live
    }

    func stop() {
        guard state == .live else { return }
        memoryMonitor.stopMonitoring()
        frameRateMonitor.stopMonitoring()
        performanceInsights.stopMonitoring()
        refreshTimer?.invalidate()
        refreshTimer = nil
        state = .stopped
    }

    func resetPeak() {
        memoryMonitor.resetPeak()
        refresh()
    }

    /// Snapshots all monitors into the observable mirror. Exposed `internal`
    /// so tests can drive it deterministically without waiting for the timer.
    func refresh() {
        fps = frameRateMonitor.currentFPS
        memoryStats = memoryMonitor.memoryStats
        pressure = memoryMonitor.getMemoryPressure()
        if let adaptive = adaptivePerformanceMode {
            adaptiveMode = adaptive.currentMode
        }
        issuesCount = performanceInsights.issues.count
        recommendationsCount = performanceInsights.recommendations.count
        let insights = performanceObservation.lastInsights
        if let highlight = insights.metricAnalyses[.syntaxHighlighting] {
            lastHighlightMs = highlight.averageDuration * 1_000
            highlightP95Ms = highlight.p95Duration * 1_000
        }
        healthScore = insights.overallHealth
        memorySparkline = Array(memoryStats.usageHistory.suffix(100))
    }
}
