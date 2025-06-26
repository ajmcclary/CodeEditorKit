@testable import CodeEditorPlugin
import XCTest

@MainActor
final class PluginArchitectureTests: XCTestCase {
    private var pluginManager: PluginManager!
    private var mockPlugin: MockLanguagePlugin!
    
    override func setUp() {
        super.setUp()
        pluginManager = PluginManager.shared
        mockPlugin = MockLanguagePlugin()
        
        // Clear any existing plugins for clean test state
        for plugin in pluginManager.allPlugins {
            await pluginManager.unregisterPlugin(plugin.identifier)
        }
    }
    
    override func tearDown() {
        // Clean up test plugins
        Task {
            await pluginManager.unregisterPlugin(mockPlugin.identifier)
        }
        mockPlugin = nil
        super.tearDown()
    }
    
    // MARK: - PluginManager Tests
    
    func testPluginManagerSingleton() {
        let manager1 = PluginManager.shared
        let manager2 = PluginManager.shared
        XCTAssertTrue(manager1 === manager2, "PluginManager should be a singleton")
    }
    
    func testPluginRegistration() async throws {
        XCTAssertFalse(pluginManager.allPlugins.contains { $0.identifier == mockPlugin.identifier })
        
        try await pluginManager.registerPlugin(mockPlugin)
        
        XCTAssertTrue(pluginManager.allPlugins.contains { $0.identifier == mockPlugin.identifier })
        XCTAssertNotNil(pluginManager.plugin(withIdentifier: mockPlugin.identifier))
    }
    
    func testPluginUnregistration() async throws {
        try await pluginManager.registerPlugin(mockPlugin)
        XCTAssertNotNil(pluginManager.plugin(withIdentifier: mockPlugin.identifier))
        
        await pluginManager.unregisterPlugin(mockPlugin.identifier)
        
        XCTAssertNil(pluginManager.plugin(withIdentifier: mockPlugin.identifier))
        XCTAssertFalse(pluginManager.allPlugins.contains { $0.identifier == mockPlugin.identifier })
    }
    
    func testPluginActivation() async throws {
        try await pluginManager.registerPlugin(mockPlugin)
        
        XCTAssertFalse(pluginManager.isPluginActive(mockPlugin.identifier))
        
        try await pluginManager.enablePlugin(mockPlugin.identifier)
        
        XCTAssertTrue(pluginManager.isPluginActive(mockPlugin.identifier))
        XCTAssertTrue(mockPlugin.isActivated)
    }
    
    func testPluginDeactivation() async throws {
        try await pluginManager.registerPlugin(mockPlugin)
        try await pluginManager.enablePlugin(mockPlugin.identifier)
        
        XCTAssertTrue(pluginManager.isPluginActive(mockPlugin.identifier))
        
        await pluginManager.disablePlugin(mockPlugin.identifier)
        
        XCTAssertFalse(pluginManager.isPluginActive(mockPlugin.identifier))
        XCTAssertTrue(mockPlugin.isDeactivated)
    }
    
    func testPluginVersionConflict() async throws {
        try await pluginManager.registerPlugin(mockPlugin)
        
        // Try to register plugin with same ID but different version
        let conflictingPlugin = MockLanguagePlugin()
        conflictingPlugin.pluginVersionOverride = "2.0.0"
        
        // Should replace the existing plugin
        try await pluginManager.registerPlugin(conflictingPlugin)
        
        let registeredPlugin = pluginManager.plugin(withIdentifier: mockPlugin.identifier)
        XCTAssertEqual(registeredPlugin?.pluginVersion, "2.0.0")
    }
    
    func testPluginAlreadyRegisteredError() async throws {
        try await pluginManager.registerPlugin(mockPlugin)
        
        // Try to register the exact same plugin again
        do {
            try await pluginManager.registerPlugin(mockPlugin)
            XCTFail("Should throw alreadyRegistered error")
        } catch PluginError.alreadyRegistered(let pluginId) {
            XCTAssertEqual(pluginId, mockPlugin.identifier)
        }
    }
    
    func testPluginNotFoundError() async throws {
        do {
            try await pluginManager.enablePlugin("non-existent-plugin")
            XCTFail("Should throw notFound error")
        } catch PluginError.notFound(let pluginId) {
            XCTAssertEqual(pluginId, "non-existent-plugin")
        }
    }
    
    func testPluginCompatibilityValidation() async throws {
        let incompatiblePlugin = IncompatibleMockPlugin()
        
        do {
            try await pluginManager.registerPlugin(incompatiblePlugin)
            XCTFail("Should throw incompatible error")
        } catch PluginError.incompatible(let pluginId, let reason) {
            XCTAssertEqual(pluginId, incompatiblePlugin.identifier)
            XCTAssertFalse(reason.isEmpty)
        }
    }
    
    // MARK: - Feature Provider Tests
    
    func testFeatureProviderRegistration() async throws {
        try await pluginManager.registerPlugin(mockPlugin)
        try await pluginManager.enablePlugin(mockPlugin.identifier)
        
        let language = Language(name: "Mock", identifier: "mock")
        
        // Test completion providers
        let completionProviders = pluginManager.completionProviders(for: language)
        XCTAssertFalse(completionProviders.isEmpty)
        
        // Test formatters
        let formatters = pluginManager.formatters(for: language)
        XCTAssertFalse(formatters.isEmpty)
        
        // Test linters
        let linters = pluginManager.linters(for: language)
        XCTAssertTrue(linters.isEmpty) // Mock plugin doesn't provide linter
        
        // Test documentation providers
        let docProviders = pluginManager.documentationProviders(for: language)
        XCTAssertTrue(docProviders.isEmpty) // Mock plugin doesn't provide doc provider
    }
    
    func testFeatureProviderUnregistration() async throws {
        try await pluginManager.registerPlugin(mockPlugin)
        try await pluginManager.enablePlugin(mockPlugin.identifier)
        
        let language = Language(name: "Mock", identifier: "mock")
        XCTAssertFalse(pluginManager.completionProviders(for: language).isEmpty)
        
        await pluginManager.disablePlugin(mockPlugin.identifier)
        
        XCTAssertTrue(pluginManager.completionProviders(for: language).isEmpty)
    }
    
    // MARK: - Plugin Capabilities Tests
    
    func testPluginCapabilities() {
        let capabilities = PluginCapabilities(
            syntaxHighlighting: true,
            codeCompletion: true,
            codeFormatting: true,
            linting: false,
            documentationLookup: false,
            symbolNavigation: true
        )
        
        XCTAssertTrue(capabilities.supportsSyntaxHighlighting)
        XCTAssertTrue(capabilities.supportsCodeCompletion)
        XCTAssertTrue(capabilities.supportsCodeFormatting)
        XCTAssertFalse(capabilities.supportsLinting)
        XCTAssertFalse(capabilities.supportsDocumentationLookup)
        XCTAssertTrue(capabilities.supportsSymbolNavigation)
    }
    
    func testPluginCapabilitiesDefaults() {
        let capabilities = PluginCapabilities()
        
        XCTAssertTrue(capabilities.supportsSyntaxHighlighting) // Default true
        XCTAssertFalse(capabilities.supportsCodeCompletion) // Default false
        XCTAssertFalse(capabilities.supportsCodeFormatting) // Default false
    }
    
    // MARK: - Plugin Validation Tests
    
    func testPluginValidationCompatible() {
        let result = mockPlugin.validateCompatibility(editorVersion: "1.0.0")
        XCTAssertEqual(result, .compatible)
    }
    
    func testPluginValidationIncompatible() {
        let plugin = IncompatibleMockPlugin()
        let result = plugin.validateCompatibility(editorVersion: "0.5.0")
        
        if case .incompatible(let reason) = result {
            XCTAssertFalse(reason.isEmpty)
        } else {
            XCTFail("Should return incompatible result")
        }
    }
    
    // MARK: - Plugin Utilities Tests
    
    func testVersionComparison() {
        XCTAssertEqual(PluginUtilities.compareVersions("1.0.0", "1.0.0"), .orderedSame)
        XCTAssertEqual(PluginUtilities.compareVersions("1.0.0", "1.0.1"), .orderedAscending)
        XCTAssertEqual(PluginUtilities.compareVersions("1.1.0", "1.0.0"), .orderedDescending)
        XCTAssertEqual(PluginUtilities.compareVersions("2.0.0", "1.9.9"), .orderedDescending)
    }
    
    func testVersionRequirementCheck() {
        XCTAssertTrue(PluginUtilities.versionMeetsRequirement("1.0.0", minimum: "1.0.0"))
        XCTAssertTrue(PluginUtilities.versionMeetsRequirement("1.1.0", minimum: "1.0.0"))
        XCTAssertFalse(PluginUtilities.versionMeetsRequirement("0.9.0", minimum: "1.0.0"))
        XCTAssertTrue(PluginUtilities.versionMeetsRequirement("2.0.0", minimum: "1.0.0"))
    }
    
    func testDefaultPluginDirectories() {
        let directories = PluginUtilities.defaultPluginDirectories()
        XCTAssertFalse(directories.isEmpty)
        
        // Should contain application support directory
        XCTAssertTrue(directories.contains { $0.path.contains("CodeEditor/Plugins") })
        
        // Should contain home directory
        XCTAssertTrue(directories.contains { $0.path.contains(".codeeditor/plugins") })
    }
    
    // MARK: - Plugin Types Tests
    
    func testPluginManifest() {
        let manifest = PluginManifest(
            identifier: "test-plugin",
            displayName: "Test Plugin",
            version: "1.0.0",
            requiredEditorVersion: "1.0.0",
            author: "Test Author",
            description: "A test plugin",
            license: "MIT",
            fileExtensions: ["test"],
            capabilities: PluginCapabilities(),
            entryPoint: PluginEntryPoint(
                type: .swift,
                entry: "TestPlugin",
                runtime: .native
            )
        )
        
        XCTAssertEqual(manifest.identifier, "test-plugin")
        XCTAssertEqual(manifest.displayName, "Test Plugin")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.fileExtensions, ["test"])
        XCTAssertEqual(manifest.entryPoint.type, .swift)
    }
    
    func testTextEdit() {
        let range = NSRange(location: 5, length: 3)
        let textEdit = TextEdit(range: range, newText: "replacement", description: "Test edit")
        
        XCTAssertEqual(textEdit.range, range)
        XCTAssertEqual(textEdit.newText, "replacement")
        XCTAssertEqual(textEdit.description, "Test edit")
    }
    
    func testTextEditEquality() {
        let range = NSRange(location: 5, length: 3)
        let edit1 = TextEdit(range: range, newText: "test")
        let edit2 = TextEdit(range: range, newText: "test")
        let edit3 = TextEdit(range: range, newText: "different")
        
        XCTAssertEqual(edit1, edit2)
        XCTAssertNotEqual(edit1, edit3)
    }
    
    // MARK: - Language Features Tests
    
    func testFormattingOptions() {
        var options = FormattingOptions()
        XCTAssertEqual(options.tabSize, 4)
        XCTAssertTrue(options.insertSpaces)
        XCTAssertTrue(options.trimTrailingWhitespace)
        XCTAssertTrue(options.insertFinalNewline)
        XCTAssertEqual(options.indentStyle, .spaces)
        
        options.tabSize = 2
        options.insertSpaces = false
        XCTAssertEqual(options.tabSize, 2)
        XCTAssertFalse(options.insertSpaces)
    }
    
    func testLintIssue() {
        let range = NSRange(location: 10, length: 5)
        let fix = LintFix(title: "Fix this", textEdits: [])
        let issue = LintIssue(
            range: range,
            severity: .error,
            message: "Test error",
            ruleId: "test-rule",
            fixes: [fix]
        )
        
        XCTAssertEqual(issue.range, range)
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(issue.message, "Test error")
        XCTAssertEqual(issue.ruleId, "test-rule")
        XCTAssertEqual(issue.fixes.count, 1)
        XCTAssertFalse(issue.id.isEmpty)
    }
    
    func testDocumentationResult() {
        let examples = [CodeExample(code: "let x = 1", language: "swift")]
        let result = DocumentationResult(
            content: "Test documentation",
            format: .markdown,
            language: "swift",
            examples: examples
        )
        
        XCTAssertEqual(result.content, "Test documentation")
        XCTAssertEqual(result.format, .markdown)
        XCTAssertEqual(result.language, "swift")
        XCTAssertEqual(result.examples.count, 1)
    }
    
    func testSymbolKinds() {
        XCTAssertEqual(SymbolKind.function.rawValue, "function")
        XCTAssertEqual(SymbolKind.class.rawValue, "class")
        XCTAssertEqual(SymbolKind.variable.rawValue, "variable")
        
        // Test all cases are covered
        XCTAssertFalse(SymbolKind.allCases.isEmpty)
        XCTAssertTrue(SymbolKind.allCases.contains(.function))
    }
    
    // MARK: - Performance Tests
    
    func testPluginActivationPerformance() throws {
        measure {
            let expectation = self.expectation(description: "Plugin activation")
            Task {
                do {
                    let plugin = MockLanguagePlugin()
                    try await pluginManager.registerPlugin(plugin)
                    try await pluginManager.enablePlugin(plugin.identifier)
                    await pluginManager.disablePlugin(plugin.identifier)
                    await pluginManager.unregisterPlugin(plugin.identifier)
                    expectation.fulfill()
                } catch {
                    XCTFail("Plugin operations failed: \(error)")
                }
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testMultiplePluginManagement() async throws {
        let plugins = (0..<10).map { MockLanguagePlugin(identifier: "plugin-\($0)") }
        
        // Register all plugins
        for plugin in plugins {
            try await pluginManager.registerPlugin(plugin)
        }
        
        XCTAssertEqual(pluginManager.allPlugins.count, plugins.count)
        
        // Activate all plugins
        for plugin in plugins {
            try await pluginManager.enablePlugin(plugin.identifier)
        }
        
        XCTAssertEqual(pluginManager.activePluginList.count, plugins.count)
        
        // Deactivate all plugins
        for plugin in plugins {
            await pluginManager.disablePlugin(plugin.identifier)
            await pluginManager.unregisterPlugin(plugin.identifier)
        }
        
        XCTAssertTrue(pluginManager.allPlugins.isEmpty)
    }
}

// MARK: - Mock Plugin Classes

@MainActor
private class MockLanguagePlugin: LanguagePlugin {
    let identifier: String
    let displayName = "Mock Plugin"
    let fileExtensions = ["mock"]
    var pluginVersionOverride: String?
    
    var isActivated = false
    var isDeactivated = false
    
    init(identifier: String = "mock-plugin") {
        self.identifier = identifier
    }
    
    var pluginVersion: String {
        pluginVersionOverride ?? "1.0.0"
    }
    
    let requiredEditorVersion = "1.0.0"
    let author = "Test Author"
    let description = "A mock plugin for testing"
    let license = "MIT"
    
    var capabilities: PluginCapabilities {
        PluginCapabilities(
            syntaxHighlighting: true,
            codeCompletion: true,
            codeFormatting: true
        )
    }
    
    nonisolated var documentationURL: URL? {
        URL(string: "https://example.com")
    }
    
    func createHighlighter() -> any SyntaxHighlighter {
        MockSyntaxHighlighter()
    }
    
    nonisolated func completionKeywords() -> [String] {
        ["mock", "test", "plugin"]
    }
    
    func createCompletionProvider() -> (any CompletionProvider)? {
        MockCompletionProvider(id: "\(identifier)-completion")
    }
    
    func createFormatter() -> (any CodeFormatter)? {
        MockCodeFormatter()
    }
    
    func activate() async throws {
        isActivated = true
    }
    
    func deactivate() async {
        isDeactivated = true
    }
    
    nonisolated func validateCompatibility(editorVersion _: String) -> PluginValidationResult {
        .compatible
    }
}

@MainActor
private class IncompatibleMockPlugin: LanguagePlugin {
    let identifier = "incompatible-plugin"
    let displayName = "Incompatible Plugin"
    let fileExtensions = ["incompatible"]
    let pluginVersion = "1.0.0"
    let requiredEditorVersion = "99.0.0" // Impossibly high version
    let author = "Test Author"
    let description = "An incompatible plugin for testing"
    let license = "MIT"
    
    nonisolated var documentationURL: URL? { nil }
    
    func createHighlighter() -> any SyntaxHighlighter {
        MockSyntaxHighlighter()
    }
    
    nonisolated func completionKeywords() -> [String] { [] }
    
    func activate() async throws {}
    func deactivate() async {}
    
    nonisolated func validateCompatibility(editorVersion _: String) -> PluginValidationResult {
        .incompatible(reason: "Requires editor version \(requiredEditorVersion)")
    }
}

private struct MockSyntaxHighlighter: SyntaxHighlighter {
    func highlight(source _: String) -> [HighlightedToken] {
        []
    }
}

@MainActor
private class MockCodeFormatter: CodeFormatter {
    let id = "mock-formatter"
    let supportedLanguages = [Language(name: "Mock", identifier: "mock")]
    let supportsRangeFormatting = true
    
    func format(source: String, options _: FormattingOptions) async throws -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func formatRange(source: String, range: NSRange, options _: FormattingOptions) async throws -> String {
        let substring = (source as NSString).substring(with: range)
        return substring.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func defaultOptions() -> FormattingOptions {
        FormattingOptions()
    }
}
