import Foundation

// MARK: - Language Provider Factory

/// Factory for creating language-specific completion providers with shared logic and reduced duplication
///
/// This factory uses centralized metadata from `LanguageStaticMetadata` and provides
/// a `UniversalCompletionProvider` for all 20 supported languages.
@MainActor
public enum LanguageProviderFactory {
    // MARK: - Member Completion Providers

    private static let memberCompletionsMap: [Language: any LanguageMemberCompletions] = [
        .swift: SwiftMemberCompletions(),
        .javascript: JavaScriptMemberCompletions(),
        .typescript: TypeScriptMemberCompletions(),
        .python: PythonMemberCompletions(),
        .rust: RustMemberCompletions(),
        .go: GoMemberCompletions(),
        .java: JavaMemberCompletions(),
        .c: CMemberCompletions(),
        .cpp: CMemberCompletions() // C++ uses same base as C
    ]

    // MARK: - Factory Methods

    /// Creates a completion provider for the specified language
    ///
    /// Uses centralized `LanguageStaticMetadata` for keyword/type/function data
    /// and language-specific member completions where available.
    public static func createProvider(for language: Language) -> CompletionProvider? {
        guard let staticMetadata = LanguageStaticMetadata.metadata(for: language) else {
            return nil
        }

        let memberCompletions = memberCompletionsMap[language] ?? DefaultMemberCompletions()

        let metadata = LanguageMetadata(
            keywords: staticMetadata.keywords,
            types: staticMetadata.types,
            functions: staticMetadata.functions,
            literals: staticMetadata.literals,
            triggerCharacters: staticMetadata.triggerCharacters,
            memberCompletions: memberCompletions
        )

        return UniversalCompletionProvider(
            language: language,
            metadata: metadata
        )
    }

    /// Creates metadata for a specific language
    ///
    /// This is useful when you need direct access to the metadata
    /// without creating a full provider.
    public static func metadata(for language: Language) -> LanguageMetadata? {
        guard let staticMetadata = LanguageStaticMetadata.metadata(for: language) else {
            return nil
        }

        let memberCompletions = memberCompletionsMap[language] ?? DefaultMemberCompletions()

        return LanguageMetadata(
            keywords: staticMetadata.keywords,
            types: staticMetadata.types,
            functions: staticMetadata.functions,
            literals: staticMetadata.literals,
            triggerCharacters: staticMetadata.triggerCharacters,
            memberCompletions: memberCompletions
        )
    }

    /// Gets all supported languages
    ///
    /// Returns all languages that have static metadata defined.
    public static var supportedLanguages: [Language] {
        Array(LanguageStaticMetadata.all.keys)
    }
}

// MARK: - Universal Completion Provider

/// Universal completion provider that works with any language metadata
@MainActor
public final class UniversalCompletionProvider: CompletionProvider {
    public let id: String
    public let supportedLanguages: [Language]
    public let triggerCharacters: [String]
    public let supportsSnippets = true

    private let language: Language
    private let metadata: LanguageMetadata

    init(language: Language, metadata: LanguageMetadata) {
        self.language = language
        self.metadata = metadata
        self.id = "\(language.rawValue)-universal"
        self.supportedLanguages = [language]
        self.triggerCharacters = metadata.triggerCharacters
    }

    // MARK: - CompletionProvider Implementation

    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Use shared context analysis
        let analysisResult = SharedContextAnalyzer.analyzeContext(context, for: language)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .keyword:
            items.append(contentsOf: SharedCompletionBuilder.createKeywordCompletions(
                from: metadata.keywords,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .type:
            items.append(contentsOf: SharedCompletionBuilder.createTypeCompletions(
                from: metadata.types,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .function:
            items.append(contentsOf: SharedCompletionBuilder.createFunctionCompletions(
                from: metadata.functions,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .literal:
            items.append(contentsOf: SharedCompletionBuilder.createLiteralCompletions(
                from: metadata.literals,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .member:
            items.append(contentsOf: metadata.memberCompletions.createMemberCompletions(
                for: analysisResult.targetType,
                filter: analysisResult.filter
            ))

        case .general:
            items.append(contentsOf: SharedCompletionBuilder.createKeywordCompletions(
                from: metadata.keywords,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createTypeCompletions(
                from: metadata.types,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createFunctionCompletions(
                from: metadata.functions,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createLiteralCompletions(
                from: metadata.literals,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .parameter:
            items.append(contentsOf: SharedCompletionBuilder.createParameterCompletions(
                for: language,
                filter: analysisResult.filter
            ))
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: processingTime
        )
    }
}

// MARK: - Supporting Types

/// Metadata container for a specific language
public struct LanguageMetadata {
    let keywords: [String]
    let types: [String]
    let functions: [String]
    let literals: [String]
    let triggerCharacters: [String]
    let memberCompletions: LanguageMemberCompletions
}

/// Protocol for language-specific member completions
public protocol LanguageMemberCompletions {
    /// Creates member completion suggestions for a specific type
    /// - Parameters:
    ///   - targetType: The type to get completions for
    ///   - filter: Filter string to narrow results
    /// - Returns: Array of completion items
    func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel]
}

/// Universal context analysis result
public struct UniversalContextAnalysisResult {
    /// Type of completion being suggested
    public enum CompletionType {
        /// Language keyword completion
        case keyword
        /// Type name completion
        case type
        /// Function or method completion
        case function
        /// Literal value completion
        case literal
        /// Member access completion
        case member
        /// Parameter completion
        case parameter
        /// General purpose completion
        case general
    }

    let type: CompletionType
    let filter: String
    let targetType: String?

    init(type: CompletionType, filter: String, targetType: String? = nil) {
        self.type = type
        self.filter = filter
        self.targetType = targetType
    }
}
