# LSP Integration

@Metadata {
    @PageKind(article)
    @PageColor(purple)
}

Enable IDE-level intelligence with Language Server Protocol support.

## Overview

CodeEditorPlugin includes foundational support for the Language Server Protocol (LSP), bringing advanced IDE features like intelligent code completion, real-time diagnostics, and refactoring capabilities to your editor. However, due to platform-specific technical constraints, LSP functionality is currently **macOS-only**.

## Platform Support Status

### ✅ Supported Platforms
- **macOS 12.0+**: Full LSP support with process-based language servers

### ❌ Unsupported Platforms
- **iOS 16.0+**: Not supported due to sandboxing restrictions
- **Mac Catalyst 16.0+**: Not supported due to process limitations

> Note: LSP integration is currently in preview with support for Swift, TypeScript, and Python. Full LSP 3.17 compliance is targeted for v2.0.

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
    @State private var config = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .onAppear {
                config.lsp.enabled = true
                config.lsp.serverPath = "/usr/bin/sourcekit-lsp"
            }
            .environment(\.codeEditorConfiguration, config)
    }
}
```

### Language Server Configuration

Configure specific language servers:

```swift
// Swift
config.lsp.servers["swift"] = LSPServerConfig(
    executable: "/usr/bin/sourcekit-lsp",
    arguments: [],
    rootPath: projectPath
)

// TypeScript
config.lsp.servers["typescript"] = LSPServerConfig(
    executable: "typescript-language-server",
    arguments: ["--stdio"],
    rootPath: projectPath
)

// Python
config.lsp.servers["python"] = LSPServerConfig(
    executable: "pylsp",
    arguments: [],
    rootPath: projectPath
)
```

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

## See Also

- <doc:Plugin-Architecture>
- <doc:Performance-Monitoring>
- <doc:Advanced-Patterns>
- <doc:Platform-Abstraction>
- <doc:Catalyst-Best-Practices>