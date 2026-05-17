import CodeEditorLanguages
import Foundation

/// Built-in completion provider that emits language keywords pulled from
/// `LanguageDescriptor.keywords`, falling back to an embedded keyword
/// table for languages without a descriptor entry and finally to a
/// generic seven-keyword list for unknown languages.
///
/// Auto-registered per-editor by `CompletionManager.ensureBuiltInProvider(for:)`
/// whenever `CodeEditorView.language` changes. Replaces the equivalent
/// "basic completions" logic previously buried inside the now-deleted
/// `CompletionGenerationService`.
@MainActor
internal final class LanguageKeywordCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false

    private let language: Language
    private let keywords: [String]

    init(language: Language) {
        self.language = language
        self.id = "builtin.keywords.\(language.identifier)"
        self.supportedLanguages = [language]
        self.keywords = Self.resolveKeywords(for: language)
    }

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let items = SharedCompletionBuilder.createKeywordCompletions(
            from: keywords,
            filter: context.lineText,
            languageName: language.name
        )
        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: 0
        )
    }

    // MARK: - Keyword resolution

    private static func resolveKeywords(for language: Language) -> [String] {
        if let descriptor = LanguageDescriptor.descriptor(for: language),
           !descriptor.keywords.isEmpty {
            return descriptor.keywords
        }
        return fallbackKeywords(for: language)
    }

    /// Copied verbatim from the now-deleted `CompletionGenerationService.fallbackKeywords(for:)`
    /// so we don't lose behavior when that file goes. Languages with a
    /// `LanguageDescriptor` entry never reach here.
    private static func fallbackKeywords(for language: Language) -> [String] {
        switch language {
        case .swift:
            return [
                "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
                "import", "if", "else", "for", "while", "switch", "case", "default",
                "return", "break", "continue", "guard", "defer", "do", "try", "catch",
                "throws", "async", "await", "actor", "typealias", "associatedtype"
            ]

        case .python:
            return [
                "def", "class", "import", "from", "if", "elif", "else", "for", "while",
                "break", "continue", "return", "yield", "lambda", "with", "as", "try",
                "except", "finally", "raise", "assert", "pass", "del", "global", "nonlocal"
            ]

        case .javascript, .typescript:
            return [
                "function", "const", "let", "var", "class", "extends", "import", "export",
                "if", "else", "for", "while", "do", "switch", "case", "default", "break",
                "continue", "return", "throw", "try", "catch", "finally", "async", "await"
            ]

        default:
            return ["if", "else", "for", "while", "return", "break", "continue"]
        }
    }
}
