#if canImport(AppKit)
import AppKit
@testable import CodeEditorSample
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EventLogPanelSnapshotTests: XCTestCase {
    func testDefault() {
        let entries = sampleEntries()
        let view = panel(entries: entries, totals: fullTotals(), muted: [], paused: false)
        assertSnapshot(of: host(view), as: .image, named: "default")
    }

    func testWithTextMuted() {
        let entries = sampleEntries().filter { $0.category != .text }
        let view = panel(entries: entries, totals: fullTotals(), muted: [.text], paused: false)
        assertSnapshot(of: host(view), as: .image, named: "with-text-muted")
    }

    func testPaused() {
        let entries = sampleEntries()
        let view = panel(entries: entries, totals: fullTotals(), muted: [], paused: true)
        assertSnapshot(of: host(view), as: .image, named: "paused")
    }

    func testEmpty() {
        let view = panel(entries: [], totals: [:], muted: [], paused: false)
        assertSnapshot(of: host(view), as: .image, named: "empty")
    }

    func testWithFailedCompletion() {
        let entries = sampleEntries(failedCompletion: true)
        let view = panel(entries: entries, totals: fullTotals(), muted: [], paused: false)
        assertSnapshot(of: host(view), as: .image, named: "with-failed-completion")
    }

    // MARK: - Helpers

    private func panel(
        entries: [EventLogSampleCoordinator.LoggedEvent],
        totals: [EventLogSampleCoordinator.EventCategory: Int],
        muted: Set<EventLogSampleCoordinator.EventCategory>,
        paused: Bool
    ) -> EventLogPanel {
        EventLogPanel(
            entries: entries,
            totals: totals,
            mutedCategories: muted,
            paused: paused,
            onToggleCategory: { _ in },
            onTogglePause: { },
            onClear: { }
        )
    }

    private func host<V: View>(_ view: V) -> NSView {
        let hosting = NSHostingView(
            rootView: view
                .frame(width: 480, height: 320)
                .background(Color.white)
                .foregroundColor(.black)
                .environment(\.colorScheme, .light)
        )
        hosting.frame = CGRect(x: 0, y: 0, width: 480, height: 320)
        return hosting
    }

    private func fullTotals() -> [EventLogSampleCoordinator.EventCategory: Int] {
        [.text: 1, .selection: 1, .focus: 1, .completion: 1]
    }

    private func sampleEntries(failedCompletion: Bool = false) -> [EventLogSampleCoordinator.LoggedEvent] {
        let base = Date(timeIntervalSince1970: 0)
        let completion: EventLogSampleCoordinator.LoggedEvent
        if failedCompletion {
            completion = EventLogSampleCoordinator.LoggedEvent(
                category: .completion,
                summary: "swift failed",
                detail: "timed out",
                timestamp: base.addingTimeInterval(3)
            )
        } else {
            completion = .completion(
                summary: "swift → 12 items · 4.3ms",
                detail: "swift-universal · trigger=\".\"",
                timestamp: base.addingTimeInterval(3)
            )
        }
        // newest-first
        return [
            completion,
            .focus(summary: "didBecomeFirstResponder", timestamp: base.addingTimeInterval(2)),
            .selection(summary: "selection=[loc=12, len=0]", timestamp: base.addingTimeInterval(1)),
            .text(summary: "textDidChange (len=42)", timestamp: base)
        ]
    }
}
#endif
