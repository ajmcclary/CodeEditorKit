import CodeEditorLanguages
@testable import CodeEditorPlugin
import XCTest

@MainActor
final class CompletionManagerBuiltInProviderTests: XCTestCase {
    private func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor())
    }

    func testEnsureBuiltInProviderRegistersOneProvider() {
        let manager = makeManager()
        manager.ensureBuiltInProvider(for: .swift)

        let ids = manager.registeredProviders.map(\.id)
        XCTAssertEqual(ids, ["builtin.keywords.swift"])
    }

    func testEnsureBuiltInProviderIsIdempotent() {
        let manager = makeManager()
        manager.ensureBuiltInProvider(for: .swift)
        manager.ensureBuiltInProvider(for: .swift)
        manager.ensureBuiltInProvider(for: .swift)

        XCTAssertEqual(manager.registeredProviders.count, 1)
        XCTAssertEqual(manager.registeredProviders.first?.id, "builtin.keywords.swift")
    }

    func testLanguageSwitchSweepsPriorBuiltIn() {
        let manager = makeManager()
        manager.ensureBuiltInProvider(for: .swift)
        manager.ensureBuiltInProvider(for: .python)

        let ids = manager.registeredProviders.map(\.id)
        XCTAssertEqual(ids, ["builtin.keywords.python"])
    }

    func testCodeEditorViewRegistersBuiltInForInitialLanguage() {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))

        let ids = editor.completionManager.registeredProviders.map(\.id)
        XCTAssertTrue(
            ids.contains("builtin.keywords.\(Language.plainText.identifier)"),
            "First-time setup should register the built-in keyword provider for initial language"
        )
    }

    func testCodeEditorViewSwapsBuiltInOnLanguageChange() {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        editor.language = .swift
        editor.language = .python

        let ids = Set(editor.completionManager.registeredProviders.map(\.id))
        XCTAssertTrue(ids.contains("builtin.keywords.python"))
        XCTAssertFalse(ids.contains("builtin.keywords.swift"))
    }

    func testHostCollisionOnBuiltInIdWins() {
        let manager = makeManager()

        let stub = StubCompletionProvider(
            id: "builtin.keywords.swift",
            supportedLanguages: [.swift]
        )
        manager.registerProvider(stub)
        manager.ensureBuiltInProvider(for: .swift)

        XCTAssertEqual(manager.registeredProviders.count, 1)
        XCTAssertIdentical(
            manager.registeredProviders.first as AnyObject,
            stub,
            "Host-supplied provider should not be replaced by built-in"
        )
    }
}

@MainActor
private final class StubCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false

    init(id: String, supportedLanguages: [Language]) {
        self.id = id
        self.supportedLanguages = supportedLanguages
    }

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        CompletionResult(items: [], context: context, isIncomplete: false, processingTime: 0)
    }
}
