import Foundation
import LanguageKit

// MARK: - Language Descriptor

/// Single source of truth for all *editor-specific* language behavior, with
/// language *identity* metadata sourced from `LanguageKit.LanguageCatalog`.
///
/// Replaces the dual `LanguageStaticMetadata` / `LanguageMetadataRegistry` systems
/// with one `Sendable` struct per language. The `Language` enum's computed properties
/// (`name`, `fileExtensions`, `lspIdentifier`) delegate here so there is exactly one
/// place to update when adding a language.
///
/// ## Identity vs. behavior (LanguageKit adoption, workspace-reorg Task 7)
///
/// The scalar identity fields `displayName`, `lspIdentifier`, and `parserName`
/// (the tree-sitter grammar identifier) are no longer stored here; they are
/// computed by looking the `language` up in `LanguageKit.LanguageCatalog` (an
/// identity mapping, because `LanguageID.rawValue == Language.rawValue` for
/// every CEP language). Deleting those 92 literal duplications was a true no-op
/// for the pinned characterization behavior, save one documented divergence:
///
/// - **swift `parserName`**: `LanguageCatalog` records grammar id `"swift"`, but
///   CEP highlights Swift via SwiftSyntax and pins `parserName == nil`. Swift is
///   listed in ``grammarIdentifierSuppressed`` so the local behavior is
///   preserved. See `LanguageCatalogCharacterizationTests`.
///
/// Fields that remain stored/local because they encode information LanguageKit
/// cannot round-trip or deliberately does not reproduce:
///
/// - **`fileExtensions`**: `LanguageCatalog` stores extensions as an *unordered*
///   `Set`, but CEP's public `Language.fileExtensions` (and its characterization)
///   are order-sensitive arrays, and CEP folds the `tsx` extension into
///   `typescript` (`["ts", "tsx"]`) whereas LanguageKit models `tsx` as its own
///   language. Ordering + that mapping are CEP-owned, so the arrays stay here.
/// - **`shebangIdentifiers` / `scriptAliases`**: richer than LanguageKit's
///   intentionally-minimal `interpreters`, and they drive live shebang detection.
/// - **Special filenames** (Dockerfile / Makefile / Rakefile ...): handled by
///   `LanguageDetectionService`, whose `dockerfile.`-prefix quirk LanguageKit
///   deliberately dropped; kept local to preserve pinned behavior.
package struct LanguageDescriptor: Sendable {
    // MARK: - Identity (sourced from LanguageKit)

    package let language: Language
    package let fileExtensions: [String]

    /// Human-readable display name, sourced from `LanguageKit.LanguageCatalog`.
    package var displayName: String {
        Self.catalogMetadata(for: language)?.displayName ?? language.rawValue.capitalized
    }

    /// LSP language identifier, sourced from `LanguageKit.LanguageCatalog`.
    package var lspIdentifier: String {
        Self.catalogMetadata(for: language)?.lspIdentifier ?? language.rawValue
    }

    // MARK: - Highlighting

    /// Whether this language is highlighted by the regex-based pipeline
    /// (`RegexSyntaxHighlighter` + `RegexRangeHighlightProvider`). Distinct
    /// from `parserName` (a tree-sitter grammar id that's still used by
    /// `LanguageDetectionService`). Languages like Swift (SwiftSyntax) and
    /// JSON (FastJSONTokenizer) have their own strategies and may still
    /// have `parserName` set; the regex pipeline ignores them via this
    /// flag.
    package let usesRegexHighlighter: Bool
    package let lineComment: String?
    package let blockCommentStart: String?
    package let blockCommentEnd: String?
    package let identifierPattern: String
    package let stringDelimiters: [Character]
    package let highlightingRules: [DescriptorHighlightRule]

    /// When true, the regex highlighter compiles the keyword / type /
    /// function word-patterns with a leading `(?i)` flag so e.g. lowercase
    /// SQL still highlights against an uppercase keyword list. Defaults to
    /// `false` because most language descriptors carry exact-case keywords
    /// and case-folding would let an identifier like `IF` match `if` in
    /// languages where casing is significant.
    package let caseInsensitiveKeywords: Bool

    // MARK: - Completion

    package let keywords: [String]
    package let types: [String]
    package let functions: [String]
    package let literals: [String]
    package let triggerCharacters: [String]

    // MARK: - Extended (snippets / member completions / modules)

    package let snippets: [SnippetTemplate]
    package let memberCompletions: (any LanguageMemberCompletions)?
    package let commonModules: [String]

    // MARK: - Parser / detection

    /// Tree-sitter grammar identifier, sourced from
    /// `LanguageKit.LanguageCatalog`'s `treeSitterGrammarIdentifier`, except for
    /// languages in ``grammarIdentifierSuppressed`` (currently only Swift, which
    /// is highlighted via SwiftSyntax and pins `nil`).
    package var parserName: String? {
        if Self.grammarIdentifierSuppressed.contains(language) { return nil }
        return Self.catalogMetadata(for: language)?.treeSitterGrammarIdentifier
    }

    package let shebangIdentifiers: Set<String>
    package let scriptAliases: Set<String>

    init(
        language: Language,
        fileExtensions: [String],
        usesRegexHighlighter: Bool,
        lineComment: String?,
        blockCommentStart: String?,
        blockCommentEnd: String?,
        identifierPattern: String,
        stringDelimiters: [Character],
        highlightingRules: [DescriptorHighlightRule] = [], // swiftlint:disable:this function_default_parameter_at_end
        caseInsensitiveKeywords: Bool = false, // swiftlint:disable:this function_default_parameter_at_end
        keywords: [String],
        types: [String],
        functions: [String],
        literals: [String],
        triggerCharacters: [String],
        snippets: [SnippetTemplate],
        memberCompletions: (any LanguageMemberCompletions)?,
        commonModules: [String],
        shebangIdentifiers: Set<String>,
        scriptAliases: Set<String>
    ) {
        self.language = language
        self.fileExtensions = fileExtensions
        self.usesRegexHighlighter = usesRegexHighlighter
        self.lineComment = lineComment
        self.blockCommentStart = blockCommentStart
        self.blockCommentEnd = blockCommentEnd
        self.identifierPattern = identifierPattern
        self.stringDelimiters = stringDelimiters
        self.highlightingRules = highlightingRules
        self.caseInsensitiveKeywords = caseInsensitiveKeywords
        self.keywords = keywords
        self.types = types
        self.functions = functions
        self.literals = literals
        self.triggerCharacters = triggerCharacters
        self.snippets = snippets
        self.memberCompletions = memberCompletions
        self.commonModules = commonModules
        self.shebangIdentifiers = shebangIdentifiers
        self.scriptAliases = scriptAliases
    }

    // MARK: - All Descriptors

    package static let allDescriptors: [Self] = [
        swiftDescriptor,
        javascriptDescriptor,
        typescriptDescriptor,
        pythonDescriptor,
        goDescriptor,
        rustDescriptor,
        cDescriptor,
        cppDescriptor,
        javaDescriptor,
        htmlDescriptor,
        cssDescriptor,
        jsonDescriptor,
        markdownDescriptor,
        yamlDescriptor,
        xmlDescriptor,
        sqlDescriptor,
        rubyDescriptor,
        phpDescriptor,
        shellDescriptor,
        dockerfileDescriptor,
        tomlDescriptor,
        luaDescriptor,
        csharpDescriptor,
        kotlinDescriptor,
        dartDescriptor,
        mermaidDescriptor,
        d2Descriptor,
        dotDescriptor,
        structurizrDescriptor,
        plantumlDescriptor,
        plainTextDescriptor
    ]

    /// Canonical descriptor for every `Language` case.
    package static let all: [Language: Self] = [
        .swift: swiftDescriptor,
        .javascript: javascriptDescriptor,
        .typescript: typescriptDescriptor,
        .python: pythonDescriptor,
        .go: goDescriptor,
        .rust: rustDescriptor,
        .c: cDescriptor,
        .cpp: cppDescriptor,
        .java: javaDescriptor,
        .html: htmlDescriptor,
        .css: cssDescriptor,
        .json: jsonDescriptor,
        .markdown: markdownDescriptor,
        .yaml: yamlDescriptor,
        .xml: xmlDescriptor,
        .sql: sqlDescriptor,
        .ruby: rubyDescriptor,
        .php: phpDescriptor,
        .shell: shellDescriptor,
        .dockerfile: dockerfileDescriptor,
        .toml: tomlDescriptor,
        .lua: luaDescriptor,
        .csharp: csharpDescriptor,
        .kotlin: kotlinDescriptor,
        .dart: dartDescriptor,
        .mermaid: mermaidDescriptor,
        .d2: d2Descriptor,
        .dot: dotDescriptor,
        .structurizr: structurizrDescriptor,
        .plantuml: plantumlDescriptor,
        .plainText: plainTextDescriptor
    ]

    // MARK: - LanguageKit adapter

    /// CEP-side divergences from `LanguageKit.LanguageCatalog`: languages whose
    /// tree-sitter grammar identifier the catalog records but CEP intentionally
    /// suppresses because the editor highlights them by another strategy.
    ///
    /// - `swift`: highlighted via SwiftSyntax, so `parserName` stays `nil` even
    ///   though `LanguageCatalog` lists grammar `"swift"`. Pinned by
    ///   `LanguageCatalogCharacterizationTests` (swift `parserName == nil`).
    private static let grammarIdentifierSuppressed: Set<Language> = [.swift]

    /// Looks a CEP `Language` up in `LanguageKit.LanguageCatalog`. The mapping is
    /// the identity on raw values: every CEP `Language.rawValue` is a registered
    /// `LanguageID.rawValue`.
    private static func catalogMetadata(for language: Language) -> LanguageMetadata? {
        LanguageCatalog.metadata(for: LanguageID(rawValue: language.rawValue))
    }

    // MARK: - Lookup

    package static func descriptor(for language: Language) -> Self? {
        all[language]
    }

    package static func keywords(for language: Language) -> [String] {
        all[language]?.keywords ?? []
    }
}
