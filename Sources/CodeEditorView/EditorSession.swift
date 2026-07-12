/// Coordinates the ordered lifecycle of feature-specific editor controllers.
@MainActor
package final class EditorSession: EditorSessionLifecycle {
    private let features: [any EditorFeatureController]
    private weak var attachedView: CodeEditorView?
    private var isAttached = false

    package init(features: [any EditorFeatureController]) {
        self.features = features
    }

    package func attach(to view: CodeEditorView) {
        guard isAttached == false || attachedView !== view else { return }

        detach()
        attachedView = view
        isAttached = true
        features.forEach { $0.attach(to: view) }
    }

    package func detach() {
        guard isAttached else { return }

        features.reversed().forEach { $0.detach() }
        isAttached = false
        attachedView = nil
    }
}
