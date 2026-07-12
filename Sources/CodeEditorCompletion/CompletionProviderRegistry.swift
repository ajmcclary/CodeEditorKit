import CodeEditorLanguages

/// Owns completion-provider registration and language applicability rules.
@MainActor
final class CompletionProviderRegistry {
    private var providers: [String: any CompletionProvider] = [:]

    /// Registers or replaces a provider at its stable identifier.
    func register(_ provider: any CompletionProvider) {
        providers[provider.id] = provider
    }

    /// Removes the provider with the supplied identifier, when present.
    func unregister(withId id: String) {
        providers.removeValue(forKey: id)
    }

    /// All registered providers.
    var registeredProviders: [any CompletionProvider] {
        Array(providers.values)
    }

    /// Providers that support the language, including unrestricted providers.
    func applicableProviders(for language: Language) -> [any CompletionProvider] {
        providers.values.filter { provider in
            provider.supportedLanguages.contains(language) ||
            provider.supportedLanguages.isEmpty
        }
    }

    /// Keeps exactly one language-keyword provider for the active language.
    ///
    /// A host provider registered at the canonical built-in identifier wins.
    func ensureBuiltInProvider(for language: Language) {
        let newId = "builtin.keywords.\(language.identifier)"

        let staleIds = providers.keys.filter {
            $0.hasPrefix("builtin.keywords.") && $0 != newId
        }
        for staleId in staleIds {
            providers.removeValue(forKey: staleId)
        }

        guard providers[newId] == nil else { return }
        register(LanguageKeywordCompletionProvider(language: language))
    }
}
