#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation

// MARK: - EditorConfiguration

struct EditorConfiguration: Sendable {
    // Display settings
    var showLineNumbers: Bool = true
    var showInvisibleCharacters: Bool = false
    var highlightSelectedLine: Bool = true
    var wrapLines: Bool = false

    // Editor behavior
    var isEditable: Bool = true
    var autoIndent: Bool = true
    var tabWidth: Int = 4
    var insertSpacesForTabs: Bool = true

    // Appearance
    var fontSize: CGFloat = 14
    var lineSpacing: CGFloat = 1.2
    var theme: ColorTheme = .xcode
    #if canImport(AppKit)
    var textContainerInset: NSSize = NSSize(width: 5, height: 5)
    #else
    var textContainerInset: CGSize = CGSize(width: 5, height: 5)
    #endif
    var lineFragmentPadding: CGFloat = 5.0

    // Plugins
    var enableAnnotations: Bool = false
    var enableCustomPlugin: Bool = false

    // Performance
    var useHardwareAcceleration: Bool = true
    var smoothScrolling: Bool = true
    
    // Text Processing
    var isContinuousSpellCheckingEnabled: Bool = false
    var isGrammarCheckingEnabled: Bool = false
    var isAutomaticQuoteSubstitutionEnabled: Bool = false
    var isAutomaticDashSubstitutionEnabled: Bool = false
    var isAutomaticTextReplacementEnabled: Bool = false
    var isAutomaticSpellingCorrectionEnabled: Bool = false
    var isAutomaticTextCompletionEnabled: Bool = false
    var isIncrementalSearchingEnabled: Bool = true
    
    // Advanced Text Settings
    var allowsDocumentBackgroundColorChange: Bool = false
    var allowsImageEditing: Bool = false
    var allowsCharacterPickerTouchBarItem: Bool = false
    var isRichText: Bool = false
    var importsGraphics: Bool = false
    var usesInspectorBar: Bool = false
    var usesFindBar: Bool = true
    var allowsNonContiguousLayout: Bool = true
    var displaysLinkToolTips: Bool = true
    
    // Selection Settings
    #if canImport(AppKit)
    var insertionPointColor: PlatformColor = PlatformColor.controlAccentColor
    #else
    var insertionPointColor: UIColor = UIColor.systemBlue
    #endif
    // Note: selectedTextAttributes removed due to Sendable constraints
    // These will be computed when needed based on theme
}

// MARK: - ConfigurationPreset

enum ConfigurationPreset: String, CaseIterable {
    case fullFeatured = "full"
    case minimal
    case readOnly = "readonly"
    case markdown
    case presentation

    var displayName: String {
        switch self {
        case .fullFeatured: "Full Featured"
        case .minimal: "Minimal"
        case .readOnly: "Read Only"
        case .markdown: "Markdown"
        case .presentation: "Presentation"
        }
    }

    var description: String {
        switch self {
        case .fullFeatured: "All features enabled for code editing"
        case .minimal: "Basic text editing with minimal UI"
        case .readOnly: "Syntax highlighted code viewer"
        case .markdown: "Optimized for Markdown editing"
        case .presentation: "Large font, high contrast for demos"
        }
    }

    var configuration: EditorConfiguration {
        switch self {
        case .fullFeatured:
            var config = EditorConfiguration()
            config.showLineNumbers = true
            config.showInvisibleCharacters = false
            config.highlightSelectedLine = true
            config.wrapLines = false
            config.isEditable = true
            config.autoIndent = true
            config.tabWidth = 4
            config.insertSpacesForTabs = true
            config.fontSize = 14
            config.lineSpacing = 1.2
            config.theme = .xcode
            config.enableAnnotations = true
            config.enableCustomPlugin = true
            config.useHardwareAcceleration = true
            config.smoothScrolling = true
            // Use defaults for other properties
            return config

        case .minimal:
            var config = EditorConfiguration()
            config.showLineNumbers = false
            config.showInvisibleCharacters = false
            config.highlightSelectedLine = false
            config.wrapLines = true
            config.isEditable = true
            config.autoIndent = false
            config.tabWidth = 4
            config.insertSpacesForTabs = true
            config.fontSize = 14
            config.lineSpacing = 1.5
            config.theme = .minimal
            config.enableAnnotations = false
            config.enableCustomPlugin = false
            config.useHardwareAcceleration = true
            config.smoothScrolling = true
            return config

        case .readOnly:
            var config = EditorConfiguration()
            config.showLineNumbers = true
            config.showInvisibleCharacters = false
            config.highlightSelectedLine = false
            config.wrapLines = false
            config.isEditable = false
            config.autoIndent = false
            config.tabWidth = 4
            config.insertSpacesForTabs = true
            config.fontSize = 13
            config.lineSpacing = 1.2
            config.theme = .vsDark
            config.enableAnnotations = true
            config.enableCustomPlugin = false
            config.useHardwareAcceleration = true
            config.smoothScrolling = true
            return config

        case .markdown:
            var config = EditorConfiguration()
            config.showLineNumbers = false
            config.showInvisibleCharacters = false
            config.highlightSelectedLine = true
            config.wrapLines = true
            config.isEditable = true
            config.autoIndent = true
            config.tabWidth = 2
            config.insertSpacesForTabs = true
            config.fontSize = 16
            config.lineSpacing = 1.6
            config.theme = .github
            config.enableAnnotations = false
            config.enableCustomPlugin = false
            config.useHardwareAcceleration = true
            config.smoothScrolling = true
            // Enable spell checking for markdown
            config.isContinuousSpellCheckingEnabled = true
            return config

        case .presentation:
            var config = EditorConfiguration()
            config.showLineNumbers = true
            config.showInvisibleCharacters = false
            config.highlightSelectedLine = true
            config.wrapLines = false
            config.isEditable = false
            config.autoIndent = false
            config.tabWidth = 4
            config.insertSpacesForTabs = true
            config.fontSize = 20
            config.lineSpacing = 1.4
            config.theme = .presentation
            config.enableAnnotations = false
            config.enableCustomPlugin = false
            config.useHardwareAcceleration = true
            config.smoothScrolling = true
            return config
        }
    }
}
