import Foundation

// MARK: - LanguagePlugin Protocol

/// Enhanced protocol for comprehensive language support plugins
@MainActor
public protocol LanguagePlugin: LanguageProvider {
    // MARK: - Plugin Metadata
    
    /// Plugin version (semantic versioning)
    var pluginVersion: String { get }
    
    /// Minimum required editor version
    var requiredEditorVersion: String { get }
    
    /// Plugin author information
    var author: String { get }
    
    /// Plugin description
    var description: String { get }
    
    /// Plugin license
    var license: String { get }
    
    /// Plugin capabilities flags
    var capabilities: PluginCapabilities { get }
    
    // MARK: - Advanced Language Features
    
    /// Create a completion provider for this language (optional)
    @MainActor
    func createCompletionProvider() -> (any CompletionProvider)?
    
    /// Create a code formatter for this language (optional)
    @MainActor
    func createFormatter() -> (any CodeFormatter)?
    
    /// Create a code linter for this language (optional)
    @MainActor
    func createLinter() -> (any CodeLinter)?
    
    /// Create a documentation provider for this language (optional)
    @MainActor
    func createDocumentationProvider() -> (any DocumentationProvider)?
    
    /// Create a symbol provider for this language (optional)
    @MainActor
    func createSymbolProvider() -> (any SymbolProvider)?
    
    /// Create an indentation provider for this language (optional)
    @MainActor
    func createIndentationProvider() -> (any IndentationProvider)?
    
    // MARK: - Language Server Protocol Support
    
    /// Language server configuration (optional)
    var languageServerConfig: LanguageServerConfig? { get }
    
    /// Create an LSP client for this language (optional)
    @MainActor
    func createLSPClient() -> (any LSPClientProtocol)?
    
    // MARK: - Lifecycle
    
    /// Called when the plugin is activated
    @MainActor
    func activate() async throws
    
    /// Called when the plugin is deactivated
    @MainActor
    func deactivate() async
    
    /// Validate plugin compatibility
    nonisolated func validateCompatibility(editorVersion: String) -> PluginValidationResult
}

// MARK: - Default Implementations

public extension LanguagePlugin {
    var author: String { "Unknown" }
    var description: String { "Language support for \(displayName)" }
    var license: String { "Unknown" }
    var capabilities: PluginCapabilities { PluginCapabilities() }
    var languageServerConfig: LanguageServerConfig? { nil }
    
    @MainActor
    func createCompletionProvider() -> (any CompletionProvider)? { nil }
    
    @MainActor
    func createFormatter() -> (any CodeFormatter)? { nil }
    
    @MainActor
    func createLinter() -> (any CodeLinter)? { nil }
    
    @MainActor
    func createDocumentationProvider() -> (any DocumentationProvider)? { nil }
    
    @MainActor
    func createSymbolProvider() -> (any SymbolProvider)? { nil }
    
    @MainActor
    func createIndentationProvider() -> (any IndentationProvider)? { nil }
    
    @MainActor
    func createLSPClient() -> (any LSPClientProtocol)? { nil }
    
    @MainActor
    func activate() async throws {
        // Default: no activation needed
    }
    
    @MainActor
    func deactivate() async {
        // Default: no deactivation needed
    }
    
    nonisolated func validateCompatibility(editorVersion _: String) -> PluginValidationResult {
        // Simple version check - can be overridden for complex validation
        .compatible
    }
}

// MARK: - Plugin Capabilities

/// Describes what features a plugin supports
public struct PluginCapabilities: Equatable, Codable, Sendable {
    public var supportsSyntaxHighlighting: Bool = true
    public var supportsCodeCompletion: Bool = false
    public var supportsCodeFormatting: Bool = false
    public var supportsLinting: Bool = false
    public var supportsDocumentationLookup: Bool = false
    public var supportsSymbolNavigation: Bool = false
    public var supportsLanguageServer: Bool = false
    public var supportsIncrementalParsing: Bool = false
    public var supportsSmartIndentation: Bool = false
    public var supportsBracketMatching: Bool = false
    public var supportsFolding: Bool = false
    public var supportsRename: Bool = false
    public var supportsGoToDefinition: Bool = false
    public var supportsFindReferences: Bool = false
    
    public init() {}
    
    public init(
        syntaxHighlighting: Bool = true,
        codeCompletion: Bool = false,
        codeFormatting: Bool = false,
        linting: Bool = false,
        documentationLookup: Bool = false,
        symbolNavigation: Bool = false,
        languageServer: Bool = false,
        incrementalParsing: Bool = false,
        smartIndentation: Bool = false,
        bracketMatching: Bool = false,
        folding: Bool = false,
        rename: Bool = false,
        goToDefinition: Bool = false,
        findReferences: Bool = false
    ) {
        self.supportsSyntaxHighlighting = syntaxHighlighting
        self.supportsCodeCompletion = codeCompletion
        self.supportsCodeFormatting = codeFormatting
        self.supportsLinting = linting
        self.supportsDocumentationLookup = documentationLookup
        self.supportsSymbolNavigation = symbolNavigation
        self.supportsLanguageServer = languageServer
        self.supportsIncrementalParsing = incrementalParsing
        self.supportsSmartIndentation = smartIndentation
        self.supportsBracketMatching = bracketMatching
        self.supportsFolding = folding
        self.supportsRename = rename
        self.supportsGoToDefinition = goToDefinition
        self.supportsFindReferences = findReferences
    }
}

// MARK: - Plugin Validation

/// Result of plugin validation
public enum PluginValidationResult: Equatable, Sendable {
    case compatible
    case incompatible(reason: String)
    case warning(message: String)
}

// MARK: - Language Server Configuration

/// Configuration for Language Server Protocol integration
public struct LanguageServerConfig: Equatable, Codable, Sendable {
    public let serverPath: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let environmentVariables: [String: String]
    public let initializationOptions: [String: String]
    public let documentSelector: [DocumentFilter]
    public let capabilities: LSPCapabilities
    
    public init(
        serverPath: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environmentVariables: [String: String] = [:],
        initializationOptions: [String: String] = [:],
        documentSelector: [DocumentFilter] = [],
        capabilities: LSPCapabilities = LSPCapabilities()
    ) {
        self.serverPath = serverPath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.initializationOptions = initializationOptions
        self.documentSelector = documentSelector
        self.capabilities = capabilities
    }
}

/// Document filter for LSP
public struct DocumentFilter: Equatable, Codable, Sendable {
    public let language: String?
    public let scheme: String?
    public let pattern: String?
    
    public init(language: String? = nil, scheme: String? = nil, pattern: String? = nil) {
        self.language = language
        self.scheme = scheme
        self.pattern = pattern
    }
}

/// LSP server capabilities
public struct LSPCapabilities: Equatable, Codable, Sendable {
    public var textDocumentSync: Bool = true
    public var completionProvider: Bool = false
    public var hoverProvider: Bool = false
    public var signatureHelpProvider: Bool = false
    public var definitionProvider: Bool = false
    public var referencesProvider: Bool = false
    public var documentHighlightProvider: Bool = false
    public var documentSymbolProvider: Bool = false
    public var workspaceSymbolProvider: Bool = false
    public var codeActionProvider: Bool = false
    public var documentFormattingProvider: Bool = false
    public var documentRangeFormattingProvider: Bool = false
    public var renameProvider: Bool = false
    
    public init() {}
}
