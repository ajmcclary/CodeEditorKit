import AppKit
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

// MARK: - EditorConfiguration + Codable

extension EditorConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case showLineNumbers
        case showInvisibleCharacters
        case highlightSelectedLine
        case wrapLines
        case isEditable
        case autoIndent
        case tabWidth
        case insertSpacesForTabs
        case fontSize
        case lineSpacing
        case themeName
        case enableAnnotations
        case enableLineHighlight
        case enableCustomPlugin
        case useHardwareAcceleration
        case smoothScrolling
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(showLineNumbers, forKey: .showLineNumbers)
        try container.encode(showInvisibleCharacters, forKey: .showInvisibleCharacters)
        try container.encode(highlightSelectedLine, forKey: .highlightSelectedLine)
        try container.encode(wrapLines, forKey: .wrapLines)
        try container.encode(isEditable, forKey: .isEditable)
        try container.encode(autoIndent, forKey: .autoIndent)
        try container.encode(tabWidth, forKey: .tabWidth)
        try container.encode(insertSpacesForTabs, forKey: .insertSpacesForTabs)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(theme.rawValue, forKey: .themeName)
        try container.encode(enableAnnotations, forKey: .enableAnnotations)
        try container.encode(enableLineHighlight, forKey: .enableLineHighlight)
        try container.encode(enableCustomPlugin, forKey: .enableCustomPlugin)
        try container.encode(useHardwareAcceleration, forKey: .useHardwareAcceleration)
        try container.encode(smoothScrolling, forKey: .smoothScrolling)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        showLineNumbers = try container.decode(Bool.self, forKey: .showLineNumbers)
        showInvisibleCharacters = try container.decode(Bool.self, forKey: .showInvisibleCharacters)
        highlightSelectedLine = try container.decode(Bool.self, forKey: .highlightSelectedLine)
        wrapLines = try container.decode(Bool.self, forKey: .wrapLines)
        isEditable = try container.decode(Bool.self, forKey: .isEditable)
        autoIndent = try container.decode(Bool.self, forKey: .autoIndent)
        tabWidth = try container.decode(Int.self, forKey: .tabWidth)
        insertSpacesForTabs = try container.decode(Bool.self, forKey: .insertSpacesForTabs)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        lineSpacing = try container.decode(CGFloat.self, forKey: .lineSpacing)

        let themeName = try container.decode(String.self, forKey: .themeName)
        theme = ColorTheme(rawValue: themeName) ?? .xcode

        enableAnnotations = try container.decode(Bool.self, forKey: .enableAnnotations)
        enableLineHighlight = try container.decode(Bool.self, forKey: .enableLineHighlight)
        enableCustomPlugin = try container.decode(Bool.self, forKey: .enableCustomPlugin)
        useHardwareAcceleration = try container.decode(Bool.self, forKey: .useHardwareAcceleration)
        smoothScrolling = try container.decode(Bool.self, forKey: .smoothScrolling)
    }
}
