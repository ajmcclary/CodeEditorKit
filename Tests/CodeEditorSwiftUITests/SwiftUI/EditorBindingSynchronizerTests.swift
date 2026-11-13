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

    @Test("a rewrite keeps most of the write; a reload does not")
    func rewriteIsANormalizationOfTheWrite() {
        #expect(EditorBindingSynchronizer.isRewrite("abcx", of: "abcx "))
        #expect(EditorBindingSynchronizer.isRewrite("let a = 1\n", of: "let a = 1"))
        // Converting every line ending changes the text throughout: treated
        // as the host's own change, so undo is discarded (safe, not kept).
        #expect(!EditorBindingSynchronizer.isRewrite("a\nb\n", of: "a\r\nb\r\n"))
        #expect(!EditorBindingSynchronizer.isRewrite("other document\n", of: "abcX"))
        #expect(!EditorBindingSynchronizer.isRewrite("x", of: ""))
        #expect(!EditorBindingSynchronizer.isRewrite("", of: "abc"))
    }
}
