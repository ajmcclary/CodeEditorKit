@testable import CodeEditorPlugin
import XCTest

@MainActor
final class PerformanceBenchmarkTests: XCTestCase {
    private var completionManager: CompletionManager!
    private var pluginManager: PluginManager!
    
    override func setUp() {
        super.setUp()
        Task { @MainActor in
            completionManager = CompletionManager()
            pluginManager = PluginManager.shared
            
            // Clear existing plugins
            for plugin in pluginManager.allPlugins {
                await pluginManager.unregisterPlugin(plugin.identifier)
            }
        }
    }
    
    override func tearDown() {
        Task { @MainActor in
            completionManager = nil
        }
        super.tearDown()
    }
    
    // MARK: - Completion Performance Tests
    
    func testCompletionPerformanceSmallFile() throws {
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        let smallSourceCode = """
        import Foundation
        
        class TestClass {
            func test() {
                let x = String.
            }
        }
        """
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: smallSourceCode,
            cursorPosition: smallSourceCode.count - 1,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        measure {
            let expectation = self.expectation(description: "Small file completion")
            Task {
                do {
                    _ = try await completionManager.requestCompletions(for: context)
                    expectation.fulfill()
                } catch {
                    XCTFail("Completion failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testCompletionPerformanceLargeFile() throws {
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        // Generate a large Swift file
        var largeSourceCode = "import Foundation\n\n"
        for i in 0..<1_000 {
            largeSourceCode += """
            class TestClass\(i) {
                var property\(i): String = "test"
                func method\(i)() -> Int { return \(i) }
            }
            
            """
        }
        largeSourceCode += "let x = String."
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: largeSourceCode,
            cursorPosition: largeSourceCode.count - 1,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        measure {
            let expectation = self.expectation(description: "Large file completion")
            Task {
                do {
                    _ = try await completionManager.requestCompletions(for: context)
                    expectation.fulfill()
                } catch {
                    XCTFail("Completion failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    func testCompletionPerformanceMultipleProviders() throws {
        // Register multiple completion providers
        for i in 0..<20 {
            completionManager.registerProvider(BenchmarkCompletionProvider(id: "provider\(i)"))
        }
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: "test code",
            cursorPosition: 9,
            language: language
        )
        
        measure {
            let expectation = self.expectation(description: "Multiple providers completion")
            Task {
                do {
                    _ = try await completionManager.requestCompletions(for: context)
                    expectation.fulfill()
                } catch {
                    XCTFail("Completion failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testCompletionDeduplicationPerformance() throws {
        // Create providers that return many duplicate items
        for i in 0..<10 {
            completionManager.registerProvider(DuplicateCompletionProvider(id: "dup-provider\(i)"))
        }
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: "test",
            cursorPosition: 4,
            language: language
        )
        
        measure {
            let expectation = self.expectation(description: "Deduplication performance")
            Task {
                do {
                    let result = try await completionManager.requestCompletions(for: context)
                    // Verify deduplication worked
                    let labels = result.items.map { $0.label }
                    let uniqueLabels = Set(labels)
                    XCTAssertEqual(labels.count, uniqueLabels.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Completion failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    // MARK: - Plugin System Performance Tests
    
    func testPluginRegistrationPerformance() throws {
        let plugins = (0..<100).map { BenchmarkLanguagePlugin(identifier: "plugin\(i)") }
        
        measure {
            let expectation = self.expectation(description: "Plugin registration")
            Task {
                do {
                    for plugin in plugins {
                        try await pluginManager.registerPlugin(plugin)
                    }
                    
                    // Clean up
                    for plugin in plugins {
                        await pluginManager.unregisterPlugin(plugin.identifier)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Plugin registration failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    func testPluginActivationPerformance() throws {
        let plugins = (0..<50).map { BenchmarkLanguagePlugin(identifier: "plugin\(i)") }
        
        // Pre-register plugins
        let setupExpectation = expectation(description: "Setup plugins")
        Task {
            do {
                for plugin in plugins {
                    try await pluginManager.registerPlugin(plugin)
                }
                setupExpectation.fulfill()
            } catch {
                XCTFail("Setup failed: \(error)")
            }
        }
        wait(for: [setupExpectation], timeout: 2.0)
        
        measure {
            let expectation = self.expectation(description: "Plugin activation")
            Task {
                do {
                    // Activate all plugins
                    for plugin in plugins {
                        try await pluginManager.enablePlugin(plugin.identifier)
                    }
                    
                    // Deactivate all plugins
                    for plugin in plugins {
                        await pluginManager.disablePlugin(plugin.identifier)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Plugin activation failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 3.0)
        }
        
        // Clean up
        let cleanupExpectation = expectation(description: "Cleanup plugins")
        Task {
            for plugin in plugins {
                await pluginManager.unregisterPlugin(plugin.identifier)
            }
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 2.0)
    }
    
    func testFeatureProviderLookupPerformance() throws {
        // Register many plugins with feature providers
        let plugins = (0..<100).map { BenchmarkLanguagePlugin(identifier: "plugin\(i)") }
        
        let setupExpectation = expectation(description: "Setup plugins")
        Task {
            do {
                for plugin in plugins {
                    try await pluginManager.registerPlugin(plugin)
                    try await pluginManager.enablePlugin(plugin.identifier)
                }
                setupExpectation.fulfill()
            } catch {
                XCTFail("Setup failed: \(error)")
            }
        }
        wait(for: [setupExpectation], timeout: 5.0)
        
        let language = Language(name: "Benchmark", identifier: "benchmark")
        
        measure {
            // Test looking up various feature providers
            _ = pluginManager.completionProviders(for: language)
            _ = pluginManager.formatters(for: language)
            _ = pluginManager.linters(for: language)
            _ = pluginManager.documentationProviders(for: language)
            _ = pluginManager.symbolProviders(for: language)
            _ = pluginManager.indentationProviders(for: language)
        }
        
        // Clean up
        let cleanupExpectation = expectation(description: "Cleanup plugins")
        Task {
            for plugin in plugins {
                await pluginManager.disablePlugin(plugin.identifier)
                await pluginManager.unregisterPlugin(plugin.identifier)
            }
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 5.0)
    }
    
    // MARK: - Syntax Highlighting Performance Tests
    
    func testSyntaxHighlightingPerformanceSmallFile() throws {
        let coordinator = SyntaxHighlightingCoordinator()
        let smallCode = """
        import Foundation
        
        func test() {
            let x = "Hello, World!"
            print(x)
        }
        """
        
        measure {
            _ = coordinator.highlight(source: smallCode, language: .swift)
        }
    }
    
    func testSyntaxHighlightingPerformanceLargeFile() throws {
        let coordinator = SyntaxHighlightingCoordinator()
        
        // Generate large Swift file
        var largeCode = "import Foundation\n\n"
        for i in 0..<5_000 {
            largeCode += """
            func function\(i)() {
                let variable\(i) = "string\(i)"
                let number\(i) = \(i)
                if number\(i) > 0 {
                    print(variable\(i))
                }
            }
            
            """
        }
        
        measure {
            _ = coordinator.highlight(source: largeCode, language: .swift)
        }
    }
    
    func testRegexHighlightingPerformance() throws {
        let coordinator = SyntaxHighlightingCoordinator()
        
        // Generate JavaScript code for regex highlighting
        var jsCode = ""
        for i in 0..<1_000 {
            jsCode += """
            function test\(i)() {
                const variable\(i) = "string\(i)";
                const number\(i) = \(i);
                if (number\(i) > 0) {
                    console.log(variable\(i));
                }
                // This is a comment \(i)
                /* Block comment \(i) */
            }
            
            """
        }
        
        measure {
            _ = coordinator.highlight(source: jsCode, language: .regex(RegexSyntaxHighlighter.LanguageDefinition.javascript))
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testCompletionMemoryUsage() throws {
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        let language = Language(name: "Swift", identifier: "swift")
        let context = CompletionContextModel(
            text: "let x = String.",
            cursorPosition: 15,
            language: language
        )
        
        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Memory usage test")
            Task {
                do {
                    for _ in 0..<100 {
                        _ = try await completionManager.requestCompletions(for: context)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Memory test failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPluginMemoryUsage() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Plugin memory usage")
            Task {
                do {
                    let plugins = (0..<50).map { BenchmarkLanguagePlugin(identifier: "memory-plugin\(i)") }
                    
                    // Register and activate plugins
                    for plugin in plugins {
                        try await pluginManager.registerPlugin(plugin)
                        try await pluginManager.enablePlugin(plugin.identifier)
                    }
                    
                    // Use feature providers
                    let language = Language(name: "Benchmark", identifier: "benchmark")
                    for _ in 0..<100 {
                        _ = pluginManager.completionProviders(for: language)
                        _ = pluginManager.formatters(for: language)
                    }
                    
                    // Clean up
                    for plugin in plugins {
                        await pluginManager.disablePlugin(plugin.identifier)
                        await pluginManager.unregisterPlugin(plugin.identifier)
                    }
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Plugin memory test failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }
}

// MARK: - Benchmark Helper Classes

@MainActor
private class BenchmarkCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language] = [Language(name: "Swift", identifier: "swift")]
    let triggerCharacters: [String] = []
    
    init(id: String) {
        self.id = id
    }
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Simulate realistic completion generation
        var items: [CompletionItemModel] = []
        
        for i in 0..<50 {
            items.append(CompletionItemModel(
                label: "item\(i)",
                kind: .function,
                detail: "Detail for item \(i)",
                documentation: "Documentation for item \(i)"
            ))
        }
        
        // Simulate some processing time
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        return CompletionResult(
            items: items,
            isIncomplete: false,
            context: context,
            processingTime: 0.001
        )
    }
}

@MainActor
private class DuplicateCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language] = [Language(name: "Swift", identifier: "swift")]
    let triggerCharacters: [String] = []
    
    init(id: String) {
        self.id = id
    }
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Return many duplicate items to test deduplication performance
        var items: [CompletionItemModel] = []
        
        let duplicateLabels = ["func", "var", "let", "class", "struct", "enum"]
        
        for _ in 0..<100 {
            for label in duplicateLabels {
                items.append(CompletionItemModel(
                    label: label,
                    kind: .keyword
                ))
            }
        }
        
        return CompletionResult(
            items: items,
            isIncomplete: false,
            context: context,
            processingTime: 0.001
        )
    }
}

@MainActor
private class BenchmarkLanguagePlugin: LanguagePlugin {
    let identifier: String
    let displayName: String
    let fileExtensions = ["benchmark"]
    let pluginVersion = "1.0.0"
    let requiredEditorVersion = "1.0.0"
    let author = "Benchmark"
    let description = "Benchmark plugin"
    let license = "MIT"
    
    init(identifier: String) {
        self.identifier = identifier
        self.displayName = "Benchmark Plugin \(identifier)"
    }
    
    var capabilities: PluginCapabilities {
        PluginCapabilities(
            syntaxHighlighting: true,
            codeCompletion: true,
            codeFormatting: true,
            smartIndentation: true
        )
    }
    
    nonisolated var documentationURL: URL? { nil }
    
    func createHighlighter() -> any SyntaxHighlighter {
        BenchmarkSyntaxHighlighter()
    }
    
    nonisolated func completionKeywords() -> [String] {
        ["benchmark", "test", "performance"]
    }
    
    func createCompletionProvider() -> (any CompletionProvider)? {
        BenchmarkCompletionProvider(id: "\(identifier)-completion")
    }
    
    func createFormatter() -> (any CodeFormatter)? {
        BenchmarkFormatter()
    }
    
    func createIndentationProvider() -> (any IndentationProvider)? {
        BenchmarkIndentationProvider()
    }
    
    func activate() async throws {
        // Simulate activation work
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms
    }
    
    func deactivate() async {
        // Simulate deactivation work
        try? await Task.sleep(nanoseconds: 100_000) // 0.1ms
    }
    
    nonisolated func validateCompatibility(editorVersion _: String) -> PluginValidationResult {
        .compatible
    }
}

private struct BenchmarkSyntaxHighlighter: SyntaxHighlighter {
    func highlight(source _: String) -> [HighlightedToken] {
        // Simple benchmark highlighting
        []
    }
}

@MainActor
private class BenchmarkFormatter: CodeFormatter {
    let id = "benchmark-formatter"
    let supportedLanguages = [Language(name: "Benchmark", identifier: "benchmark")]
    let supportsRangeFormatting = true
    
    func format(source: String, options _: FormattingOptions) async throws -> String {
        // Simulate formatting work
        try await Task.sleep(nanoseconds: 500_000) // 0.5ms
        return source
    }
    
    func formatRange(source: String, range: NSRange, options _: FormattingOptions) async throws -> String {
        (source as NSString).substring(with: range)
    }
    
    func defaultOptions() -> FormattingOptions {
        FormattingOptions()
    }
}

@MainActor
private class BenchmarkIndentationProvider: IndentationProvider {
    let id = "benchmark-indentation"
    let supportedLanguages = [Language(name: "Benchmark", identifier: "benchmark")]
    let supportsAutomaticIndentation = true
    
    func indentationForNewLine(after _: String, in _: String, at _: Int) -> Int {
        0
    }
    
    func indentationForLine(at _: Int, in _: String) -> Int {
        0
    }
}
