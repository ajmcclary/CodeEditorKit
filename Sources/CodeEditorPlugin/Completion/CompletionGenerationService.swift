import Foundation

// MARK: - Completion Generation Service

/// Service responsible for generating completion items
@MainActor
internal final class CompletionGenerationService {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "CompletionGenerationService")

    // MARK: - Properties

    private var completionProviders: [CompletionProvider] = []
    private let providerRegistry: CompletionProviderRegistry

    // MARK: - Initialization

    /// Initialize with a completion provider registry
    /// - Parameter providerRegistry: The registry to use for managing completion providers
    internal init(providerRegistry: CompletionProviderRegistry? = nil) {
        self.providerRegistry = providerRegistry ?? CompletionProviderRegistry()
    }

    // MARK: - Public Methods

    /// Configures providers for the specified language
    internal func configureProviders(for language: Language) {
        completionProviders = providerRegistry.providers(for: language)

        // If no providers found, try to create one from the factory
        if completionProviders.isEmpty {
            if let provider = LanguageProviderFactory.createProvider(for: language) {
                providerRegistry.register(provider)
                completionProviders = [provider]
            }
        }

        logger.debug("Configured \(completionProviders.count) providers for \(language.name)")
    }

    /// Generates completions for the given context
    internal func generateCompletions(for context: CompletionContext) async throws -> [CompletionItemModel] {
        let startTime = Date()
        var allItems: [CompletionItemModel] = []

        // Convert context to provider format
        let providerContext = CompletionContextModel(
            text: "", // Would need full text from text view
            cursorPosition: context.triggerLocation,
            language: context.language,
            triggerKind: determineTriggerKind(context.triggerCharacter),
            triggerCharacter: context.triggerCharacter,
            lineText: context.currentLine
        )

        // Gather completions from all providers
        for provider in completionProviders {
            do {
                let result = try await provider.completions(for: providerContext)
                let items = result.items.map { convertToCompletionItemModel($0) }
                allItems.append(contentsOf: items)
            } catch {
                logger.error("Provider \(provider.id) failed: \(error)")
            }
        }

        // Add basic language completions if needed
        if allItems.isEmpty {
            allItems = generateBasicCompletions(for: context)
        }

        // Sort by priority and relevance
        allItems.sort { item1, item2 in
            if item1.priority == item2.priority {
                return item1.sortText ?? item1.label < item2.sortText ?? item2.label
            }
            return item1.priority > item2.priority
        }

        let elapsedTime = Date().timeIntervalSince(startTime)
        logger.debug("Generated \(allItems.count) completions in \(String(format: "%.3f", elapsedTime))s")

        return allItems
    }

    // MARK: - Private Methods

    private func determineTriggerKind(_ triggerCharacter: String?) -> CompletionTriggerKind {
        guard triggerCharacter != nil else { return .manual }

        return .character
    }

    private func convertToCompletionItemModel(_ model: CompletionItemModel) -> CompletionItemModel {
        // Simply return the model as-is since it's already a CompletionItemModel
        model
    }

    private func generateBasicCompletions(for context: CompletionContext) -> [CompletionItemModel] {
        var items: [CompletionItemModel] = []

        // Language-specific basic completions
        switch context.language {
        case .swift:
            items.append(contentsOf: generateSwiftBasicCompletions(context))

        case .python:
            items.append(contentsOf: generatePythonBasicCompletions(context))

        case .javascript, .typescript:
            items.append(contentsOf: generateJavaScriptBasicCompletions(context))

        default:
            // Generic keywords
            items.append(contentsOf: generateGenericCompletions(context))
        }

        return items
    }

    private func generateSwiftBasicCompletions(_ context: CompletionContext) -> [CompletionItemModel] {
        let keywords = [
            "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
            "import", "if", "else", "for", "while", "switch", "case", "default",
            "return", "break", "continue", "guard", "defer", "do", "try", "catch",
            "throws", "async", "await", "actor", "typealias", "associatedtype"
        ]

        return keywords
            .filter { $0.lowercased().hasPrefix(context.prefix.lowercased()) }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    kind: .keyword,
                    priority: CompletionItemKind.keyword.defaultPriority
                )
            }
    }

    private func generatePythonBasicCompletions(_ context: CompletionContext) -> [CompletionItemModel] {
        let keywords = [
            "def", "class", "import", "from", "if", "elif", "else", "for", "while",
            "break", "continue", "return", "yield", "lambda", "with", "as", "try",
            "except", "finally", "raise", "assert", "pass", "del", "global", "nonlocal"
        ]

        return keywords
            .filter { $0.lowercased().hasPrefix(context.prefix.lowercased()) }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    kind: .keyword,
                    priority: CompletionItemKind.keyword.defaultPriority
                )
            }
    }

    private func generateJavaScriptBasicCompletions(_ context: CompletionContext) -> [CompletionItemModel] {
        let keywords = [
            "function", "const", "let", "var", "class", "extends", "import", "export",
            "if", "else", "for", "while", "do", "switch", "case", "default", "break",
            "continue", "return", "throw", "try", "catch", "finally", "async", "await"
        ]

        return keywords
            .filter { $0.lowercased().hasPrefix(context.prefix.lowercased()) }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    kind: .keyword,
                    priority: CompletionItemKind.keyword.defaultPriority
                )
            }
    }

    private func generateGenericCompletions(_ context: CompletionContext) -> [CompletionItemModel] {
        let keywords = ["if", "else", "for", "while", "return", "break", "continue"]

        return keywords
            .filter { $0.lowercased().hasPrefix(context.prefix.lowercased()) }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    kind: .keyword,
                    priority: CompletionItemKind.keyword.defaultPriority
                )
            }
    }

    private func calculateSimpleMatchScore(_ text: String, prefix: String) -> Double {
        guard !prefix.isEmpty else { return 1.0 }

        let lowerText = text.lowercased()
        let lowerPrefix = prefix.lowercased()

        if lowerText.hasPrefix(lowerPrefix) {
            return 1.0 - (Double(prefix.count) / Double(text.count) * 0.1)
        }

        return 0.5
    }
}
