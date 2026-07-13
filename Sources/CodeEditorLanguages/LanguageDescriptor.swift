import Foundation

// MARK: - Language Descriptor

/// Single source of truth for all language metadata.
///
/// Replaces the dual `LanguageStaticMetadata` / `LanguageMetadataRegistry` systems
/// with one `Sendable` struct per language. The `Language` enum's computed properties
/// (`name`, `fileExtensions`, `lspIdentifier`) delegate here so there is exactly one
/// place to update when adding a language.
package struct LanguageDescriptor: Sendable {
    // MARK: - Identity

    package let language: Language
    package let displayName: String
    package let fileExtensions: [String]
    package let lspIdentifier: String

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

    package let parserName: String?
    package let shebangIdentifiers: Set<String>
    package let scriptAliases: Set<String>

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

    // MARK: - Lookup

    package static func descriptor(for language: Language) -> Self? {
        all[language]
    }

    package static func keywords(for language: Language) -> [String] {
        all[language]?.keywords ?? []
    }
}
