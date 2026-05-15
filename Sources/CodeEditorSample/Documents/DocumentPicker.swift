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

#if !canImport(AppKit)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// State payload that drives the iOS Save-As sheet from `IOSRootView`.
/// `Identifiable` so it can power `.sheet(item:)`; nil dismisses.
struct SaveSheetState: Identifiable {
    let id = UUID()
    let temporaryURL: URL
    let suggestedName: String
}

/// SwiftUI wrapper around `UIDocumentPickerViewController(forExporting:asCopy:)`
/// for Save-As on iOS. The picker moves the temp file to the user's chosen
/// destination (asCopy: false) and returns the destination URL via delegate.
struct ExportDocumentSheet: UIViewControllerRepresentable {
    let temporaryURL: URL
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forExporting: [temporaryURL],
            asCopy: false
        )
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

/// SwiftUI wrapper around `UIDocumentPickerViewController(forOpeningContentTypes:)`
/// for Open File… on iOS. Accepts plain text, source code, and a `.data`
/// fallback so the user can pick any extension.
struct ImportDocumentSheet: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.plainText, .sourceCode, .data]
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
#endif
