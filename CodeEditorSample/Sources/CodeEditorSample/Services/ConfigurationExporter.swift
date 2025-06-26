#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import Foundation

// MARK: - ConfigurationExporter

enum ConfigurationExporter {
    // MARK: - Export Configuration

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
}

// Note: EditorConfiguration is already Codable in the plugin, so no additional extension needed
#endif
