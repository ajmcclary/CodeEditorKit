import Foundation

// MARK: - Language Descriptor

/// Single source of truth for all language metadata.
///
/// Replaces the dual `LanguageStaticMetadata` / `LanguageMetadataRegistry` systems
/// with one `Sendable` struct per language. The `Language` enum's computed properties
/// (`name`, `fileExtensions`, `lspIdentifier`) delegate here so there is exactly one
/// place to update when adding a language.
internal struct LanguageDescriptor: Sendable {
    // MARK: - Identity

    let language: Language
    let displayName: String
    let fileExtensions: [String]
    let lspIdentifier: String

    // MARK: - Highlighting

    /// Whether this language is highlighted by the regex-based pipeline
    /// (`RegexSyntaxHighlighter` + `RegexRangeHighlightProvider`). Distinct
    /// from `parserName` (a tree-sitter grammar id that's still used by
    /// `LanguageDetectionService`). Languages like Swift (SwiftSyntax) and
    /// JSON (FastJSONTokenizer) have their own strategies and may still
    /// have `parserName` set; the regex pipeline ignores them via this
    /// flag.
    let usesRegexHighlighter: Bool
    let lineComment: String?
    let blockCommentStart: String?
    let blockCommentEnd: String?
    let identifierPattern: String
    let stringDelimiters: [Character]
    let highlightingRules: [DescriptorHighlightRule]

    /// When true, the regex highlighter compiles the keyword / type /
    /// function word-patterns with a leading `(?i)` flag so e.g. lowercase
    /// SQL still highlights against an uppercase keyword list. Defaults to
    /// `false` because most language descriptors carry exact-case keywords
    /// and case-folding would let an identifier like `IF` match `if` in
    /// languages where casing is significant.
    let caseInsensitiveKeywords: Bool

    // MARK: - Completion

    let keywords: [String]
    let types: [String]
    let functions: [String]
    let literals: [String]
    let triggerCharacters: [String]

    // MARK: - Extended (snippets / member completions / modules)

    let snippets: [SnippetTemplate]
    let memberCompletions: (any LanguageMemberCompletions)?
    let commonModules: [String]

    // MARK: - Parser / detection

    let parserName: String?
    let shebangIdentifiers: Set<String>
    let scriptAliases: Set<String>

    init(
        language: Language,
        displayName: String,
        fileExtensions: [String],
        lspIdentifier: String,
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
        parserName: String?,
        shebangIdentifiers: Set<String>,
        scriptAliases: Set<String>
    ) {
        self.language = language
        self.displayName = displayName
        self.fileExtensions = fileExtensions
        self.lspIdentifier = lspIdentifier
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
        self.parserName = parserName
        self.shebangIdentifiers = shebangIdentifiers
        self.scriptAliases = scriptAliases
    }

    // MARK: - All Descriptors

    static let allDescriptors: [Self] = [
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
        plainTextDescriptor
    ]

    /// Canonical descriptor for every `Language` case.
    static let all: [Language: Self] = [
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
        .plainText: plainTextDescriptor
    ]

    // MARK: - Lookup

    static func descriptor(for language: Language) -> Self? {
        all[language]
    }

    static func keywords(for language: Language) -> [String] {
        all[language]?.keywords ?? []
    }
}
