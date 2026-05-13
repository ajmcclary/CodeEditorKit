import CodeEditorPlugin
import Foundation

/// Per-language sample snippets used by the sample app's editor pane.
/// Each entry is short, self-contained, and exercises the syntax features
/// the highlighter cares about (keywords, strings, numbers, comments,
/// punctuation).
///
/// Snippets ship as bundled resources in
/// `Sources/CodeEditorSample/Resources/SampleSnippets/<id>.txt` and are
/// loaded via `Bundle.module`. The plain-text snippet is generated in
/// code because it interpolates `Language.allCases.count`.
enum SampleCodeCatalog {
    /// Returns the canonical sample text for the given language.
    static func text(for language: Language) -> String {
        if language == .plainText {
            return plainTextSample
        }
        return loadBundled(slug(for: language)) ?? ""
    }

    // MARK: - Slug

    private static func slug(for language: Language) -> String {
        switch language {
        case .swift: return "swift"
        case .javascript: return "javascript"
        case .typescript: return "typescript"
        case .python: return "python"
        case .go: return "go"
        case .rust: return "rust"
        case .c: return "c"
        case .cpp: return "cpp"
        case .java: return "java"
        case .html: return "html"
        case .css: return "css"
        case .json: return "json"
        case .markdown: return "markdown"
        case .yaml: return "yaml"
        case .xml: return "xml"
        case .sql: return "sql"
        case .ruby: return "ruby"
        case .php: return "php"
        case .shell: return "shell"
        case .dockerfile: return "dockerfile"
        case .toml: return "toml"
        case .lua: return "lua"
        case .csharp: return "csharp"
        case .kotlin: return "kotlin"
        case .dart: return "dart"
        case .plainText: return "plainText"
        }
    }

    /// Reads `Resources/SampleSnippets/<slug>.txt` via `Bundle.module`.
    /// Returns `nil` if the resource is missing or unreadable.
    private static func loadBundled(_ slug: String) -> String? {
        guard let url = Bundle.module.url(forResource: slug, withExtension: "txt") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Plain-text (dynamic — interpolates the language count)

    private static let plainTextSample: String = """
    Plain text — no syntax to highlight.

    A small README-style document showing how the editor handles
    free-form text. Line wrapping, selection, and find-replace all
    work the same as in any other language.

      • Editor renders \(Language.allCases.count) languages with theme-aware highlighting.
      • Switch languages via the Language picker on the left.
      • Customize the theme via the Theme picker.
      • Tweak knobs in the Display / Layout / Behavior sections.

    — end of sample —
    """
}
