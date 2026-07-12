@testable import CodeEditorView
import Testing

@MainActor
private final class RecordingFeatureController: EditorFeatureController {
    private(set) var attachedViews: [CodeEditorView] = []
    private(set) var detachCount = 0

    func attach(to view: CodeEditorView) {
        attachedViews.append(view)
    }

    func detach() {
        detachCount += 1
    }
}

@MainActor
@Suite("EditorSession lifecycle")
struct EditorSessionTests {
    @Test("session attaches and detaches each feature once")
    func lifecycleIsIdempotent() {
        let feature = RecordingFeatureController()
        let session = EditorSession(features: [feature])
        let view = CodeEditorView(frame: .zero)

        session.attach(to: view)
        session.attach(to: view)
        session.detach()
        session.detach()

        #expect(feature.attachedViews.count == 1)
        #expect(feature.attachedViews.first === view)
        #expect(feature.detachCount == 1)
    }

    @Test("attaching to another view detaches before reattaching")
    func replacingViewBalancesLifecycle() {
        let feature = RecordingFeatureController()
        let session = EditorSession(features: [feature])
        let firstView = CodeEditorView(frame: .zero)
        let secondView = CodeEditorView(frame: .zero)

        session.attach(to: firstView)
        session.attach(to: secondView)

        #expect(feature.attachedViews.count == 2)
        #expect(feature.attachedViews.last === secondView)
        #expect(feature.detachCount == 1)
    }
}
