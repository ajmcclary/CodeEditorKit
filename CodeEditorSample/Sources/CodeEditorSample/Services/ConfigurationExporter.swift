#if canImport(AppKit)
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
        // Display settings
        case showLineNumbers
        case showInvisibleCharacters
        case highlightSelectedLine
        case wrapLines
        
        // Editor behavior
        case isEditable
        case autoIndent
        case tabWidth
        case insertSpacesForTabs
        
        // Appearance
        case fontSize
        case lineSpacing
        case themeName
        case textContainerInset
        case lineFragmentPadding
        
        // Plugins
        case enableAnnotations
        case enableCustomPlugin
        
        // Performance
        case useHardwareAcceleration
        case smoothScrolling
        
        // Text Processing
        case isContinuousSpellCheckingEnabled
        case isGrammarCheckingEnabled
        case isAutomaticQuoteSubstitutionEnabled
        case isAutomaticDashSubstitutionEnabled
        case isAutomaticTextReplacementEnabled
        case isAutomaticSpellingCorrectionEnabled
        case isAutomaticTextCompletionEnabled
        case isIncrementalSearchingEnabled
        
        // Advanced Text Settings
        case allowsDocumentBackgroundColorChange
        case allowsImageEditing
        case allowsCharacterPickerTouchBarItem
        case isRichText
        case importsGraphics
        case usesInspectorBar
        case usesFindBar
        case allowsNonContiguousLayout
        case displaysLinkToolTips
        
        // Selection Settings
        case insertionPointColor
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Display settings
        try container.encode(showLineNumbers, forKey: .showLineNumbers)
        try container.encode(showInvisibleCharacters, forKey: .showInvisibleCharacters)
        try container.encode(highlightSelectedLine, forKey: .highlightSelectedLine)
        try container.encode(wrapLines, forKey: .wrapLines)
        
        // Editor behavior
        try container.encode(isEditable, forKey: .isEditable)
        try container.encode(autoIndent, forKey: .autoIndent)
        try container.encode(tabWidth, forKey: .tabWidth)
        try container.encode(insertSpacesForTabs, forKey: .insertSpacesForTabs)
        
        // Appearance
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(theme.rawValue, forKey: .themeName)
        try container.encode([textContainerInset.width, textContainerInset.height], forKey: .textContainerInset)
        try container.encode(lineFragmentPadding, forKey: .lineFragmentPadding)
        
        // Plugins
        try container.encode(enableAnnotations, forKey: .enableAnnotations)
        try container.encode(enableCustomPlugin, forKey: .enableCustomPlugin)
        
        // Performance
        try container.encode(useHardwareAcceleration, forKey: .useHardwareAcceleration)
        try container.encode(smoothScrolling, forKey: .smoothScrolling)
        
        // Text Processing
        try container.encode(isContinuousSpellCheckingEnabled, forKey: .isContinuousSpellCheckingEnabled)
        try container.encode(isGrammarCheckingEnabled, forKey: .isGrammarCheckingEnabled)
        try container.encode(isAutomaticQuoteSubstitutionEnabled, forKey: .isAutomaticQuoteSubstitutionEnabled)
        try container.encode(isAutomaticDashSubstitutionEnabled, forKey: .isAutomaticDashSubstitutionEnabled)
        try container.encode(isAutomaticTextReplacementEnabled, forKey: .isAutomaticTextReplacementEnabled)
        try container.encode(isAutomaticSpellingCorrectionEnabled, forKey: .isAutomaticSpellingCorrectionEnabled)
        try container.encode(isAutomaticTextCompletionEnabled, forKey: .isAutomaticTextCompletionEnabled)
        try container.encode(isIncrementalSearchingEnabled, forKey: .isIncrementalSearchingEnabled)
        
        // Advanced Text Settings
        try container.encode(allowsDocumentBackgroundColorChange, forKey: .allowsDocumentBackgroundColorChange)
        try container.encode(allowsImageEditing, forKey: .allowsImageEditing)
        try container.encode(allowsCharacterPickerTouchBarItem, forKey: .allowsCharacterPickerTouchBarItem)
        try container.encode(isRichText, forKey: .isRichText)
        try container.encode(importsGraphics, forKey: .importsGraphics)
        try container.encode(usesInspectorBar, forKey: .usesInspectorBar)
        try container.encode(usesFindBar, forKey: .usesFindBar)
        try container.encode(allowsNonContiguousLayout, forKey: .allowsNonContiguousLayout)
        try container.encode(displaysLinkToolTips, forKey: .displaysLinkToolTips)
        
        // Note: We're not encoding insertionPointColor and selectedTextAttributes as they're complex types
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Display settings
        showLineNumbers = try container.decode(Bool.self, forKey: .showLineNumbers)
        showInvisibleCharacters = try container.decode(Bool.self, forKey: .showInvisibleCharacters)
        highlightSelectedLine = try container.decode(Bool.self, forKey: .highlightSelectedLine)
        wrapLines = try container.decode(Bool.self, forKey: .wrapLines)
        
        // Editor behavior
        isEditable = try container.decode(Bool.self, forKey: .isEditable)
        autoIndent = try container.decode(Bool.self, forKey: .autoIndent)
        tabWidth = try container.decode(Int.self, forKey: .tabWidth)
        insertSpacesForTabs = try container.decode(Bool.self, forKey: .insertSpacesForTabs)
        
        // Appearance
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        lineSpacing = try container.decode(CGFloat.self, forKey: .lineSpacing)
        let themeName = try container.decode(String.self, forKey: .themeName)
        theme = ColorTheme(rawValue: themeName) ?? .xcode
        
        if let insetArray = try? container.decode([CGFloat].self, forKey: .textContainerInset), insetArray.count >= 2 {
            textContainerInset = NSSize(width: insetArray[0], height: insetArray[1])
        } else {
            textContainerInset = NSSize(width: 5, height: 5)
        }
        
        lineFragmentPadding = (try? container.decode(CGFloat.self, forKey: .lineFragmentPadding)) ?? 5.0
        
        // Plugins
        enableAnnotations = try container.decode(Bool.self, forKey: .enableAnnotations)
        enableCustomPlugin = try container.decode(Bool.self, forKey: .enableCustomPlugin)
        
        // Performance
        useHardwareAcceleration = try container.decode(Bool.self, forKey: .useHardwareAcceleration)
        smoothScrolling = try container.decode(Bool.self, forKey: .smoothScrolling)
        
        // Text Processing - with defaults for backward compatibility
        isContinuousSpellCheckingEnabled = 
            (try? container.decode(Bool.self, forKey: .isContinuousSpellCheckingEnabled)) ?? false
        isGrammarCheckingEnabled = 
            (try? container.decode(Bool.self, forKey: .isGrammarCheckingEnabled)) ?? false
        isAutomaticQuoteSubstitutionEnabled = 
            (try? container.decode(Bool.self, forKey: .isAutomaticQuoteSubstitutionEnabled)) ?? false
        isAutomaticDashSubstitutionEnabled = 
            (try? container.decode(Bool.self, forKey: .isAutomaticDashSubstitutionEnabled)) ?? false
        isAutomaticTextReplacementEnabled = 
            (try? container.decode(Bool.self, forKey: .isAutomaticTextReplacementEnabled)) ?? false
        isAutomaticSpellingCorrectionEnabled = 
            (try? container.decode(Bool.self, forKey: .isAutomaticSpellingCorrectionEnabled)) ?? false
        isAutomaticTextCompletionEnabled = 
            (try? container.decode(Bool.self, forKey: .isAutomaticTextCompletionEnabled)) ?? false
        isIncrementalSearchingEnabled = 
            (try? container.decode(Bool.self, forKey: .isIncrementalSearchingEnabled)) ?? true
        
        // Advanced Text Settings - with defaults for backward compatibility
        allowsDocumentBackgroundColorChange = 
            (try? container.decode(Bool.self, forKey: .allowsDocumentBackgroundColorChange)) ?? false
        allowsImageEditing = 
            (try? container.decode(Bool.self, forKey: .allowsImageEditing)) ?? false
        allowsCharacterPickerTouchBarItem = 
            (try? container.decode(Bool.self, forKey: .allowsCharacterPickerTouchBarItem)) ?? false
        isRichText = 
            (try? container.decode(Bool.self, forKey: .isRichText)) ?? false
        importsGraphics = 
            (try? container.decode(Bool.self, forKey: .importsGraphics)) ?? false
        usesInspectorBar = 
            (try? container.decode(Bool.self, forKey: .usesInspectorBar)) ?? false
        usesFindBar = 
            (try? container.decode(Bool.self, forKey: .usesFindBar)) ?? true
        allowsNonContiguousLayout = 
            (try? container.decode(Bool.self, forKey: .allowsNonContiguousLayout)) ?? true
        displaysLinkToolTips = 
            (try? container.decode(Bool.self, forKey: .displaysLinkToolTips)) ?? true
        
        // Selection Settings - use defaults
        insertionPointColor = PlatformColor.controlAccentColor
    }
}
#endif
