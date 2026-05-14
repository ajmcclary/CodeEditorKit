//
//  PerformanceObservationTests.swift
//  CodeEditorPluginTests
//

@testable import CodeEditorPlugin
import Testing

@Suite("PerformanceObservation")
@MainActor
struct PerformanceObservationTests {
    @Test("init sets initial lastInsights to a zero-state snapshot")
    func initStartsWithZeroSnapshot() {
        let observation = PerformanceObservation(refreshInterval: .seconds(1))
        #expect(observation.lastInsights.metricAnalyses.isEmpty)
        #expect(observation.lastInsights.issues.isEmpty)
        #expect(observation.lastInsights.recommendations.isEmpty)
        #expect(observation.lastInsights.overallHealth == 100.0)
        #expect(observation.refreshCount == 0)
    }

    @Test("refresh updates lastInsights from tracked operations")
    func refreshUpdatesLastInsights() async throws {
        let observation = PerformanceObservation(refreshInterval: .seconds(1))
        await observation.system.track(.syntaxHighlighting) { /* no-op */ }
        observation.refresh()
        #expect(observation.lastInsights.metricAnalyses[.syntaxHighlighting]?.count == 1)
        #expect(observation.refreshCount == 1)
    }

    @Test("start is idempotent — second start does not spawn a parallel loop")
    func startIsIdempotent() {
        let observation = PerformanceObservation(refreshInterval: .milliseconds(20))
        #expect(observation.refreshTaskSpawnCount == 0)
        observation.start()
        observation.start()  // Immediate second start — must be a no-op.
        observation.start()  // Triple-start for good measure.
        #expect(
            observation.refreshTaskSpawnCount == 1,
            "Idempotent start() must spawn exactly one refresh task."
        )
        observation.stop()
    }

    @Test("stop cancels the refresh task")
    func stopCancelsRefreshTask() async throws {
        let observation = PerformanceObservation(refreshInterval: .milliseconds(20))
        observation.start()
        try await Task.sleep(for: .milliseconds(80))
        let snapshot = observation.refreshCount
        observation.stop()
        try await Task.sleep(for: .milliseconds(80))
        #expect(observation.refreshCount == snapshot)
    }

    @Test("restart after stop resumes refresh ticks")
    func restartAfterStopResumes() async throws {
        let observation = PerformanceObservation(refreshInterval: .milliseconds(20))
        observation.start()
        try await Task.sleep(for: .milliseconds(40))
        observation.stop()
        let stopSnapshot = observation.refreshCount
        observation.start()
        try await Task.sleep(for: .milliseconds(80))
        observation.stop()
        #expect(observation.refreshCount > stopSnapshot)
    }
}
