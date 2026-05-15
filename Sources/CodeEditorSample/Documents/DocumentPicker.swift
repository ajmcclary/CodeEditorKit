#if canImport(AppKit)
import AppKit
import Foundation

/// macOS NSSavePanel / NSOpenPanel wrappers used by the sample's
/// Save-As, Save As…, and Open File… commands. Mirrors the existing
/// `WorkspacePicker` shape (synchronous modal, completion-handler
/// callback). iOS branch lives in the same file behind `#if !canImport(AppKit)`.
enum DocumentPicker {
    /// Presents `NSSavePanel` configured for a single-file save. Invokes
    /// `onChoose` with the picked URL on confirm; invokes nothing on cancel.
    @MainActor
    static func save(
        suggestedName: String,
        defaultDirectory: URL? = nil,
        onChoose: @escaping (URL) -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let defaultDirectory {
            panel.directoryURL = defaultDirectory
        }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }

    /// Presents `NSOpenPanel` configured to pick exactly one file (no
    /// directories, no multi-select). Allowed content types are not
    /// restricted — a code editor accepts any extension.
    @MainActor
    static func openFile(
        defaultDirectory: URL? = nil,
        onChoose: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let defaultDirectory {
            panel.directoryURL = defaultDirectory
        }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }
}
#endif
