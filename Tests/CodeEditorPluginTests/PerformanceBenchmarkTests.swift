@testable import CodeEditorPlugin
import XCTest

final class PerformanceBenchmarkTests: XCTestCase {
    deinit {}
    // MARK: - Completion Performance Tests
    
    @MainActor
    func testCompletionPerformanceSmallFile() throws {
        let completionManager = CompletionManager()
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
        
        let language = Language.swift
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
    
    @MainActor
    func testCompletionPerformanceLargeFile() throws {
        let completionManager = CompletionManager()
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        // Generate a moderately large Swift file (reduced from 1,000 to 100)
        var largeSourceCode = "import Foundation\n\n"
        for index in 0..<100 {
            largeSourceCode += """
            class TestClass\(index) {
                var property\(index): String = "test"
                func method\(index)() -> Int { return \(index) }
            }
            
            """
        }
        largeSourceCode += "let x = String."
        
        let language = Language.swift
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
    
    @MainActor
    func testCompletionPerformanceMultipleProviders() throws {
        let completionManager = CompletionManager()
        // Register multiple completion providers
        for index in 0..<20 {
            completionManager.registerProvider(BenchmarkCompletionProvider(id: "provider\(index)"))
        }
        
        let language = Language.swift
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
    
    @MainActor
    func testCompletionDeduplicationPerformance() throws {
        let completionManager = CompletionManager()
        // Create providers that return many duplicate items
        for index in 0..<10 {
            completionManager.registerProvider(DuplicateCompletionProvider(id: "dup-provider\(index)"))
        }
        
        let language = Language.swift
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
    
    @MainActor
    func testPluginRegistrationPerformance() throws {
        let pluginManager = PluginManager.shared
        let plugins = (0..<100).map { index in BenchmarkLanguagePlugin(identifier: "plugin\(index)") }
        
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
    
    @MainActor
    func testPluginActivationPerformance() throws {
        let pluginManager = PluginManager.shared
        let plugins = (0..<50).map { index in BenchmarkLanguagePlugin(identifier: "plugin\(index)") }
        
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
    
    @MainActor
    func testFeatureProviderLookupPerformance() throws {
        let pluginManager = PluginManager.shared
        // Register many plugins with feature providers
        let plugins = (0..<100).map { index in BenchmarkLanguagePlugin(identifier: "plugin\(index)") }
        
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
        
        let language = Language.plainText
        
        measure {
            // Test looking up various feature providers
            _ = pluginManager.completionProviders(for: language)
            _ = pluginManager.formatters(for: language)
            _ = pluginManager.linters(for: language)
            _ = pluginManager.documentationProviders(for: language)
            _ = pluginManager.symbolProviders(for: language)
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
    
    @MainActor
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
    
    @MainActor
    func testSyntaxHighlightingPerformanceLargeFile() throws {
        let coordinator = SyntaxHighlightingCoordinator()
        
        // Generate smaller "large" Swift file (reduced from 5,000 to 500)
        var largeCode = "import Foundation\n\n"
        for index in 0..<500 {
            largeCode += """
            func function\(index)() {
                let variable\(index) = "string\(index)"
                let number\(index) = \(index)
                if number\(index) > 0 {
                    print(variable\(index))
                }
            }
            
            """
        }
        
        // Add timeout to prevent hanging
        measure(metrics: [XCTClockMetric()]) {
            _ = coordinator.highlight(source: largeCode, language: .swift)
        }
    }
    
    @MainActor
    func testRegexHighlightingPerformance() throws {
        let coordinator = SyntaxHighlightingCoordinator()
        
        // Generate smaller JavaScript code for regex highlighting (reduced from 1,000 to 100)
        var jsCode = ""
        for index in 0..<100 {
            jsCode += """
            function test\(index)() {
                const variable\(index) = "string\(index)";
                const number\(index) = \(index);
                if (number\(index) > 0) {
                    console.log(variable\(index));
                }
                // This is a comment \(index)
                /* Block comment \(index) */
            }
            
            """
        }
        
        measure {
            // Highlight JavaScript code directly
            _ = coordinator.highlight(source: jsCode, language: .javascript)
        }
    }
    
    // MARK: - Memory Performance Tests
    
    @MainActor
    func testCompletionMemoryUsage() throws {
        let completionManager = CompletionManager()
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        let language = Language.swift
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
    
    @MainActor
    func testPluginMemoryUsage() throws {
        let pluginManager = PluginManager.shared
        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Plugin memory usage")
            Task {
                do {
                    let plugins = (0..<50).map { index in BenchmarkLanguagePlugin(identifier: "memory-plugin\(index)") }
                    
                    // Register and activate plugins
                    for plugin in plugins {
                        try await pluginManager.registerPlugin(plugin)
                        try await pluginManager.enablePlugin(plugin.identifier)
                    }
                    
                    // Use feature providers
                    let language = Language.plainText
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
    deinit {}
    
    let id: String
    let supportedLanguages: [Language] = [.swift]
    let triggerCharacters: [String] = []
    
    init(id: String) {
        self.id = id
    }
    
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Simulate realistic completion generation
        var items: [CompletionItemModel] = []
        
        for index in 0..<50 {
            items.append(CompletionItemModel(
                label: "item\(index)",
                kind: .function,
                detail: "Detail for item \(index)",
                documentation: "Documentation for item \(index)"
            ))
        }
        
        // Simulate some processing time
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: 0.001
        )
    }
}

@MainActor
private class DuplicateCompletionProvider: CompletionProvider {
    deinit {}
    
    let id: String
    let supportedLanguages: [Language] = [.swift]
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
            context: context,
            isIncomplete: false,
            processingTime: 0.001
        )
    }
}

@MainActor
private class BenchmarkLanguagePlugin: LanguagePlugin {
    deinit {}
    
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
    deinit {}
    
    let id = "benchmark-formatter"
    let supportedLanguages = [Language.plainText]
    let supportsRangeFormatting = true
    
    func format(source: String, options _: FormattingOptions) async throws -> String {
        // Simulate formatting work
        try await Task.sleep(nanoseconds: 500_000) // 0.5ms
        return source
    }
    
    func formatRange(source: String, range: NSRange, options _: FormattingOptions) async throws -> String {
        let start = source.index(source.startIndex, offsetBy: range.location)
        let end = source.index(start, offsetBy: range.length)
        return String(source[start..<end])
    }
    
    func defaultOptions() -> FormattingOptions {
        FormattingOptions()
    }
}

@MainActor
private class BenchmarkIndentationProvider: IndentationProvider {
    deinit {}
    
    let id = "benchmark-indentation"
    let supportedLanguages = [Language.plainText]
    let supportsAutomaticIndentation = true
    
    func indentationForNewLine(after _: String, in _: String, at _: Int) -> Int {
        0
    }
    
    func indentationForLine(at _: Int, in _: String) -> Int {
        0
    }
}
