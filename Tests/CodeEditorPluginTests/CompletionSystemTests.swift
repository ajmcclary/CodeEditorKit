@testable import CodeEditorPlugin
import XCTest

@MainActor
final class CompletionSystemTests: XCTestCase {
    private var completionManager: CompletionManager!
    private var mockProvider: MockCompletionProvider!
    
    override func setUp() {
        super.setUp()
        Task { @MainActor in
            completionManager = CompletionManager()
            mockProvider = MockCompletionProvider()
        }
    }
    
    override func tearDown() {
        Task { @MainActor in
            completionManager = nil
            mockProvider = nil
        }
        super.tearDown()
    }
    
    // MARK: - CompletionItemModel Tests
    
    func testCompletionItemModelCreation() {
        let item = CompletionItemModel(
            label: "testFunction",
            insertText: "testFunction()",
            kind: .function,
            detail: "A test function",
            documentation: "This is a test function for unit testing"
        )
        
        XCTAssertEqual(item.label, "testFunction")
        XCTAssertEqual(item.insertText, "testFunction()")
        XCTAssertEqual(item.kind, .function)
        XCTAssertEqual(item.detail, "A test function")
        XCTAssertEqual(item.documentation, "This is a test function for unit testing")
        XCTAssertFalse(item.id.isEmpty)
        XCTAssertEqual(item.priority, 0)
        XCTAssertFalse(item.snippetSupport)
        XCTAssertFalse(item.deprecated)
        XCTAssertFalse(item.preselect)
    }
    
    func testCompletionItemModelDefaults() {
        let item = CompletionItemModel(label: "test")
        
        XCTAssertEqual(item.label, "test")
        XCTAssertEqual(item.insertText, "test") // Should default to label
        XCTAssertEqual(item.kind, .text)
        XCTAssertNil(item.detail)
        XCTAssertNil(item.documentation)
    }
    
    func testCompletionItemKindPriorities() {
        XCTAssertEqual(CompletionItemKind.keyword.defaultPriority, 100)
        XCTAssertEqual(CompletionItemKind.snippet.defaultPriority, 90)
        XCTAssertEqual(CompletionItemKind.function.defaultPriority, 80)
        XCTAssertEqual(CompletionItemKind.property.defaultPriority, 70)
        XCTAssertTrue(CompletionItemKind.keyword.defaultPriority > CompletionItemKind.function.defaultPriority)
    }
    
    func testCompletionItemKindIcons() {
        XCTAssertFalse(CompletionItemKind.function.icon.isEmpty)
        XCTAssertFalse(CompletionItemKind.variable.icon.isEmpty)
        XCTAssertFalse(CompletionItemKind.class.icon.isEmpty)
        XCTAssertNotEqual(CompletionItemKind.function.icon, CompletionItemKind.variable.icon)
    }
    
    // MARK: - CompletionContextModel Tests
    
    func testCompletionContextModelCreation() {
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: "let x = ",
            cursorPosition: 8,
            language: language,
            triggerKind: .character,
            triggerCharacter: ".",
            lineText: "let x = ",
            wordRange: NSRange(location: 4, length: 1)
        )
        
        XCTAssertEqual(context.text, "let x = ")
        XCTAssertEqual(context.cursorPosition, 8)
        XCTAssertEqual(context.language.identifier, "swift")
        XCTAssertEqual(context.triggerKind, .character)
        XCTAssertEqual(context.triggerCharacter, ".")
        XCTAssertEqual(context.lineText, "let x = ")
        XCTAssertEqual(context.wordRange, NSRange(location: 4, length: 1))
        XCTAssertNotNil(context.timestamp)
    }
    
    // MARK: - CompletionManager Tests
    
    func testCompletionManagerProviderRegistration() {
        XCTAssertTrue(completionManager.registeredProviders.isEmpty)
        
        completionManager.registerProvider(mockProvider)
        XCTAssertEqual(completionManager.registeredProviders.count, 1)
        XCTAssertEqual(completionManager.registeredProviders.first?.id, mockProvider.id)
        
        completionManager.unregisterProvider(withId: mockProvider.id)
        XCTAssertTrue(completionManager.registeredProviders.isEmpty)
    }
    
    func testCompletionManagerRequestsCompletions() async throws {
        // Register mock provider
        completionManager.registerProvider(mockProvider)
        
        // Create context
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: "let x = String.",
            cursorPosition: 15,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        // Request completions
        let result = try await completionManager.requestCompletions(for: context)
        
        XCTAssertFalse(result.items.isEmpty)
        XCTAssertEqual(result.context.text, context.text)
        XCTAssertFalse(result.isIncomplete)
        XCTAssertTrue(result.processingTime >= 0)
    }
    
    func testCompletionManagerDeduplication() async throws {
        // Create two providers that return duplicate items
        let provider1 = MockCompletionProvider(id: "provider1")
        let provider2 = MockCompletionProvider(id: "provider2")
        
        completionManager.registerProvider(provider1)
        completionManager.registerProvider(provider2)
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        let result = try await completionManager.requestCompletions(for: context)
        
        // Should deduplicate items with same label and kind
        let labels = result.items.map { $0.label }
        let uniqueLabels = Set(labels)
        XCTAssertEqual(labels.count, uniqueLabels.count, "Items should be deduplicated")
    }
    
    func testCompletionManagerSorting() async throws {
        completionManager.registerProvider(mockProvider)
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        let result = try await completionManager.requestCompletions(for: context)
        
        // Verify items are sorted by priority and then by label
        for i in 0..<(result.items.count - 1) {
            let current = result.items[i]
            let next = result.items[i + 1]
            
            if current.priority == next.priority && current.kind.defaultPriority == next.kind.defaultPriority {
                XCTAssertTrue(current.label.localizedCaseInsensitiveCompare(next.label) != .orderedDescending)
            } else if current.priority == next.priority {
                XCTAssertGreaterThanOrEqual(current.kind.defaultPriority, next.kind.defaultPriority)
            } else {
                XCTAssertGreaterThanOrEqual(current.priority, next.priority)
            }
        }
    }
    
    func testCompletionManagerCancellation() async throws {
        completionManager.registerProvider(MockSlowCompletionProvider())
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        // Start a request
        let requestTask = Task {
            try await completionManager.requestCompletions(for: context)
        }
        
        // Cancel it immediately
        completionManager.cancelCurrentRequest()
        
        // The task should be cancelled
        do {
            _ = try await requestTask.value
            XCTFail("Request should have been cancelled")
        } catch {
            // Expected to be cancelled
        }
    }
    
    // MARK: - SwiftCompletionProvider Tests
    
    func testSwiftCompletionProviderBasics() {
        let provider = SwiftCompletionProvider()
        
        XCTAssertEqual(provider.id, "swift-builtin")
        XCTAssertTrue(provider.supportedLanguages.contains { $0.identifier == "swift" })
        XCTAssertTrue(provider.triggerCharacters.contains("."))
        XCTAssertTrue(provider.triggerCharacters.contains("("))
    }
    
    func testSwiftCompletionProviderCompletions() async throws {
        let provider = SwiftCompletionProvider()
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: "let x = String.",
            cursorPosition: 15,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        let result = try await provider.completions(for: context)
        
        XCTAssertFalse(result.items.isEmpty)
        
        // Should contain Swift keywords
        let labels = result.items.map { $0.label }
        XCTAssertTrue(labels.contains("func"))
        XCTAssertTrue(labels.contains("var"))
        XCTAssertTrue(labels.contains("let"))
        XCTAssertTrue(labels.contains("class"))
        
        // Should contain built-in types
        XCTAssertTrue(labels.contains("String"))
        XCTAssertTrue(labels.contains("Int"))
        XCTAssertTrue(labels.contains("Bool"))
    }
    
    func testSwiftCompletionProviderContextAwareness() async throws {
        let provider = SwiftCompletionProvider()
        let language = Language(name: "Swift", identifier: "swift")
        
        // Test different contexts
        let contexts = [
            ("import ", "Import context"),
            ("class MyClass: ", "Inheritance context"),
            ("func test() -> ", "Return type context"),
            ("var x: ", "Type annotation context")
        ]
        
        for (text, description) in contexts {
            let context = CompletionContextModel(
                text: text,
                cursorPosition: text.count,
                language: language
            )
            
            let result = try await provider.completions(for: context)
            XCTAssertFalse(result.items.isEmpty, "Should provide completions for: \(description)")
        }
    }
    
    // MARK: - CompletionTextEdit Tests
    
    func testCompletionTextEdit() {
        let range = NSRange(location: 10, length: 5)
        let textEdit = CompletionTextEdit(range: range, newText: "replacement")
        
        XCTAssertEqual(textEdit.range, range)
        XCTAssertEqual(textEdit.newText, "replacement")
    }
    
    // MARK: - Performance Tests
    
    func testCompletionManagerPerformance() throws {
        // Register multiple providers
        for i in 0..<10 {
            completionManager.registerProvider(MockCompletionProvider(id: "provider\(i)"))
        }
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        measure {
            let expectation = self.expectation(description: "Completion request")
            Task {
                do {
                    _ = try await completionManager.requestCompletions(for: context)
                    expectation.fulfill()
                } catch {
                    XCTFail("Completion request failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Mock Providers

@MainActor
private class MockCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language] = [Language(name: "Swift", identifier: "swift")]
    let triggerCharacters: [String] = [".", "(", "["]
    
    init(id: String = "mock-provider") {
        self.id = id
    }
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let items = [
            CompletionItemModel(label: "testFunction", kind: .function),
            CompletionItemModel(label: "testVariable", kind: .variable),
            CompletionItemModel(label: "TestClass", kind: .class),
            CompletionItemModel(label: "testProperty", kind: .property),
            CompletionItemModel(label: "let", kind: .keyword, priority: 100),
            CompletionItemModel(label: "var", kind: .keyword, priority: 100),
            CompletionItemModel(label: "func", kind: .keyword, priority: 100)
        ]
        
        return CompletionResult(
            items: items,
            isIncomplete: false,
            context: context,
            processingTime: 0.001
        )
    }
}

@MainActor
private class MockSlowCompletionProvider: CompletionProvider {
    let id = "slow-provider"
    let supportedLanguages: [Language] = [Language(name: "Swift", identifier: "swift")]
    let triggerCharacters: [String] = []
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Simulate slow operation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return CompletionResult(
            items: [],
            isIncomplete: false,
            context: context,
            processingTime: 2.0
        )
    }
}
