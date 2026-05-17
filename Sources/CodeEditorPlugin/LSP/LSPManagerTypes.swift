// LSP types are available on all platforms to support remote LSP connections

import CodeEditorPlatform
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
    public let fileExtensions: [String]
    public let capabilities: ClientCapabilities
    public let autoStart: Bool
    public let retryConfiguration: LSPRetryConfiguration

    // Local-server fields. `serverPath == ""` on remote-shaped configs.
    public let serverPath: String
    public let serverArguments: [String]
    public let enablePathResolution: Bool

    // Remote-server fields. `remoteURL == nil` on local-shaped configs.
    public let remoteURL: URL?
    public let remoteHeaders: [String: String]
    public let remoteAuthentication: LSPAuthentication?
    public let remoteTransportConfiguration: LSPTransportConfiguration?

    /// Existing positional initializer — kept for source compatibility.
    /// Constructs a local-shaped config (`remoteURL == nil`).
    public init(
        languageId: String,
        serverPath: String,
        fileExtensions: [String],
        serverArguments: [String] = [],
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        enablePathResolution: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    ) {
        self.languageId = languageId
        self.serverPath = serverPath
        self.serverArguments = serverArguments
        self.fileExtensions = fileExtensions
        self.capabilities = capabilities
        self.autoStart = autoStart
        self.enablePathResolution = enablePathResolution
        self.retryConfiguration = retryConfiguration
        self.remoteURL = nil
        self.remoteHeaders = [:]
        self.remoteAuthentication = nil
        self.remoteTransportConfiguration = nil
    }

    /// Construct a local LSP server configuration. Process-based; macOS only at start time.
    public static func local(
        languageId: String,
        serverPath: String,
        fileExtensions: [String],
        serverArguments: [String] = [],
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        enablePathResolution: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    ) -> Self {
        Self(
            languageId: languageId,
            serverPath: serverPath,
            fileExtensions: fileExtensions,
            serverArguments: serverArguments,
            capabilities: capabilities,
            autoStart: autoStart,
            enablePathResolution: enablePathResolution,
            retryConfiguration: retryConfiguration
        )
    }

    /// Construct a remote LSP server configuration. Uses WebSocket transport on all platforms.
    public static func remote(
        languageId: String,
        url: URL,
        fileExtensions: [String],
        headers: [String: String] = [:],
        authentication: LSPAuthentication? = nil,
        transportConfiguration: LSPTransportConfiguration? = nil,
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    ) -> Self {
        Self(
            languageId: languageId,
            fileExtensions: fileExtensions,
            capabilities: capabilities,
            autoStart: autoStart,
            retryConfiguration: retryConfiguration,
            remoteURL: url,
            remoteHeaders: headers,
            remoteAuthentication: authentication,
            remoteTransportConfiguration: transportConfiguration
        )
    }

    /// Internal designated initializer used by `.remote(...)`. Not public — callers go through the factories.
    private init(
        languageId: String,
        fileExtensions: [String],
        capabilities: ClientCapabilities,
        autoStart: Bool,
        retryConfiguration: LSPRetryConfiguration,
        remoteURL: URL,
        remoteHeaders: [String: String],
        remoteAuthentication: LSPAuthentication?,
        remoteTransportConfiguration: LSPTransportConfiguration?
    ) {
        self.languageId = languageId
        self.serverPath = ""
        self.serverArguments = []
        self.fileExtensions = fileExtensions
        self.capabilities = capabilities
        self.autoStart = autoStart
        self.enablePathResolution = false
        self.retryConfiguration = retryConfiguration
        self.remoteURL = remoteURL
        self.remoteHeaders = remoteHeaders
        self.remoteAuthentication = remoteAuthentication
        self.remoteTransportConfiguration = remoteTransportConfiguration
    }
}

extension LanguageServerConfig {
    /// Translate this configuration into the transport-typed `LSPServerConfiguration`
    /// that `LSPClient.connect(configuration:, languageId:)` consumes.
    ///
    /// - Parameter workspaceRoot: workspace directory used by local-server transports.
    ///   Ignored for remote configurations.
    /// - Throws: `LSPError.serverError` on iOS for local-shaped configurations.
    ///   Local LSP servers require AppKit's `Process` API.
    internal func makeServerConfiguration(workspaceRoot: URL) throws -> LSPServerConfiguration {
        if let remoteURL {
            return .remote(RemoteLSPConfiguration(
                serverURL: remoteURL,
                authentication: remoteAuthentication,
                customHeaders: remoteHeaders,
                transportConfiguration: remoteTransportConfiguration
            ))
        }

        #if canImport(AppKit)
        return .local(LocalLSPConfiguration(
            executablePath: serverPath,
            arguments: serverArguments,
            workingDirectory: workspaceRoot,
            environment: [:]
        ))
        #else
        throw LSPError.serverError(
            code: -1,
            message: "Local language servers require AppKit (macOS). Use LanguageServerConfig.remote(url:) for iOS.",
            data: nil
        )
        #endif
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
