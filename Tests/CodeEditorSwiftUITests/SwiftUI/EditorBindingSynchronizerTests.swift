@testable import CodeEditorSwiftUI
import Testing

@MainActor
@Suite("EditorBindingSynchronizer")
struct EditorBindingSynchronizerTests {
    @Test("editor text updates host once after debounce")
    func debouncedBindingUpdate() async {
        var writes: [String] = []
        let synchronizer = EditorBindingSynchronizer(
            debounce: .milliseconds(1)
        ) { writes.append($0) }

        synchronizer.receiveEditorText("a")
        synchronizer.receiveEditorText("ab")
        // Await the debounced write itself rather than polling against a
        // wall-clock deadline: under parallel CI load the main actor can be
        // busy past any fixed deadline, which made this test fail with [].
        await synchronizer.waitForPendingWrite()

        #expect(writes == ["ab"])
    }

    @Test("host echo does not schedule another write")
    func hostEchoIsIgnored() async {
        var writes: [String] = []
        let synchronizer = EditorBindingSynchronizer(
            debounce: .milliseconds(1)
        ) { writes.append($0) }

        synchronizer.installHostText("host")
        synchronizer.receiveEditorText("host")
        try? await Task.sleep(for: .milliseconds(5))

        #expect(writes.isEmpty)
    }

    @Test("cancel prevents the pending host write")
    func cancellation() async {
        var writes: [String] = []
        let synchronizer = EditorBindingSynchronizer(
            debounce: .milliseconds(20)
        ) { writes.append($0) }

        synchronizer.receiveEditorText("pending")
        synchronizer.cancel()
        try? await Task.sleep(for: .milliseconds(30))

        #expect(writes.isEmpty)
    }
}
