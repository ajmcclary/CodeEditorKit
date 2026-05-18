#if canImport(AppKit)
import CodeEditorCommon
import CodeEditorCompletion
@testable import CodeEditorPlugin
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

    @Test("ring caps at 200 entries, oldest dropped")
    func ringCapsAt200() {
        let coordinator = EventLogSampleCoordinator()
        for index in 0..<250 {
            coordinator.append(.text(summary: "e\(index)", timestamp: Date(timeIntervalSince1970: TimeInterval(index))))
        }
        #expect(coordinator.snapshot.ringCount == 200)
        // Newest-first: first visible entry should be the very last one we appended.
        #expect(coordinator.snapshot.entries.first?.summary == "e249")
        // Oldest 50 should have been dropped.
        #expect(coordinator.snapshot.entries.contains { $0.summary == "e49" } == false)
    }

    @Test("muted category hidden from snapshot but totals still update")
    func mutedHiddenButTotalsUpdate() {
        let coordinator = EventLogSampleCoordinator()
        for index in 0..<5 {
            coordinator.append(.text(summary: "t\(index)"))
        }
        coordinator.setMuted(.text, true)
        #expect(coordinator.snapshot.entries.isEmpty)
        #expect(coordinator.snapshot.totals[.text] == 5)
        #expect(coordinator.snapshot.ringCount == 5)
    }

    @Test("paused drops events; unpausing accepts new events")
    func pausedDrops() {
        let coordinator = EventLogSampleCoordinator()
        coordinator.setPaused(true)
        for index in 0..<10 {
            coordinator.append(.text(summary: "p\(index)"))
        }
        #expect(coordinator.snapshot.ringCount == 0)

        coordinator.setPaused(false)
        coordinator.append(.text(summary: "after-resume"))
        #expect(coordinator.snapshot.ringCount == 1)
        #expect(coordinator.snapshot.entries.first?.summary == "after-resume")
    }

    @Test("clear empties ring and totals")
    func clearEmptiesEverything() {
        let coordinator = EventLogSampleCoordinator()
        coordinator.append(.text(summary: "t"))
        coordinator.append(.selection(summary: "s"))
        coordinator.clear()
        #expect(coordinator.snapshot.entries.isEmpty)
        #expect(coordinator.snapshot.totals.isEmpty)
        #expect(coordinator.snapshot.ringCount == 0)
    }

    @Test("textDidChange from UnifiedEventSystem lands in the .text category")
    func attachReceivesTextDidChange() {
        let coordinator = EventLogSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)
        let eventSystem = UnifiedEventSystem()
        coordinator.attach(controller: controller, eventSystem: eventSystem)
        defer { coordinator.detach() }

        eventSystem.publish(.textDidChange("hello"))

        #expect(coordinator.snapshot.entries.count == 1)
        let entry = coordinator.snapshot.entries.first
        #expect(entry?.category == .text)
        #expect(entry?.summary == "textDidChange (len=5)")
    }

    @Test("translate(completionEvent:) renders succeeded outcomes")
    func translateCompletionSucceeded() {
        let event = CompletionEvent(
            providerID: "swift-universal",
            language: .swift,
            triggerCharacter: ".",
            prefix: "",
            durationMilliseconds: 4.31,
            outcome: .succeeded(itemCount: 12)
        )
        let entry = EventLogSampleCoordinator.translate(completionEvent: event)
        #expect(entry.category == .completion)
        #expect(entry.summary == "swift → 12 items · 4.3ms")
        #expect(entry.detail == "swift-universal · trigger=\".\"")
    }

    @Test("translate(completionEvent:) renders failed outcomes")
    func translateCompletionFailed() {
        let event = CompletionEvent(
            providerID: "swift-universal",
            language: .swift,
            triggerCharacter: nil,
            prefix: "",
            durationMilliseconds: 1.0,
            outcome: .failed(SendableError(message: "timed out", domain: "Completion"))
        )
        let entry = EventLogSampleCoordinator.translate(completionEvent: event)
        #expect(entry.category == .completion)
        #expect(entry.summary == "swift failed")
        #expect(entry.detail?.contains("timed out") == true)
    }

    @Test("selection and focus events land in their categories")
    func attachReceivesSelectionAndFocus() {
        let coordinator = EventLogSampleCoordinator()
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)
        let eventSystem = UnifiedEventSystem()
        coordinator.attach(controller: controller, eventSystem: eventSystem)
        defer { coordinator.detach() }

        eventSystem.publish(.textSelectionDidChange(NSRange(location: 3, length: 2)))
        eventSystem.publish(.didBecomeFirstResponder)

        // Two events; newest-first means focus is at .first.
        #expect(coordinator.snapshot.entries.count == 2)
        #expect(coordinator.snapshot.entries.first?.category == .focus)
        #expect(coordinator.snapshot.entries.first?.summary == "didBecomeFirstResponder")
        #expect(coordinator.snapshot.entries.last?.category == .selection)
        #expect(coordinator.snapshot.entries.last?.summary == "selection=[loc=3, len=2]")
    }
}
#endif
