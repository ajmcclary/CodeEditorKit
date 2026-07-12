@testable import CodeEditorSwiftUI
import Testing

@MainActor
@Suite("EditorBindingSynchronizer")
struct EditorBindingSynchronizerTests {
    @Test("editor text updates host once after debounce")
    func debouncedBindingUpdate() async {
        var writes: [String] = []
        let synchronizer = EditorBindingSynchronizer(
            debounce: .milliseconds(1),
            write: { writes.append($0) }
        )

        synchronizer.receiveEditorText("a")
        synchronizer.receiveEditorText("ab")
        try? await Task.sleep(for: .milliseconds(10))

        #expect(writes == ["ab"])
    }

    @Test("host echo does not schedule another write")
    func hostEchoIsIgnored() async {
        var writes: [String] = []
        let synchronizer = EditorBindingSynchronizer(
            debounce: .milliseconds(1),
            write: { writes.append($0) }
        )

        synchronizer.installHostText("host")
        synchronizer.receiveEditorText("host")
        try? await Task.sleep(for: .milliseconds(5))

        #expect(writes.isEmpty)
    }

    @Test("cancel prevents the pending host write")
    func cancellation() async {
        var writes: [String] = []
        let synchronizer = EditorBindingSynchronizer(
            debounce: .milliseconds(20),
            write: { writes.append($0) }
        )

        synchronizer.receiveEditorText("pending")
        synchronizer.cancel()
        try? await Task.sleep(for: .milliseconds(30))

        #expect(writes.isEmpty)
    }
}
