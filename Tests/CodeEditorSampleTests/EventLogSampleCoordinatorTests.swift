#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("EventLogSampleCoordinator")
@MainActor
struct EventLogSampleCoordinatorTests {
    @Test("initial snapshot is empty")
    func emptyAtBirth() {
        let coordinator = EventLogSampleCoordinator()
        #expect(coordinator.snapshot.entries.isEmpty)
        #expect(coordinator.snapshot.ringCount == 0)
        #expect(coordinator.mutedCategories.isEmpty)
        #expect(coordinator.paused == false)
    }

    @Test("appending a LoggedEvent shows up in the snapshot newest-first")
    func appendsNewestFirst() {
        let coordinator = EventLogSampleCoordinator()
        coordinator.append(.text(summary: "first", timestamp: Date(timeIntervalSince1970: 1)))
        coordinator.append(.text(summary: "second", timestamp: Date(timeIntervalSince1970: 2)))

        #expect(coordinator.snapshot.entries.count == 2)
        #expect(coordinator.snapshot.entries.first?.summary == "second")
        #expect(coordinator.snapshot.entries.last?.summary == "first")
        #expect(coordinator.snapshot.ringCount == 2)
        #expect(coordinator.snapshot.totals[.text] == 2)
    }
}
#endif
