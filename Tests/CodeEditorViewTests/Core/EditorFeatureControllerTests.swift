@testable import CodeEditorView
import Testing

@MainActor
private final class RecordingEditorSession: EditorSessionLifecycle {
    private(set) var attachCount = 0
    private(set) var detachCount = 0

    func attach(to _: CodeEditorView) {
        attachCount += 1
    }

    func detach() {
        detachCount += 1
    }
}

@MainActor
private final class CompletionCancellationSpy: CompletionRequestCancelling {
    private(set) var cancelCount = 0

    func cancelCurrentRequest() {
        cancelCount += 1
    }
}

@MainActor
private final class FoldingLifecycleSpy: EditorFoldingLifecycle {
    private(set) var attachCount = 0
    private(set) var detachCount = 0

    func attach(to _: CodeEditorView) {
        attachCount += 1
    }

    func detach() {
        detachCount += 1
    }
}

@MainActor
@Suite("Editor feature controller ownership")
struct EditorFeatureControllerTests {
    @Test("view teardown delegates feature cleanup to its session")
    func viewTeardownUsesSession() {
        let session = RecordingEditorSession()
        let view = CodeEditorView(frame: .zero, session: session)

        #expect(session.attachCount == 1)
        view.removeFromSuperview()

        #expect(session.detachCount == 1)
    }

    @Test("completion controller cancels the active request on detach")
    func completionDetachCancelsRequest() {
        let cancellation = CompletionCancellationSpy()
        let controller = EditorCompletionController(cancellation: cancellation)

        controller.attach(to: CodeEditorView(frame: .zero))
        controller.detach()

        #expect(cancellation.cancelCount == 1)
        #expect(controller.isAttached == false)
    }

    @Test("folding controller detaches its engine")
    func foldingDetachReleasesEngine() {
        let lifecycle = FoldingLifecycleSpy()
        let controller = EditorFoldingController(lifecycle: lifecycle)

        controller.attach(to: CodeEditorView(frame: .zero))
        controller.detach()

        #expect(lifecycle.attachCount == 1)
        #expect(lifecycle.detachCount == 1)
    }
}
