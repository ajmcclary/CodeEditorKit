import AppKit
import Foundation

// MARK: - EditorConfiguration

struct EditorConfiguration {
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

    // Plugins
    var enableAnnotations: Bool = false
    var enableLineHighlight: Bool = true
    var enableCustomPlugin: Bool = false

    // Performance
    var useHardwareAcceleration: Bool = true
    var smoothScrolling: Bool = true
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
            EditorConfiguration(
                showLineNumbers: true,
                showInvisibleCharacters: false,
                highlightSelectedLine: true,
                wrapLines: false,
                isEditable: true,
                autoIndent: true,
                tabWidth: 4,
                insertSpacesForTabs: true,
                fontSize: 14,
                lineSpacing: 1.2,
                theme: .xcode,
                enableAnnotations: true,
                enableLineHighlight: true,
                enableCustomPlugin: true,
                useHardwareAcceleration: true,
                smoothScrolling: true
            )

        case .minimal:
            EditorConfiguration(
                showLineNumbers: false,
                showInvisibleCharacters: false,
                highlightSelectedLine: false,
                wrapLines: true,
                isEditable: true,
                autoIndent: false,
                tabWidth: 4,
                insertSpacesForTabs: true,
                fontSize: 14,
                lineSpacing: 1.5,
                theme: .minimal,
                enableAnnotations: false,
                enableLineHighlight: false,
                enableCustomPlugin: false,
                useHardwareAcceleration: true,
                smoothScrolling: true
            )

        case .readOnly:
            EditorConfiguration(
                showLineNumbers: true,
                showInvisibleCharacters: false,
                highlightSelectedLine: false,
                wrapLines: false,
                isEditable: false,
                autoIndent: false,
                tabWidth: 4,
                insertSpacesForTabs: true,
                fontSize: 13,
                lineSpacing: 1.2,
                theme: .vsDark,
                enableAnnotations: true,
                enableLineHighlight: false,
                enableCustomPlugin: false,
                useHardwareAcceleration: true,
                smoothScrolling: true
            )

        case .markdown:
            EditorConfiguration(
                showLineNumbers: false,
                showInvisibleCharacters: false,
                highlightSelectedLine: true,
                wrapLines: true,
                isEditable: true,
                autoIndent: true,
                tabWidth: 2,
                insertSpacesForTabs: true,
                fontSize: 16,
                lineSpacing: 1.6,
                theme: .github,
                enableAnnotations: false,
                enableLineHighlight: true,
                enableCustomPlugin: false,
                useHardwareAcceleration: true,
                smoothScrolling: true
            )

        case .presentation:
            EditorConfiguration(
                showLineNumbers: true,
                showInvisibleCharacters: false,
                highlightSelectedLine: true,
                wrapLines: false,
                isEditable: false,
                autoIndent: false,
                tabWidth: 4,
                insertSpacesForTabs: true,
                fontSize: 20,
                lineSpacing: 1.4,
                theme: .presentation,
                enableAnnotations: false,
                enableLineHighlight: true,
                enableCustomPlugin: false,
                useHardwareAcceleration: true,
                smoothScrolling: true
            )
        }
    }
}
