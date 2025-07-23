# LSP System Complete Architecture

This diagram shows the comprehensive Language Server Protocol implementation that provides advanced language features through external language servers, including retry configuration with exponential backoff.

```mermaid
classDiagram
    direction LR
    
    %% Top Row - Core Management
    class LSPManager {
        &lt;&lt;LSP orchestrator&gt;&gt;
        +clients [String: LSPClient]
        +registry LSPClientRegistry
        +documentManager LSPDocumentManager
        +messageHandler LSPMessageHandler
        +pathResolver LSPPathResolver
        +startLanguageServer()
        +stopLanguageServer()
        +getClient()
        +handleDocumentChange()
    }

    class LSPClientRegistry {
        &lt;&lt;client registry&gt;&gt;
        +registeredServers [String: LSPServerConfiguration]
        +activeClients [String: LSPClient]
        +configurationProvider LSPConfigurationProvider
        +register()
        +unregister()
        +getConfiguration()
        +isLanguageSupported()
    }

    class LSPClient {
        &lt;&lt;language client&gt;&gt;
        +serverProcess Process?
        +transport LSPTransport
        +messageHandler LSPMessageHandler
        +documentManager LSPDocumentManager
        +capabilities ServerCapabilities?
        +state LSPClientState
        +retryConfiguration LSPRetryConfiguration
        +initialize()
        +shutdown()
        +sendRequest()
        +sendNotification()
    }

    %% Second Row - Transport Layer
    class LSPTransport {
        &lt;&lt;transport protocol&gt;&gt;
        +isConnected Bool
        +connect()
        +disconnect()
        +sendMessage()
        +onMessageReceived
        +onError
    }

    class ProcessTransport {
        &lt;&lt;stdio transport&gt;&gt;
        +process Process
        +executablePath String
        +arguments [String]
        +workingDirectory String?
        +environment [String: String]
        +startProcess()
        +terminateProcess()
        +writeToStdin()
        +readFromStdout()
    }

    class WebSocketTransport {
        &lt;&lt;websocket transport&gt;&gt;
        +webSocket URLSessionWebSocketTask
        +url URL
        +headers [String: String]
        +tlsConfiguration TLSConfiguration?
        +certificatePinning CertificatePinning?
        +connectWebSocket()
        +closeWebSocket()
        +sendWebSocketMessage()
        +validateCertificate()
    }

    %% Third Row - Document Management & TCP
    class LSPDocumentManager {
        &lt;&lt;document sync&gt;&gt;
        +openDocuments [String: LSPTextDocument]
        +documentVersions [String: Int]
        +synchronizationKind TextDocumentSyncKind
        +openDocument()
        +closeDocument()
        +changeDocument()
        +saveDocument()
        +getDocument()
    }

    class LSPTextDocument {
        &lt;&lt;text document&gt;&gt;
        +uri String
        +languageId String
        +version Int
        +text String
        +isDirty Bool
        +lastSyncedVersion Int
        +applyChanges()
        +getTextInRange()
        +positionToOffset()
    }

    class TCPTransport {
        &lt;&lt;TCP transport&gt;&gt;
        +socket NWConnection
        +host String
        +port Int
        +establishConnection()
        +closeConnection()
        +sendData()
        +receiveData()
    }

    %% Fourth Row - Message Handling & Protocol
    class LSPMessageHandler {
        &lt;&lt;message handler&gt;&gt;
        +requestHandlers [String: LSPRequestHandler]
        +notificationHandlers [String: LSPNotificationHandler]
        +responseCallbacks [String: LSPResponseCallback]
        +nextRequestId Int
        +handleMessage()
        +registerRequestHandler()
        +registerNotificationHandler()
        +sendRequest()
    }

    class LSPMessage {
        &lt;&lt;LSP message&gt;&gt;
        +jsonrpc String
        +id LSPRequestId?
        +method String?
        +params Any?
        +result Any?
        +error LSPResponseError?
    }

    class LSPProtocol {
        &lt;&lt;protocol methods&gt;&gt;
        +initialize InitializeRequest
        +textDocument TextDocumentMethods
        +workspace WorkspaceMethods
        +window WindowMethods
        +completionProvider CompletionProvider
        +hoverProvider HoverProvider
        +signatureHelpProvider SignatureHelpProvider
        +definitionProvider DefinitionProvider
    }

    %% Fifth Row - Protocol Types & Configuration
    class LSPTypes {
        &lt;&lt;protocol types&gt;&gt;
        +Position LSPPosition
        +Range LSPRange
        +Location LSPLocation
        +Diagnostic LSPDiagnostic
        +CompletionItem LSPCompletionItem
        +Hover LSPHover
        +SignatureHelp LSPSignatureHelp
    }

    class ServerCapabilities {
        &lt;&lt;server capabilities&gt;&gt;
        +textDocumentSync TextDocumentSyncOptions?
        +completionProvider CompletionOptions?
        +hoverProvider Bool
        +signatureHelpProvider SignatureHelpOptions?
        +definitionProvider Bool
        +referencesProvider Bool
        +documentHighlightProvider Bool
        +documentSymbolProvider Bool
        +codeActionProvider CodeActionOptions?
        +documentFormattingProvider Bool
        +documentRangeFormattingProvider Bool
        +renameProvider RenameOptions?
        +foldingRangeProvider Bool
        +semanticTokensProvider SemanticTokensOptions?
    }

    class LSPConfigurationProvider {
        &lt;&lt;config provider&gt;&gt;
        +configurations [String: LSPServerConfiguration]
        +userConfigurations [String: Any]
        +workspaceConfigurations [String: Any]
        +getConfiguration()
        +updateConfiguration()
        +loadUserConfigurations()
        +loadWorkspaceConfigurations()
    }

    %% Sixth Row - Configuration & Path Resolution
    class LSPServerConfiguration {
        &lt;&lt;server config&gt;&gt;
        +languageId String
        +serverName String
        +command String
        +arguments [String]
        +workingDirectory String?
        +environment [String: String]
        +transportType LSPTransportType
        +initializationOptions [String: Any]?
        +settings [String: Any]?
        +retryConfiguration LSPRetryConfiguration?
    }

    class LSPPathResolver {
        &lt;&lt;path resolver&gt;&gt;
        +workspaceRoots [String]
        +fileWatcher LSPFileWatcher
        +resolveURI()
        +createURI()
        +isFileInWorkspace()
        +getRelativePath()
        +watchWorkspaceChanges()
    }

    class RemoteLSPConfiguration {
        &lt;&lt;remote config&gt;&gt;
        +remoteServers [RemoteServerConfig]
        +connectionManager RemoteConnectionManager
        +authenticator RemoteAuthenticator
        +certificatePinning CertificatePinning
        +tlsConfiguration TLSConfiguration
        +connectToRemoteServer()
        +authenticateConnection()
        +handleConnectionLoss()
        +validateServerCertificate()
    }

    %% Seventh Row - Feature Providers & Enums
    class LSPCompletionProvider {
        &lt;&lt;completion provider&gt;&gt;
        +client LSPClient
        +triggerCharacters [String]
        +resolveProvider Bool
        +provideCompletions()
        +resolveCompletion()
        +mapLSPCompletionItems()
    }

    class LSPHoverProvider {
        &lt;&lt;hover provider&gt;&gt;
        +client LSPClient
        +provideHover()
        +convertLSPHover()
    }

    class LSPDefinitionProvider {
        &lt;&lt;definition provider&gt;&gt;
        +client LSPClient
        +provideDefinition()
        +convertLSPLocations()
    }

    %% Eighth Row - Security & TLS
    class CertificatePinning {
        &lt;&lt;security&gt;&gt;
        +pinnedCertificates [SecCertificate]
        +pinnedPublicKeys [SecKey]
        +validationMode ValidationMode
        +validateCertificateChain()
        +extractPublicKey()
    }

    class TLSConfiguration {
        &lt;&lt;TLS settings&gt;&gt;
        +minimumTLSVersion TLSVersion
        +cipherSuites [CipherSuite]
        +certificateVerification Bool
        +alpnProtocols [String]
        +sessionCache URLSession.Configuration
    }

    class LSPRetryConfiguration {
        &lt;&lt;retry config&gt;&gt;
        +maxRetries Int
        +initialDelay TimeInterval
        +maxDelay TimeInterval
        +backoffFactor Double
        +jitterEnabled Bool
        +default LSPRetryConfiguration
        +aggressive LSPRetryConfiguration
        +conservative LSPRetryConfiguration
        +noRetry LSPRetryConfiguration
        +calculateNextDelay() TimeInterval
    }

    %% Bottom Row - Diagnostics & Enums
    class LSPDiagnosticsProvider {
        &lt;&lt;diagnostics provider&gt;&gt;
        +client LSPClient
        +diagnosticsByURI [String: [LSPDiagnostic]]
        +onDiagnosticsReceived
        +handlePublishDiagnostics()
        +getDiagnostics()
        +clearDiagnostics()
    }

    class LSPClientState {
        &lt;&lt;enumeration&gt;&gt;
        notStarted
        starting
        initialized
        shutdownRequested
        stopped
        failed
    }

    class LSPTransportType {
        &lt;&lt;enumeration&gt;&gt;
        stdio
        tcp
        websocket
        namedPipe
    }

    %% Key Relationships
    LSPManager --> LSPClientRegistry : uses
    LSPManager --> LSPClient : manages
    LSPManager --> LSPDocumentManager : coordinates
    LSPManager --> LSPMessageHandler : uses
    LSPManager --> LSPPathResolver : uses

    LSPClientRegistry --> LSPServerConfiguration : manages
    LSPClientRegistry --> LSPConfigurationProvider : uses

    LSPClient --> LSPTransport : uses
    LSPClient --> LSPMessageHandler : uses
    LSPClient --> LSPDocumentManager : syncs with
    LSPClient --> LSPClientState : maintains
    LSPClient --> ServerCapabilities : negotiates
    LSPClient --> LSPRetryConfiguration : uses

    LSPTransport <|-- ProcessTransport : implements
    LSPTransport <|-- WebSocketTransport : implements
    LSPTransport <|-- TCPTransport : implements
    
    WebSocketTransport --> CertificatePinning : uses
    WebSocketTransport --> TLSConfiguration : uses
    RemoteLSPConfiguration --> CertificatePinning : configures
    RemoteLSPConfiguration --> TLSConfiguration : configures

    LSPDocumentManager --> LSPTextDocument : manages
    LSPMessageHandler --> LSPMessage : processes
    LSPProtocol --> LSPTypes : uses
    LSPConfigurationProvider --> LSPServerConfiguration : provides
    LSPServerConfiguration --> LSPTransportType : specifies
    LSPServerConfiguration --> LSPRetryConfiguration : includes

    LSPCompletionProvider --> LSPClient : uses
    LSPHoverProvider --> LSPClient : uses
    LSPDefinitionProvider --> LSPClient : uses
    LSPDiagnosticsProvider --> LSPClient : uses

    %% Styling - Dark mode friendly colors
    classDef manager fill:#007AFF20,stroke:#007AFF,stroke-width:3px,color:#1D1D1F
    classDef client fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef transport fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef document fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef protocol fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef provider fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    classDef config fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef enum fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F

    class LSPManager manager
    class LSPClientRegistry client
    class LSPClient client
    class LSPTransport transport
    class ProcessTransport transport
    class WebSocketTransport transport
    class TCPTransport transport
    class LSPDocumentManager document
    class LSPTextDocument document
    class LSPMessageHandler protocol
    class LSPMessage protocol
    class LSPProtocol protocol
    class LSPTypes protocol
    class ServerCapabilities protocol
    class LSPCompletionProvider provider
    class LSPHoverProvider provider
    class LSPDefinitionProvider provider
    class LSPDiagnosticsProvider provider
    class LSPConfigurationProvider config
    class LSPServerConfiguration config
    class LSPPathResolver config
    class RemoteLSPConfiguration config
    class LSPClientState enum
    class LSPTransportType enum
    class CertificatePinning security
    class TLSConfiguration security
    class LSPRetryConfiguration config
    class ValidationMode enum
    class TLSVersion enum
```

## LSP System Flow

```mermaid
sequenceDiagram
    participant Editor as CodeEditorView
    participant Manager as LSPManager
    participant Client as LSPClient
    participant Transport as LSPTransport
    participant Server as Language Server

    Editor->>Manager: Document opened
    Manager->>Client: Initialize if needed
    Client->>Transport: Connect to server
    Transport->>Server: Initialize request
    Server-->>Transport: Server capabilities
    Transport-->>Client: Initialize response
    Client-->>Manager: Client ready

    Manager->>Client: Document sync
    Client->>Transport: textDocument/didOpen
    Transport->>Server: Notification sent
    
    Editor->>Manager: Text changed
    Manager->>Client: Document change
    Client->>Transport: textDocument/didChange
    Transport->>Server: Change notification
    
    Server-->>Transport: publishDiagnostics
    Transport-->>Client: Diagnostic notification
    Client-->>Manager: Process diagnostics
    Manager-->>Editor: Update UI

    Editor->>Manager: Request completion
    Manager->>Client: Get completions
    Client->>Transport: textDocument/completion
    Transport->>Server: Completion request
    Server-->>Transport: Completion response
    Transport-->>Client: Completion items
    Client-->>Manager: Processed completions
    Manager-->>Editor: Display completions
```

## Key LSP Features

### 1. Multi-Transport Support
- **Process Transport**: Standard stdio-based communication
- **WebSocket Transport**: Web-based language servers
- **TCP Transport**: Network-based language servers
- **Named Pipe Transport**: IPC-based communication

### 2. Document Synchronization
- **Full Sync**: Complete document content synchronization
- **Incremental Sync**: Delta-based change synchronization
- **Version Management**: Document version tracking
- **Change Batching**: Efficient change aggregation

### 3. Feature Providers
- **Completion Provider**: LSP-based code completion
- **Hover Provider**: Symbol information on hover
- **Definition Provider**: Go-to-definition functionality
- **Diagnostics Provider**: Error and warning reporting
- **Formatting Provider**: Code formatting support

### 4. Configuration Management
- **Server Registry**: Automatic server discovery
- **User Configuration**: Customizable server settings
- **Workspace Configuration**: Project-specific settings
- **Remote Support**: Cloud-based language servers

### 5. Reliability Features
- **Connection Recovery**: Automatic reconnection on failure
- **Error Handling**: Comprehensive error management
- **State Management**: Robust client state tracking
- **Resource Cleanup**: Proper resource disposal
- **Retry Configuration**: Configurable retry logic with exponential backoff
- **Jitter Support**: Prevents thundering herd problems during retries

## Benefits

1. **Language Agnostic**: Works with any LSP-compliant language server
2. **Scalable**: Handles multiple concurrent language servers
3. **Robust**: Built-in error handling and recovery with configurable retry strategies
4. **Extensible**: Plugin architecture for custom providers
5. **Performance**: Optimized message handling and caching

## Retry Configuration Examples

```swift
// Default configuration (3 retries, 1s initial delay)
let defaultRetry = LSPRetryConfiguration.default

// Aggressive retry for critical connections
let aggressiveRetry = LSPRetryConfiguration.aggressive
// 5 retries, 0.5s initial delay, 1.5x backoff

// Conservative for resource-limited environments
let conservativeRetry = LSPRetryConfiguration.conservative
// 2 retries, 2s initial delay, no jitter

// No retry for single-attempt scenarios
let noRetry = LSPRetryConfiguration.noRetry
```