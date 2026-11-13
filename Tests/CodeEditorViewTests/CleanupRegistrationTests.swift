import CodeEditorCompletion
import CodeEditorDiagnostics
import CodeEditorInstrumentation
import CodeEditorLSP
import CodeEditorPlatform
import CodeEditorSyntaxHighlighting
import Foundation
import Testing

/// Records cleanup-handler registrations so tests can see what stays
/// registered after its owner is gone.
@MainActor
private final class RecordingMemoryMonitor: MemoryMonitoring {
    var memoryThresholdMB: Double = 1_000
    var memoryStats = MemoryStatistics()
    var availableMemoryMB: Double { 1_000 }
    private(set) var registered: Set<String> = []

    func getMemoryPressure() -> MemoryPressure { .normal }

    func registerCleanupHandler(
        identifier: String,
        priority _: CleanupPriority,
        handler _: @escaping @MainActor @Sendable () async -> CleanupResult
    ) {
        registered.insert(identifier)
    }

    func unregisterCleanupHandler(identifier: String) {
        registered.remove(identifier)
    }
}

@Suite("Cleanup registrations end with their owner")
struct CleanupRegistrationTests {
    @MainActor
    @Test("released owners unregister their memory-monitor handlers")
    func ownersUnregisterOnDeinit() async throws {
        let monitor = RecordingMemoryMonitor()
        do {
            let cache = LRUCache<String, Int>(capacity: 4, memoryMonitor: monitor)
            let manager = LSPManager(memoryMonitor: monitor)
            let highlighter = BackgroundSyntaxHighlighter(memoryMonitor: monitor)
            #expect(monitor.registered.count >= 3)
            _ = (cache, manager, highlighter)
        }
        // An isolated deinit may be enqueued on the main actor.
        for _ in 0..<50 where !monitor.registered.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(monitor.registered.isEmpty, "still registered: \(monitor.registered)")
    }

    @Test("PerformanceInsights can be released off the main thread")
    func performanceInsightsReleasedOffMain() async {
        let insights = await MainActor.run {
            PerformanceInsights(memoryMonitor: MemoryMonitor.mock(memoryUsage: 100), frameRateMonitor: FrameRateMonitor())
        }
        // The last reference goes away on a background thread.
        await Task.detached { _ = insights }.value
    }
}
