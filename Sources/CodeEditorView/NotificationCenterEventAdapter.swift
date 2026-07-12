import Foundation

/// Projects canonical editor events onto legacy `NotificationCenter` APIs.
@MainActor
final class NotificationCenterEventAdapter {
    private var observation: EditorEventObservation?
    private weak var bus: EditorEventBus?

    init(
        bus: EditorEventBus,
        editor: CodeEditorView,
        center: NotificationCenter = .default
    ) {
        self.bus = bus
        observation = bus.observe { [weak editor] value in
            guard let editor else { return }
            if case .textSelectionDidChange = value.event {
                center.post(
                    name: CodeEditorView.codeEditorViewDidChangeSelectionNotification,
                    object: editor
                )
            }
        }
    }

    func isAttached(to bus: EditorEventBus) -> Bool {
        self.bus === bus
    }
}
