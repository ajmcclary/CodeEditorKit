import CodeEditorPlugin
import Foundation

// MARK: - EditorConfiguration Extensions

// Use the plugin's EditorConfiguration as the main type
// EditorConfiguration is directly available from the CodeEditorPlugin module

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
            return EditorConfigurationBuilder()
                .showLineNumbers(true)
                .showInvisibleCharacters(false)
                .highlightSelectedLine(true)
                .wrapLines(false)
                .editable(true)
                .autoIndent(true)
                .tabWidth(4)
                .insertSpacesForTabs(true)
                .fontSize(14)
                .lineSpacing(1.2)
                .annotations(true)
                .hardwareAcceleration(true)
                .smoothScrolling(true)
                .codeCompletion(true)
                .syntaxHighlighting(true)
                .build()

        case .minimal:
            return EditorConfigurationBuilder(base: .minimal)
                .fontSize(14)
                .lineSpacing(1.5)
                .wrapLines(true)
                .build()

        case .readOnly:
            return EditorConfigurationBuilder(base: .readOnly)
                .showLineNumbers(true)
                .fontSize(13)
                .lineSpacing(1.2)
                .annotations(true)
                .build()

        case .markdown:
            return EditorConfigurationBuilder(base: .markdown)
                .fontSize(16)
                .lineSpacing(1.6)
                .tabWidth(2)
                .build()

        case .presentation:
            return EditorConfigurationBuilder(base: .presentation)
                .fontSize(20)
                .lineSpacing(1.4)
                .build()
        }
    }
}
