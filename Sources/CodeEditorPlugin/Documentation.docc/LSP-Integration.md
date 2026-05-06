# LSP Integration

@Metadata {
    @PageKind(article)
    @PageColor(purple)
}

Enable IDE-level intelligence with Language Server Protocol support.

## Overview

> Important: LSP functionality is only available on macOS. On iOS and Mac Catalyst, LSP features are not available due to platform limitations.

CodeEditorPlugin provides comprehensive Language Server Protocol (LSP) support, bringing advanced IDE features like intelligent code completion, real-time diagnostics, and refactoring capabilities to your editor. The framework supports two modes of operation to ensure cross-platform compatibility.

LSP support provides advanced IDE features including:
- Code completion with context awareness
- Hover information and documentation
- Go to definition and find references
- Real-time diagnostics and error reporting
- Document symbols and outline view
- Code actions and refactoring support

## Required Configuration

### Setting Workspace Root

The most important requirement for LSP to work is setting a workspace root. Without it, you'll see errors like:
```
Failed to start language server for swift: Invalid LSP response: No workspace root set
```

### SwiftUI Configuration

```swift
import SwiftUI
import CodeEditorPlugin

struct MyEditorView: View {
    @State private var code = ""
    @State private var projectURL = URL(fileURLWithPath: "/path/to/project")
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .codeWorkspaceRoot(projectURL)  // Required for LSP
    }
}
```

### Programmatic Configuration

```swift
var configuration = EditorConfiguration()
configuration.workspaceRoot = URL(fileURLWithPath: "/path/to/project")

// Apply to editor
editorView.configuration = configuration
```

### Dynamic Workspace Detection

For file-based editors, automatically detect the workspace root:

```swift
func findWorkspaceRoot(for fileURL: URL) -> URL? {
    var currentURL = fileURL.deletingLastPathComponent()
    
    // Look for common project indicators
    let projectIndicators = [
        ".git",
        "Package.swift",
        ".xcodeproj",
        ".xcworkspace",
        "Cargo.toml",
        "package.json",
        "pyproject.toml",
        "go.mod"
    ]
    
    while currentURL.path != "/" {
        for indicator in projectIndicators {
            let indicatorURL = currentURL.appendingPathComponent(indicator)
            if FileManager.default.fileExists(atPath: indicatorURL.path) {
                return currentURL
            }
        }
        currentURL = currentURL.deletingLastPathComponent()
    }
    
    // Fallback to file's directory
    return fileURL.deletingLastPathComponent()
}
```

## Platform Support Matrix

| Feature | macOS | iOS | Mac Catalyst |
|---------|-------|-----|--------------|
| **Local LSP Servers** | ✅ Full support | ❌ Not available | ❌ Not available |
| **Remote LSP Servers** | ✅ Full support | ✅ Full support | ✅ Full support |

### Local LSP Servers (macOS Only)

Local language servers run as child processes and provide the best performance and integration:

- **macOS 12.0+**: Full support using ProcessTransport
- **iOS/Catalyst**: Not supported due to platform restrictions (no Process API)

### Remote LSP Servers (All Platforms)

Connect to language servers over WebSocket for cross-platform support:

- **All platforms**: Full support via WebSocketTransport
- **Use cases**: iOS apps, cloud-based development, shared language servers
- **Security**: TLS/SSL support with certificate validation

> Important: When developing for iOS or Mac Catalyst, you must use remote LSP servers. Plan your architecture accordingly.

> Note: LSP integration is currently in preview with support for Swift, TypeScript, and Python. Full LSP 3.17 compliance is targeted for v2.0.

## Supported Language Servers

### Swift (sourcekit-lsp)
- **Auto-detected**: Yes (bundled with Xcode)
- **Path**: `/usr/bin/sourcekit-lsp` or Xcode toolchain
- **Features**: Full support including SwiftSyntax integration

### TypeScript/JavaScript
- **Installation**: `npm install -g typescript-language-server`
- **Features**: IntelliSense, type checking, refactoring

### Python (pylsp)
- **Installation**: `pip install python-lsp-server`
- **Features**: Auto-completion, linting, formatting

### Rust (rust-analyzer)
- **Installation**: `rustup component add rust-analyzer`
- **Features**: Type inference, macro expansion, inlay hints

### Go (gopls)
- **Installation**: `go install golang.org/x/tools/gopls@latest`
- **Features**: Auto-imports, formatting, diagnostics

## Supported Features

### Code Completion

Context-aware suggestions from language servers:

```swift
editor.lspConfiguration.enableCompletion = true

// Triggers intelligent completion
editor.completionHandler = { context in
    let completions = await lspClient.getCompletions(at: context.position)
    return completions.map { CompletionItem($0) }
}
```

### Diagnostics

Real-time error and warning detection:

```swift
editor.lspConfiguration.enableDiagnostics = true

// Diagnostics appear automatically as you type
editor.diagnosticHandler = { diagnostics in
    for diagnostic in diagnostics {
        editor.showDiagnostic(
            diagnostic,
            at: diagnostic.range,
            severity: diagnostic.severity
        )
    }
}
```

### Go to Definition

Navigate to symbol definitions:

```swift
editor.defineAction = { position in
    let definition = await lspClient.getDefinition(at: position)
    if let location = definition {
        editor.navigateTo(location)
    }
}
```

### Hover Information

Rich documentation on hover:

```swift
editor.hoverHandler = { position in
    let hover = await lspClient.getHover(at: position)
    return HoverInfo(
        content: hover.contents,
        range: hover.range
    )
}
```

### Find References

Locate all usages of a symbol:

```swift
editor.referencesAction = { position in
    let references = await lspClient.getReferences(at: position)
    editor.showReferences(references)
}
```

## Configuration

### Enabling LSP

```swift
// SwiftUI
struct LSPEditor: View {
    @State private var lspClient: LSPClient?
    @State private var code = ""
    
    var body: some View {
        CodeEditor(text: $code)
            .task {
                let client = await LSPClient.createAndSetup()
                let server = LSPServerConfiguration.remote(
                    RemoteLSPConfiguration.publicServer(
                        url: URL(string: "wss://lsp.example.com/swift")!
                    )
                )

                try? await client.connect(configuration: server, language: .swift)
                lspClient = client
            }
    }
}
```

### Language Server Configuration

Configure specific language servers:

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
let manager = LSPManager(memoryMonitor: MemoryMonitor(), workspaceRoot: projectPath)

// Swift local server
manager.registerLanguageServer(LanguageServerConfig(
    languageId: "swift",
    serverPath: "/usr/bin/sourcekit-lsp",
    fileExtensions: ["swift"]
))

try await manager.startLanguageServer(for: "swift")

// Python local server
manager.registerLanguageServer(LanguageServerConfig(
    languageId: "python",
    serverPath: "pylsp",
    fileExtensions: ["py", "pyw"]
))
#endif
```

### Remote LSP Configuration (iOS/Catalyst Compatible)

For platforms without local process support, use remote LSP servers:

```swift
// Remote LSP for iOS/Catalyst
let client = await LSPClient.createAndSetup()
let server = LSPServerConfiguration.remote(
    RemoteLSPConfiguration(
        serverURL: URL(string: "wss://lsp.example.com/swift")!,
        authentication: .bearerToken("your-token"),
        reconnectPolicy: .exponentialBackoff(maxAttempts: 5)
    )
)

try await client.connect(configuration: server, language: .swift)

// SwiftUI example for iOS
struct IOSLSPEditor: View {
    @State private var lspClient: LSPClient?
    @State private var code = ""
    
    var body: some View {
        CodeEditor(text: $code)
            .task {
                // Remote LSP works on all platforms
                let client = await LSPClient.createAndSetup()
                let server = LSPServerConfiguration.remote(
                    RemoteLSPConfiguration.publicServer(
                        url: URL(string: "wss://typescript-lsp.cloud.com")!
                    )
                )
                try? await client.connect(configuration: server, language: .typescript)
                lspClient = client
            }
    }
}
```

> Tip: Many cloud IDE providers offer WebSocket-based LSP endpoints that work perfectly with iOS apps.

### Secure Remote LSP Configuration

For production environments, use certificate pinning and enhanced security:

```swift
// Certificate pinning with public key
let secureLSPConfig = RemoteLSPConfiguration.enterpriseServer(
    url: URL(string: "wss://secure-lsp.company.com")!,
    authentication: .bearerToken(secureToken),
    pinnedPublicKeys: [
        Data(base64Encoded: "AAAB3NzaC1yc2EAAAADAQABAAAB...")!,
        Data(base64Encoded: "AAAB3NzaC1yc2EAAAADAQABAAAC...")!
    ],
    backupKeys: [
        // Backup keys for certificate rotation
        Data(base64Encoded: "AAAB3NzaC1yc2EAAAADAQABAAAD...")!
    ]
)

// Custom security configuration
let customSecureConfig = RemoteLSPConfiguration(
    serverURL: URL(string: "wss://lsp.secure.com")!,
    authentication: .oauth2(accessToken: oauthToken),
    certificatePinning: CertificatePinning(
        method: .publicKey,
        pinnedData: pinnedKeys,
        allowDebugBypass: false  // Strict in production
    ),
    securityOptions: SecurityOptions(
        minimumTLSVersion: .tls13,
        allowedCipherSuites: ["TLS_AES_256_GCM_SHA384"],
        requireOCSPStapling: true,
        requireCertificateTransparency: true
    )
)

// Load certificates from files
let pinning = try CertificatePinning.fromCertificateFiles([
    "/path/to/server-cert.pem",
    "/path/to/intermediate-cert.pem"
])
```

> Important: Certificate pinning helps prevent man-in-the-middle attacks but requires careful management during certificate rotation.

## LSP Client

### Client Lifecycle

```swift
class LSPManager {
    func startServer(for language: Language) async throws {
        let config = serverConfigs[language]
        let client = LSPClient(configuration: config)
        
        try await client.initialize(
            rootPath: projectRoot,
            capabilities: clientCapabilities
        )
        
        activeClients[language] = client
    }
    
    func stopServer(for language: Language) async {
        if let client = activeClients[language] {
            await client.shutdown()
            activeClients[language] = nil
        }
    }
}
```

### Request/Response

```swift
// Text document synchronization
client.didOpenTextDocument(uri: documentURI, text: content)
client.didChangeTextDocument(uri: documentURI, changes: changes)
client.didSaveTextDocument(uri: documentURI)

// Language features
let completions = try await client.completion(at: position)
let hover = try await client.hover(at: position)
let definition = try await client.definition(at: position)
```

## Advanced Features

### Code Actions

Quick fixes and refactoring:

```swift
editor.codeActionHandler = { range, context in
    let actions = await lspClient.getCodeActions(
        range: range,
        context: context
    )
    
    return actions.map { action in
        CodeAction(
            title: action.title,
            kind: action.kind,
            edit: action.edit
        )
    }
}
```

### Rename Symbol

Project-wide renaming:

```swift
editor.renameHandler = { position, newName in
    let edit = await lspClient.rename(
        at: position,
        newName: newName
    )
    
    // Apply workspace edit
    for change in edit.changes {
        applyTextEdit(change)
    }
}
```

### Formatting

Document and range formatting:

```swift
// Format entire document
let edits = await lspClient.formatting(uri: documentURI)
editor.applyTextEdits(edits)

// Format selection
let rangeEdits = await lspClient.rangeFormatting(
    uri: documentURI,
    range: selectedRange
)
editor.applyTextEdits(rangeEdits)
```

## Custom Language Servers

### Protocol Extensions

Extend LSP with custom capabilities:

```swift
extension LSPClient {
    // Custom request
    func customRequest<T: Codable>(
        method: String,
        params: T
    ) async throws -> LSPResponse {
        return try await sendRequest(
            method: method,
            params: params
        )
    }
}
```

### Server Implementation

Create minimal language servers:

```swift
// Example: Simple JSON schema validator
class JSONSchemaServer: LanguageServer {
    func initialize(_ params: InitializeParams) -> InitializeResult {
        InitializeResult(
            capabilities: ServerCapabilities(
                textDocumentSync: .full,
                diagnosticProvider: true
            )
        )
    }
    
    func validateDocument(_ uri: DocumentURI) async -> [Diagnostic] {
        // Validate JSON against schema
    }
}
```

## Performance Considerations

### Connection Pooling

Reuse server connections:

```swift
class LSPConnectionPool {
    private var connections: [Language: LSPClient] = [:]
    
    func getConnection(for language: Language) async -> LSPClient {
        if let existing = connections[language] {
            return existing
        }
        
        let client = await createClient(for: language)
        connections[language] = client
        return client
    }
}
```

### Request Debouncing

Optimize server communication:

```swift
// Debounce rapid typing
let debouncer = Debouncer(delay: 0.3)

editor.textDidChange = { change in
    debouncer.debounce {
        await lspClient.didChangeTextDocument(change)
    }
}
```

### Caching

Cache expensive operations:

```swift
class LSPCache {
    private var definitionCache: [Position: Location] = [:]
    
    func getDefinition(at position: Position) async -> Location? {
        if let cached = definitionCache[position] {
            return cached
        }
        
        let definition = await lspClient.getDefinition(at: position)
        definitionCache[position] = definition
        return definition
    }
}
```

## Troubleshooting Setup Issues

### "No workspace root set" Error

**Cause**: LSPManager created without workspace root configuration.

**Solution**: Always set workspace root before using LSP features:
```swift
// SwiftUI
.codeWorkspaceRoot(projectURL)

// UIKit/AppKit
config.workspaceRoot = projectURL
```

### Language Server Not Found

**Cause**: Language server executable not in PATH.

**Solution**: Install the language server or specify full path:
```swift
// Check if language server is available
let availability = lspManager.getLanguageServerAvailability()
print(availability)

// Find language server paths
let paths = lspManager.findLanguageServerPaths(for: "sourcekit-lsp")
print(paths)
```

### No Completions Appearing

**Cause**: Document not opened in LSP or wrong file path.

**Solution**: Ensure file paths are absolute and documents are opened:
```swift
// Use absolute paths
let absolutePath = fileURL.path
try await lspManager.openDocument(
    filePath: absolutePath,
    content: documentContent
)
```

## Best Practices

1. **Always Set Workspace Root**: This is mandatory for LSP to function.

2. **Use Absolute Paths**: LSP requires absolute file paths, not relative ones.

3. **Handle Async Operations**: LSP operations are asynchronous:
   ```swift
   Task {
       try await lspManager.startLanguageServer(for: .swift)
   }
   ```

4. **Monitor LSP Status**: Check if servers are running:
   ```swift
   let activeClients = lspManager.activeClients
   let isSwiftLSPRunning = activeClients["swift"] != nil
   ```

5. **Clean Up Resources**: Stop servers when done:
   ```swift
   lspManager.stopAllServers()
   ```

## Technical Analysis

### Platform Dependencies

The LSP implementation relies on platform-specific capabilities:

#### Process Management
```swift
// macOS-only code in LSPClient.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
private var serverProcess: Process?
private var stdinPipe: Pipe?
private var stdoutPipe: Pipe?
#endif
```

**iOS/Catalyst Limitations:**
- iOS sandboxing prevents spawning external processes
- `Process` class is not available for security reasons
- Direct pipe communication requires system-level access

#### Inter-Process Communication
```swift
private func startServerProcess() async throws {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: serverPath)
    // Configure stdin/stdout pipes for LSP communication
    #else
    throw LSPError.serverError(message: "LSP not supported on this platform")
    #endif
}
```

## Alternative Solutions for iOS/Catalyst

### 1. Network-Based LSP (Recommended)

Replace process-based communication with WebSocket/HTTP communication:

```swift
protocol LSPTransport {
    func connect() async throws
    func sendMessage(_ message: LSPMessage) async throws
    func receiveMessage() async throws -> LSPMessage
}

class WebSocketLSPTransport: LSPTransport {
    private var webSocketTask: URLSessionWebSocketTask?
    
    func connect(to serverURL: URL) async throws {
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
    }
}
```

**Architecture:**
```
┌─────────────────┐    WebSocket/HTTP    ┌──────────────────┐
│   iOS/Catalyst  │ ◄─────────────────► │   Cloud LSP      │
│   CodeEditor    │                     │   Service        │
└─────────────────┘                     └──────────────────┘
                                               │
                                        ┌──────▼──────┐
                                        │  Language   │
                                        │  Servers    │
                                        └─────────────┘
```

### 2. Enhanced Local Intelligence

Improve existing completion providers:

```swift
class EnhancedSwiftCompletionProvider: CompletionProvider {
    private let parser: SwiftParser  // Local AST parser
    private let symbolIndex: LocalSymbolIndex
    
    func completions(for context: CompletionContextModel) async -> CompletionResult {
        // Parse current file for symbols
        let symbols = await parser.parseSymbols(context.text)
        
        // Analyze context for intelligent completions
        let contextualCompletions = analyzeContext(symbols, context)
        
        return combineCompletions(contextualCompletions, basicCompletions)
    }
}
```

### 3. WebAssembly Language Servers

Run language servers compiled to WebAssembly:

```swift
import WebAssembly

class WASMLSPProvider {
    private let wasmRuntime: WASMRuntime
    
    func initializeLanguageServer(wasmData: Data) async throws {
        wasmRuntime = try WASMRuntime(wasmData)
        try await wasmRuntime.call("initialize", params: initParams)
    }
}
```

## Platform Feature Matrix

| Feature | macOS | iOS | Mac Catalyst | Implementation |
|---------|-------|-----|--------------|----------------|
| **Basic Completions** | ✅ | ✅ | ✅ | Local providers |
| **Syntax Highlighting** | ✅ | ✅ | ✅ | Local regex/AST |
| **Process-based LSP** | ✅ | ❌ | ❌ | Process spawning |
| **Network LSP** | 🔄 | 🔄 | 🔄 | Planned implementation |
| **Local Symbol Index** | 🔄 | 🔄 | 🔄 | Planned enhancement |
| **Cloud Intelligence** | 🔄 | 🔄 | 🔄 | Future integration |

**Legend:**
- ✅ Fully supported
- ❌ Not supported (technical limitations)
- 🔄 Planned/in development

## Current Workarounds

### For iOS/Catalyst Development

```swift
// Configuration for iOS/Catalyst without LSP
let config = EditorConfiguration()
config.behavior.enableCodeCompletion = true  // Uses local providers
config.behavior.enableLSP = false            // Disable LSP features
config.display.showCompletionPopup = true    // Local completions still work
```

The existing completion system provides:
- 20 language-specific completion providers
- Context-aware completions
- Snippet support
- Symbol detection within files

## Recommended Implementation Strategy

### Phase 1: Network LSP Foundation (2-3 weeks)

1. Create transport abstraction layer
2. Implement WebSocket transport
3. Update LSPManager for multi-transport

### Phase 2: Enhanced Local Intelligence (3-4 weeks)

1. Improve completion providers
2. Add local symbol indexing
3. Implement basic type checking

### Phase 3: Hybrid Cloud + Local (4-5 weeks)

1. Intelligent caching
2. Performance optimization
3. Configuration and preferences

## Troubleshooting

### Debug Logging

Enable LSP communication logging:

```swift
LSPLogger.level = .verbose
LSPLogger.logFile = URL(fileURLWithPath: "~/lsp.log")
```

### Common Issues

1. **Server Not Starting**
   - Verify server executable path
   - Check server permissions
   - Review initialization parameters
   - Confirm platform is macOS

2. **No Completions**
   - Ensure file is saved (some servers require it)
   - Check server capabilities
   - Verify document synchronization
   - Use local providers on iOS/Catalyst

3. **Performance Issues**
   - Enable request debouncing
   - Implement caching
   - Use connection pooling

4. **Platform Not Supported**
   - Use enhanced local completions
   - Consider cloud-based alternatives
   - Monitor for future platform updates

## Future Roadmap

### v1.5
- Network-based LSP transport
- Enhanced local intelligence
- WebAssembly language server support

### v2.0
- Full cross-platform LSP support
- Cloud LSP service integration
- Hybrid local/cloud intelligence
- Multi-root workspace support

## Conclusion

While LSP support is currently macOS-only due to platform security restrictions, CodeEditorPlugin has excellent foundations for implementing alternative solutions. The existing completion system already provides excellent code intelligence for most use cases, making the editor highly functional on all platforms even without full LSP support.

## Example: Complete Setup

```swift
import SwiftUI
import CodeEditorPlugin

struct ProjectEditorView: View {
    @State private var code = ""
    @State private var configuration = EditorConfiguration()
    
    let projectURL: URL
    let fileURL: URL
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(detectLanguage())
            .codeWorkspaceRoot(projectURL)
            .environment(\.codeEditorConfiguration, configuration)
            .onAppear {
                setupLSP()
            }
    }
    
    private func setupLSP() {
        // Enable completion features
        configuration.behavior.autoCompletion = true
        configuration.behavior.showCompletionOnTyping = true
        
        // Set workspace root
        configuration.workspaceRoot = projectURL
    }
    
    private func detectLanguage() -> Language {
        switch fileURL.pathExtension {
        case "swift": return .swift
        case "py": return .python
        case "js": return .javascript
        case "ts": return .typescript
        default: return .plainText
        }
    }
}
```

## See Also

- <doc:Performance-Monitoring>
- <doc:Advanced-Patterns>
- <doc:Platform-Abstraction>
- <doc:Catalyst-Best-Practices>
- <doc:LSP-Retry-Configuration>
