import Foundation

// MARK: - Completion Provider Registry

/// Centralized registry for managing completion providers with automatic language support
@MainActor
public final class CompletionProviderRegistry {
    // MARK: - Singleton
    
    public static let shared = CompletionProviderRegistry()

    private init() {
        loadBuiltInProviders()
    }
    
    // MARK: - Properties
    
    private var providers: [String: CompletionProvider] = [:]
    private var languageProviders: [Language: [CompletionProvider]] = [:]
    
    // MARK: - Registration
    
    /// Registers a completion provider
    public func register(_ provider: CompletionProvider) {
        providers[provider.id] = provider
        
        // Index by supported languages
        for language in provider.supportedLanguages {
            if languageProviders[language] == nil {
                languageProviders[language] = []
            }
            languageProviders[language]?.append(provider)
        }
        
        CrossPlatformLogger.logger().info("Registered completion provider: \(provider.id) for languages: \(provider.supportedLanguages)")
    }
    
    /// Unregisters a completion provider
    public func unregister(providerId: String) {
        guard let provider = providers.removeValue(forKey: providerId) else { return }
        
        // Remove from language index
        for language in provider.supportedLanguages {
            languageProviders[language]?.removeAll { $0.id == providerId }
            if languageProviders[language]?.isEmpty == true {
                languageProviders[language] = nil
            }
        }
        
        CrossPlatformLogger.logger().info("Unregistered completion provider: \(providerId)")
    }
    
    /// Registers multiple providers at once
    public func registerProviders(_ providers: [CompletionProvider]) {
        for provider in providers {
            register(provider)
        }
    }
    
    // MARK: - Provider Access
    
    /// Gets all providers for a specific language
    public func providers(for language: Language) -> [CompletionProvider] {
        languageProviders[language] ?? []
    }
    
    /// Gets a specific provider by ID
    public func provider(withId id: String) -> CompletionProvider? {
        providers[id]
    }
    
    /// Gets all registered providers
    public var allProviders: [CompletionProvider] {
        Array(providers.values)
    }
    
    /// Gets all supported languages
    public var supportedLanguages: [Language] {
        Array(languageProviders.keys)
    }
    
    // MARK: - Dynamic Provider Creation
    
    /// Creates and registers a provider for a language if one doesn't exist
    public func ensureProvider(for language: Language) -> CompletionProvider? {
        // Check if we already have a provider for this language
        if !providers(for: language).isEmpty {
            return providers(for: language).first
        }
        
        // Try to create one using the metadata registry
        guard let provider = LanguageMetadataRegistry.shared.createProvider(for: language) else {
            CrossPlatformLogger.logger().warning("No provider available for language: \(language)")
            return nil
        }
        
        register(provider)
        return provider
    }
    
    /// Creates providers for all supported languages
    public func loadAllLanguageProviders() {
        let supportedLanguages = LanguageMetadataRegistry.shared.supportedLanguages
        
        for language in supportedLanguages {
            _ = ensureProvider(for: language)
        }
        
        CrossPlatformLogger.logger().info("Loaded providers for \(supportedLanguages.count) languages")
    }
    
    // MARK: - Built-in Providers
    
    private func loadBuiltInProviders() {
        // Load providers for commonly used languages
        let commonLanguages: [Language] = [.swift, .javascript, .typescript, .python, .rust, .go]
        
        for language in commonLanguages {
            _ = ensureProvider(for: language)
        }
    }
    
    // MARK: - Provider Statistics
    
    /// Gets statistics about registered providers
    public func getProviderStatistics() -> ProviderStatistics {
        let languageCount = languageProviders.count
        let providerCount = providers.count
        let languageCoverage = Dictionary(uniqueKeysWithValues: languageProviders.map { language, providers in
            (language, providers.count)
        })
        
        return ProviderStatistics(
            totalProviders: providerCount,
            supportedLanguages: languageCount,
            languageCoverage: languageCoverage
        )
    }
    
    // MARK: - Completion Coordination
    
    /// Gets completions from all providers for a specific language
    public func getCompletions(
        for context: CompletionContextModel,
        language: Language
    ) async throws -> [CompletionResult] {
        let availableProviders = providers(for: language)
        
        guard !availableProviders.isEmpty else {
            // Try to create a provider dynamically
            guard let provider = ensureProvider(for: language) else {
                return []
            }
            
            let result = try await provider.completions(for: context)
            return [result]
        }
        
        // Get completions from all providers concurrently
        return try await withThrowingTaskGroup(of: CompletionResult?.self) { group in
            for provider in availableProviders {
                group.addTask {
                    do {
                        return try await provider.completions(for: context)
                    } catch {
                        CrossPlatformLogger.logger().error("Provider \(provider.id) failed: \(error)")
                        return nil
                    }
                }
            }
            
            var results: [CompletionResult] = []
            for try await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }
    }
    
    /// Merges completion results from multiple providers
    public func mergeCompletionResults(_ results: [CompletionResult]) -> CompletionResult? {
        guard !results.isEmpty else { return nil }
        
        if results.count == 1 {
            return results.first
        }
        
        // Merge items from all results
        var allItems: [CompletionItemModel] = []
        var totalProcessingTime: TimeInterval = 0
        let context = results.first?.context
        var isIncomplete = false
        
        for result in results {
            allItems.append(contentsOf: result.items)
            totalProcessingTime += result.processingTime
            isIncomplete = isIncomplete || result.isIncomplete
        }
        
        // Remove duplicates and sort by priority
        let uniqueItems = Dictionary(grouping: allItems, by: \.label)
            .compactMapValues { items in
                items.max { $0.priority < $1.priority }
            }
            .values
            .sorted { $0.priority > $1.priority }
        
        return CompletionResult(
            items: Array(uniqueItems),
            context: context ?? CompletionContextModel(text: "", cursorPosition: 0, language: .swift, lineText: ""),
            isIncomplete: isIncomplete,
            processingTime: totalProcessingTime
        )
    }
}

// MARK: - Provider Statistics

public struct ProviderStatistics {
    public let totalProviders: Int
    public let supportedLanguages: Int
    public let languageCoverage: [Language: Int]
    
    public var description: String {
        let coverageDescription = languageCoverage.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return "Providers: \(totalProviders), Languages: \(supportedLanguages), Coverage: [\(coverageDescription)]"
    }
}

// MARK: - Registry Extensions

extension CompletionProviderRegistry {
    /// Convenience method to register built-in providers for specific languages
    public func registerBuiltInProviders(for languages: [Language]) {
        for language in languages {
            _ = ensureProvider(for: language)
        }
    }
    
    /// Removes all providers and resets the registry
    public func reset() {
        providers.removeAll()
        languageProviders.removeAll()
        CrossPlatformLogger.logger().info("Provider registry reset")
    }
    
    /// Validates that all registered providers are working correctly
    public func validateProviders() async {
        let testContext = CompletionContextModel(text: "test", cursorPosition: 4, language: .swift, lineText: "test")
        
        for provider in allProviders {
            do {
                let startTime = Date()
                _ = try await provider.completions(for: testContext)
                let elapsed = Date().timeIntervalSince(startTime)
                
                if elapsed > 1.0 {
                    CrossPlatformLogger.logger().warning("Provider \(provider.id) is slow: \(elapsed)s")
                }
            } catch {
                CrossPlatformLogger.logger().error("Provider \(provider.id) validation failed: \(error)")
            }
        }
    }
}
