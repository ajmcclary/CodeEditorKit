@testable import CodeEditorCompletion
import CodeEditorLanguages
import Testing

@MainActor
private final class RegistryProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]

    init(id: String, supportedLanguages: [Language]) {
        self.id = id
        self.supportedLanguages = supportedLanguages
    }

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        CompletionResult(
            items: [],
            context: context,
            isIncomplete: false,
            processingTime: 0
        )
    }
}

@MainActor
@Suite("CompletionProviderRegistry")
struct CompletionProviderRegistryTests {
    @Test("host collision wins while stale built-ins are swept")
    func hostCollisionAndSweep() {
        let registry = CompletionProviderRegistry()
        registry.ensureBuiltInProvider(for: .python)
        let host = RegistryProvider(
            id: "builtin.keywords.swift",
            supportedLanguages: [.swift]
        )
        registry.register(host)

        registry.ensureBuiltInProvider(for: .swift)

        #expect(registry.registeredProviders.count == 1)
        #expect(registry.registeredProviders.first as AnyObject === host)
    }

    @Test("language changes replace the prior built-in")
    func builtInLanguageSweep() {
        let registry = CompletionProviderRegistry()
        registry.ensureBuiltInProvider(for: .swift)
        registry.ensureBuiltInProvider(for: .python)

        #expect(registry.registeredProviders.map(\.id) == [
            "builtin.keywords.python"
        ])
    }

    @Test("providers with no language restriction are applicable everywhere")
    func wildcardProvider() {
        let registry = CompletionProviderRegistry()
        let wildcard = RegistryProvider(id: "wildcard", supportedLanguages: [])
        let swiftOnly = RegistryProvider(id: "swift", supportedLanguages: [.swift])
        registry.register(wildcard)
        registry.register(swiftOnly)

        #expect(registry.applicableProviders(for: .python).map(\.id) == [
            "wildcard"
        ])
    }
}
