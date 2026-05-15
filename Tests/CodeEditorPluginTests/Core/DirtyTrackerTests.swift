@testable import CodeEditorPlugin
import Testing

@Suite("DirtyTracker")
struct DirtyTrackerTests {
    @Test("Returns false when no baseline is set")
    func returnsFalseWithoutBaseline() {
        let tracker = DirtyTracker()
        #expect(tracker.isDirty(currentText: "") == false)
        #expect(tracker.isDirty(currentText: "anything") == false)
    }

    @Test("Returns false when current matches baseline")
    func returnsFalseWhenMatchingBaseline() {
        var tracker = DirtyTracker()
        tracker.setBaseline("hello")
        #expect(tracker.isDirty(currentText: "hello") == false)
    }

    @Test("Returns true when current differs from baseline")
    func returnsTrueWhenDiffersFromBaseline() {
        var tracker = DirtyTracker()
        tracker.setBaseline("hello")
        #expect(tracker.isDirty(currentText: "world") == true)
    }

    @Test("Undo back to baseline returns to clean")
    func undoBackToBaselineGoesClean() {
        var tracker = DirtyTracker()
        tracker.setBaseline("a")
        #expect(tracker.isDirty(currentText: "ab") == true)
        #expect(tracker.isDirty(currentText: "a") == false)
    }

    @Test("markClean adopts current text as new baseline")
    func markCleanAdoptsCurrent() {
        var tracker = DirtyTracker()
        tracker.setBaseline("hello")
        tracker.markClean(currentText: "world")
        #expect(tracker.isDirty(currentText: "world") == false)
        #expect(tracker.isDirty(currentText: "hello") == true)
    }

    @Test("setBaseline overwrites a prior baseline")
    func setBaselineOverwrites() {
        var tracker = DirtyTracker()
        tracker.setBaseline("first")
        tracker.setBaseline("second")
        #expect(tracker.isDirty(currentText: "second") == false)
        #expect(tracker.isDirty(currentText: "first") == true)
    }
}
