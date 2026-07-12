@testable import CodeEditorView
import Testing

@MainActor
private final class HighlightingCancellationSpy: HighlightingCancelling {
    private(set) var cancelCount = 0

    func cancelAll() {
        cancelCount += 1
    }
}

@MainActor
@Suite("HighlightingController lifecycle")
struct HighlightingControllerTests {
    @Test("detaching highlighting cancels work and clears attachment")
    func detachCancelsHighlighting() {
        let cancellation = HighlightingCancellationSpy()
        let controller = HighlightingController(cancellation: cancellation)

        controller.attach(to: CodeEditorView(frame: .zero))
        controller.detach()

        #expect(cancellation.cancelCount == 1)
        #expect(controller.isAttached == false)
    }

    @Test("repeated detach is idempotent")
    func detachIsIdempotent() {
        let cancellation = HighlightingCancellationSpy()
        let controller = HighlightingController(cancellation: cancellation)

        controller.attach(to: CodeEditorView(frame: .zero))
        controller.detach()
        controller.detach()

        #expect(cancellation.cancelCount == 1)
    }
}
