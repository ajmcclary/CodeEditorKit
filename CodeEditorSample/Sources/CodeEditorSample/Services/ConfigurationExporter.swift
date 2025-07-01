import CodeEditorPlugin
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

// MARK: - ConfigurationExporter

// Associated object key holder
private final class AssociatedObjectKey: Sendable {
    static let coordinator = AssociatedObjectKey()
    private init() {}
}

enum ConfigurationExporter {

    // MARK: - Export Configuration

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @MainActor
    static func exportConfiguration(_ config: EditorConfiguration, from window: NSWindow?) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Configuration"
        savePanel.message = "Save your editor configuration for later use"
        savePanel.nameFieldStringValue = "editor-config.json"
        savePanel.allowedContentTypes = [.json]

        guard let window else {
            return
        }

        savePanel.beginSheetModal(for: window) { response in
            Task { @MainActor in
                if response == .OK, let url = savePanel.url {
                    do {
                        let data = try JSONEncoder().encode(config)
                        try data.write(to: url)

                        showAlert(
                            title: "Configuration Exported",
                            message: "Your configuration has been saved successfully.",
                            in: window
                        )
                    } catch {
                        showAlert(
                            title: "Export Failed",
                            message: "Could not save configuration: \(error.localizedDescription)",
                            style: .warning,
                            in: window
                        )
                    }
                }
            }
        }
    }

    // MARK: - Import Configuration

    @MainActor
    static func importConfiguration(
        from window: NSWindow?,
        completion: @escaping @Sendable (EditorConfiguration?) -> Void
    ) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Configuration"
        openPanel.message = "Choose a configuration file to import"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        guard let window else {
            completion(nil)
            return
        }

        openPanel.beginSheetModal(for: window) { response in
            Task { @MainActor in
                if response == .OK, let url = openPanel.url {
                    do {
                        let data = try Data(contentsOf: url)
                        let config = try JSONDecoder().decode(EditorConfiguration.self, from: data)

                        showAlert(
                            title: "Configuration Imported",
                            message: "Your configuration has been loaded successfully.",
                            in: window
                        )
                        completion(config)
                    } catch {
                        showAlert(
                            title: "Import Failed",
                            message: "Could not load configuration: \(error.localizedDescription)",
                            style: .warning,
                            in: window
                        )
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private static func showAlert(
        title: String,
        message: String,
        style: NSAlert.Style = .informational,
        in window: NSWindow
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window, completionHandler: nil)
    }

#elseif canImport(UIKit)

// MARK: - Document Picker Coordinator

private class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    private var completion: (([URL]) -> Void)?
    private weak var viewController: UIViewController?
    
    init(viewController: UIViewController?, completion: @escaping ([URL]) -> Void) {
        self.viewController = viewController
        self.completion = completion
        super.init()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion?(urls)
        cleanup()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?([])
        cleanup()
    }
    
    private func cleanup() {
        completion = nil
        // Remove coordinator reference from associated object
        if let vc = viewController {
            objc_setAssociatedObject(vc, Unmanaged.passUnretained(AssociatedObjectKey.coordinator).toOpaque(), nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

    @MainActor
    static func exportConfiguration(_ config: EditorConfiguration, from viewController: UIViewController?) {
        guard let viewController else { return }
        
        do {
            let data = try JSONEncoder().encode(config)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("editor-config.json")
            try data.write(to: tempURL)
            
            let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL])
            documentPicker.modalPresentationStyle = .pageSheet
            
            // Create coordinator to handle delegate callbacks
            let coordinator = DocumentPickerCoordinator(viewController: viewController) { [weak viewController] urls in
                Task { @MainActor in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    if !urls.isEmpty {
                        showAlert(
                            title: "Configuration Exported",
                            message: "Your configuration has been saved successfully.",
                            in: viewController
                        )
                    }
                }
            }
            
            // Store coordinator to keep it alive
            objc_setAssociatedObject(viewController, Unmanaged.passUnretained(AssociatedObjectKey.coordinator).toOpaque(), coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            documentPicker.delegate = coordinator
            
            viewController.present(documentPicker, animated: true)
        } catch {
            showAlert(
                title: "Export Failed",
                message: "Could not save configuration: \(error.localizedDescription)",
                style: .alert,
                in: viewController
            )
        }
    }
    
    // MARK: - Import Configuration
    
    @MainActor
    static func importConfiguration(
        from viewController: UIViewController?,
        completion: @escaping @Sendable (EditorConfiguration?) -> Void
    ) {
        guard let viewController else {
            completion(nil)
            return
        }
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .pageSheet
        
        // Create coordinator to handle delegate callbacks
        let coordinator = DocumentPickerCoordinator(viewController: viewController) { [weak viewController] urls in
            Task { @MainActor in
                guard let url = urls.first else {
                    completion(nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let config = try JSONDecoder().decode(EditorConfiguration.self, from: data)
                    
                    showAlert(
                        title: "Configuration Imported",
                        message: "Your configuration has been loaded successfully.",
                        in: viewController
                    )
                    completion(config)
                } catch {
                    showAlert(
                        title: "Import Failed",
                        message: "Could not load configuration: \(error.localizedDescription)",
                        style: .alert,
                        in: viewController
                    )
                    completion(nil)
                }
            }
        }
        
        // Store coordinator to keep it alive
        objc_setAssociatedObject(viewController, Unmanaged.passUnretained(AssociatedObjectKey.coordinator).toOpaque(), coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        documentPicker.delegate = coordinator
        
        viewController.present(documentPicker, animated: true)
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private static func showAlert(
        title: String,
        message: String,
        style: UIAlertController.Style = .alert,
        in viewController: UIViewController?
    ) {
        guard let viewController else { return }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
#endif
}

// Note: EditorConfiguration is already Codable in the plugin, so no additional extension needed

