/// Owns one editor feature's attachment and teardown lifecycle.
@MainActor
package protocol EditorFeatureController: AnyObject {
    /// Attaches the feature to an editor view.
    func attach(to view: CodeEditorView)

    /// Releases work and state associated with the attached view.
    func detach()
}

/// Lifecycle surface used by an editor view to manage its feature session.
@MainActor
package protocol EditorSessionLifecycle: AnyObject {
    /// Attaches all session features to an editor view.
    func attach(to view: CodeEditorView)

    /// Detaches all session features.
    func detach()
}
