#if canImport(AppKit)
import AppKit
import CodeEditorSwiftUI
import Foundation

/// macOS-only NSOpenPanel wrapper used by the workspace surface
/// (empty-state button, footer button) and the "Open Folder…"
/// command. Modal; returns synchronously via the completion handler.
enum WorkspacePicker {
    /// Presents an `NSOpenPanel` configured for a single directory choice.
    /// Invokes `onChoose` with the picked URL when the user confirms;
    /// invokes nothing on cancel.
    @MainActor
    static func choose(currentRoot: URL? = nil, onChoose: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Workspace"
        if let currentRoot {
            panel.directoryURL = currentRoot
        }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }
}
#endif
