import Foundation

/// Configuration for remote LSP server connections
///
/// Defines how to connect to and authenticate with remote Language Server Protocol
/// servers, enabling LSP functionality on platforms without local process support.
///
/// ## Example Usage
/// ```swift
/// let config = RemoteLSPConfiguration(
///     serverURL: URL(string: "wss://lsp.example.com/swift")!,
///     authentication: .bearerToken("secret-token"),
///     reconnectPolicy: .exponentialBackoff(maxAttempts: 5)
/// )
/// ```
@available(macOS 10.15, iOS 13.0, *)
public struct RemoteLSPConfiguration: Sendable, Codable {
    /// The WebSocket URL of the remote LSP server
    public let serverURL: URL
    
    /// Authentication method for the server
    public let authentication: LSPAuthentication?
    
    /// Policy for handling disconnections
    public let reconnectPolicy: ReconnectPolicy
    
    /// Custom headers to send with the connection
    public let customHeaders: [String: String]
    
    /// Transport configuration overrides
    public let transportConfiguration: LSPTransportConfiguration?
    
    /// Whether to validate SSL certificates (for wss:// connections)
    public let validateSSLCertificates: Bool
    
    public init(
        serverURL: URL,
        authentication: LSPAuthentication? = nil,
        reconnectPolicy: ReconnectPolicy = .exponentialBackoff(maxAttempts: 3),
        customHeaders: [String: String] = [:],
        transportConfiguration: LSPTransportConfiguration? = nil,
        validateSSLCertificates: Bool = true
    ) {
        self.serverURL = serverURL
        self.authentication = authentication
        self.reconnectPolicy = reconnectPolicy
        self.customHeaders = customHeaders
        self.transportConfiguration = transportConfiguration
        self.validateSSLCertificates = validateSSLCertificates
    }
}

/// Authentication methods for remote LSP servers
@available(macOS 10.15, iOS 13.0, *)
public enum LSPAuthentication: Sendable, Codable {
    /// No authentication required
    case noAuth
    
    /// Bearer token authentication
    case bearerToken(String)
    
    /// Basic authentication with username and password
    case basic(username: String, password: String)
    
    /// API key authentication
    case apiKey(key: String, headerName: String = "X-API-Key")
    
    /// Custom authentication headers
    case custom(headers: [String: String])
    
    /// OAuth2 token (requires separate token management)
    case oauth2(accessToken: String)
    
    /// Get the authentication headers
    public var headers: [String: String] {
        switch self {
        case .noAuth:
            return [:]

        case let .bearerToken(token):
            return ["Authorization": "Bearer \(token)"]

        case let .basic(username, password):
            let credentials = "\(username):\(password)"
            guard let data = credentials.data(using: .utf8) else { return [:] }
            let base64 = data.base64EncodedString()
            return ["Authorization": "Basic \(base64)"]

        case let .apiKey(key, headerName):
            return [headerName: key]

        case let .custom(headers):
            return headers

        case let .oauth2(accessToken):
            return ["Authorization": "Bearer \(accessToken)"]
        }
    }
}

/// Policy for reconnecting to remote LSP servers
@available(macOS 10.15, iOS 13.0, *)
public enum ReconnectPolicy: Sendable, Codable {
    /// Never attempt to reconnect
    case never
    
    /// Reconnect immediately on disconnection
    case immediate
    
    /// Exponential backoff with maximum attempts
    case exponentialBackoff(maxAttempts: Int, initialDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 60.0)
    
    /// Fixed delay between attempts
    case fixedDelay(attempts: Int, delay: TimeInterval)
    
    /// Convert to transport configuration
    public var transportConfig: (autoReconnect: Bool, maxAttempts: Int, delay: TimeInterval) {
        switch self {
        case .never:
            return (false, 0, 0)

        case .immediate:
            return (true, Int.max, 0)

        case let .exponentialBackoff(maxAttempts, initialDelay, _):
            return (true, maxAttempts, initialDelay)

        case let .fixedDelay(attempts, delay):
            return (true, attempts, delay)
        }
    }
}

/// Extended server configuration that includes both local and remote options
@available(macOS 10.15, iOS 13.0, *)
public enum LSPServerConfiguration: Sendable {
    /// Local server (macOS only)
    case local(LocalLSPConfiguration)
    
    /// Remote server (all platforms)
    case remote(RemoteLSPConfiguration)
    
    /// Create appropriate transport based on configuration
    public func createTransport() async throws -> LSPTransport {
        switch self {
        case .local(let config):
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return ProcessTransport(
                executablePath: config.executablePath,
                arguments: config.arguments,
                workingDirectory: config.workingDirectory,
                environment: config.environment
            )
            #else
            throw LSPTransportError.transportSpecific(
                message: "Local LSP servers are not supported on this platform"
            )
            #endif
            
        case .remote(let config):
            var headers = config.customHeaders
            
            // Add authentication headers
            if let auth = config.authentication {
                headers.merge(auth.headers) { _, new in new }
            }
            
            let transportConfig = config.transportConfiguration ?? {
                let policy = config.reconnectPolicy.transportConfig
                return LSPTransportConfiguration(
                    autoReconnect: policy.autoReconnect,
                    maxReconnectAttempts: policy.maxAttempts,
                    reconnectDelay: policy.delay
                )
            }()
            
            return WebSocketTransport(
                url: config.serverURL,
                headers: headers,
                configuration: transportConfig
            )
        }
    }
}

/// Configuration for local LSP servers
@available(macOS 10.15, iOS 13.0, *)
public struct LocalLSPConfiguration: Sendable, Codable {
    /// Path to the LSP server executable
    public let executablePath: String
    
    /// Command line arguments
    public let arguments: [String]
    
    /// Working directory for the server
    public let workingDirectory: URL?
    
    /// Environment variables
    public let environment: [String: String]
    
    public init(
        executablePath: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

// MARK: - Convenience Extensions

extension RemoteLSPConfiguration {
    /// Create a configuration for a public LSP server with no authentication
    public static func publicServer(url: URL) -> RemoteLSPConfiguration {
        RemoteLSPConfiguration(
            serverURL: url,
            authentication: .noAuth,
            reconnectPolicy: .exponentialBackoff(maxAttempts: 5)
        )
    }
    
    /// Create a configuration for a private server with bearer token
    public static func privateServer(url: URL, token: String) -> RemoteLSPConfiguration {
        RemoteLSPConfiguration(
            serverURL: url,
            authentication: .bearerToken(token),
            reconnectPolicy: .exponentialBackoff(maxAttempts: 5)
        )
    }
}
