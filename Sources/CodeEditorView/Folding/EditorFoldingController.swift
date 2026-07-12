/// Attachment boundary required by the editor-level folding lifecycle.
@MainActor
package protocol EditorFoldingLifecycle: AnyObject {
    /// Attaches folding behavior to an editor view.
    func attach(to view: CodeEditorView)

    /// Cancels folding work and releases its editor attachment.
    func detach()
}

extension CodeFoldingEngine: EditorFoldingLifecycle {}

/// Owns the attachment lifecycle of the editor's folding engine.
@MainActor
package final class EditorFoldingController: EditorFeatureController {
    private let lifecycle: any EditorFoldingLifecycle
    private weak var attachedView: CodeEditorView?
    package private(set) var isAttached = false

    package init(lifecycle: any EditorFoldingLifecycle) {
        self.lifecycle = lifecycle
    }

    package func attach(to view: CodeEditorView) {
        guard isAttached == false || attachedView !== view else { return }

        detach()
        attachedView = view
        isAttached = true
        lifecycle.attach(to: view)
    }

    package func detach() {
        guard isAttached else { return }

        lifecycle.detach()
        attachedView = nil
        isAttached = false
    }
}
