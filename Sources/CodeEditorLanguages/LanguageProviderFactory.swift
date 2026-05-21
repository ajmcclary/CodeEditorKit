import Foundation

// MARK: - Language Provider Factory

/// Factory for creating language-specific completion providers with shared logic and reduced duplication
///
/// This factory uses centralized metadata from `LanguageDescriptor` and provides
/// a `UniversalCompletionProvider` for all supported languages.
@MainActor
public enum LanguageProviderFactory {
    // MARK: - Factory Methods

    /// Creates a completion provider for the specified language
    ///
    /// Uses centralized `LanguageDescriptor` for keyword/type/function data
    /// and language-specific member completions where available.
    public static func createProvider(for language: Language) -> CompletionProvider? {
        guard let descriptor = LanguageDescriptor.descriptor(for: language) else {
            return nil
        }

        return UniversalCompletionProvider(
            language: language,
            profile: CompletionProfile(descriptor: descriptor)
        )
    }

    /// Creates a descriptor-derived completion profile for a specific language.
    ///
    /// This is useful when you need direct access to completion data
    /// without creating a full provider.
    public static func profile(for language: Language) -> CompletionProfile? {
        guard let descriptor = LanguageDescriptor.descriptor(for: language) else {
            return nil
        }

        return CompletionProfile(descriptor: descriptor)
    }

    /// Gets all supported languages
    ///
    /// Returns all languages that have static metadata defined.
    public static var supportedLanguages: [Language] {
        Array(LanguageDescriptor.all.keys)
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
    private let profile: CompletionProfile

    init(language: Language, profile: CompletionProfile) {
        self.language = language
        self.profile = profile
        self.id = "\(language.rawValue)-universal"
        self.supportedLanguages = [language]
        self.triggerCharacters = profile.triggerCharacters
    }

    // MARK: - CompletionProvider Implementation

    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Use shared context analysis
        let analysisResult = profile.analyze(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .keyword:
            items.append(contentsOf: SharedCompletionBuilder.createKeywordCompletions(
                from: profile.keywords,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .type:
            items.append(contentsOf: SharedCompletionBuilder.createTypeCompletions(
                from: profile.types,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .function:
            items.append(contentsOf: SharedCompletionBuilder.createFunctionCompletions(
                from: profile.functions,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .literal:
            items.append(contentsOf: SharedCompletionBuilder.createLiteralCompletions(
                from: profile.literals,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createModuleCompletions(
                from: profile.commonModules,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .member:
            items.append(contentsOf: profile.memberCompletions.createMemberCompletions(
                for: analysisResult.targetType,
                filter: analysisResult.filter
            ))

        case .general:
            items.append(contentsOf: SharedCompletionBuilder.createKeywordCompletions(
                from: profile.keywords,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createTypeCompletions(
                from: profile.types,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createFunctionCompletions(
                from: profile.functions,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createLiteralCompletions(
                from: profile.literals,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createSnippetCompletions(
                from: profile.snippets,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createModuleCompletions(
                from: profile.commonModules,
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

/// Protocol for language-specific member completions
public protocol LanguageMemberCompletions: Sendable {
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
