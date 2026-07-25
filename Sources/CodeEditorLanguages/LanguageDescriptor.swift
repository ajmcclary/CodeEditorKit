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
/// The identity + detection metadata (`displayName`, `lspIdentifier`,
/// `parserName`, `fileExtensions`, plus the shebang interpreter aliases and
/// special-filename rules) is no longer mirrored here. It is sourced from
/// ``registry`` — a CEP-specific ``LanguageKit/LanguageRegistry`` derived from
/// ``LanguageKit/LanguageRegistry/standard`` with CodeEditorKit's two
/// deliberate divergences layered on as registry data:
///
/// - **tsx → typescript**: CEP folds the `tsx` extension into TypeScript
///   (ordered `["ts", "tsx"]`) and does not model `tsx` as a distinct language,
///   whereas LanguageKit's standard catalog makes `tsx` first-class. The CEP
///   registry restricts the standard catalog to CEP's 31 languages (dropping
///   `tsx`) and merges a TypeScript override reclaiming the `tsx` extension.
/// - **swift grammar suppression**: `LanguageCatalog` records grammar id
///   `"swift"`, but CEP highlights Swift via SwiftSyntax and pins
///   `parserName == nil`. The CEP registry merges a Swift override whose
///   `treeSitterGrammarIdentifier` is `nil`.
///
/// The registry also carries CEP's richer shebang interpreter aliases (a
/// superset of LanguageKit's intentionally-minimal `interpreters`) and the
/// special-filename rules that drive `LanguageDetectionService`. The one thing
/// that stays a local heuristic is the `dockerfile.`-prefix quirk that
/// LanguageKit deliberately did not reproduce (see `LanguageDetectionService`).
///
/// Ordering is preserved by ``LanguageKit/LanguageMetadata/fileExtensions``
/// (an ordered array). All of this is pinned by
/// `LanguageCatalogCharacterizationTests` and `CEPLanguageRegistryTests`.
package struct LanguageDescriptor: Sendable {
    // MARK: - Identity (sourced from LanguageKit)

    package let language: Language

    /// File extensions for this language, in priority order (first = primary),
    /// sourced from ``registry``.
    package var fileExtensions: [String] {
        Self.metadata(for: language)?.fileExtensions ?? []
    }

    /// Human-readable display name, sourced from ``registry``.
    package var displayName: String {
        Self.metadata(for: language)?.displayName ?? language.rawValue.capitalized
    }

    /// LSP language identifier, sourced from ``registry``.
    package var lspIdentifier: String {
        Self.metadata(for: language)?.lspIdentifier ?? language.rawValue
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

    /// Tree-sitter grammar identifier, sourced from ``registry``'s
    /// `treeSitterGrammarIdentifier`. `nil` for Swift (suppressed in the CEP
    /// registry because Swift is highlighted via SwiftSyntax), the diagram DSLs,
    /// and plain text.
    package var parserName: String? {
        Self.metadata(for: language)?.treeSitterGrammarIdentifier
    }

    init(
        language: Language,
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
        commonModules: [String]
    ) {
        self.language = language
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

    // MARK: - LanguageKit registry

    /// The CEP-specific ``LanguageKit/LanguageRegistry``: the standard catalog
    /// restricted to CodeEditorKit's 31 languages (dropping first-class `tsx`)
    /// with CEP's two deliberate divergences and its richer shebang interpreter
    /// aliases layered on as registry data.
    ///
    /// This is the single source of truth for CEP's language identity and
    /// detection metadata; the descriptor's identity properties and
    /// `LanguageDetectionService` read from it. See ``CEPLanguageRegistryTests``.
    package static let registry: LanguageRegistry = Self.makeRegistry()

    private static func makeRegistry() -> LanguageRegistry {
        let cepIDs = Set(Language.allCases.map { LanguageID(rawValue: $0.rawValue) })
        let base = LanguageRegistry.standard.restricted(to: cepIDs)
        do {
            return try base.merging(Self.cepOverrides(base: base))
        } catch {
            preconditionFailure("CEP LanguageRegistry overrides are inconsistent: \(error)")
        }
    }

    /// CEP's divergences from the standard catalog, expressed as full-metadata
    /// overrides (``LanguageKit/LanguageRegistry/merging(_:)`` replaces the whole
    /// entry for a matching id):
    ///
    /// - **typescript**: reclaims the `tsx` extension (ordered `["ts", "tsx"]`,
    ///   the standard catalog gives `tsx` its own language) and carries CEP's
    ///   `deno` / `ts-node` interpreter aliases.
    /// - **swift**: `treeSitterGrammarIdentifier` suppressed to `nil` (SwiftSyntax
    ///   highlighting) plus the `swift` interpreter alias.
    /// - **javascript / python / ruby**: richer interpreter aliases than the
    ///   standard catalog's minimal set.
    private static func cepOverrides(base: LanguageRegistry) -> [LanguageMetadata] {
        var overrides: [LanguageMetadata] = []

        // Appends a copy of `base`'s metadata for `id` after `transform` edits it,
        // skipping ids not present in `base`.
        func override(_ id: LanguageID, _ transform: (LanguageMetadata) -> LanguageMetadata) {
            guard let metadata = base.metadata(for: id) else { return }
            overrides.append(transform(metadata))
        }

        // Divergence #1: tsx folds into typescript (ordered ["ts", "tsx"]); also
        // carries CEP's richer TypeScript interpreter aliases.
        override(.typescript) { metadata in
            LanguageMetadata(
                id: metadata.id,
                displayName: metadata.displayName,
                fileExtensions: ["ts", "tsx"],
                filenames: metadata.filenames,
                interpreters: ["deno", "ts-node"],
                lspIdentifier: metadata.lspIdentifier,
                treeSitterGrammarIdentifier: metadata.treeSitterGrammarIdentifier
            )
        }

        // Divergence #2: swift grammar suppression (highlighted via SwiftSyntax).
        override(.swift) { metadata in
            LanguageMetadata(
                id: metadata.id,
                displayName: metadata.displayName,
                fileExtensions: metadata.fileExtensions,
                filenames: metadata.filenames,
                interpreters: ["swift"],
                lspIdentifier: metadata.lspIdentifier,
                treeSitterGrammarIdentifier: nil
            )
        }

        // Richer interpreter aliases (supersets of LanguageKit's minimal set).
        override(.javascript) { withInterpreters($0, ["node", "javascript", "js"]) }
        override(.python) { withInterpreters($0, ["python", "python2", "python3"]) }
        override(.ruby) { withInterpreters($0, ["ruby", "rb"]) }

        return overrides
    }

    /// A copy of `metadata` with only its interpreter aliases replaced.
    private static func withInterpreters(
        _ metadata: LanguageMetadata,
        _ interpreters: Set<String>
    ) -> LanguageMetadata {
        LanguageMetadata(
            id: metadata.id,
            displayName: metadata.displayName,
            fileExtensions: metadata.fileExtensions,
            filenames: metadata.filenames,
            interpreters: interpreters,
            lspIdentifier: metadata.lspIdentifier,
            treeSitterGrammarIdentifier: metadata.treeSitterGrammarIdentifier
        )
    }

    /// Looks a CEP `Language` up in ``registry``. The mapping is the identity on
    /// raw values: every CEP `Language.rawValue` is a registered
    /// `LanguageID.rawValue`.
    package static func metadata(for language: Language) -> LanguageMetadata? {
        registry.metadata(for: LanguageID(rawValue: language.rawValue))
    }

    // MARK: - Lookup

    package static func descriptor(for language: Language) -> Self? {
        all[language]
    }

    package static func keywords(for language: Language) -> [String] {
        all[language]?.keywords ?? []
    }
}
