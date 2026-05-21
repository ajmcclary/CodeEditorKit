import Foundation

/// Descriptor-derived completion profile for a language.
public struct CompletionProfile: Sendable {
    public let language: Language
    public let keywords: [String]
    public let types: [String]
    public let functions: [String]
    public let literals: [String]
    public let snippets: [SnippetTemplate]
    public let triggerCharacters: [String]
    public let commonModules: [String]
    public let memberCompletions: any LanguageMemberCompletions

    init(descriptor: LanguageDescriptor) {
        self.language = descriptor.language
        self.keywords = descriptor.keywords
        self.types = descriptor.types
        self.functions = descriptor.functions
        self.literals = descriptor.literals
        self.snippets = descriptor.snippets
        self.triggerCharacters = descriptor.triggerCharacters
        self.commonModules = descriptor.commonModules
        self.memberCompletions = descriptor.memberCompletions ?? DefaultMemberCompletions()
    }

    public func analyze(_ context: CompletionContextModel) -> UniversalContextAnalysisResult {
        SharedContextAnalyzer.analyzeContext(context, for: language)
    }
}
