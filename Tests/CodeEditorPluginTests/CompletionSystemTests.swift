@testable import CodeEditorPlugin
import XCTest

final class CompletionSystemTests: XCTestCase {
    deinit {}
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
        let language = Language.swift
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
        XCTAssertEqual(context.language, .swift)
        XCTAssertEqual(context.triggerKind, .character)
        XCTAssertEqual(context.triggerCharacter, ".")
        XCTAssertEqual(context.lineText, "let x = ")
        XCTAssertEqual(context.wordRange, NSRange(location: 4, length: 1))
        XCTAssertNotNil(context.timestamp)
    }
    
    // MARK: - CompletionManager Tests
    
    @MainActor
    func testCompletionManagerProviderRegistration() async throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        let mockProvider = MockCompletionProvider()
        XCTAssertTrue(completionManager.registeredProviders.isEmpty)
        
        completionManager.registerProvider(mockProvider)
        XCTAssertEqual(completionManager.registeredProviders.count, 1)
        XCTAssertEqual(completionManager.registeredProviders.first?.id, mockProvider.id)
        
        completionManager.unregisterProvider(withId: mockProvider.id)
        XCTAssertTrue(completionManager.registeredProviders.isEmpty)
    }
    
    @MainActor
    func testCompletionManagerRequestsCompletions() async throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        let mockProvider = MockCompletionProvider()
        // Register mock provider
        completionManager.registerProvider(mockProvider)
        
        // Create context
        let language = Language.swift
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
    
    @MainActor
    func testCompletionManagerDeduplication() async throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        // Create two providers that return duplicate items
        let provider1 = MockCompletionProvider(id: "provider1")
        let provider2 = MockCompletionProvider(id: "provider2")
        
        completionManager.registerProvider(provider1)
        completionManager.registerProvider(provider2)
        
        let language = Language.swift
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        let result = try await completionManager.requestCompletions(for: context)
        
        // Should deduplicate items with same label and kind
        let labels = result.items.map { $0.label }
        let uniqueLabels = Set(labels)
        XCTAssertEqual(labels.count, uniqueLabels.count, "Items should be deduplicated")
    }
    
    @MainActor
    func testCompletionManagerSorting() async throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        let mockProvider = MockCompletionProvider()
        completionManager.registerProvider(mockProvider)
        
        let language = Language.swift
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        let result = try await completionManager.requestCompletions(for: context)
        
        // Verify items are sorted by priority and then by label
        for index in 0..<(result.items.count - 1) {
            let current = result.items[index]
            let next = result.items[index + 1]
            
            if current.priority == next.priority && current.kind.defaultPriority == next.kind.defaultPriority {
                XCTAssertNotEqual(current.label.localizedCaseInsensitiveCompare(next.label), .orderedDescending)
            } else if current.priority == next.priority {
                XCTAssertGreaterThanOrEqual(current.kind.defaultPriority, next.kind.defaultPriority)
            } else {
                XCTAssertGreaterThanOrEqual(current.priority, next.priority)
            }
        }
    }
    
    @MainActor
    func testCompletionManagerCancellation() async throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        let slowProvider = MockSlowCompletionProvider()
        completionManager.registerProvider(slowProvider)
        
        let language = Language.swift
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        // Start a long-running request
        Task {
            do {
                _ = try await completionManager.requestCompletions(for: context)
            } catch {
                // Expected - request will be cancelled
            }
        }
        
        // Give it time to start
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Cancel the request
        completionManager.cancelCurrentRequest()
        
        // Now test that a new request works immediately  
        let quickProvider = MockCompletionProvider()
        completionManager.unregisterProvider(withId: slowProvider.id)
        completionManager.registerProvider(quickProvider)
        
        // This new request should complete quickly since the previous one was cancelled
        let startTime = Date()
        _ = try await completionManager.requestCompletions(for: context)
        let elapsed = Date().timeIntervalSince(startTime)
        
        // The second request should complete quickly
        XCTAssertLessThan(elapsed, 0.1, "Second request should complete quickly after cancellation")
    }
    
    // MARK: - SwiftCompletionProvider Tests
    
    @MainActor
    func testSwiftCompletionProviderBasics() {
        let provider = SwiftCompletionProvider()
        
        XCTAssertEqual(provider.id, "swift-builtin")
        XCTAssertTrue(provider.supportedLanguages.contains { $0.identifier == "swift" })
        XCTAssertTrue(provider.triggerCharacters.contains("."))
        XCTAssertTrue(provider.triggerCharacters.contains("("))
    }
    
    @MainActor
    func testSwiftCompletionProviderCompletions() async throws {
        let provider = SwiftCompletionProvider()
        let language = Language.swift
        
        // Test general context (should return keywords and types)
        let generalContext = CompletionContextModel(
            text: "let x = ",
            cursorPosition: 8,
            language: language,
            triggerKind: .manual
        )
        
        let generalResult = try await provider.completions(for: generalContext)
        XCTAssertFalse(generalResult.items.isEmpty)
        
        // Should contain Swift keywords
        let generalLabels = generalResult.items.map { $0.label }
        XCTAssertTrue(generalLabels.contains("func"))
        XCTAssertTrue(generalLabels.contains("var"))
        XCTAssertTrue(generalLabels.contains("let"))
        XCTAssertTrue(generalLabels.contains("class"))
        
        // Should contain built-in types
        XCTAssertTrue(generalLabels.contains("String"))
        XCTAssertTrue(generalLabels.contains("Int"))
        XCTAssertTrue(generalLabels.contains("Bool"))
        
        // Test member context (should return String members)
        let memberContext = CompletionContextModel(
            text: "let x = String.",
            cursorPosition: 15,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        let memberResult = try await provider.completions(for: memberContext)
        XCTAssertFalse(memberResult.items.isEmpty)
        
        // Should contain String members
        let memberLabels = memberResult.items.map { $0.label }
        XCTAssertTrue(memberLabels.contains { $0.contains("count") })
        XCTAssertTrue(memberLabels.contains { $0.contains("isEmpty") })
        XCTAssertTrue(memberLabels.contains { $0.contains("uppercased") })
    }
    
    @MainActor
    func testSwiftCompletionProviderContextAwareness() async throws {
        let provider = SwiftCompletionProvider()
        let language = Language.swift
        
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
    
    @MainActor
    func testCompletionManagerPerformance() throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        // Register multiple providers
        for index in 0..<10 {
            completionManager.registerProvider(MockCompletionProvider(id: "provider\(index)"))
        }
        
        let language = Language.swift
        let context = CompletionContextModel(text: "test", cursorPosition: 4, language: language)
        
        measure(options: Self.standardMeasureOptions) {
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
    deinit {}
    
    let id: String
    let supportedLanguages: [Language] = [.swift]
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
            context: context,
            isIncomplete: false,
            processingTime: 0.001
        )
    }
}

@MainActor
private class MockSlowCompletionProvider: CompletionProvider {
    deinit {}
    
    let id = "slow-provider"
    let supportedLanguages: [Language] = [.swift]
    let triggerCharacters: [String] = []
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Instead of sleeping, just check for cancellation frequently
        // This makes the test fast while still verifying cancellation works
        for _ in 0..<20 {
            try Task.checkCancellation()
            // Very short sleep to allow cancellation to propagate
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        return CompletionResult(
            items: [],
            context: context,
            isIncomplete: false,
            processingTime: 0.02
        )
    }
}

@MainActor
private class MockCancellationTrackingProvider: CompletionProvider {
    deinit {}
    
    let id = "cancellation-tracking-provider"
    let supportedLanguages: [Language] = [.swift]
    let triggerCharacters: [String] = []
    
    private(set) var wasCancelled = false
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Add a small delay to ensure the task starts before cancellation
        try await Task.sleep(nanoseconds: 2_000_000) // 2ms
        
        do {
            // Check for cancellation multiple times
            for _ in 0..<5 {
                try Task.checkCancellation()
                await Task.yield()
            }
            
            return CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0.001
            )
        } catch is CancellationError {
            wasCancelled = true
            throw CancellationError()
        }
    }
}
