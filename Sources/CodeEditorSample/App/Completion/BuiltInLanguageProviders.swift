import CodeEditorPlugin
import Foundation

/// Wraps the framework's `LanguageProviderFactory.createProvider(for:)`
/// output for a curated set of languages so the sample can register them
/// against `CompletionManager` and demonstrate the provider protocol.
///
/// The framework's factory produces `UniversalCompletionProvider`s that
/// cover keywords, types, functions, literals, members, parameters, and
/// snippets per `LanguageDescriptor`. This wrapper does not change that
/// behavior — it simply picks the eight languages for which the framework
/// also ships `LanguageMemberCompletions` data, ensuring member-access
/// completions fire alongside the descriptor-derived data.
@MainActor
enum BuiltInLanguageProviders {
    /// Curated set of languages with rich completion data: the eight
    /// `LanguageMemberCompletions` conformers shipped by the framework.
    static let curatedLanguages: [Language] = [
        .swift, .python, .javascript, .typescript,
        .go, .rust, .java, .c
    ]

    static func all() -> [any CompletionProvider] {
        curatedLanguages.compactMap { LanguageProviderFactory.createProvider(for: $0) }
    }
}
