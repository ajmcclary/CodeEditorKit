// LSP types are available on all platforms to support remote LSP connections

import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Configuration Types

/// Configuration for a language server.
///
/// Defines how to start and communicate with a language server for a specific
/// programming language.
///
/// ## Example
///
/// ```swift
/// let config = LanguageServerConfig(
///     languageId: "python",
///     serverPath: "/usr/local/bin/pylsp",
///     fileExtensions: ["py", "pyw"],
///     serverArguments: ["--log-file", "/tmp/pylsp.log"],
///     capabilities: .init(completion: true, hover: true),
///     autoStart: true
/// )
/// ```
public struct LanguageServerConfig: Sendable {
    public let languageId: String
    public let serverPath: String
    public let serverArguments: [String]
    public let fileExtensions: [String]
    public let capabilities: ClientCapabilities
    public let autoStart: Bool
    public let enablePathResolution: Bool
    
    public init(
        languageId: String,
        serverPath: String,
        fileExtensions: [String],
        serverArguments: [String] = [],
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        enablePathResolution: Bool = true
    ) {
        self.languageId = languageId
        self.serverPath = serverPath
        self.serverArguments = serverArguments
        self.fileExtensions = fileExtensions
        self.capabilities = capabilities
        self.autoStart = autoStart
        self.enablePathResolution = enablePathResolution
    }
}

// MARK: - Document Types

/// Represents an open document in the LSP manager
struct OpenDocument {
    let uri: String
    let languageId: String
    var version: Int
    let filePath: String
    
    mutating func incrementVersion() {
        version += 1
    }
}

// MARK: - Completion Types

@MainActor
public struct LSPManagerCompletionItem: CompletionItemView {
    public let item: any CompletionItemView
    public let languageId: String
    public let client: LSPClient
    
    nonisolated public var id: String { 
        // Generate a unique ID based on item properties
        "\(languageId)-\(UUID().uuidString)"
    }
    
    public var view: PlatformView { item.view }
    
    public init(item: any CompletionItemView, languageId: String, client: LSPClient) {
        self.item = item
        self.languageId = languageId
        self.client = client
    }
}
